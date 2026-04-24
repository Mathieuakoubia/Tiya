import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SquadService {
  static const squadId = 'ZvpDnxWkjDL5djWEdRu6';

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get currentUid => _auth.currentUser?.uid ?? 'anonymous';

  // Stream temps réel de tous les membres du squad
  static Stream<QuerySnapshot<Map<String, dynamic>>> membersStream() => _db
      .collection('Squad')
      .doc(squadId)
      .collection('members')
      .snapshots();

  // Écrire l'énergie de l'utilisateur courant dans Firestore
  static Future<void> updateMyEnergy(double energy,
      {String displayName = 'Moi'}) =>
      _db
          .collection('Squad')
          .doc(squadId)
          .collection('members')
          .doc(currentUid)
          .set({
        'displayName': displayName,
        'energy': energy,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
