import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';

// Redirige vers HomePage si connecté, sinon vers AuthScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // Utilisateur connecté → on importe HomePage dynamiquement
          // pour éviter les imports circulaires
          return const _HomeRedirect();
        }
        return const AuthScreen();
      },
    );
  }
}

// Widget intermédiaire pour accéder à HomePage sans import circulaire
class _HomeRedirect extends StatelessWidget {
  const _HomeRedirect();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed('/home');
    });
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Étape 1 — connexion ou inscription
  bool _isLogin = true;
  // Étape 2 — profil (uniquement inscription)
  bool _step2 = false;

  // Étape 1
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  // Étape 2
  final _prenomCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  String _trancheAge = '25-29';
  String _profession = 'Autre';

  bool _loading = false;
  String? _error;

  static const _burgundy = Color(0xFF065963);
  static const _bg = Color(0xFF121212);

  static const _tranches = ['18-24', '25-29', '30-35', '36-40', '41-50', '50+'];
  static const _professions = [
    'Étudiant(e)', 'Salarié(e)', 'Indépendant(e)',
    'Entrepreneur(e)', 'Sans emploi', 'Retraité(e)', 'Autre'
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _prenomCtrl.dispose();
    _adresseCtrl.dispose();
    super.dispose();
  }

  // Connexion
  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.signIn(_emailCtrl.text.trim(), _pwCtrl.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Étape 1 inscription → passe à l'étape 2
  void _goToStep2() {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Email invalide.');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = 'Mot de passe trop court (6 caractères min).');
      return;
    }
    setState(() { _step2 = true; _error = null; });
  }

  // Étape 2 inscription → crée le compte
  Future<void> _signUp() async {
    if (_prenomCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Entre ton prénom.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.signUp(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        trancheAge: _trancheAge,
        profession: _profession,
        adresse: _adresseCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _error = _friendlyError(e.code); _step2 = false; });
    } catch (e) {
      // Firestore write failure ou autre erreur non-Auth
      setState(() { _error = 'Erreur lors de la création du profil : $e'; _step2 = false; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found': return 'Aucun compte avec cet email.';
      case 'wrong-password': return 'Mot de passe incorrect.';
      case 'email-already-in-use': return 'Cet email est déjà utilisé.';
      case 'weak-password': return 'Mot de passe trop faible (6 caractères min).';
      case 'invalid-email': return 'Email invalide.';
      default: return 'Erreur : $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Text('Tiyia', style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 42, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                _isLogin ? 'Connexion'
                    : _step2 ? 'Ton profil'
                    : 'Créer un compte',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 18, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 40),

              if (!_step2) ...[
                // ── Étape 1 : email + mot de passe ──────────────────
                _Field(controller: _emailCtrl, label: 'Email',
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _Field(controller: _pwCtrl, label: 'Mot de passe', obscure: true),
              ] else ...[
                // ── Étape 2 : profil ─────────────────────────────────
                _Field(controller: _prenomCtrl, label: 'Prénom'),
                const SizedBox(height: 16),
                _Field(controller: _adresseCtrl, label: 'Ville / Adresse'),
                const SizedBox(height: 16),
                _DropdownField(
                  label: 'Tranche d\'âge',
                  value: _trancheAge,
                  items: _tranches,
                  onChanged: (v) => setState(() => _trancheAge = v!),
                ),
                const SizedBox(height: 16),
                _DropdownField(
                  label: 'Profession',
                  value: _profession,
                  items: _professions,
                  onChanged: (v) => setState(() => _profession = v!),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: GoogleFonts.poppins(
                  color: Colors.redAccent, fontSize: 13)),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : () {
                    if (_isLogin) {
                      _signIn();
                    } else if (_step2) {
                      _signUp();
                    } else {
                      _goToStep2();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _burgundy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isLogin ? 'Se connecter'
                              : _step2 ? 'Créer mon compte'
                              : 'Continuer →',
                          style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: _step2
                    ? TextButton(
                        onPressed: () => setState(() { _step2 = false; _error = null; }),
                        child: Text('← Retour', style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
                      )
                    : TextButton(
                        onPressed: () => setState(() {
                          _isLogin = !_isLogin;
                          _error = null;
                          _step2 = false;
                        }),
                        child: Text(
                          _isLogin ? "Pas encore de compte ? S'inscrire"
                              : 'Déjà un compte ? Se connecter',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 13)),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E1E1E),
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            items: items.map((e) => DropdownMenuItem(
              value: e,
              child: Text(e),
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF0DAABA), width: 1.5),
        ),
      ),
    );
  }
}
