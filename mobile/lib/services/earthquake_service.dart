import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/earthquake.dart';
import 'settings_service.dart';

class EarthquakeServiceException implements Exception {
  final String message;
  EarthquakeServiceException(this.message);
  @override
  String toString() => message;
}

/// Trae la lista de sismos recientes.
///
/// Si hay un backend propio configurado (SettingsService.hasBackend), se usa
/// ese endpoint: ya viene deduplicado entre USGS + EMSC. Si no, se consulta
/// USGS directo (es gratis, sin API key, y soporta CORS/HTTPS bien desde una
/// app), que es más que suficiente para arrancar sin desplegar nada.
class EarthquakeService {
  final SettingsService settings;
  final http.Client _client;

  EarthquakeService(this.settings, {http.Client? client})
      : _client = client ?? http.Client();

  static const _usgsBase = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary';

  /// Feed global reciente para la pantalla "Todos los sismos".
  /// [minMagnitude] usa los feeds pre-armados de USGS (all/1.0/2.5/4.5/significant)
  /// y [period] puede ser hour, day, week o month.
  Future<List<Earthquake>> fetchRecent({
    double minMagnitude = 2.5,
    String period = 'day',
  }) async {
    if (settings.hasBackend) {
      return _fetchFromBackend(
        path: '/earthquakes/all',
        query: {
          'min_magnitude': minMagnitude.toString(),
          'period': period,
        },
      );
    }
    return _fetchFromUsgs(minMagnitude: minMagnitude, period: period);
  }

  /// Sismos cerca de una ubicación, ordenados por distancia. Si hay backend,
  /// filtra server-side; si no, trae el feed global (mag 2.5+, últimos 7 días
  /// para tener margen) y filtra en el cliente con Haversine.
  Future<List<Earthquake>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
    double minMagnitude = 2.5,
  }) async {
    if (settings.hasBackend) {
      return _fetchFromBackend(
        path: '/earthquakes/nearby',
        query: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'radius_km': radiusKm.toString(),
          'min_magnitude': minMagnitude.toString(),
        },
      );
    }

    final all = await _fetchFromUsgs(minMagnitude: minMagnitude, period: 'week');
    final nearby = all
        .where((eq) => eq.distanceKmFrom(latitude, longitude) <= radiusKm)
        .toList();
    nearby.sort(
      (a, b) => a
          .distanceKmFrom(latitude, longitude)
          .compareTo(b.distanceKmFrom(latitude, longitude)),
    );
    return nearby;
  }

  Future<List<Earthquake>> _fetchFromUsgs({
    required double minMagnitude,
    required String period,
  }) async {
    // USGS expone feeds fijos: significant, 4.5, 2.5, 1.0, all — cada uno con
    // ventanas hour/day/week/month. Elegimos el feed fijo más chico que
    // cubra la magnitud pedida para no traer de más.
    String magBucket;
    if (minMagnitude >= 4.5) {
      magBucket = '4.5';
    } else if (minMagnitude >= 2.5) {
      magBucket = '2.5';
    } else if (minMagnitude >= 1.0) {
      magBucket = '1.0';
    } else {
      magBucket = 'all';
    }

    final url = Uri.parse('$_usgsBase/${magBucket}_$period.geojson');
    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw EarthquakeServiceException(
        'USGS respondió ${response.statusCode} al pedir sismos.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List).cast<Map<String, dynamic>>();
    return features
        .map(Earthquake.fromUsgsFeature)
        .where((eq) => eq.magnitude >= minMagnitude)
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time));
  }

  Future<List<Earthquake>> _fetchFromBackend({
    required String path,
    required Map<String, String> query,
  }) async {
    final base = settings.backendBaseUrl!.replaceAll(RegExp(r'/+$'), '');
    final url = Uri.parse('$base$path').replace(queryParameters: query);
    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw EarthquakeServiceException(
        'El backend respondió ${response.statusCode} al pedir sismos.',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['earthquakes'] as List).cast<Map<String, dynamic>>();
    return items.map(Earthquake.fromBackendJson).toList();
  }
}
