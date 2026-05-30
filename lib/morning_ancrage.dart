import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData sun     = IconData(0xe969, fontFamily: _f);
  static const IconData sparkle = IconData(0xe964, fontFamily: _f);
}

const _bg    = Color(0xFF121212);
const _teal  = Color(0xFF0DAABA);
const _dark  = Color(0xFF065963);
const _gold  = Color(0xFFE8B86E);
const _lilas = Color(0xFFD9CCE8);

const _intentions = [
  ('Clarté',    _teal),
  ('Douceur',   _lilas),
  ('Présence',  _gold),
  ('Force',     Color(0xFFF2631D)),
  ('Légèreté',  Color(0xFF065963)),
  ('Patience',  Color(0xFFD9CCE8)),
];

enum _Screen { choice, breathing, complete }

class MorningAncrage extends StatefulWidget {
  final VoidCallback? onComplete;
  const MorningAncrage({super.key, this.onComplete});

  @override
  State<MorningAncrage> createState() => _MorningAncrageState();
}

class _MorningAncrageState extends State<MorningAncrage>
    with SingleTickerProviderStateMixin {
  static const int _cycleSec    = 10;
  static const int _inhaleSec   = 5;
  static const int _breathCycles = 4;

  _Screen _screen        = _Screen.choice;
  String? _chosen;
  Color   _chosenColor   = _teal;
  bool    _isInhaling    = true;
  int     _cyclesDone    = 0;

  late AnimationController _ctrl;
  late Animation<double>   _aura;

  Timer? _breathTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(seconds: _cycleSec), vsync: this);
    _aura = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.75, end: 1.30)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 5),
      TweenSequenceItem(
          tween: Tween(begin: 1.30, end: 0.75)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 5),
    ]).animate(_ctrl);
    _ctrl.addListener(_onBreathTick);
  }

  void _onBreathTick() {
    final inhale = _ctrl.value < (_inhaleSec / _cycleSec);
    if (inhale != _isInhaling) {
      setState(() => _isInhaling = inhale);
      if (!inhale) Vibration.vibrate(duration: 50);
    }
  }

  void _onIntentionSelected(String word, Color color) {
    setState(() {
      _chosen      = word;
      _chosenColor = color;
      _screen      = _Screen.breathing;
    });
    _ctrl.repeat();
    // 4 cycles × 10s = 40s
    _breathTimer = Timer.periodic(
        const Duration(seconds: _cycleSec), (t) {
      if (!mounted) { t.cancel(); return; }
      _cyclesDone++;
      if (_cyclesDone >= _breathCycles) {
        t.cancel();
        _complete();
      }
    });
  }

  Future<void> _complete() async {
    _ctrl.stop();
    Vibration.vibrate(pattern: [0, 200, 100, 200]);
    setState(() => _screen = _Screen.complete);
    // Sauvegarde idempotente (set avec merge)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && _chosen != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'intentionDuJour': _chosen}, SetOptions(merge: true));
    }
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onBreathTick);
    _ctrl.dispose();
    _breathTimer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _buildScreen(),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case _Screen.choice:    return _buildChoice();
      case _Screen.breathing: return _buildBreathing();
      case _Screen.complete:  return _buildComplete();
    }
  }

  Widget _buildChoice() => Container(
    key: const ValueKey('choice'),
    color: _bg,
    child: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(children: [
        const SizedBox(height: 20),
        const Text(
          'Avant que la journée\nne vous prenne,',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Gelica', color: Colors.white,
              fontSize: 22, fontWeight: FontWeight.w200,
              fontStyle: FontStyle.italic, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text('que voulez-vous y apporter ?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Gelica',
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 16, fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic)),
        const Spacer(),
        Wrap(
          spacing: 14, runSpacing: 14,
          alignment: WrapAlignment.center,
          children: _intentions.map((e) {
            final word  = e.$1;
            final color = e.$2;
            return GestureDetector(
              onTap: () => _onIntentionSelected(word, color),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: color.withValues(alpha: 0.10),
                  border: Border.all(
                      color: color.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Text(word,
                    style: TextStyle(
                        fontFamily: 'Gelica',
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ),
            );
          }).toList(),
        ),
        const Spacer(),
      ]),
    )),
  );

  Widget _buildBreathing() => AnimatedBuilder(
    key: const ValueKey('breath'),
    animation: _ctrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: Stack(alignment: Alignment.center, children: [
        Transform.scale(
          scale: _aura.value,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _chosenColor.withValues(alpha: 0.08),
              boxShadow: [BoxShadow(
                color: _chosenColor.withValues(alpha: 0.20),
                blurRadius: 60, spreadRadius: 12)],
            ),
          ),
        ),
        Text(_chosen ?? '',
            style: TextStyle(
                fontFamily: 'Gelica',
                color: _chosenColor,
                fontSize: 26,
                fontWeight: FontWeight.w600)),
      ])),
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 42),
          child: Text(
            _isInhaling ? 'Inspirez...' : 'Expirez...',
            style: const TextStyle(
                fontFamily: 'Gelica',
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic),
          ),
        )),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Text('${_breathCycles - _cyclesDone} cycle${_breathCycles - _cyclesDone > 1 ? 's' : ''} restant${_breathCycles - _cyclesDone > 1 ? 's' : ''}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 13)),
        )),
      ),
    ]),
  );

  Widget _buildComplete() => Stack(
    key: const ValueKey('done'),
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
      Container(color: Colors.white.withValues(alpha: 0.10)),
      SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _chosenColor.withValues(alpha: 0.85)),
              child: const Icon(_Ico.sun, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 28),
            Text("'Votre intention du jour\nest $_chosen.'",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Gelica', color: Color(0xFF232323),
                    fontSize: 22, fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic, height: 1.45)),
            const SizedBox(height: 52),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _dark, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0),
                child: const Text('Commencer la journée',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ))),
    ],
  );
}
