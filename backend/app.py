"""API REST que consume la app Flutter.

Este proceso es SOLO la API (lecturas rápidas desde SQLite + proxy del
clima). La ingesta de sismos y el envío de pushes viven en ingest.py, un
proceso aparte pensado para correr como "Always-on task" en PythonAnywhere
(plan Hacker) — separar los dos componentes fue justamente la refactor que
había quedado pendiente. Ver backend/README.md para el deploy.
"""
import logging
from datetime import datetime, timedelta, timezone

from flask import Flask, jsonify, request
from flask_cors import CORS

import storage
import sources
from config import Config

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("quakewatch.app")

app = Flask(__name__)
CORS(app, origins=Config.CORS_ORIGINS)

storage.init_db()

_PERIOD_TO_TIMEDELTA = {
    "hour": timedelta(hours=1),
    "day": timedelta(days=1),
    "week": timedelta(days=7),
    "month": timedelta(days=30),
}


def _earthquake_to_json(row: dict) -> dict:
    return {
        "id": row["id"],
        "source": row["source"],
        "magnitude": row["magnitude"],
        "magnitude_type": row.get("magnitude_type"),
        "place": row["place"],
        "time": row["time_utc"],
        "latitude": row["latitude"],
        "longitude": row["longitude"],
        "depth_km": row.get("depth_km"),
        "url": row.get("url"),
        "tsunami_warning": bool(row.get("tsunami_warning")),
    }


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


@app.get("/earthquakes/all")
def earthquakes_all():
    min_magnitude = float(request.args.get("min_magnitude", 2.5))
    period = request.args.get("period", "day")
    delta = _PERIOD_TO_TIMEDELTA.get(period, timedelta(days=1))
    since = datetime.now(timezone.utc) - delta

    rows = storage.get_recent(
        min_magnitude=min_magnitude, since_utc=since, limit=Config.DEFAULT_RESULT_LIMIT
    )
    return jsonify({"earthquakes": [_earthquake_to_json(r) for r in rows]})


@app.get("/earthquakes/nearby")
def earthquakes_nearby():
    try:
        lat = float(request.args["lat"])
        lon = float(request.args["lon"])
    except (KeyError, ValueError):
        return jsonify({"error": "Parámetros lat/lon requeridos y numéricos"}), 400

    radius_km = float(request.args.get("radius_km", 300))
    min_magnitude = float(request.args.get("min_magnitude", 2.5))
    # Ventana amplia (30 días) porque "cerca de mí" prioriza cobertura
    # geográfica, no reciente-nomás; el cliente ordena/filtra visualmente.
    since = datetime.now(timezone.utc) - timedelta(days=30)

    rows = storage.get_nearby(
        latitude=lat, longitude=lon, radius_km=radius_km,
        min_magnitude=min_magnitude, since_utc=since, limit=Config.DEFAULT_RESULT_LIMIT,
    )
    payload = []
    for r in rows:
        item = _earthquake_to_json(r)
        item["distance_km"] = r.get("distance_km")
        payload.append(item)
    return jsonify({"earthquakes": payload})


@app.get("/weather/alerts")
def weather_alerts():
    try:
        lat = float(request.args["lat"])
        lon = float(request.args["lon"])
    except (KeyError, ValueError):
        return jsonify({"error": "Parámetros lat/lon requeridos y numéricos"}), 400

    try:
        data = sources.fetch_weather_alerts(lat, lon)
    except RuntimeError as e:
        return jsonify({"error": str(e)}), 503
    except Exception as e:  # error de red / OpenWeatherMap caído
        log.exception("Fallo consultando OpenWeatherMap")
        return jsonify({"error": f"No se pudo consultar el clima: {e}"}), 502

    return jsonify(data)


@app.post("/devices/register")
def register_device():
    body = request.get_json(silent=True) or {}
    fcm_token = body.get("fcm_token")
    if not fcm_token:
        return jsonify({"error": "fcm_token requerido"}), 400

    storage.upsert_device(
        fcm_token=fcm_token,
        platform=body.get("platform", "android"),
        latitude=body.get("latitude"),
        longitude=body.get("longitude"),
        radius_km=float(body.get("radius_km", 300)),
        min_magnitude=float(body.get("min_magnitude", 4.0)),
    )
    return jsonify({"status": "registered"})


if __name__ == "__main__":
    # Solo para desarrollo local. En PythonAnywhere, app.app es lo que se
    # apunta desde el WSGI config (ver backend/README.md).
    app.run(debug=True, port=5000)
