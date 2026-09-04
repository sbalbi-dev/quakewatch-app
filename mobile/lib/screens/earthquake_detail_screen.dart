import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/earthquake.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Pantalla de detalle de un sismo: mapa con el epicentro y toda la info
/// (país, ciudad/región, intensidad, fecha y hora) que se pudo reunir.
///
/// El país/ciudad se resuelve con reverse geocoding a partir de la lat/lon
/// (paquete `geocoding`, usa el Geocoder nativo de Android). Para epicentros
/// oceánicos o muy remotos es normal que no devuelva nada — en ese caso se
/// muestra la descripción de texto que ya trae la fuente (USGS/EMSC), que
/// siempre está disponible.
class EarthquakeDetailScreen extends StatefulWidget {
  final Earthquake earthquake;

  const EarthquakeDetailScreen({super.key, required this.earthquake});

  @override
  State<EarthquakeDetailScreen> createState() =>
      _EarthquakeDetailScreenState();
}

class _EarthquakeDetailScreenState extends State<EarthquakeDetailScreen> {
  bool _resolvingPlace = true;
  String? _country;
  String? _locality;

  @override
  void initState() {
    super.initState();
    _resolvePlace();
  }

  Future<void> _resolvePlace() async {
    try {
      final placemarks = await placemarkFromCoordinates(
        widget.earthquake.latitude,
        widget.earthquake.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final locality = _firstNonEmpty([
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
        ]);
        if (mounted) {
          setState(() {
            _country = _firstNonEmpty([p.country]);
            _locality = locality;
            _resolvingPlace = false;
          });
        }
        return;
      }
    } catch (_) {
      // Sin resultado (epicentro en el mar, geocoder no disponible, etc.):
      // seguimos y mostramos el texto de la fuente como fallback.
    }
    if (mounted) setState(() => _resolvingPlace = false);
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final eq = widget.earthquake;
    final point = ll.LatLng(eq.latitude, eq.longitude);
    final color = AppTheme.severityColor(eq.severity);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del sismo')),
      body: Column(
        children: [
          SizedBox(
            height: 280,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 6,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sebas.quakewatch',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 46,
                      height: 46,
                      child: Icon(
                        Icons.location_on,
                        color: color,
                        size: 46,
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      child: Text(
                        Formatters.magnitude(eq.magnitude),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eq.place,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            AppTheme.severityLabel(eq.severity),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (eq.tsunamiWarning)
                      const Tooltip(
                        message: 'Alerta de tsunami asociada',
                        child: Icon(Icons.tsunami, color: Colors.blueAccent),
                      ),
                  ],
                ),
                const Divider(height: 32),
                _InfoRow(
                  icon: Icons.speed,
                  label: 'Intensidad (magnitud)',
                  value: 'M ${Formatters.magnitude(eq.magnitude)}'
                      '${eq.magnitudeType != null ? ' (${eq.magnitudeType})' : ''}',
                ),
                _InfoRow(
                  icon: Icons.schedule,
                  label: 'Fecha y hora',
                  value: Formatters.dateTime(eq.time),
                ),
                _InfoRow(
                  icon: Icons.public,
                  label: 'País',
                  value: _resolvingPlace
                      ? 'Buscando…'
                      : (_country ?? 'No disponible (epicentro remoto/oceánico)'),
                ),
                _InfoRow(
                  icon: Icons.location_city,
                  label: 'Ciudad / región',
                  value: _resolvingPlace ? 'Buscando…' : (_locality ?? eq.place),
                ),
                _InfoRow(
                  icon: Icons.vertical_align_bottom,
                  label: 'Profundidad',
                  value: '${eq.depthKm.round()} km',
                ),
                _InfoRow(
                  icon: Icons.my_location,
                  label: 'Coordenadas',
                  value:
                      '${eq.latitude.toStringAsFixed(3)}, ${eq.longitude.toStringAsFixed(3)}',
                ),
                _InfoRow(
                  icon: Icons.source,
                  label: 'Fuente',
                  value: eq.source.toUpperCase(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
