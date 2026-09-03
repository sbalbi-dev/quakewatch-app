"""Ejemplo de contenido para el WSGI configuration file que PythonAnywhere
genera en Web > Code > WSGI configuration file.

Solo hace falta para el COMPONENTE WEB (app.py). El ingestor (ingest.py) se
configura aparte, como "Always-on task" (ver backend/README.md) — no pasa
por WSGI.
"""
import os
import sys

# Ajustar a la ruta real donde subiste la carpeta backend/ en PythonAnywhere.
project_home = "/home/TU_USUARIO/quakewatch-backend"
if project_home not in sys.path:
    sys.path.insert(0, project_home)

# Si preferís no usar el panel de "Environment variables" de PythonAnywhere,
# se pueden setear acá directamente antes de importar app:
# os.environ["QW_OPENWEATHER_API_KEY"] = "..."
# os.environ["QW_FIREBASE_CREDENTIALS_PATH"] = f"{project_home}/firebase-service-account.json"

from app import app as application  # noqa: E402,F401
