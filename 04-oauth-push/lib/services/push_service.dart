import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Se ejecuta cuando llega un mensaje con la app en segundo plano o cerrada.
/// Los mensajes con bloque "notification" los muestra el sistema automáticamente.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

class PushService {
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel('objetos_channel', 'Coincidencias y mensajes',
      description: 'Avisos de coincidencias y nuevos mensajes', importance: Importance.high);

  static Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      // toque en una notificación local (app en primer plano)
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) openFromData(Map<String, dynamic>.from(jsonDecode(r.payload!)));
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // App en primer plano: FCM no muestra la notificación, la mostramos localmente
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      _local.show(
        m.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(_channel.id, _channel.name, importance: Importance.high, priority: Priority.high),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(m.data),
      );
    });

    // App en segundo plano -> el usuario toca la notificación
    FirebaseMessaging.onMessageOpenedApp.listen((m) => openFromData(m.data));

    // Token renovado
    _fcm.onTokenRefresh.listen((_) => registerToken());
  }

  /// App cerrada (terminated) -> se abrió desde una notificación
  static Future<void> handleInitialMessage() async {
    final m = await _fcm.getInitialMessage();
    if (m != null) {
      // espera a que exista el navigator
      WidgetsBinding.instance.addPostFrameCallback((_) => openFromData(m.data));
    }
  }

  /// Navega a la publicación o conversación indicada en el payload
  static void openFromData(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    if (data['type'] == 'match' && data['postId'] != null) {
      nav.pushNamed('/post', arguments: data['postId']);
    } else if (data['type'] == 'chat' && data['chatId'] != null) {
      nav.pushNamed('/chat', arguments: data['chatId']);
    }
  }

  static Future<void> registerToken() async {
    final u = FirebaseAuth.instance.currentUser;
    final token = await _fcm.getToken();
    if (u == null || token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  static Future<void> unregisterToken() async {
    final u = FirebaseAuth.instance.currentUser;
    final token = await _fcm.getToken();
    if (u == null || token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(u.uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }
}
