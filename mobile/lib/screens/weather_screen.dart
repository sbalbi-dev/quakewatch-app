import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weather_alert.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../widgets/weather_alert_card.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _locationService = LocationService();

  CurrentWeather? _current;
  List<WeatherAlert> _alerts = [];
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
    final service = context.read<WeatherService>();
    try {
      final position = await _locationService.getCurrentPosition();
      final result = await service.fetchWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _current = result.current;
        _alerts = result.alerts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e'.replaceFirst('WeatherServiceException: ', '')
            .replaceFirst('LocationUnavailableException: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_current != null) _CurrentWeatherCard(current: _current!),
          const SizedBox(height: 16),
          Text(
            _alerts.isEmpty ? 'Sin alertas activas' : 'Alertas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._alerts.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: WeatherAlertCard(alert: a),
              )),
        ],
      ),
    );
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  final CurrentWeather current;
  const _CurrentWeatherCard({required this.current});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.network(
              'https://openweathermap.org/img/wn/${current.icon}@2x.png',
              width: 64,
              height: 64,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.cloud, size: 48),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${current.tempC.round()}°C',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(current.description),
                  Text(
                    'Sensación ${current.feelsLikeC.round()}°C · Humedad ${current.humidity}% · Viento ${current.windKph.round()} km/h',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
