import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'settings_service.dart';

/// Handler top-level requerido por firebase_messaging para mensajes que
/// llegan con la app en background/terminada.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No hace falta mostrar nada acá manualmente: si el push trae un bloque
  // "notification" (que es como lo arma nuestro backend), Android ya la
  // muestra sola usando el canal por defecto declarado en el manifest.
  debugPrint('[FCM][background] ${message.messageId}: ${message.data}');
}

const _alertsChannel = AndroidNotificationChannel(
  'quakewatch_alerts',
  'Alertas de sismos y clima',
  description: 'Notificaciones de sismos cerca tuyo y alertas meteorológicas',
  importance: Importance.high,
);

/// Maneja permisos de notificación, registro del token FCM contra el
/// backend, y la presentación de notificaciones locales cuando el mensaje
/// llega con la app abierta en primer plano (FCM no muestra push visual
/// automáticamente en foreground).
class NotificationService {
  final SettingsService settings;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationService(this.settings);

  Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_alertsChannel);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    final token = await _messaging.getToken();
    if (token != null) {
      await settings.setFcmToken(token);
      await _registerTokenWithBackend(token);
    }
    _messaging.onTokenRefresh.listen((newToken) async {
      await settings.setFcmToken(newToken);
      await _registerTokenWithBackend(newToken);
    });
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alertsChannel.id,
          _alertsChannel.name,
          channelDescription: _alertsChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Le avisa al backend "este dispositivo quiere recibir alertas para tal
  /// ubicación / radio / magnitud mínima", para que el ingestor sepa a
  /// quién pushear cuando entra un sismo nuevo. Si no hay backend
  /// configurado, no hace nada (no hay a quién avisar).
  Future<void> registerLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (!settings.hasBackend || settings.fcmToken == null) return;
    await _registerTokenWithBackend(
      settings.fcmToken!,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> _registerTokenWithBackend(
    String token, {
    double? latitude,
    double? longitude,
  }) async {
    if (!settings.hasBackend) return;
    try {
      final base = settings.backendBaseUrl!.replaceAll(RegExp(r'/+$'), '');
      await http.post(
        Uri.parse('$base/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcm_token': token,
          'platform': Platform.isAndroid ? 'android' : 'other',
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'radius_km': settings.radiusKm,
          'min_magnitude': settings.minMagnitudeToNotify,
        }),
      );
    } catch (e) {
      debugPrint('No se pudo registrar el token en el backend: $e');
    }
  }
}
