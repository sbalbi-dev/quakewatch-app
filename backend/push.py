"""Envío de notificaciones push vía Firebase Admin SDK (FCM)."""
import logging
import os

import firebase_admin
from firebase_admin import credentials, messaging

from config import Config

log = logging.getLogger("quakewatch.push")

_app = None


def _ensure_initialized():
    global _app
    if _app is not None:
        return _app
    if not os.path.exists(Config.FIREBASE_CREDENTIALS_PATH):
        raise RuntimeError(
            "No se encontró el service account de Firebase en "
            f"{Config.FIREBASE_CREDENTIALS_PATH}. Descargalo desde "
            "Firebase Console > Project settings > Service accounts."
        )
    cred = credentials.Certificate(Config.FIREBASE_CREDENTIALS_PATH)
    _app = firebase_admin.initialize_app(cred)
    return _app


def send_earthquake_alert(*, fcm_token: str, place: str, magnitude: float,
                           distance_km: float, earthquake_id: str):
    _ensure_initialized()
    title = f"Sismo M{magnitude:.1f}"
    body = f"{place} · a {distance_km:.0f} km de tu ubicación"
    message = messaging.Message(
        token=fcm_token,
        notification=messaging.Notification(title=title, body=body),
        data={
            "type": "earthquake",
            "earthquake_id": earthquake_id,
            "magnitude": str(magnitude),
        },
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(channel_id="quakewatch_alerts"),
        ),
    )
    try:
        return messaging.send(message)
    except Exception:
        log.exception("Fallo al enviar push a %s", fcm_token[:12])
        return None


def send_weather_alert(*, fcm_token: str, event: str, description: str):
    _ensure_initialized()
    message = messaging.Message(
        token=fcm_token,
        notification=messaging.Notification(title=event, body=description[:180]),
        data={"type": "weather"},
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(channel_id="quakewatch_alerts"),
        ),
    )
    try:
        return messaging.send(message)
    except Exception:
        log.exception("Fallo al enviar push de clima a %s", fcm_token[:12])
        return None
