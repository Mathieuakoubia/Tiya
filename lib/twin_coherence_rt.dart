// Routine 7 — Twin-Coherence — synchronie respiratoire — Firebase RTDB
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData heart = IconData(0xe940, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { waiting, countdown, exercise, complete }

class TwinCoherenceRt extends StatefulWidget {
  final String sessionId;
  final bool isInitiator;
  final String partnerName;
  final VoidCallback? onComplete;
  const TwinCoherenceRt({
    super.key, required this.sessionId, required this.isInitiator,
    required this.partnerName, this.onComplete,
  });
  @override State<TwinCoherenceRt> createState() => _TwinCoherenceRtState();
}

class _TwinCoherenceRtState extends State<TwinCoherenceRt>
    with SingleTickerProviderStateMixin {
  static const int _cycleSec = 10;
  static const int _inhaleSec = 5;
  static const int _totalSec = 180;
  static const double _syncThreshold = 0.12;

  _Phase _phase = _Phase.waiting;
  int _countdown = 3, _elapsed = 0;
  double _myPhase = 0.0, _partnerPhase = 0.0;
  bool _isInhaling = true;
  int _syncSeconds = 0;

  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;
  late RtdbSession _session;
  Timer? _cdTimer, _exTimer;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(duration: const Duration(seconds: _cycleSec), vsync: this);
    _breathAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.72, end: 1.28).chain(CurveTween(curve: Curves.easeInOut)), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.72).chain(CurveTween(curve: Curves.easeInOut)), weight: 5),
    ]).animate(_breathCtrl);
    _breathCtrl.addListener(() {
      _myPhase = _breathCtrl.value;
      final inhale = _myPhase < (_inhaleSec / _cycleSec);
      if (inhale != _isInhaling) setState(() => _isInhaling = inhale);
      _session.send('breath', _myPhase);
    });
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () {
      if (!mounted) return;
      if (widget.isInitiator) _startCountdown();
      else {
        _session.listenBroadcast('countdown_start', (_) {
          if (mounted && _phase == _Phase.waiting) _startCountdown();
        });
      }
    });
    _session.listenPartner('breath', (val) {
      if (!mounted) return;
      setState(() => _partnerPhase = (val as num).toDouble().clamp(0.0, 1.0));
    });
  }

  void _startCountdown() {
    if (widget.isInitiator) _session.broadcast('countdown_start', true);
    setState(() { _phase = _Phase.countdown; _countdown = 3; });
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 1) { _countdown--; } else { t.cancel(); _startExercise(); }
      });
    });
  }

  void _startExercise() {
    setState(() => _phase = _Phase.exercise);
    _breathCtrl.repeat();
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _elapsed++;
        if ((_myPhase - _partnerPhase).abs() < _syncThreshold) _syncSeconds++;
      });
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  Future<void> _complete() async {
    _breathCtrl.stop();
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'syncSeconds': _syncSeconds,
              'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _cdTimer?.cancel(); _exTimer?.cancel();
    _session.dispose();
    super.dispose();
  }

  bool get _synced => (_myPhase - _partnerPhase).abs() < _syncThreshold && _phase == _Phase.exercise;
  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _bg, body: AnimatedSwitcher(
      duration: const Duration(milliseconds: 450), child: _buildPhase()));
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:   return _buildWaiting();
      case _Phase.countdown: return _buildCountdown();
      case _Phase.exercise:  return _buildExercise();
      case _Phase.complete:  return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('wait'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(_teal))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildCountdown() => Container(key: const ValueKey('cd'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('${widget.partnerName} est là',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 16)),
      const SizedBox(height: 24),
      Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
    ])));

  Widget _buildExercise() => AnimatedBuilder(
    key: const ValueKey('ex'), animation: _breathCtrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      if (_synced) Center(child: AnimatedContainer(
        duration: const Duration(milliseconds: 400), width: 140, height: 140,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: _gold.withValues(alpha: 0.08),
            boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 60, spreadRadius: 15)]),
      )),
      Positioned(left: MediaQuery.of(context).size.width * 0.12, top: MediaQuery.of(context).size.height * 0.38,
          child: _BreathCircle(scale: _breathAnim.value, color: _teal, label: 'Vous', size: 90)),
      Positioned(right: MediaQuery.of(context).size.width * 0.12, top: MediaQuery.of(context).size.height * 0.38,
          child: _BreathCircle(scale: 0.72 + _partnerPhase * 0.56, color: _gold, label: widget.partnerName, size: 90)),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
          if (_synced) ...[const SizedBox(height: 6), Text('En résonance ✦',
              style: TextStyle(color: _gold.withValues(alpha: 0.80), fontSize: 12))],
        ])))),
      Align(alignment: Alignment.bottomCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(bottom: 36),
        child: Text(_isInhaling ? 'Inspirez naturellement...' : 'Expirez...',
            style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic))))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.heart, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vous avez respiré ensemble.'", textAlign: TextAlign.center,
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

class _BreathCircle extends StatelessWidget {
  final double scale, size;
  final Color color;
  final String label;
  const _BreathCircle({required this.scale, required this.color, required this.label, required this.size});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Transform.scale(scale: scale.clamp(0.6, 1.5), child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 30, spreadRadius: 6)],
            border: Border.all(color: color.withValues(alpha: 0.40), width: 1.5)))),
      const SizedBox(height: 10),
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.70), fontSize: 12, fontWeight: FontWeight.w500)),
    ]);
  }
}
