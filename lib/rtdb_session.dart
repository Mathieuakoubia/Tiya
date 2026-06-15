// Helper partagé pour toutes les routines Twin/Squad — Firebase RTDB
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Gère la connexion RTDB pour une session Twin ou Squad.
/// Usage :
///   final session = RtdbSession('sessionId');
///   await session.init();
///   session.onBothReady(() { ... });
///   session.send('breathPhase', 0.45);
///   session.listenPartner('breathPhase', (val) { ... });
///   session.dispose();
class RtdbSession {
  final String sessionId;
  late final DatabaseReference _ref;
  late final String _myUid;
  final List<StreamSubscription> _subs = [];

  RtdbSession(this.sessionId) {
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _ref   = FirebaseDatabase.instance.ref('sessions/$sessionId');
  }

  String get myUid => _myUid;

  /// Marque l'utilisateur comme prêt et appelle [onReady] quand au moins
  /// [minUsers] participants sont connectés.
  Future<void> markReady({int minUsers = 2, void Function()? onReady}) async {
    await _ref.child('ready/$_myUid').set(true);
    _subs.add(_ref.child('ready').onValue.listen((event) {
      final map = event.snapshot.value as Map?;
      if (map != null && map.length >= minUsers) onReady?.call();
    }));
  }

  /// Écrit une valeur sous sessions/{id}/{key}/{myUid}
  Future<void> send(String key, dynamic value) async {
    await _ref.child('$key/$_myUid').set(value);
  }

  /// Écoute les changements de sessions/{id}/{key} et appelle [callback]
  /// avec la valeur du partenaire (tous les UIDs sauf le mien).
  StreamSubscription listenPartner(String key, void Function(dynamic) callback) {
    final sub = _ref.child(key).onValue.listen((event) {
      final map = event.snapshot.value as Map?;
      if (map == null) return;
      map.forEach((uid, val) {
        if (uid != _myUid) callback(val);
      });
    });
    _subs.add(sub);
    return sub;
  }

  /// Écoute toute la map d'une clé (utile pour Squad avec plusieurs membres).
  StreamSubscription listenAll(String key, void Function(Map) callback) {
    final sub = _ref.child(key).onValue.listen((event) {
      final map = event.snapshot.value as Map?;
      if (map != null) callback(Map.from(map));
    });
    _subs.add(sub);
    return sub;
  }

  /// Écrit directement sessions/{id}/{key} = value (broadcast simple).
  Future<void> broadcast(String key, dynamic value) async {
    await _ref.child(key).set(value);
  }

  /// Écoute sessions/{id}/{key} (broadcast simple).
  StreamSubscription listenBroadcast(String key, void Function(dynamic) callback) {
    final sub = _ref.child(key).onValue.listen((event) {
      callback(event.snapshot.value);
    });
    _subs.add(sub);
    return sub;
  }

  /// Nettoie toutes les données éphémères et annule les abonnements.
  Future<void> dispose() async {
    for (final s in _subs) await s.cancel();
    await _ref.remove();
  }
}
