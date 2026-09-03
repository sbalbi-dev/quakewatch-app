import 'package:intl/intl.dart';

class Formatters {
  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  /// Convierte un DateTime en UTC a la hora local del dispositivo y lo
  /// formatea como dd/MM/yyyy HH:mm.
  static String dateTime(DateTime utcTime) {
    return _dateFmt.format(utcTime.toLocal());
  }

  static String relative(DateTime utcTime) {
    final diff = DateTime.now().toUtc().difference(utcTime);
    if (diff.inMinutes < 1) return 'recién';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return dateTime(utcTime);
  }

  static String distanceKm(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  static String magnitude(double mag) => mag.toStringAsFixed(1);
}
