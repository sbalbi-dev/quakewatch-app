import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/earthquake.dart';
import '../services/earthquake_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../widgets/earthquake_tile.dart';
import 'earthquake_detail_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final _locationService = LocationService();

  Position? _position;
  List<Earthquake> _earthquakes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final settings = context.read<SettingsService>();
    final earthquakeService = context.read<EarthquakeService>();
    final notificationService = context.read<NotificationService>();

    try {
      final position = await _locationService.getCurrentPosition();
      final earthquakes = await earthquakeService.fetchNearby(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: settings.radiusKm,
        minMagnitude: 2.5,
      );

      // Le avisamos al backend dónde estamos para que nos pueda pushear
      // alertas nuevas mientras la app está cerrada. Si no hay backend
      // configurado, esto no hace nada (ver NotificationService).
      unawaited(notificationService.registerLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      ));

      if (!mounted) return;
      setState(() {
        _position = position;
        _earthquakes = earthquakes;
        _loading = false;
      });
    } on LocationUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on EarthquakeServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la lista: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.my_location, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _position != null
                        ? 'Radio de búsqueda: ${settings.radiusKm.round()} km'
                        : 'Ubicación no disponible',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _earthquakes.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 64),
                        child: Center(
                          child: Text('No hay sismos recientes en tu zona 🎉'),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _earthquakes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final eq = _earthquakes[index];
                      final distance = _position != null
                          ? eq.distanceKmFrom(
                              _position!.latitude, _position!.longitude)
                          : null;
                      return EarthquakeTile(
                        earthquake: eq,
                        distanceKm: distance,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EarthquakeDetailScreen(earthquake: eq),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
