import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda las preferencias del usuario: radio de "cerca de mí", magnitud
/// mínima para notificar, URL del backend propio y (opcional) API key de
/// OpenWeatherMap para usar la app sin backend desplegado todavía.
///
/// Es un [ChangeNotifier] para que las pantallas se puedan suscribir con
/// `provider` y refrescarse solas cuando el usuario cambia algo en Ajustes.
class SettingsService extends ChangeNotifier {
  static const _keyBackendUrl = 'backend_base_url';
  static const _keyOpenWeatherKey = 'openweather_api_key';
  static const _keyRadiusKm = 'radius_km';
  static const _keyMinMagnitude = 'min_magnitude_notify';
  static const _keyFcmToken = 'fcm_token';

  // Valores por defecto pensados para arrancar sin configurar nada:
  // el radio y la magnitud mínima de notificación son razonables para uso
  // personal, y sin backend la app igual funciona consultando USGS directo
  // para sismos (no requiere key) — el clima sí necesita, o el backend, o
  // una API key de OpenWeatherMap cargada en Ajustes.
  static const double defaultRadiusKm = 300;
  static const double defaultMinMagnitude = 4.0;

  late SharedPreferences _prefs;
  bool _ready = false;

  String? backendBaseUrl;
  String? openWeatherApiKey;
  double radiusKm = defaultRadiusKm;
  double minMagnitudeToNotify = defaultMinMagnitude;
  String? fcmToken;

  bool get isReady => _ready;

  /// Si no hay backend configurado, la app usa USGS directo para sismos y
  /// requiere una API key propia de OpenWeatherMap para el clima.
  bool get hasBackend => backendBaseUrl != null && backendBaseUrl!.isNotEmpty;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    backendBaseUrl = _prefs.getString(_keyBackendUrl);
    openWeatherApiKey = _prefs.getString(_keyOpenWeatherKey);
    radiusKm = _prefs.getDouble(_keyRadiusKm) ?? defaultRadiusKm;
    minMagnitudeToNotify =
        _prefs.getDouble(_keyMinMagnitude) ?? defaultMinMagnitude;
    fcmToken = _prefs.getString(_keyFcmToken);
    _ready = true;
    notifyListeners();
  }

  Future<void> setBackendBaseUrl(String? url) async {
    backendBaseUrl = (url == null || url.trim().isEmpty) ? null : url.trim();
    if (backendBaseUrl == null) {
      await _prefs.remove(_keyBackendUrl);
    } else {
      await _prefs.setString(_keyBackendUrl, backendBaseUrl!);
    }
    notifyListeners();
  }

  Future<void> setOpenWeatherApiKey(String? key) async {
    openWeatherApiKey = (key == null || key.trim().isEmpty) ? null : key.trim();
    if (openWeatherApiKey == null) {
      await _prefs.remove(_keyOpenWeatherKey);
    } else {
      await _prefs.setString(_keyOpenWeatherKey, openWeatherApiKey!);
    }
    notifyListeners();
  }

  Future<void> setRadiusKm(double value) async {
    radiusKm = value;
    await _prefs.setDouble(_keyRadiusKm, value);
    notifyListeners();
  }

  Future<void> setMinMagnitudeToNotify(double value) async {
    minMagnitudeToNotify = value;
    await _prefs.setDouble(_keyMinMagnitude, value);
    notifyListeners();
  }

  Future<void> setFcmToken(String? token) async {
    fcmToken = token;
    if (token == null) {
      await _prefs.remove(_keyFcmToken);
    } else {
      await _prefs.setString(_keyFcmToken, token);
    }
  }
}
