// Routine 37 — Cocon Prémenstruel — Phase lutéale — respiration 4 cycles/min
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData lotus = IconData(0xe93b, fontFamily: _f); }
const _bg   = Color(0xFF120A0A);
const _warm = Color(0xFFD9753A); // corail chaud
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { countdown, exercise, complete }

class CoconPremenstruel extends StatefulWidget {
  final VoidCallback? onComplete;
  const CoconPremenstruel({super.key, this.onComplete});
  @override State<CoconPremenstruel> createState() => _CoconPremenstruelState();
}

class _CoconPremenstruelState extends State<CoconPremenstruel>
    with SingleTickerProviderStateMixin {
  // 4 cycles/min = 15s/cycle, inspire 7s + expire 8s
  static const int _cycleSec = 15, _inhaleSec = 7, _totalSec = 180;
  _Phase _phase = _Phase.countdown;
  int _countdown = 3, _elapsed = 0;
  bool _isInhaling = true;
  String _label = 'Inspirez...';

  late AnimationController _ctrl;
  late Animation<double>   _aura;
  Timer? _cdTimer, _exTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: _cycleSec), vsync: this);
    _aura = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.70, end: 1.25).chain(CurveTween(curve: Curves.easeIn)), weight: 7),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.70).chain(CurveTween(curve: Curves.easeOut)), weight: 8),
    ]).animate(_ctrl);
    _ctrl.addListener(() {
      final inhale = _ctrl.value < (_inhaleSec / _cycleSec);
      if (inhale != _isInhaling) setState(() { _isInhaling = inhale; _label = inhale ? 'Inspirez...' : 'Expirez doucement...'; });
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
    Vibration.vibrate(duration: 60);
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _ctrl.stop(); Vibration.cancel(); Vibration.vibrate(pattern: [0, 200, 100, 200]);
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
      Text('Ralentissons ensemble', style: TextStyle(fontFamily: 'Gelica', color: Colors.white.withValues(alpha: 0.45),
          fontSize: 16, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
      const SizedBox(height: 24),
      Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
    ])));

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _ctrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: Transform.scale(scale: _aura.value, child: Container(
        width: 180, height: 180,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: _warm.withValues(alpha: 0.08),
            boxShadow: [BoxShadow(color: _warm.withValues(alpha: 0.18), blurRadius: 60, spreadRadius: 12)])))),
      Center(child: Icon(_Ico.lotus, color: _warm.withValues(alpha: 0.30), size: 44)),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_label, style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
        ])))),
      Align(alignment: Alignment.bottomCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(bottom: 36),
        child: Text('C\'est le moment de ralentir, pas de performer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.30), fontSize: 13, height: 1.5))))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: BoxDecoration(shape: BoxShape.circle, color: _warm.withValues(alpha: 0.80)),
            child: const Icon(_Ico.lotus, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vous avez pris soin de vous.'", textAlign: TextAlign.center,
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
