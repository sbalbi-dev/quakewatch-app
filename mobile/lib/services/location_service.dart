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

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
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
