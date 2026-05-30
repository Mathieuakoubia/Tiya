// Routine 39 — Énergie d'Ovulation — activation (rare : montée au lieu d'apaisement)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData fire = IconData(0xe93a, fontFamily: _f); }
const _bg   = Color(0xFF121212);
const _fire = Color(0xFFF2631D);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { countdown, exercise, complete }

class EnergieOvulation extends StatefulWidget {
  final VoidCallback? onComplete;
  const EnergieOvulation({super.key, this.onComplete});
  @override State<EnergieOvulation> createState() => _EnergieOvulationState();
}

class _EnergieOvulationState extends State<EnergieOvulation>
    with SingleTickerProviderStateMixin {
  // 3 cycles activants — inspire rapide 3s + expire 3s
  static const int _cycleSec = 6, _inhaleSec = 3, _totalSec = 90;
  _Phase _phase = _Phase.countdown;
  int _countdown = 3, _elapsed = 0;
  bool _isInhaling = true;

  late AnimationController _ctrl;
  late Animation<double>   _burst;
  Timer? _cdTimer, _exTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: _cycleSec), vsync: this);
    _burst = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.4).chain(CurveTween(curve: Curves.easeOut)), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.6).chain(CurveTween(curve: Curves.easeIn)), weight: 3),
    ]).animate(_ctrl);
    _ctrl.addListener(() {
      final inhale = _ctrl.value < (_inhaleSec / _cycleSec);
      if (inhale != _isInhaling) {
        setState(() => _isInhaling = inhale);
        if (inhale) Vibration.vibrate(duration: 40);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
  }

  void _startCountdown() {
    setState(() { _phase = _Phase.countdown; _countdown = 3; });
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_countdown > 1) { _countdown--; } else { t.cancel(); _startExercise(); }});
    });
  }

  void _startExercise() {
    setState(() => _phase = _Phase.exercise);
    _ctrl.repeat();
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _ctrl.stop(); Vibration.cancel(); Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 200]);
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() { _ctrl.dispose(); _cdTimer?.cancel(); _exTimer?.cancel(); Vibration.cancel(); super.dispose(); }

  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.countdown: return _buildCountdown();
      case _Phase.exercise:  return _buildExercise();
      case _Phase.complete:  return _buildComplete();
    }
  }

  Widget _buildCountdown() => Container(key: const ValueKey('cd'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Vous êtes dans une phase d\'énergie.', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Gelica', color: Colors.white.withValues(alpha: 0.50),
              fontSize: 15, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
      const SizedBox(height: 24),
      Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
    ])));

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _ctrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: Transform.scale(scale: _burst.value, child: Container(
        width: 180, height: 180,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: _fire.withValues(alpha: 0.08),
            boxShadow: [BoxShadow(color: _fire.withValues(alpha: 0.25), blurRadius: 60, spreadRadius: 15)])))),
      Center(child: Icon(_Ico.fire, color: _fire.withValues(alpha: 0.50), size: 48)),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_isInhaling ? 'Inspirez — vite !' : 'Expirez...',
              style: TextStyle(fontFamily: 'Gelica', color: _isInhaling ? _fire : Colors.white.withValues(alpha: 0.60),
                  fontSize: 20, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
        ])))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: BoxDecoration(shape: BoxShape.circle, color: _fire.withValues(alpha: 0.85)),
            child: const Icon(_Ico.fire, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Profitez de cette énergie.'", textAlign: TextAlign.center,
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
