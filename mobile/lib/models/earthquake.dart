import 'dart:math' as math;

/// Representa un sismo, normalizado desde cualquiera de las fuentes
/// (USGS GeoJSON, EMSC, o el backend propio que agrega ambas).
class Earthquake {
  final String id;
  final double magnitude;
  final String? magnitudeType; // ml, mb, mw, etc.
  final String place;
  final DateTime time;
  final double latitude;
  final double longitude;
  final double depthKm;
  final String source; // "usgs" | "emsc" | "backend"
  final String? url; // link a la página de detalle de la fuente
  final bool tsunamiWarning;

  const Earthquake({
    required this.id,
    required this.magnitude,
    this.magnitudeType,
    required this.place,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.depthKm,
    required this.source,
    this.url,
    this.tsunamiWarning = false,
  });

  /// Parsea un feature del formato GeoJSON de USGS.
  /// https://earthquake.usgs.gov/earthquakes/feed/v1.0/geojson_detail.php
  factory Earthquake.fromUsgsFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coords = (geometry['coordinates'] as List).cast<num>();

    return Earthquake(
      id: feature['id'] as String,
      magnitude: (props['mag'] as num?)?.toDouble() ?? 0,
      magnitudeType: props['magType'] as String?,
      place: (props['place'] as String?) ?? 'Ubicación desconocida',
      time: DateTime.fromMillisecondsSinceEpoch(
        (props['time'] as num).toInt(),
        isUtc: true,
      ),
      longitude: coords[0].toDouble(),
      latitude: coords[1].toDouble(),
      depthKm: coords.length > 2 ? coords[2].toDouble() : 0,
      source: 'usgs',
      url: props['url'] as String?,
      tsunamiWarning: (props['tsunami'] as num?) == 1,
    );
  }

  /// Parsea un evento del feed de notificaciones de EMSC/SeismicPortal.
  /// Formato tipo GeoJSON con propiedades ligeramente distintas.
  factory Earthquake.fromEmscFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coords = geometry != null
        ? (geometry['coordinates'] as List).cast<num>()
        : <num>[
            (props['lon'] as num?) ?? 0,
            (props['lat'] as num?) ?? 0,
            (props['depth'] as num?) ?? 0,
          ];

    return Earthquake(
      id: 'emsc_${props['unid'] ?? props['source_id'] ?? feature['id']}',
      magnitude: (props['mag'] as num?)?.toDouble() ?? 0,
      magnitudeType: props['magtype'] as String?,
      place: (props['flynn_region'] as String?) ??
          (props['place'] as String?) ??
          'Ubicación desconocida',
      time: DateTime.parse(props['time'] as String).toUtc(),
      longitude: coords[0].toDouble(),
      latitude: coords[1].toDouble(),
      depthKm: coords.length > 2 ? coords[2].toDouble() : 0,
      source: 'emsc',
      url: props['source_catalog'] != null
          ? 'https://www.emsc-csem.org/Earthquake/?id=${props['source_id']}'
          : null,
    );
  }

  /// Parsea la respuesta ya normalizada del backend propio.
  factory Earthquake.fromBackendJson(Map<String, dynamic> json) {
    return Earthquake(
      id: json['id'] as String,
      magnitude: (json['magnitude'] as num).toDouble(),
      magnitudeType: json['magnitude_type'] as String?,
      place: json['place'] as String? ?? 'Ubicación desconocida',
      time: DateTime.parse(json['time'] as String).toUtc(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      depthKm: (json['depth_km'] as num?)?.toDouble() ?? 0,
      source: json['source'] as String? ?? 'backend',
      url: json['url'] as String?,
      tsunamiWarning: json['tsunami_warning'] as bool? ?? false,
    );
  }

  /// Distancia aproximada en kilómetros usando la fórmula de Haversine.
  double distanceKmFrom(double lat, double lon) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(latitude - lat);
    final dLon = _degToRad(longitude - lon);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat)) *
            math.cos(_degToRad(latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Nivel de severidad simple para colorear la UI.
  EarthquakeSeverity get severity {
    if (magnitude >= 6.0) return EarthquakeSeverity.severe;
    if (magnitude >= 4.5) return EarthquakeSeverity.strong;
    if (magnitude >= 3.0) return EarthquakeSeverity.moderate;
    return EarthquakeSeverity.minor;
  }
}

enum EarthquakeSeverity { minor, moderate, strong, severe }
