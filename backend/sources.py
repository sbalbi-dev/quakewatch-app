"""Normaliza eventos de USGS y EMSC al mismo formato de dict que espera
storage.upsert_earthquake, y trae el feed de alertas de OpenWeatherMap.
"""
import logging
from datetime import datetime, timezone

import requests

from config import Config

log = logging.getLogger("quakewatch.sources")


def fetch_usgs_events(feed: str = None) -> list[dict]:
    feed = feed or Config.USGS_POLL_FEED
    url = f"{Config.USGS_FEED_BASE}/{feed}.geojson"
    resp = requests.get(url, timeout=20)
    resp.raise_for_status()
    body = resp.json()

    events = []
    for feature in body.get("features", []):
        props = feature["properties"]
        coords = feature["geometry"]["coordinates"]
        mag = props.get("mag")
        if mag is None:
            continue
        events.append({
            "id": feature["id"],
            "source": "usgs",
            "magnitude": float(mag),
            "magnitude_type": props.get("magType"),
            "place": props.get("place") or "Ubicación desconocida",
            "time_utc": datetime.fromtimestamp(
                props["time"] / 1000, tz=timezone.utc
            ).isoformat(),
            "latitude": coords[1],
            "longitude": coords[0],
            "depth_km": coords[2] if len(coords) > 2 else None,
            "url": props.get("url"),
            "tsunami_warning": props.get("tsunami") == 1,
        })
    return events


def normalize_emsc_message(payload: dict) -> dict | None:
    """Convierte un mensaje del websocket de SeismicPortal/EMSC
    (formato tipo GeoJSON con 'action': 'create'|'update') a nuestro dict
    común. Devuelve None si el mensaje no trae datos de sismo (heartbeats,
    etc.) o si es una acción de borrado.
    """
    data = payload.get("data")
    if not data:
        return None
    action = payload.get("action", "create")
    if action == "delete":
        return None

    props = data.get("properties", {})
    geometry = data.get("geometry", {})
    coords = geometry.get("coordinates")
    mag = props.get("mag")
    if mag is None or not coords:
        return None

    unid = props.get("unid") or data.get("id")
    time_str = props.get("time")
    try:
        time_utc = datetime.fromisoformat(time_str.replace("Z", "+00:00")).astimezone(timezone.utc)
    except (TypeError, ValueError):
        time_utc = datetime.now(timezone.utc)

    return {
        "id": f"emsc_{unid}",
        "source": "emsc",
        "magnitude": float(mag),
        "magnitude_type": props.get("magtype"),
        "place": props.get("flynn_region") or "Ubicación desconocida",
        "time_utc": time_utc.isoformat(),
        "latitude": coords[1],
        "longitude": coords[0],
        "depth_km": coords[2] if len(coords) > 2 else props.get("depth"),
        "url": f"https://www.emsc-csem.org/Earthquake/?id={props.get('source_id', unid)}",
        "tsunami_warning": False,
    }


def fetch_weather_alerts(lat: float, lon: float) -> dict:
    """Proxea el One Call API 3.0 de OpenWeatherMap (clima actual + alerts).
    Mantener la key acá (server-side) es justamente el motivo de tener este
    endpoint en vez de llamar OpenWeatherMap directo desde el celular.
    """
    if not Config.OPENWEATHER_API_KEY:
        raise RuntimeError(
            "QW_OPENWEATHER_API_KEY no está configurada en el entorno del backend."
        )
    resp = requests.get(
        Config.OPENWEATHER_ONECALL_URL,
        params={
            "lat": lat,
            "lon": lon,
            "units": "metric",
            "lang": "es",
            "exclude": "minutely,hourly,daily",
            "appid": Config.OPENWEATHER_API_KEY,
        },
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()
