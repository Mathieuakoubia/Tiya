// Routine 32 — Between Two Worlds — 60s — transition de contexte ultra-simple
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

const _dark = Color(0xFF065963);

enum _Phase { exercise, complete }

class BetweenTwoWorlds extends StatefulWidget {
  final VoidCallback? onComplete;
  const BetweenTwoWorlds({super.key, this.onComplete});
  @override State<BetweenTwoWorlds> createState() => _BetweenTwoWorldsState();
}

class _BetweenTwoWorldsState extends State<BetweenTwoWorlds>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 60;
  _Phase _phase = _Phase.exercise;
  int _elapsed = 0;

  late AnimationController _ctrl;
  late Animation<Color?> _colorAnim;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: _totalSec), vsync: this)..forward();
    _colorAnim = ColorTween(
      begin: const Color(0xFF0DAABA),
      end: const Color(0xFFE8B86E),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    // Haptique très légère toutes les 10s
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed % 10 == 0 && _elapsed < _totalSec) Vibration.vibrate(duration: 30);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() { _ctrl.dispose(); _exTimer?.cancel(); Vibration.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.exercise: return _buildExercise();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _colorAnim,
    builder: (_, __) => Container(
      color: _colorAnim.value ?? const Color(0xFF0DAABA),
      child: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Un moment\nentre deux.', textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
                  fontSize: 28, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.4)),
          const SizedBox(height: 24),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: _elapsed / _totalSec, minHeight: 3,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(Colors.white))),
        ]))))));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text("'Vous êtes prête\npour la suite.'", textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Color(0xFF232323),
                fontSize: 24, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.4)),
        const SizedBox(height: 52),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
          child: const Text('Continuer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)))),
      ])))),
  ]);
}
