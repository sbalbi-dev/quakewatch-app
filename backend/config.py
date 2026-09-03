"""Configuración centralizada del backend, vía variables de entorno.

En PythonAnywhere se cargan desde el panel "Web > Environment variables"
(o desde un .env leído acá con python-dotenv para desarrollo local).
"""
import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    # SQLite es más que suficiente para el volumen de este proyecto
    # (uso personal/grupo chico, según lo hablado). Se puede migrar a
    # Postgres más adelante sin tocar la interfaz de storage.py.
    DB_PATH = os.environ.get("QW_DB_PATH", os.path.join(
        os.path.dirname(__file__), "quakewatch.db"))

    # --- Fuentes de datos de sismos ---
    USGS_FEED_BASE = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary"
    # Feed que consume el ingestor cada POLL_INTERVAL_SECONDS. "all_hour" trae
    # todo (sin piso de magnitud) de la última hora; el filtrado por umbral
    # de notificación se hace por dispositivo en ingest.py.
    USGS_POLL_FEED = os.environ.get("QW_USGS_POLL_FEED", "all_hour")
    POLL_INTERVAL_SECONDS = int(os.environ.get("QW_POLL_INTERVAL_SECONDS", "60"))

    EMSC_WEBSOCKET_URL = os.environ.get(
        "QW_EMSC_WS_URL", "wss://www.seismicportal.eu/standing_order/websocket"
    )
    ENABLE_EMSC_WEBSOCKET = os.environ.get("QW_ENABLE_EMSC", "true").lower() == "true"

    # Umbral mínimo global: eventos por debajo de esto ni se guardan (evita
    # llenar la base con microsismos M0.x irrelevantes para alertas).
    MIN_MAGNITUDE_STORE = float(os.environ.get("QW_MIN_MAGNITUDE_STORE", "1.5"))

    # Tolerancia para considerar que dos eventos (uno de USGS, otro de EMSC)
    # son el mismo sismo reportado por ambas fuentes.
    DEDUP_TIME_WINDOW_SECONDS = int(os.environ.get("QW_DEDUP_TIME_WINDOW", "120"))
    DEDUP_DISTANCE_KM = float(os.environ.get("QW_DEDUP_DISTANCE_KM", "75"))

    # --- Clima ---
    OPENWEATHER_API_KEY = os.environ.get("QW_OPENWEATHER_API_KEY", "")
    OPENWEATHER_ONECALL_URL = "https://api.openweathermap.org/data/3.0/onecall"

    # --- Push notifications (Firebase Admin SDK) ---
    # Ruta al JSON de la service account de Firebase (Project settings >
    # Service accounts > Generate new private key). NO lo subas al repo.
    FIREBASE_CREDENTIALS_PATH = os.environ.get(
        "QW_FIREBASE_CREDENTIALS_PATH",
        os.path.join(os.path.dirname(__file__), "firebase-service-account.json"),
    )

    # --- API ---
    CORS_ORIGINS = os.environ.get("QW_CORS_ORIGINS", "*")
    DEFAULT_RESULT_LIMIT = int(os.environ.get("QW_RESULT_LIMIT", "500"))
