// Routine 20 — Co-Gaze Alpha — synchronie cérébrale via regard partagé — Firebase RTDB
// Note : rPPG non implémenté (outil SOZIA futur) → pulsation fixe 0.1 Hz
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData eye = IconData(0xe936, fontFamily: _f); }
const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { waiting, countdown, exercise, complete }

class CoGazeAlpha extends StatefulWidget {
  final String sessionId, partnerName;
  final VoidCallback? onComplete;
  const CoGazeAlpha({super.key, required this.sessionId, required this.partnerName, this.onComplete});
  @override State<CoGazeAlpha> createState() => _CoGazeAlphaState();
}

class _CoGazeAlphaState extends State<CoGazeAlpha>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 180;
  _Phase _phase = _Phase.waiting;
  int _countdown = 3, _elapsed = 0;

  // Pulsation fixe 0.1 Hz = 10s/cycle (sans rPPG)
  late AnimationController _ctrl;
  late Animation<double>   _pulse;
  late RtdbSession _session;
  Timer? _cdTimer, _exTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: 10), vsync: this);
    _pulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.15).chain(CurveTween(curve: Curves.easeInOut)), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.85).chain(CurveTween(curve: Curves.easeInOut)), weight: 5),
    ]).animate(_ctrl);
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () {
      if (mounted) {
        if (true) _startCountdown(); // premier arrivé lance le countdown
      }
    });
  }

  void _startCountdown() {
    _session.broadcast('countdown_start', true);
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

  Future<void> _complete() async {
    _ctrl.stop();
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() { _ctrl.dispose(); _cdTimer?.cancel(); _exTimer?.cancel(); _session.dispose(); super.dispose(); }

  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:   return _buildWaiting();
      case _Phase.countdown: return _buildCountdown();
      case _Phase.exercise:  return _buildExercise();
      case _Phase.complete:  return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(_teal))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...', style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildCountdown() => Container(key: const ValueKey('cd'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Fixez le point ensemble.', style: TextStyle(fontFamily: 'Gelica',
          color: Colors.white.withValues(alpha: 0.50), fontSize: 16, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
      const SizedBox(height: 24),
      Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
    ])));

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _ctrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: Transform.scale(scale: _pulse.value, child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _teal,
            boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.55), blurRadius: 24 * _pulse.value, spreadRadius: 4)])))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Fixez le point.\n${widget.partnerName} est avec vous.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Gelica', color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        ])))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.eye, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vos regards se sont rejoints.'", textAlign: TextAlign.center,
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
