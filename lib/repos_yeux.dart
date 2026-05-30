// Routine 43 — Repos Yeux — 60s — fatigue oculaire numérique
import 'dart:async';
import 'package:flutter/material.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData eye = IconData(0xe934, fontFamily: _f); }
const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

const _targets = [
  _Target('Proche', Alignment.center, 0.05),
  _Target('Lointain', Alignment.center, 0.35),
  _Target('Gauche', Alignment(-0.8, 0.0), 0.60),
  _Target('Droite', Alignment(0.8, 0.0), 0.80),
];

class _Target {
  final String label;
  final Alignment align;
  final double from; // proportion du temps total
  const _Target(this.label, this.align, this.from);
}

enum _Phase { exercise, eyesClosed, complete }

class ReposYeux extends StatefulWidget {
  final VoidCallback? onComplete;
  const ReposYeux({super.key, this.onComplete});
  @override State<ReposYeux> createState() => _ReposYeuxState();
}

class _ReposYeuxState extends State<ReposYeux> {
  static const int _totalSec = 60, _closedSec = 15;
  _Phase _phase = _Phase.exercise;
  int _elapsed = 0;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec - _closedSec && _phase == _Phase.exercise) {
        setState(() => _phase = _Phase.eyesClosed);
      }
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() { _exTimer?.cancel(); super.dispose(); }

  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  _Target get _currentTarget {
    final progress = _elapsed / _totalSec;
    _Target current = _targets[0];
    for (final t in _targets) { if (progress >= t.from) current = t; }
    return current;
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 500), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.exercise:    return _buildExercise();
      case _Phase.eyesClosed: return _buildEyesClosed();
      case _Phase.complete:    return _buildComplete();
    }
  }

  Widget _buildExercise() {
    final target = _currentTarget;
    return Stack(key: ValueKey('ex${target.label}'), children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      // Point de fixation
      Align(alignment: target.align, child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        width: 18, height: 18,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _teal,
            boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.50), blurRadius: 14, spreadRadius: 3)]))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Regardez ${target.label.toLowerCase()}',
              style: TextStyle(fontFamily: 'Gelica', color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 16, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        ])))),
      Align(alignment: Alignment.bottomCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(bottom: 36),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: _targets.map((t) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentTarget == t ? 10 : 7, height: _currentTarget == t ? 10 : 7,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _currentTarget == t ? _teal : Colors.white.withValues(alpha: 0.20)))).toList())))),
    ]);
  }

  Widget _buildEyesClosed() => Container(key: const ValueKey('closed'), color: _bg,
    child: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_Ico.eye, color: _teal.withValues(alpha: 0.40), size: 48),
      const SizedBox(height: 24),
      const Text('Fermez les yeux.', style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
          fontSize: 22, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
      const SizedBox(height: 8),
      Text('${(_totalSec - _elapsed).clamp(0,_closedSec)}s',
          style: const TextStyle(color: _gold, fontSize: 14)),
    ]))));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.eye, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vos yeux se sont reposés.'", textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Color(0xFF232323),
                fontSize: 22, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.45)),
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
