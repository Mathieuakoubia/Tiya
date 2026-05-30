// Routine 41 — Réveil Doux — 60s — transition sommeil → éveil
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

const _dark = Color(0xFF065963);
const _teal = Color(0xFF0DAABA);
const _gold = Color(0xFFE8B86E);

enum _Phase { exercise, complete }

class ReveilDoux extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onChainMorningAncrage; // optionnel — enchaîner avec MorningAncrage
  const ReveilDoux({super.key, this.onComplete, this.onChainMorningAncrage});
  @override State<ReveilDoux> createState() => _ReveilDouxState();
}

class _ReveilDouxState extends State<ReveilDoux>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 60, _cycleSec = 10, _inhaleSec = 5;
  _Phase _phase = _Phase.exercise;
  int _elapsed = 0;
  bool _isInhaling = true;

  late AnimationController _ctrl;
  late Animation<double>    _auraAnim;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: _cycleSec), vsync: this)..repeat();
    _auraAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.15).chain(CurveTween(curve: Curves.easeInOut)), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.75).chain(CurveTween(curve: Curves.easeInOut)), weight: 5),
    ]).animate(_ctrl);
    _ctrl.addListener(() {
      final inhale = _ctrl.value < (_inhaleSec / _cycleSec);
      if (inhale != _isInhaling) {
        setState(() => _isInhaling = inhale);
        if (inhale) Vibration.vibrate(duration: 30);
      }
    });
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _ctrl.stop(); Vibration.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() { _ctrl.dispose(); _exTimer?.cancel(); Vibration.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 600), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.exercise: return _buildExercise();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _ctrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFF050808))),
      // Halo soleil levant
      Center(child: Transform.scale(scale: _auraAnim.value, child: Container(
        width: 200, height: 200,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: _teal.withValues(alpha: 0.04 + (_elapsed / _totalSec) * 0.10),
            boxShadow: [BoxShadow(
                color: _teal.withValues(alpha: 0.05 + (_elapsed / _totalSec) * 0.15),
                blurRadius: 80, spreadRadius: 20)])))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Bonjour.',
              style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
                  fontSize: 32, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          Text(_isInhaling ? 'Inspirez doucement...' : 'Expirez...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14,
                  fontFamily: 'Gelica', fontStyle: FontStyle.italic)),
        ])))),
      Align(alignment: Alignment.bottomCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: _elapsed / _totalSec, minHeight: 3,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation(_teal.withValues(alpha: 0.40))))))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text("'Prenez votre temps.'", textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Color(0xFF232323),
                fontSize: 26, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        const SizedBox(height: 40),
        if (widget.onChainMorningAncrage != null) SizedBox(
          width: double.infinity, child: ElevatedButton(
          onPressed: widget.onChainMorningAncrage,
          style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
          child: const Text('Choisir mon intention du jour',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
          child: const Text('Commencer la journée',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
      ])))),
  ]);
}
