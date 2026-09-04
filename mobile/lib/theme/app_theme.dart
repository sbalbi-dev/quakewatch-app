import 'package:flutter/material.dart';
import '../models/earthquake.dart';

class AppTheme {
  static const Color primary = Color(0xFF17324A); // azul oscuro (clima/noche)
  static const Color accent = Color(0xFFFF8C00); // naranja (alerta)

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primary,
      brightness: Brightness.light,
    );
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primary,
      brightness: Brightness.dark,
    );
  }

  static Color severityColor(EarthquakeSeverity severity) {
    switch (severity) {
      case EarthquakeSeverity.minor:
        return const Color(0xFF4CAF50);
      case EarthquakeSeverity.moderate:
        return const Color(0xFFFFC107);
      case EarthquakeSeverity.strong:
        return const Color(0xFFFF7043);
      case EarthquakeSeverity.severe:
        return const Color(0xFFD32F2F);
    }
  }

  /// Etiqueta en español para mostrar junto a la magnitud, a modo de
  /// "intensidad" percibida en criollo (no es la escala de Mercalli real,
  /// que necesitaría datos que USGS/EMSC no exponen de forma consistente).
  static String severityLabel(EarthquakeSeverity severity) {
    switch (severity) {
      case EarthquakeSeverity.minor:
        return 'Leve';
      case EarthquakeSeverity.moderate:
        return 'Moderado';
      case EarthquakeSeverity.strong:
        return 'Fuerte';
      case EarthquakeSeverity.severe:
        return 'Severo';
    }
  }
}
