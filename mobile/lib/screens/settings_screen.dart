import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _backendController;
  late TextEditingController _weatherKeyController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _backendController = TextEditingController(text: settings.backendBaseUrl ?? '');
    _weatherKeyController =
        TextEditingController(text: settings.openWeatherApiKey ?? '');
  }

  @override
  void dispose() {
    _backendController.dispose();
    _weatherKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Alertas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Radio "cerca de mí": ${settings.radiusKm.round()} km',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Slider(
          value: settings.radiusKm,
          min: 50,
          max: 1000,
          divisions: 19,
          label: '${settings.radiusKm.round()} km',
          onChanged: (v) => context.read<SettingsService>().setRadiusKm(v),
        ),
        const SizedBox(height: 8),
        Text(
          'Magnitud mínima para notificarme: M ${settings.minMagnitudeToNotify.toStringAsFixed(1)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Slider(
          value: settings.minMagnitudeToNotify,
          min: 2.0,
          max: 7.0,
          divisions: 10,
          label: 'M ${settings.minMagnitudeToNotify.toStringAsFixed(1)}',
          onChanged: (v) =>
              context.read<SettingsService>().setMinMagnitudeToNotify(v),
        ),
        const Divider(height: 32),
        Text('Backend propio (opcional)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Si desplegaste el backend de QuakeWatch (ver README), pegá acá su URL. '
          'Habilita notificaciones push y evita cargar tu API key de clima en el '
          'teléfono.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _backendController,
          decoration: const InputDecoration(
            labelText: 'URL del backend',
            hintText: 'https://tuusuario.pythonanywhere.com',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          onSubmitted: (v) =>
              context.read<SettingsService>().setBackendBaseUrl(v),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => context
                .read<SettingsService>()
                .setBackendBaseUrl(_backendController.text),
            child: const Text('Guardar backend'),
          ),
        ),
        const Divider(height: 32),
        Text('API key de OpenWeatherMap (modo sin backend)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Solo necesaria si NO configuraste un backend. Se guarda únicamente '
          'en este dispositivo, pero tené en cuenta que cualquiera que '
          'decompile el APK podría verla — para un release público conviene '
          'usar el backend.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _weatherKeyController,
          decoration: const InputDecoration(
            labelText: 'OpenWeatherMap API key',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          onSubmitted: (v) =>
              context.read<SettingsService>().setOpenWeatherApiKey(v),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => context
                .read<SettingsService>()
                .setOpenWeatherApiKey(_weatherKeyController.text),
            child: const Text('Guardar API key'),
          ),
        ),
      ],
    );
  }
}
