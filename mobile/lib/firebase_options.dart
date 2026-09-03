// ignore_for_file: type=lint
// PLACEHOLDER generado a mano — reemplazar corriendo:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// desde la carpeta mobile/, con tu propio proyecto de Firebase. Eso
// regenera este archivo con las claves reales y también deja
// android/app/google-services.json correcto. Hasta entonces, la app
// compila pero Firebase Messaging no va a poder inicializar el token real.
//
// Ver README.md -> "Configurar Firebase" para el paso a paso.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'QuakeWatch está pensado para Android; configurá flutterfire para web si lo necesitás.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para esta plataforma.',
        );
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'REEMPLAZAR-CON-flutterfire-configure',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'quakewatch-xxxxx',
    storageBucket: 'quakewatch-xxxxx.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'REEMPLAZAR-CON-flutterfire-configure',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'quakewatch-xxxxx',
    storageBucket: 'quakewatch-xxxxx.appspot.com',
    iosBundleId: 'com.sebas.quakewatch',
  );
}
