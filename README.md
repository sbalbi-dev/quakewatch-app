# QuakeWatch

App Android (Flutter) que muestra, según tu ubicación, alertas de sismos y
de clima, además de un listado global de todos los sismos recientes.

- **`mobile/`** — la app Flutter (Android). Tres pantallas principales:
  "Cerca de mí" (sismos dentro de un radio configurable, con push cuando
  hay uno nuevo), "Todos los sismos" (feed global filtrable por magnitud y
  período) y "Clima" (condiciones actuales + alertas meteorológicas).
- **`backend/`** — API Flask + worker de ingesta, pensados para
  PythonAnywhere (plan Hacker). Agrega USGS + EMSC, deduplica sismos
  reportados por ambas fuentes, proxea OpenWeatherMap, y manda las
  notificaciones push vía Firebase Cloud Messaging.
- **`.github/workflows/android-build.yml`** — compila el APK
  automáticamente en cada push, porque este proyecto se armó en un entorno
  sin Flutter/Android SDK instalado.

La app funciona en dos modos:

| Modo | Qué necesitás | Qué te da |
|---|---|---|
| **Con backend** (recomendado) | Desplegar `backend/` en PythonAnywhere | Notificaciones push reales, key de OpenWeatherMap protegida en el servidor, dedup USGS+EMSC |
| **Sin backend** | Nada, o solo una API key de OpenWeatherMap cargada en Ajustes | Sismos vía USGS directo (sin key), clima si cargaste la key — pero sin push en background |

Podés arrancar en modo "sin backend" para probar la app ya mismo, y sumar
el backend cuando quieras push notifications de verdad.

## Cómo compilar el APK

Este proyecto **no se compiló localmente** porque el entorno donde se armó
no tiene Flutter/Android SDK — se resolvió con GitHub Actions:

1. Subí este código a tu repo de GitHub (ver sección siguiente).
2. En cuanto hagas push a `main`, el workflow **Build Android APK** corre
   solo y deja el `.apk` como artifact descargable desde la pestaña
   **Actions** del repo (pestaña Actions > el run más reciente > Artifacts
   > `quakewatch-release-apk`).
3. Opcional: si además pusheás un tag `v1.0.0` (por ejemplo), el workflow
   crea automáticamente un GitHub Release con el APK adjunto, listo para
   compartir un link de descarga directo.

Si en algún momento preferís compilar en tu propia máquina en vez de (o
además de) usar CI: instalá el [Flutter SDK](https://docs.flutter.dev/get-started/install)
y el Android SDK, y desde `mobile/` corré `flutter pub get` y
`flutter build apk --release`.

## Subir el proyecto a tu repo

```bash
cd quakewatch-app
git init   # si el repo todavía no tiene historial
git remote add origin <URL_DE_TU_REPO_EN_GITHUB>
git add .
git commit -m "QuakeWatch: app Flutter + backend Flask, sismos y clima por ubicación"
git branch -M main
git push -u origin main
```

Con eso ya deberías ver correr el workflow de Actions solo.

## Configurar Firebase (para que las notificaciones push funcionen)

1. Creá un proyecto en [Firebase Console](https://console.firebase.google.com/).
2. Agregá una app Android con `applicationId` = `com.sebas.quakewatch`
   (o cambiá el `applicationId` en `mobile/android/app/build.gradle` si
   preferís otro paquete, y usá ese mismo en Firebase).
3. Descargá el `google-services.json` real y reemplazá el placeholder en
   `mobile/android/app/google-services.json.example` -> guardalo como
   `mobile/android/app/google-services.json` (sin `.example`; ya está en
   `.gitignore`, no se sube al repo).
4. Para que **GitHub Actions** también pueda compilar con Firebase real
   (no solo tu build local), subilo como secret del repo:
   ```bash
   base64 -w0 mobile/android/app/google-services.json
   ```
   Pegá el resultado como secret `GOOGLE_SERVICES_JSON_BASE64` en
   GitHub > tu repo > Settings > Secrets and variables > Actions.
5. Corré `flutterfire configure` desde `mobile/` para regenerar
   `lib/firebase_options.dart` con las claves reales (o completalo a mano
   con los datos de `google-services.json` — los campos son los mismos).
6. Generá una **service account key** (Project settings > Service
   accounts > Generate new private key) y usala como
   `QW_FIREBASE_CREDENTIALS_PATH` del backend (ver `backend/README.md`).

## Configurar el clima

- Creá una cuenta gratuita en [OpenWeatherMap](https://openweathermap.org/api)
  y suscribite al **One Call API 3.0** (tiene capa gratuita con límite
  mensual de llamadas, más que suficiente para uso personal).
- Si desplegaste el backend: la key va en `QW_OPENWEATHER_API_KEY` del
  backend (ver `backend/README.md`), nunca en la app.
- Si estás probando sin backend: pegá la key en Ajustes de la app
  ("modo sin backend") — la app te avisa que en ese caso queda guardada
  en el teléfono, no en un servidor.

## Estructura del proyecto

```
quakewatch-app/
├── mobile/                  # App Flutter (Android)
│   ├── lib/
│   │   ├── models/          # Earthquake, WeatherAlert, CurrentWeather
│   │   ├── services/        # location, earthquake, weather, notifications, settings
│   │   ├── screens/         # Cerca de mí, Todos los sismos, Clima, Ajustes
│   │   └── widgets/
│   └── android/
├── backend/                 # API Flask + worker de ingesta
│   ├── app.py                (API REST — componente "Web" de PythonAnywhere)
│   ├── ingest.py              (worker USGS+EMSC+push — "Always-on task")
│   ├── storage.py             (SQLite + dedup entre fuentes)
│   ├── sources.py             (parseo de USGS/EMSC/OpenWeatherMap)
│   └── push.py                 (Firebase Admin SDK)
└── .github/workflows/
    └── android-build.yml     # compila el APK en cada push
```

## Qué falta / próximos pasos

- Firmar el APK con una key de release propia antes de publicarlo en Play
  Store (por ahora usa la key de debug para que el build de CI sea
  instalable sin configuración extra).
- Ícono de la app: se generó uno simple como placeholder
  (`mobile/android/app/src/main/res/mipmap-*/ic_launcher.png`,
  master en `mobile/assets_icon_master.png`) — reemplazalo por el
  definitivo cuando tengas uno (podés usar `flutter_launcher_icons` para
  regenerar todas las densidades a partir de un solo PNG).
- Soporte de tsunamis: pospuesto, tal como se había decidido.
- Si el proyecto crece más allá de uso personal, migrar SQLite -> Postgres
  en el backend (la interfaz de `storage.py` ya está pensada para eso).
