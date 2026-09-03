/// Alerta meteorológica, normalizada desde la respuesta de alertas de
/// OpenWeatherMap (One Call API 3.0 -> campo "alerts") vía el backend.
class WeatherAlert {
  final String senderName;
  final String event; // ej: "Alerta amarilla por tormentas"
  final DateTime start;
  final DateTime end;
  final String description;
  final List<String> tags;

  const WeatherAlert({
    required this.senderName,
    required this.event,
    required this.start,
    required this.end,
    required this.description,
    this.tags = const [],
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      senderName: json['sender_name'] as String? ?? 'Servicio meteorológico',
      event: json['event'] as String? ?? 'Alerta meteorológica',
      start: DateTime.fromMillisecondsSinceEpoch(
        ((json['start'] as num).toInt()) * 1000,
        isUtc: true,
      ),
      end: DateTime.fromMillisecondsSinceEpoch(
        ((json['end'] as num).toInt()) * 1000,
        isUtc: true,
      ),
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  bool get isActive {
    final now = DateTime.now().toUtc();
    return now.isAfter(start) && now.isBefore(end);
  }
}

/// Snapshot del clima actual para la ubicación del usuario (además de las
/// alertas, mostramos condiciones actuales en la pantalla de Clima).
class CurrentWeather {
  final double tempC;
  final double feelsLikeC;
  final String description;
  final String icon;
  final double windKph;
  final int humidity;

  const CurrentWeather({
    required this.tempC,
    required this.feelsLikeC,
    required this.description,
    required this.icon,
    required this.windKph,
    required this.humidity,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    final weatherList = json['weather'] as List?;
    final weather = weatherList != null && weatherList.isNotEmpty
        ? weatherList.first as Map<String, dynamic>
        : <String, dynamic>{};
    return CurrentWeather(
      tempC: (json['temp'] as num).toDouble(),
      feelsLikeC: (json['feels_like'] as num?)?.toDouble() ??
          (json['temp'] as num).toDouble(),
      description: weather['description'] as String? ?? '',
      icon: weather['icon'] as String? ?? '01d',
      windKph: ((json['wind_speed'] as num?) ?? 0).toDouble() * 3.6,
      humidity: (json['humidity'] as num?)?.toInt() ?? 0,
    );
  }
}
