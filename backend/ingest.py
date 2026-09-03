"""Worker de ingesta: se corre como proceso aparte de app.py (pensado como
"Always-on task" en PythonAnywhere plan Hacker, tal como se había definido).

Hace dos cosas en paralelo:
  1. Polling de USGS cada POLL_INTERVAL_SECONDS (hilo principal).
  2. Escucha el websocket de EMSC/SeismicPortal para eventos casi en tiempo
     real (hilo aparte), si QW_ENABLE_EMSC=true.

Cada evento nuevo (no duplicado, ver storage.find_duplicate) que supere el
umbral de un dispositivo registrado dispara un push por Firebase.

Uso: `python ingest.py`
"""
import json
import logging
import threading
import time

import storage
import sources
import push
from config import Config

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("quakewatch.ingest")


def process_new_earthquake(eq: dict):
    """Guarda el evento si es nuevo y, si corresponde, notifica a los
    dispositivos cuyo radio/umbral lo cubren."""
    if eq["magnitude"] < Config.MIN_MAGNITUDE_STORE:
        return

    is_new, final_id = storage.upsert_earthquake(eq)
    if not is_new:
        return

    log.info(
        "Nuevo sismo [%s] M%.1f %s",
        eq["source"], eq["magnitude"], eq["place"],
    )

    devices = storage.get_devices_near(
        latitude=eq["latitude"], longitude=eq["longitude"],
        min_magnitude=eq["magnitude"],
    )
    if not devices:
        storage.mark_notified(final_id)
        return

    sent = 0
    for device in devices:
        distance = storage.haversine_km(
            eq["latitude"], eq["longitude"], device["latitude"], device["longitude"]
        )
        result = push.send_earthquake_alert(
            fcm_token=device["fcm_token"],
            place=eq["place"],
            magnitude=eq["magnitude"],
            distance_km=distance,
            earthquake_id=final_id,
        )
        if result:
            sent += 1
    log.info("Notificados %d/%d dispositivos para %s", sent, len(devices), final_id)
    storage.mark_notified(final_id)


def poll_usgs_loop():
    log.info("Arrancando polling de USGS cada %ss (feed=%s)",
              Config.POLL_INTERVAL_SECONDS, Config.USGS_POLL_FEED)
    while True:
        try:
            events = sources.fetch_usgs_events()
            log.info("USGS devolvió %d eventos", len(events))
            for eq in events:
                process_new_earthquake(eq)
        except Exception:
            log.exception("Error en el ciclo de polling de USGS")
        time.sleep(Config.POLL_INTERVAL_SECONDS)


def emsc_websocket_loop():
    """Se reconecta solo con backoff exponencial si el socket se cae —
    típico en un always-on task de larga duración."""
    import websocket  # websocket-client

    backoff = 5
    while True:
        try:
            log.info("Conectando a EMSC websocket: %s", Config.EMSC_WEBSOCKET_URL)

            def on_message(ws, message):
                nonlocal backoff
                backoff = 5  # conexión sana: resetear backoff
                try:
                    payload = json.loads(message)
                    eq = sources.normalize_emsc_message(payload)
                    if eq:
                        process_new_earthquake(eq)
                except Exception:
                    log.exception("Error procesando mensaje de EMSC")

            def on_error(ws, error):
                log.warning("Error en websocket EMSC: %s", error)

            def on_close(ws, code, msg):
                log.warning("Websocket EMSC cerrado (code=%s, msg=%s)", code, msg)

            ws_app = websocket.WebSocketApp(
                Config.EMSC_WEBSOCKET_URL,
                on_message=on_message,
                on_error=on_error,
                on_close=on_close,
            )
            ws_app.run_forever(ping_interval=30, ping_timeout=10)
        except Exception:
            log.exception("Fallo estableciendo el websocket de EMSC")

        log.info("Reintentando conexión EMSC en %ss", backoff)
        time.sleep(backoff)
        backoff = min(backoff * 2, 300)


def main():
    storage.init_db()

    threads = [threading.Thread(target=poll_usgs_loop, daemon=True, name="usgs-poll")]
    if Config.ENABLE_EMSC_WEBSOCKET:
        threads.append(
            threading.Thread(target=emsc_websocket_loop, daemon=True, name="emsc-ws")
        )
    else:
        log.info("EMSC websocket deshabilitado (QW_ENABLE_EMSC=false)")

    for t in threads:
        t.start()

    # Mantiene vivo el proceso principal (los workers son threads daemon).
    while True:
        time.sleep(3600)
        storage.prune_old_devices()


if __name__ == "__main__":
    main()
