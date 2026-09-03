import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/weather_alert.dart';
import 'settings_service.dart';

class WeatherServiceException implements Exception {
  final String message;
  WeatherServiceException(this.message);
  @override
  String toString() => message;
}

class WeatherResult {
  final CurrentWeather? current;
  final List<WeatherAlert> alerts;
  WeatherResult({required this.current, required this.alerts});
}

/// Trae clima actual + alertas para una ubicación.
///
/// Preferí siempre pasar por el backend propio: mantiene la API key de
/// OpenWeatherMap del lado del servidor. Cargar la key directo en la app
/// (SettingsService.openWeatherApiKey) es un modo "modo rápido" para probar
/// sin desplegar el backend todavía — quien decompile el APK vería esa key,
/// así que no es la opción recomendada para un release público.
class WeatherService {
  final SettingsService settings;
  final http.Client _client;

  WeatherService(this.settings, {http.Client? client})
      : _client = client ?? http.Client();

  static const _openWeatherBase = 'https://api.openweathermap.org/data/3.0/onecall';

  Future<WeatherResult> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    if (settings.hasBackend) {
      return _fetchFromBackend(latitude: latitude, longitude: longitude);
    }
    if (settings.openWeatherApiKey != null) {
      return _fetchFromOpenWeatherDirect(
        latitude: latitude,
        longitude: longitude,
      );
    }
    throw WeatherServiceException(
      'Configurá un backend o una API key de OpenWeatherMap en Ajustes para ver el clima.',
    );
  }

  Future<WeatherResult> _fetchFromBackend({
    required double latitude,
    required double longitude,
  }) async {
    final base = settings.backendBaseUrl!.replaceAll(RegExp(r'/+$'), '');
    final url = Uri.parse('$base/weather/alerts').replace(queryParameters: {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
    });
    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw WeatherServiceException(
        'El backend respondió ${response.statusCode} al pedir el clima.',
      );
    }
    return _parseOneCallStyleBody(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WeatherResult> _fetchFromOpenWeatherDirect({
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse(_openWeatherBase).replace(queryParameters: {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'units': 'metric',
      'lang': 'es',
      'exclude': 'minutely,hourly,daily',
      'appid': settings.openWeatherApiKey,
    });
    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw WeatherServiceException(
        'OpenWeatherMap respondió ${response.statusCode}. Revisá la API key en Ajustes.',
      );
    }
    return _parseOneCallStyleBody(jsonDecode(response.body) as Map<String, dynamic>);
  }

  WeatherResult _parseOneCallStyleBody(Map<String, dynamic> body) {
    final currentJson = body['current'] as Map<String, dynamic>?;
    final alertsJson = (body['alerts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return WeatherResult(
      current: currentJson != null ? CurrentWeather.fromJson(currentJson) : null,
      alerts: alertsJson.map(WeatherAlert.fromJson).toList(),
    );
  }
}
