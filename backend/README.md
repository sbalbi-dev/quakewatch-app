# QuakeWatch backend — despliegue en PythonAnywhere

Dos componentes independientes, tal como se había definido:

1. **`app.py`** — la API REST (lecturas rápidas + proxy de clima). Va como
   la "Web app" de PythonAnywhere.
2. **`ingest.py`** — el worker que hace polling a USGS, escucha el
   websocket de EMSC, guarda en SQLite y dispara los pushes. Va como un
   **"Always-on task"** (disponible en el plan Hacker en adelante).

Ambos comparten `quakewatch.db` (SQLite con journal mode WAL, para que
convivan sin pisarse) y el mismo `config.py` / variables de entorno.

## 1. Subir el código

Desde una consola Bash de PythonAnywhere:

```bash
git clone <URL_DE_TU_REPO> quakewatch
cd quakewatch/backend
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 2. Variables de entorno / archivos de configuración

Copiá `.env.example` a `.env` y completá:

- `QW_OPENWEATHER_API_KEY`: tu API key de OpenWeatherMap (plan gratuito
  alcanza para uso personal).
- `QW_FIREBASE_CREDENTIALS_PATH`: dejalo apuntando a
  `firebase-service-account.json` y subí ese archivo (Firebase Console >
  Configuración del proyecto > Cuentas de servicio > Generar nueva clave
  privada). **No lo subas a git.**

PythonAnywhere no siempre carga `.env` automáticamente fuera del venv, así
que lo más confiable es setear las mismas variables en **Web > Environment
variables** (para el componente web) y en la definición del Always-on task
(para el ingestor) — o cargarlas explícitamente al principio del WSGI file
y de `ingest.py`.

## 3. Componente web (`app.py`)

En la pestaña **Web** de PythonAnywhere:

1. Create a new web app > Manual configuration > Python 3.11.
2. Virtualenv: la ruta al `venv` creado arriba.
3. WSGI configuration file: reemplazá el contenido por el de
   `wsgi_pythonanywhere_example.py` (ajustando `project_home` a tu ruta
   real).
4. Reload.

Probá `https://tuusuario.pythonanywhere.com/health` — debería devolver
`{"status": "ok"}`.

## 4. Componente ingestor (`ingest.py`)

En la pestaña **Tasks** (plan Hacker o superior tiene "Always-on tasks"):

- Comando: `/home/tuusuario/quakewatch/backend/venv/bin/python /home/tuusuario/quakewatch/backend/ingest.py`
- Revisá el log ahí mismo: debería mostrar "Arrancando polling de USGS..."
  y, si `QW_ENABLE_EMSC=true`, "Conectando a EMSC websocket...".

Si tu plan no tiene Always-on tasks, una alternativa es un **Scheduled
task** cada 5-10 minutos que solo haga el polling de USGS (llamando a
`poll_usgs_loop` una vez y saliendo) — vas a perder el near-real-time de
EMSC, pero seguís teniendo sismos nuevos con poca demora.

## 5. Probar el flujo completo

```bash
curl "https://tuusuario.pythonanywhere.com/earthquakes/all?min_magnitude=2.5&period=day"
curl "https://tuusuario.pythonanywhere.com/weather/alerts?lat=-34.6&lon=-58.4"
curl -X POST https://tuusuario.pythonanywhere.com/devices/register \
  -H "Content-Type: application/json" \
  -d '{"fcm_token":"...", "latitude":-34.6, "longitude":-58.4, "radius_km":300, "min_magnitude":4}'
```

Y en la app, en Ajustes, pegá `https://tuusuario.pythonanywhere.com` como
"URL del backend".

## Notas

- Tsunamis: quedó explícitamente pospuesto para una implementación futura
  (el modelo ya trae `tsunami_warning` desde USGS, pero no hay lógica de
  alerta específica todavía).
- Escala: pensado para uso personal/grupo chico (decenas de usuarios).
  Si esto crece, lo primero en migrar sería SQLite -> Postgres — la interfaz
  de `storage.py` ya está aislada para que ese cambio no toque `app.py` ni
  `ingest.py`.
