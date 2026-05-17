import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Handler isolé pour les messages reçus quand l'app est terminée
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage _) async {}

class NotificationService {
  static final _msg = FirebaseMessaging.instance;
  static final _db  = FirebaseFirestore.instance;
  static bool _initialized = false;

  // Clé globale — permet de naviguer sans BuildContext depuis les handlers
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Route en attente si l'app était terminée au moment du tap
  static String? _pendingRoute;

  // Mapping routineName (champ FCM data) → route Flutter
  static const _routes = <String, String>{
    'collective_shield': '/collective-shield',
    'squad_pulse':       '/squad-pulse',
    'morning_ritual':    '/morning-ritual',
    'audio_capsule':     '/audio-capsule',
    'twin_coherence':    '/twin-coherence',
    'mirror_aura':       '/mirror-aura',
    'silent_presence':   '/silent-presence',
    'pulse_match':       '/pulse-match',
  };

  /// À appeler une fois quand l'utilisateur est authentifié.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    // Demande la permission (iOS + Android 13+)
    await _msg.requestPermission(alert: true, badge: true, sound: true);

    // Sauvegarde le token FCM dans Firestore et surveille les rotations
    await _saveToken();
    _msg.onTokenRefresh.listen((_) => _saveToken());

    // Message reçu en foreground → bannière in-app
    FirebaseMessaging.onMessage.listen(_onForeground);

    // Tap sur la notif quand l'app est en background (ouverte)
    FirebaseMessaging.onMessageOpenedApp.listen(_onTap);

    // App rouverte depuis une notif (état terminé)
    // On stocke la route et on la flush après que la home page est prête
    final initial = await _msg.getInitialMessage();
    if (initial != null) {
      final route = _routes[initial.data['routineName'] as String? ?? ''];
      if (route != null) _pendingRoute = route;
    }
  }

  /// Appelé par la HomePage après son build — pousse la route en attente.
  static void flushPendingRoute() {
    if (_pendingRoute == null) return;
    final route = _pendingRoute!;
    _pendingRoute = null;
    // Petit délai pour laisser la HomePage se construire complètement
    Future.delayed(const Duration(milliseconds: 300), () {
      navigatorKey.currentState?.pushNamed(route);
    });
  }

  static Future<void> _saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await _msg.getToken();
    if (token == null) return;
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  static void _onForeground(RemoteMessage msg) {
    final routineName = msg.data['routineName'] as String?;
    final ctx = navigatorKey.currentContext;
    if (ctx == null || routineName == null) return;

    ScaffoldMessenger.of(ctx).showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFF065963),
        content: Text(
          msg.notification?.body ?? 'Invitation à une routine',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(ctx).hideCurrentMaterialBanner();
              _navigate(routineName);
            },
            child: const Text('Rejoindre',
                style: TextStyle(color: Color(0xFFE8B86E), fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(ctx).hideCurrentMaterialBanner(),
            child: const Text('Plus tard',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  static void _onTap(RemoteMessage msg) {
    final routineName = msg.data['routineName'] as String?;
    if (routineName != null) _navigate(routineName);
  }

  static void _navigate(String routineName) {
    final route = _routes[routineName];
    if (route != null) navigatorKey.currentState?.pushNamed(route);
  }
}
