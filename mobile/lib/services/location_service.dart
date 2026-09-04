import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationUnavailableException implements Exception {
  final String message;
  LocationUnavailableException(this.message);
  @override
  String toString() => message;
}

/// Wrapper fino sobre `geolocator` que traduce sus distintos estados de
/// permiso/servicio a mensajes en español listos para mostrar en la UI.
class LocationService {
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationUnavailableException(
        'El GPS/ubicación está desactivado. Activalo para ver alertas cerca tuyo.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationUnavailableException(
          'Se necesita permiso de ubicación para mostrar alertas cerca tuyo.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationUnavailableException(
        'El permiso de ubicación está bloqueado. Habilitalo desde Ajustes del sistema.',
      );
    }

    try {
      // Sin timeLimit, getCurrentPosition() puede quedar esperando para
      // siempre si el dispositivo no logra un fix de GPS (típico en
      // interiores) — eso es lo que hacía que la pantalla se quede
      // "pensando" sin fin. Con el límite, si no hay fix a tiempo pasamos
      // a los fallbacks de abajo en vez de trabarnos.
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on TimeoutException {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;
      throw LocationUnavailableException(
        'No se pudo obtener tu ubicación (sin señal de GPS). Probá salir '
        'a un lugar más despejado o reintentar en unos segundos.',
      );
    } catch (e) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;
      throw LocationUnavailableException(
        'No se pudo obtener tu ubicación: $e',
      );
    }
  }

  /// Pide solo el permiso, sin bloquear si el usuario lo rechaza (usado al
  /// arrancar la app para no forzar el flujo si todavía no llegó a la
  /// pantalla que lo necesita).
  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
