import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TwinService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get currentUid => _auth.currentUser?.uid ?? '';

  // ── Compatibilité routines existantes ────────────────────────────
  static String get myUid => currentUid;

  static Future<String?> getTwinUid() async {
    if (currentUid.isEmpty) return null;
    // Ancien système (profil_twin)
    final doc = await _db.collection('profil_twin').doc(currentUid).get();
    final oldUid = doc.data()?['twinUid'] as String?;
    if (oldUid != null && oldUid.isNotEmpty) return oldUid;
    // Nouveau système (twinInvitation) — utilisé si profil_twin vide
    final invite = await getMyMatchedTwin();
    if (invite == null) return null;
    final users = List<String>.from(invite['users'] ?? []);
    return users.firstWhere((uid) => uid != currentUid, orElse: () => '');
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> twinSignalStream(
          String twinUid) =>
      _db.collection('twin_signals').doc(twinUid).snapshots();

  static Future<void> sendSignal({
    double energy = 0.5,
    String status = 'active',
    Map<String, dynamic> routineData = const {},
  }) async {
    if (currentUid.isEmpty) return;
    await _db.collection('twin_signals').doc(currentUid).set({
      'energy': energy,
      'status': status,
      'routineData': routineData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> leaveRoutine() => sendSignal(status: 'idle');

  // ══════════════════════════════════════════════════════════════════
  // MATCHING TWIN
  // ══════════════════════════════════════════════════════════════════

  // Retourne le document twinInvitation où le match est confirmé
  // (status == 'accepted' ou pas de champ status — ancienne data FlutterFlow)
  static Future<Map<String, dynamic>?> getMyMatchedTwin() async {
    if (currentUid.isEmpty) return null;
    final snap = await _db
        .collection('twinInvitation')
        .where('users', arrayContains: currentUid)
        .get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      // Pas de status = ancienne data FlutterFlow déjà matchée
      if (status == null || status == 'accepted') {
        return {'id': doc.id, ...data};
      }
    }
    return null;
  }

  // Retourne le profil Firestore du twin matché
  static Future<Map<String, dynamic>?> getMyTwinProfile() async {
    final invite = await getMyMatchedTwin();
    if (invite == null) return null;
    final users = List<String>.from(invite['users'] ?? []);
    final twinUid =
        users.firstWhere((uid) => uid != currentUid, orElse: () => '');
    if (twinUid.isEmpty) return null;
    final doc = await _db.collection('users').doc(twinUid).get();
    if (doc.exists) return {'uid': doc.id, ...doc.data()!};
    // Compte sans profil Firestore (ex: compte test émulateur) — profil minimal
    return {'uid': twinUid, 'prenom': 'Twin'};
  }

  // Envoie une invitation de matching à quelqu'un
  static Future<void> sendTwinRequest(String toUid) async {
    // Vérifie qu'on n'a pas déjà un twin matché
    final existing = await getMyMatchedTwin();
    if (existing != null) throw Exception('Tu as déjà un twin.');

    // Vérifie qu'une invitation n'est pas déjà en attente entre ces deux personnes
    final pending = await _db
        .collection('twinInvitation')
        .where('users', arrayContains: currentUid)
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in pending.docs) {
      final users = List<String>.from(doc.data()['users'] ?? []);
      if (users.contains(toUid)) throw Exception('Invitation déjà envoyée.');
    }

    await _db.collection('twinInvitation').add({
      'users': [currentUid, toUid],
      'fromUid': currentUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Accepte une invitation de matching → le twin est confirmé
  static Future<void> acceptTwinRequest(String inviteId) async {
    final existing = await getMyMatchedTwin();
    if (existing != null) throw Exception('Tu as déjà un twin.');

    await _db.collection('twinInvitation').doc(inviteId).update({
      'status': 'accepted',
    });
  }

  // Refuse une invitation de matching
  static Future<void> declineTwinRequest(String inviteId) async {
    await _db.collection('twinInvitation').doc(inviteId).update({
      'status': 'declined',
    });
  }

  // Stream des invitations de matching en attente reçues
  static Stream<QuerySnapshot> myPendingTwinRequestsStream() {
    if (currentUid.isEmpty) return const Stream.empty();
    return _db
        .collection('twinInvitation')
        .where('users', arrayContains: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Recherche d'utilisateurs (même logique que squad)
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();

    final byEmail = await _db
        .collection('users')
        .where('email', isEqualTo: q)
        .limit(5)
        .get();

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

  // ══════════════════════════════════════════════════════════════════
  // SESSIONS DE ROUTINE TWIN
  // ══════════════════════════════════════════════════════════════════

  // Lance une session de routine — le twin reçoit l'invitation
  static Future<String> startTwinSession(
      String twinUid, String inviteId, String routineName) async {
    final ref = await _db.collection('twin_sessions').add({
      'twinInvitationId': inviteId,
      'users': [currentUid, twinUid],
      'routineName': routineName,
      'launchedBy': currentUid,
      'status': 'waiting',
      'acceptedBy': [currentUid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // Accepte une session → passe à 'active', les deux naviguent vers la routine
  static Future<void> acceptTwinSession(String sessionId) async {
    final ref = _db.collection('twin_sessions').doc(sessionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final accepted = List<String>.from(snap.data()?['acceptedBy'] ?? []);
      if (!accepted.contains(currentUid)) accepted.add(currentUid);
      tx.update(ref, {'acceptedBy': accepted, 'status': 'active'});
    });
  }

  // Refuse une session
  static Future<void> declineTwinSession(String sessionId) async {
    await _db
        .collection('twin_sessions')
        .doc(sessionId)
        .update({'status': 'declined'});
  }

  // Stream des sessions en attente (envoyées par le twin)
  static Stream<QuerySnapshot> pendingTwinSessionsStream(
      String twinInvitationId) {
    if (currentUid.isEmpty) return const Stream.empty();
    return _db
        .collection('twin_sessions')
        .where('twinInvitationId', isEqualTo: twinInvitationId)
        .where('users', arrayContains: currentUid)
        .where('status', isEqualTo: 'waiting')
        .snapshots();
  }

  // Stream temps réel d'une session
  static Stream<DocumentSnapshot> sessionStream(String sessionId) =>
      _db.collection('twin_sessions').doc(sessionId).snapshots();

  // ── Sessions de routine (nouveau flow Lobby) ──────────────────────

  static Future<String> createRoutineSession({
    required String twinUid,
    required String inviteId,
    required String routineKey,
    required String routineTitle,
    required String initiatorName,
    required String twinName,
  }) async {
    final ref = await _db.collection('twin_sessions').add({
      'routineKey':       routineKey,
      'routineTitle':     routineTitle,
      'twinInvitationId': inviteId,
      'users':            [currentUid, twinUid],
      'launchedBy':       currentUid,
      'initiatorName':    initiatorName,
      'twinName':         twinName,
      'status':           'waiting',
      'acceptedBy':       [currentUid],
      'extraData':        {},
      'createdAt':        FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // Stream des sessions en attente reçues (pour le twin qui n'est pas initiateur)
  static Stream<QuerySnapshot> incomingRoutineSessionsStream() {
    if (currentUid.isEmpty) return const Stream.empty();
    return _db
        .collection('twin_sessions')
        .where('users', arrayContains: currentUid)
        .where('status', whereIn: ['waiting', 'accepted'])
        .snapshots();
  }
}
