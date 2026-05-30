// Routine 34 — Capturer un moment positif + capsule persistante
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData sparkle = IconData(0xe964, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

class SavoringMoment extends StatefulWidget {
  final VoidCallback? onComplete;
  const SavoringMoment({super.key, this.onComplete});

  @override
  State<SavoringMoment> createState() => _SavoringMomentState();
}

class _SavoringMomentState extends State<SavoringMoment> {
  final _q1Ctrl = TextEditingController(); // ressenti corporel
  final _q2Ctrl = TextEditingController(); // ce qu'on veut retenir
  final _q3Ctrl = TextEditingController(); // à qui/quoi on le doit

  bool _saving = false;
  bool _saved  = false;

  @override
  void dispose() {
    _q1Ctrl.dispose();
    _q2Ctrl.dispose();
    _q3Ctrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _q1Ctrl.text.trim().isNotEmpty &&
      _q2Ctrl.text.trim().isNotEmpty &&
      _q3Ctrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final now = DateTime.now();
      // ID déterministe avec timestamp ms — idempotent sur même contenu
      await FirebaseFirestore.instance
          .collection('user_notes')
          .doc(uid)
          .collection('entries')
          .add({
        'type'       : 'savoring',
        'ressenti'   : _q1Ctrl.text.trim(),
        'retenir'    : _q2Ctrl.text.trim(),
        'grace_a'    : _q3Ctrl.text.trim(),
        'createdAt'  : FieldValue.serverTimestamp(),
      });
    }
    setState(() { _saving = false; _saved = true; });
    await Future.delayed(const Duration(milliseconds: 1200));
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _saved ? _buildSaved() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() => SingleChildScrollView(
    key: const ValueKey('form'),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
    child: Column(children: [
      Icon(_Ico.sparkle, color: _gold.withValues(alpha: 0.70), size: 44),
      const SizedBox(height: 20),
      const Text(
        'Quelque chose de bon arrive.\nCapturons-le.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: 'Gelica', color: Colors.white,
            fontSize: 20, fontWeight: FontWeight.w200,
            fontStyle: FontStyle.italic, height: 1.4),
      ),
      const SizedBox(height: 36),
      _Question(
        number: '01',
        question: 'Qu\'est-ce que vous ressentez\ndans votre corps ?',
        ctrl: _q1Ctrl,
        color: _teal,
        maxLength: 120,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 24),
      _Question(
        number: '02',
        question: 'Qu\'est-ce que vous voulez\nretenir de ce moment ?',
        ctrl: _q2Ctrl,
        color: _gold,
        maxLength: 120,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 24),
      _Question(
        number: '03',
        question: 'À qui ou à quoi\nvous le devez-vous ?',
        ctrl: _q3Ctrl,
        color: const Color(0xFFD9CCE8),
        maxLength: 80,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 40),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canSave && !_saving ? _save : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              disabledBackgroundColor: _dark.withValues(alpha: 0.30),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0),
          child: _saving
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white)))
              : const Text('Archiver cette capsule',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
  );

  Widget _buildSaved() => Stack(
    key: const ValueKey('saved'),
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
      Container(color: Colors.white.withValues(alpha: 0.10)),
      SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 88, height: 88,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.sparkle, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          const Text("'Ce moment est maintenant\narchivé pour vous.'",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Gelica', color: Color(0xFF232323),
                  fontSize: 22, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic, height: 1.45)),
        ]),
      ))),
    ],
  );
}

class _Question extends StatelessWidget {
  final String number;
  final String question;
  final TextEditingController ctrl;
  final Color color;
  final int maxLength;
  final ValueChanged<String> onChanged;

  const _Question({
    required this.number, required this.question,
    required this.ctrl, required this.color,
    required this.maxLength, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(number,
            style: TextStyle(
                fontFamily: 'Gelica',
                color: color.withValues(alpha: 0.50),
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(question,
              style: TextStyle(
                  fontFamily: 'Gelica',
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 14, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic, height: 1.4)),
        ),
      ]),
      const SizedBox(height: 10),
      TextField(
        controller: ctrl,
        onChanged: onChanged,
        maxLength: maxLength,
        maxLines: 3,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color, width: 1.5)),
        ),
      ),
    ]);
  }
}
