import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData plant = IconData(0xe95b, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);
const _rose = Color(0xFFFFD7E7);

final _pebbleColors = [_teal, _gold, _rose,
    const Color(0xFFD9CCE8), const Color(0xFF065963)];

class GratitudeFlash extends StatefulWidget {
  final VoidCallback? onComplete;
  const GratitudeFlash({super.key, this.onComplete});

  @override
  State<GratitudeFlash> createState() => _GratitudeFlashState();
}

class _GratitudeFlashState extends State<GratitudeFlash>
    with TickerProviderStateMixin {
  final _ctrl1 = TextEditingController();
  final _ctrl2 = TextEditingController();
  final _ctrl3 = TextEditingController();

  bool _saving    = false;
  bool _showAnim  = false;
  List<_Pebble>   _pebbles = [];
  List<AnimationController> _animCtrls = [];
  final _rng      = Random();

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    _ctrl3.dispose();
    for (final c in _animCtrls) c.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _ctrl1.text.trim().isNotEmpty &&
      _ctrl2.text.trim().isNotEmpty &&
      _ctrl3.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2,'0')}'
          '-${today.day.toString().padLeft(2,'0')}';
      // ID déterministe = idempotent
      await FirebaseFirestore.instance
          .collection('user_notes')
          .doc(uid)
          .collection('entries')
          .doc('gratitude_$dateKey')
          .set({
        'type': 'gratitude',
        'items': [
          _ctrl1.text.trim(),
          _ctrl2.text.trim(),
          _ctrl3.text.trim(),
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    _launchPebbleAnim();
  }

  void _launchPebbleAnim() {
    final size = MediaQuery.of(context).size;
    _pebbles = List.generate(3, (i) => _Pebble(
      x: size.width * 0.25 + i * size.width * 0.25,
      y: size.height * 0.45,
      color: _pebbleColors[i % _pebbleColors.length],
      radius: 14.0 + _rng.nextDouble() * 8,
    ));
    _animCtrls = List.generate(3, (i) => AnimationController(
      duration: Duration(milliseconds: 600 + i * 120),
      vsync: this,
    ));
    setState(() { _saving = false; _showAnim = true; });
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 120), () {
        if (mounted) _animCtrls[i].forward();
      });
    }
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _showAnim ? _buildAnim() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() => SingleChildScrollView(
    key: const ValueKey('form'),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
    child: Column(children: [
      const Text(
        'Trois choses qui vous ont\nfait du bien aujourd\'hui.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: 'Gelica', color: Colors.white,
            fontSize: 22, fontWeight: FontWeight.w200,
            fontStyle: FontStyle.italic, height: 1.45),
      ),
      const SizedBox(height: 8),
      Text('Même petites.',
          style: TextStyle(
              fontFamily: 'Gelica',
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 15, fontWeight: FontWeight.w200,
              fontStyle: FontStyle.italic)),
      const SizedBox(height: 36),
      _GratInput(ctrl: _ctrl1, number: '01', color: _teal,
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 16),
      _GratInput(ctrl: _ctrl2, number: '02', color: _gold,
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 16),
      _GratInput(ctrl: _ctrl3, number: '03', color: _rose,
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 40),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canSave && !_saving ? _save : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              disabledBackgroundColor: _dark.withValues(alpha: 0.35),
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
              : const Text('Déposer mes galets',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
  );

  Widget _buildAnim() => Stack(
    key: const ValueKey('anim'),
    children: [
      Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover,
          width: double.infinity, height: double.infinity),
      Container(color: Colors.white.withValues(alpha: 0.10)),
      Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ..._pebbles.asMap().entries.map((e) {
            final i   = e.key;
            final p   = e.value;
            if (i >= _animCtrls.length) return const SizedBox.shrink();
            return AnimatedBuilder(
              animation: _animCtrls[i],
              builder: (_, __) {
                final t = _animCtrls[i].value;
                return Transform.translate(
                  offset: Offset(0, -40 * t),
                  child: Opacity(
                    opacity: t < 0.8 ? 1.0 : (1.0 - t) / 0.2,
                    child: Container(
                      width: p.radius * 2, height: p.radius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.color,
                        boxShadow: [BoxShadow(
                            color: p.color.withValues(alpha: 0.40),
                            blurRadius: 20, spreadRadius: 2)],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          const SizedBox(height: 32),
          const Text('Vos galets ont été déposés.',
              style: TextStyle(
                  fontFamily: 'Gelica', color: Color(0xFF232323),
                  fontSize: 18, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic)),
        ],
      )),
    ],
  );
}

class _GratInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String number;
  final Color color;
  final ValueChanged<String> onChanged;
  const _GratInput({
    required this.ctrl, required this.number,
    required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(number,
          style: TextStyle(
              fontFamily: 'Gelica',
              color: color.withValues(alpha: 0.50),
              fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(width: 14),
      Expanded(
        child: TextField(
          controller: ctrl,
          onChanged: onChanged,
          maxLength: 80,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Quelque chose de bien...',
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 14),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: color, width: 1.5)),
          ),
        ),
      ),
    ]);
  }
}

class _Pebble {
  final double x, y, radius;
  final Color color;
  const _Pebble({
    required this.x, required this.y,
    required this.radius, required this.color,
  });
}
