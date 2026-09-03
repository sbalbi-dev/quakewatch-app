import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Si Firebase todavía no está configurado (ver firebase_options.dart),
    // la app arranca igual: earthquake/weather funcionan, solo faltan los
    // pushes hasta que corras `flutterfire configure`. El resto de la
    // inicialización de notificaciones (canal, permisos, registro del
    // token) ocurre en HomeScreen una vez que hay un SettingsService listo.
    debugPrint('Firebase no se pudo inicializar todavía: $e');
  }

  runApp(const QuakeWatchApp());
}
