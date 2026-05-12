import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get userStream => _auth.authStateChanges();

  static Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  // Crée le compte Auth + le document Firestore en une seule opération
  static Future<UserCredential> signUp({
    required String email,
    required String password,
    required String prenom,
    required String trancheAge,
    required String profession,
    required String adresse,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Crée le document users/{uid} avec toutes les infos du profil
    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': email,
      'prenom': prenom,
      'trancheAge': trancheAge,
      'profession': profession,
      'adresse': adresse,
      'squadUnlock': false,
      'twinUnlock': false,
      'created_time': FieldValue.serverTimestamp(),
    });
    return cred;
  }

  static Future<void> signOut() => _auth.signOut();
}
