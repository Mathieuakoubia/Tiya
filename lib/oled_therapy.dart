// Routine 16 — Introduction différée J45
// Pas d'interaction requise — fullscreen lumière pulsante à 0.1 Hz
import 'dart:async';
import 'package:flutter/material.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData sun = IconData(0xe966, fontFamily: _f);
}

const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _bg   = Color(0xFF121212);
const _gold = Color(0xFFE8B86E);

enum _Phase { warning, countdown, exercise, complete }

class OledTherapy extends StatefulWidget {
  final VoidCallback? onComplete;
  const OledTherapy({super.key, this.onComplete});

  @override
  State<OledTherapy> createState() => _OledTherapyState();
}

class _OledTherapyState extends State<OledTherapy>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 120;

  _Phase _phase     = _Phase.warning;
  int    _countdown = 3;
  int    _elapsed   = 0;

  // 0.1 Hz = 1 cycle / 10s = 5s montée + 5s descente
  late AnimationController _ctrl;
  late Animation<Color?>    _colorAnim;

  Timer? _cdTimer;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(seconds: 10), vsync: this);
    _colorAnim = ColorTween(
      begin: _bg,
      end: const Color(0xFF1A4A50),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  void _dismiss() {
    setState(() { _phase = _Phase.countdown; _countdown = 3; });
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          t.cancel();
          _startExercise();
        }
      });
    });
  }

  void _startExercise() {
    setState(() => _phase = _Phase.exercise);
    _ctrl.repeat(reverse: true);
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _ctrl.stop();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _cdTimer?.cancel();
    _exTimer?.cancel();
    super.dispose();
  }

  int    get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s)    => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.warning:   return _buildWarning();
      case _Phase.countdown: return _buildCountdown();
      case _Phase.exercise:  return _buildExercise();
      case _Phase.complete:  return _buildComplete();
    }
  }

  Widget _buildWarning() => Container(
    key: const ValueKey('warn'),
    color: _bg,
    child: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_Ico.sun, color: _teal.withValues(alpha: 0.60), size: 48),
        const SizedBox(height: 28),
        const Text(
          'Luminothérapie douce',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Gelica', color: Colors.white,
              fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Text(
          'Si vous êtes sensible à la lumière,\névitez cette routine.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _dismiss,
            style: ElevatedButton.styleFrom(
                backgroundColor: _dark, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0),
            child: const Text('Je comprends, continuer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ))),
  );

  Widget _buildCountdown() => Container(
    key: const ValueKey('cd'),
    color: _bg,
    child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Posez le téléphone face à vous',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 15, fontWeight: FontWeight.w300)),
        const SizedBox(height: 24),
        Text('$_countdown',
            style: const TextStyle(
                color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
      ],
    )),
  );

  Widget _buildExercise() => AnimatedBuilder(
    key: const ValueKey('ex'),
    animation: _colorAnim,
    builder: (_, __) => Stack(children: [
      Positioned.fill(child: ColoredBox(color: _colorAnim.value ?? _bg)),
      // Centre lumineux
      Center(child: Container(
        width: 200, height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _teal.withValues(alpha: _ctrl.value * 0.08),
          boxShadow: [BoxShadow(
            color: _teal.withValues(alpha: _ctrl.value * 0.18),
            blurRadius: 80, spreadRadius: 20)],
        ),
      )),
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text(_fmt(_remaining),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25), fontSize: 13)),
        )),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Text('Laissez la lumière agir',
              style: TextStyle(
                  fontFamily: 'Gelica',
                  color: Colors.white.withValues(alpha: 0.20),
                  fontSize: 14, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic)),
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 88, height: 88,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.sun, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          const Text("'Votre système nerveux\na été bercé par la lumière.'",
              textAlign: TextAlign.center,
              style: TextStyle(
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
              child: const Text('Continuer',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ))),
    ],
  );
}
