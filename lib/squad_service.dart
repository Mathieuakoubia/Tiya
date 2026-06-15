import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SquadService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get currentUid => _auth.currentUser?.uid ?? '';

  // ── Squad Pulse (énergie temps réel — ancien système FlutterFlow) ──

  static const _hardcodedSquadId = 'ZvpDnxWkjDL5djWEdRu6';

  static Stream<QuerySnapshot<Map<String, dynamic>>> membersStream() =>
      _db.collection('Squad').doc(_hardcodedSquadId).collection('members').snapshots();

  static Future<void> updateMyEnergy(double energy,
          {String displayName = 'Moi'}) =>
      _db.collection('Squad').doc(_hardcodedSquadId).collection('members').doc(currentUid).set({
        'displayName': displayName,
        'energy': energy,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  // ── Lecture ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getMyProfile() async {
    final doc = await _db.collection('users').doc(currentUid).get();
    return doc.data();
  }

  static Future<Map<String, dynamic>?> getMySquad() async {
    final profile = await getMyProfile();
    final squadId = profile?['squadId'] as String?;
    if (squadId == null) return null;
    final doc = await _db.collection('squads').doc(squadId).get();
    return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
  }

  // Stream temps réel des membres du squad courant
  static Stream<List<Map<String, dynamic>>> mySquadMembersStream(
      String squadId) {
    return _db
        .collection('squads')
        .doc(squadId)
        .snapshots()
        .asyncMap((snap) async {
      final users = List<String>.from(snap.data()?['users'] ?? []);
      if (users.isEmpty) return [];
      final docs = await Future.wait(
        users.map((uid) => _db.collection('users').doc(uid).get()),
      );
      return docs
          .where((d) => d.exists)
          .map((d) => {'uid': d.id, ...d.data()!})
          .toList();
    });
  }

  // Stream des invitations en attente pour l'utilisateur courant
  static Stream<QuerySnapshot> myPendingInvitesStream() {
    if (currentUid.isEmpty) return const Stream.empty();
    return _db
        .collection('squad_invitations')
        .where('toUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // ── Recherche ─────────────────────────────────────────────────────

  // Cherche des utilisateurs par email exact ou prénom (préfixe, insensible à la casse)
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();

    final byEmail = await _db
        .collection('users')
        .where('email', isEqualTo: q)
        .limit(5)
        .get();

    //  est le caractère Unicode le plus haut — permet une recherche par préfixe
    final byName = await _db
        .collection('users')
        .orderBy('prenom')
        .startAt([q])
        .endAt(['$q'])
        .limit(5)
        .get();

    final seen = <String>{};
    final results = <Map<String, dynamic>>[];
    for (final doc in [...byEmail.docs, ...byName.docs]) {
      if (doc.id == currentUid) continue;
      if (seen.contains(doc.id)) continue;
      seen.add(doc.id);
      results.add({'uid': doc.id, ...doc.data()});
    }
    return results;
  }

  // ── Création & Gestion du Squad ───────────────────────────────────

  static Future<String> createSquad(String name) async {
    final profile = await getMyProfile();
    if (profile?['squadId'] != null) {
      throw Exception('Tu fais déjà partie d\'un squad.');
    }

    final ref = _db.collection('squads').doc();
    await ref.set({
      'name': name,
      'createdBy': currentUid,
      'users': [currentUid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(currentUid).update({
      'squadId': ref.id,
    });

    return ref.id;
  }

  static Future<void> sendInvite(String toUid) async {
    final squad = await getMySquad();
    if (squad == null) throw Exception('Tu n\'as pas de squad.');

    final users = List<String>.from(squad['users'] ?? []);
    if (users.length >= 5) throw Exception('Squad complet (5 membres max).');
    if (users.contains(toUid)) throw Exception('Déjà membre du squad.');

    final myProfile = await getMyProfile();

    final existing = await _db
        .collection('squad_invitations')
        .where('squadId', isEqualTo: squad['id'])
        .where('fromUid', isEqualTo: currentUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existing.docs.isNotEmpty) throw Exception('Invitation déjà envoyée.');

    await _db.collection('squad_invitations').add({
      'squadId': squad['id'],
      'squadName': squad['name'],
      'fromUid': currentUid,
      'fromName': myProfile?['prenom'] ?? 'Quelqu\'un',
      'toUid': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> acceptInvite(String inviteId, String squadId) async {
    final profile = await getMyProfile();
    if (profile?['squadId'] != null) {
      throw Exception('Tu fais déjà partie d\'un squad.');
    }

    // Pas de lecture préalable du squad : le receveur n'est pas encore membre
    // et les règles Firestore bloquent la lecture. La limite de 5 membres est
    // vérifiée côté serveur lors du update (règle hasOnly(['users']) + size() <= 5).
    await _db.runTransaction((tx) async {
      tx.update(_db.collection('squads').doc(squadId), {
        'users': FieldValue.arrayUnion([currentUid]),
      });
      tx.update(_db.collection('squad_invitations').doc(inviteId), {
        'status': 'accepted',
      });
      tx.update(_db.collection('users').doc(currentUid), {
        'squadId': squadId,
      });
    });
  }

  static Future<void> declineInvite(String inviteId) async {
    await _db.collection('squad_invitations').doc(inviteId).update({
      'status': 'declined',
    });
  }

  static Future<void> leaveSquad() async {
    final profile = await getMyProfile();
    final squadId = profile?['squadId'] as String?;
    if (squadId == null) return;

    await _db.runTransaction((tx) async {
      tx.update(_db.collection('squads').doc(squadId), {
        'users': FieldValue.arrayRemove([currentUid]),
      });
      tx.update(_db.collection('users').doc(currentUid), {
        'squadId': FieldValue.delete(),
      });
    });
  }

  // ── Sessions de routine ───────────────────────────────────────────

  static Future<String> startRoutineSession(
      String squadId, String routineName) async {
    final ref = _db.collection('squad_sessions').add({
      'squadId': squadId,
      'routineName': routineName,
      'launchedBy': currentUid,
      'status': 'waiting',
      'acceptedBy': [currentUid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return (await ref).id;
  }

  static Future<void> acceptRoutineSession(String sessionId) async {
    final ref = _db.collection('squad_sessions').doc(sessionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final accepted = List<String>.from(snap.data()?['acceptedBy'] ?? []);
      accepted.add(currentUid);
      final newStatus = accepted.length >= 2 ? 'active' : 'waiting';
      tx.update(ref, {
        'acceptedBy': accepted,
        'status': newStatus,
      });
    });
  }

  static Stream<DocumentSnapshot> sessionStream(String sessionId) {
    return _db.collection('squad_sessions').doc(sessionId).snapshots();
  }

  static Stream<QuerySnapshot> pendingSessionsStream(String squadId) {
    return _db
        .collection('squad_sessions')
        .where('squadId', isEqualTo: squadId)
        .where('status', isEqualTo: 'waiting')
        .snapshots();
  }

  // ── Sessions de routine (nouveau flow Lobby) ──────────────────────

  static Future<String> createRoutineSession({
    required String squadId,
    required String routineKey,
    required String routineTitle,
    required String initiatorName,
    required List<String> memberUids,
    required List<String> memberNames,
  }) async {
    final ref = await _db.collection('squad_sessions').add({
      'routineKey':    routineKey,
      'routineTitle':  routineTitle,
      'squadId':       squadId,
      'launchedBy':    currentUid,
      'initiatorName': initiatorName,
      'memberUids':    memberUids,
      'memberNames':   memberNames,
      'status':        'waiting',
      'acceptedBy':    [currentUid],
      'extraData':     {},
      'createdAt':     FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // Sessions en attente pour tout le squad (reçues ET envoyées)
  static Stream<QuerySnapshot> incomingRoutineSessionsStream(String squadId) {
    if (currentUid.isEmpty) return const Stream.empty();
    return _db
        .collection('squad_sessions')
        .where('squadId', isEqualTo: squadId)
        .where('status', whereIn: ['waiting', 'accepted'])
        .snapshots();
  }
}
