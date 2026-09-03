import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/earthquake_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/weather_service.dart';
import 'theme/app_theme.dart';

class QuakeWatchApp extends StatelessWidget {
  const QuakeWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()..load()),
        ProxyProvider<SettingsService, EarthquakeService>(
          update: (_, settings, __) => EarthquakeService(settings),
        ),
        ProxyProvider<SettingsService, WeatherService>(
          update: (_, settings, __) => WeatherService(settings),
        ),
        ProxyProvider<SettingsService, NotificationService>(
          update: (_, settings, __) => NotificationService(settings),
        ),
      ],
      child: MaterialApp(
        title: 'QuakeWatch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}
