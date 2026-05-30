// Routine 48 — Cycle Companion — Twin — accompagnement du cycle féminin
// Nécessite : consentement explicite stocké dans users/{uid}.cycleShareConsent
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData lotus = IconData(0xe93b, fontFamily: _f); }
const _bg    = Color(0xFF100A0A);
const _coral = Color(0xFFD9753A);
const _dark  = Color(0xFF065963);
const _gold  = Color(0xFFE8B86E);

enum _Phase { waiting, exercise, complete }

class CycleCompanion extends StatefulWidget {
  final String sessionId, partnerName;
  final bool isCompanion; // true = accompagne, false = reçoit
  final VoidCallback? onComplete;
  const CycleCompanion({super.key, required this.sessionId, required this.partnerName,
    required this.isCompanion, this.onComplete});
  @override State<CycleCompanion> createState() => _CycleCompanionState();
}

class _CycleCompanionState extends State<CycleCompanion>
    with SingleTickerProviderStateMixin {
  static const int _cycleSec = 15, _totalSec = 120;
  _Phase _phase = _Phase.waiting;
  int _elapsed = 0;
  bool _isInhaling = true;

  late AnimationController _ctrl;
  late Animation<double>   _aura;
  late RtdbSession _session;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: _cycleSec), vsync: this);
    _aura = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.72, end: 1.20).chain(CurveTween(curve: Curves.easeInOut)), weight: 7),
      TweenSequenceItem(tween: Tween(begin: 1.20, end: 0.72).chain(CurveTween(curve: Curves.easeInOut)), weight: 8),
    ]).animate(_ctrl);
    _ctrl.addListener(() {
      final inhale = _ctrl.value < (7 / _cycleSec);
      if (inhale != _isInhaling) {
        setState(() => _isInhaling = inhale);
        if (!inhale && !widget.isCompanion) Vibration.vibrate(duration: 40);
      }
    });
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) { setState(() => _phase = _Phase.exercise); _startExercise(); }});
    // Sync de la phase respiratoire (companion → reçoit)
    if (widget.isCompanion) {
      _ctrl.addListener(() => _session.send('phase', _ctrl.value));
    } else {
      _session.listenPartner('phase', (val) {
        // En tant que reçoit, on suit la phase du companion
      });
    }
  }

  void _startExercise() {
    if (widget.isCompanion) _ctrl.repeat();
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  Future<void> _complete() async {
    _ctrl.stop(); Vibration.cancel();
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() { _ctrl.dispose(); _exTimer?.cancel(); Vibration.cancel(); _session.dispose(); super.dispose(); }

  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:  return _buildWaiting();
      case _Phase.exercise: return _buildExercise();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_coral))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...', style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _ctrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: Transform.scale(scale: _aura.value, child: Container(
        width: 200, height: 200,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: _coral.withValues(alpha: 0.06),
            boxShadow: [BoxShadow(color: _coral.withValues(alpha: 0.14), blurRadius: 60, spreadRadius: 12)])))),
      Center(child: Icon(_Ico.lotus, color: _coral.withValues(alpha: 0.25), size: 44)),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
          const SizedBox(height: 10),
          Text(widget.isCompanion
              ? 'Respirez lentement avec ${widget.partnerName}...'
              : '${widget.partnerName} est là pour vous.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        ])))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: BoxDecoration(shape: BoxShape.circle, color: _coral.withValues(alpha: 0.80)),
            child: const Icon(_Ico.lotus, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vous étiez là l\'une pour l\'autre.'", textAlign: TextAlign.center,
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
