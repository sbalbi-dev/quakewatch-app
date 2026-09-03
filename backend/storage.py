"""Capa de acceso a SQLite compartida entre app.py (API) e ingest.py
(worker de ingesta). Usar siempre a través de estas funciones para que el
esquema y la lógica de dedup vivan en un solo lugar.
"""
import math
import sqlite3
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone

from config import Config

_SCHEMA = """
CREATE TABLE IF NOT EXISTS earthquakes (
    id TEXT PRIMARY KEY,
    source TEXT NOT NULL,
    magnitude REAL NOT NULL,
    magnitude_type TEXT,
    place TEXT,
    time_utc TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    depth_km REAL,
    url TEXT,
    tsunami_warning INTEGER DEFAULT 0,
    notified INTEGER DEFAULT 0,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_earthquakes_time ON earthquakes(time_utc);
CREATE INDEX IF NOT EXISTS idx_earthquakes_notified ON earthquakes(notified);

CREATE TABLE IF NOT EXISTS devices (
    fcm_token TEXT PRIMARY KEY,
    platform TEXT,
    latitude REAL,
    longitude REAL,
    radius_km REAL DEFAULT 300,
    min_magnitude REAL DEFAULT 4.0,
    updated_at TEXT NOT NULL
);
"""


@contextmanager
def get_connection():
    conn = sqlite3.connect(Config.DB_PATH, timeout=30)
    conn.row_factory = sqlite3.Row
    # WAL permite que app.py (lecturas) e ingest.py (escrituras) convivan
    # sin bloquearse todo el tiempo entre sí.
    conn.execute("PRAGMA journal_mode=WAL;")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db():
    with get_connection() as conn:
        conn.executescript(_SCHEMA)


def haversine_km(lat1, lon1, lat2, lon2):
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


# Alias retrocompatible por si algún módulo interno todavía lo importa con
# el nombre viejo.
_haversine_km = haversine_km


def find_duplicate(conn, *, magnitude, time_utc, latitude, longitude):
    """Busca un sismo ya guardado (de OTRA fuente) que probablemente sea el
    mismo evento físico, dentro de una ventana de tiempo/distancia/magnitud.
    Se usa para no mandar dos notificaciones distintas para un mismo sismo
    reportado por USGS y EMSC casi al mismo tiempo.
    """
    window_start = (time_utc - timedelta(seconds=Config.DEDUP_TIME_WINDOW_SECONDS)).isoformat()
    window_end = (time_utc + timedelta(seconds=Config.DEDUP_TIME_WINDOW_SECONDS)).isoformat()
    rows = conn.execute(
        "SELECT * FROM earthquakes WHERE time_utc BETWEEN ? AND ?",
        (window_start, window_end),
    ).fetchall()
    for row in rows:
        distance = _haversine_km(latitude, longitude, row["latitude"], row["longitude"])
        if distance <= Config.DEDUP_DISTANCE_KM and abs(row["magnitude"] - magnitude) <= 1.0:
            return row
    return None


def upsert_earthquake(eq: dict) -> tuple[bool, str]:
    """Inserta un sismo si es nuevo. Devuelve (es_nuevo, id_final).

    Si ya existe un evento equivalente de otra fuente (ver find_duplicate),
    NO se inserta una fila nueva: se devuelve es_nuevo=False con el id del
    que ya estaba guardado, para no duplicar notificaciones.
    """
    time_utc = datetime.fromisoformat(eq["time_utc"])
    with get_connection() as conn:
        existing = conn.execute(
            "SELECT id FROM earthquakes WHERE id = ?", (eq["id"],)
        ).fetchone()
        if existing:
            return False, eq["id"]

        duplicate = find_duplicate(
            conn,
            magnitude=eq["magnitude"],
            time_utc=time_utc,
            latitude=eq["latitude"],
            longitude=eq["longitude"],
        )
        if duplicate:
            return False, duplicate["id"]

        conn.execute(
            """INSERT INTO earthquakes
               (id, source, magnitude, magnitude_type, place, time_utc,
                latitude, longitude, depth_km, url, tsunami_warning, notified, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)""",
            (
                eq["id"], eq["source"], eq["magnitude"], eq.get("magnitude_type"),
                eq.get("place"), eq["time_utc"], eq["latitude"], eq["longitude"],
                eq.get("depth_km"), eq.get("url"), int(eq.get("tsunami_warning", False)),
                datetime.now(timezone.utc).isoformat(),
            ),
        )
        return True, eq["id"]


def mark_notified(earthquake_id: str):
    with get_connection() as conn:
        conn.execute(
            "UPDATE earthquakes SET notified = 1 WHERE id = ?", (earthquake_id,)
        )


def get_unnotified_earthquakes():
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT * FROM earthquakes WHERE notified = 0 ORDER BY time_utc ASC"
        ).fetchall()
        return [dict(r) for r in rows]


def get_recent(*, min_magnitude: float, since_utc: datetime, limit: int):
    with get_connection() as conn:
        rows = conn.execute(
            """SELECT * FROM earthquakes
               WHERE magnitude >= ? AND time_utc >= ?
               ORDER BY time_utc DESC LIMIT ?""",
            (min_magnitude, since_utc.isoformat(), limit),
        ).fetchall()
        return [dict(r) for r in rows]


def get_nearby(*, latitude: float, longitude: float, radius_km: float,
               min_magnitude: float, since_utc: datetime, limit: int):
    with get_connection() as conn:
        rows = conn.execute(
            """SELECT * FROM earthquakes
               WHERE magnitude >= ? AND time_utc >= ?
               ORDER BY time_utc DESC LIMIT ?""",
            (min_magnitude, since_utc.isoformat(), limit * 5),
        ).fetchall()
    result = []
    for row in rows:
        d = dict(row)
        distance = _haversine_km(latitude, longitude, d["latitude"], d["longitude"])
        if distance <= radius_km:
            d["distance_km"] = round(distance, 1)
            result.append(d)
    result.sort(key=lambda r: r["distance_km"])
    return result[:limit]


def upsert_device(*, fcm_token, platform, latitude, longitude, radius_km, min_magnitude):
    with get_connection() as conn:
        conn.execute(
            """INSERT INTO devices (fcm_token, platform, latitude, longitude,
                                     radius_km, min_magnitude, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(fcm_token) DO UPDATE SET
                   platform=excluded.platform,
                   latitude=COALESCE(excluded.latitude, devices.latitude),
                   longitude=COALESCE(excluded.longitude, devices.longitude),
                   radius_km=excluded.radius_km,
                   min_magnitude=excluded.min_magnitude,
                   updated_at=excluded.updated_at""",
            (fcm_token, platform, latitude, longitude, radius_km, min_magnitude,
             datetime.now(timezone.utc).isoformat()),
        )


def get_devices_near(*, latitude: float, longitude: float, min_magnitude: float):
    """Dispositivos cuyo radio configurado cubre este epicentro y cuyo
    umbral de magnitud fue superado por el sismo."""
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT * FROM devices WHERE min_magnitude <= ? "
            "AND latitude IS NOT NULL AND longitude IS NOT NULL",
            (min_magnitude,),
        ).fetchall()
    matches = []
    for row in rows:
        distance = _haversine_km(latitude, longitude, row["latitude"], row["longitude"])
        if distance <= row["radius_km"]:
            matches.append(dict(row))
    return matches


def prune_old_devices(days: int = 90):
    """Los tokens FCM pueden quedar obsoletos (app desinstalada). Se
    limpian los que no se re-registraron en mucho tiempo."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    with get_connection() as conn:
        conn.execute("DELETE FROM devices WHERE updated_at < ?", (cutoff,))
