import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Ce service gère la connexion temps réel entre deux Twins.
//
// Structure Firestore attendue :
//   profil_twin/{uid}  →  { twinUid: "uid_du_partenaire", twinName: "Prénom" }
//   twin_signals/{uid} →  { energy: 0.0–1.0, status: "active"|"idle",
//                           routineData: { ... }, updatedAt: timestamp }

class TwinService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get myUid => _auth.currentUser?.uid ?? '';

  // ── Trouver l'UID du Twin depuis profil_twin ───────────────────────
  static Future<String?> getTwinUid() async {
    if (myUid.isEmpty) return null;
    final doc = await _db.collection('profil_twin').doc(myUid).get();
    return doc.data()?['twinUid'] as String?;
  }

  // ── Écouter les signaux du Twin en temps réel ──────────────────────
  static Stream<DocumentSnapshot<Map<String, dynamic>>> twinSignalStream(
      String twinUid) =>
      _db.collection('twin_signals').doc(twinUid).snapshots();

  // ── Envoyer mes données (énergie, statut, données de routine) ──────
  static Future<void> sendSignal({
    double energy = 0.5,
    String status = 'active',
    Map<String, dynamic> routineData = const {},
  }) async {
    if (myUid.isEmpty) return;
    await _db.collection('twin_signals').doc(myUid).set({
      'energy': energy,
      'status': status,
      'routineData': routineData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Marquer qu'on est sorti de la routine ──────────────────────────
  static Future<void> leaveRoutine() => sendSignal(status: 'idle');
}
