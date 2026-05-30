// Routine 28 — Thermal Touch — Firebase RTDB
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData heart = IconData(0xe940, fontFamily: _f); }
const _bg = Color(0xFF121212); const _dark = Color(0xFF065963); const _gold = Color(0xFFE8B86E);

enum _Phase { waiting, exercise, complete }

class ThermalTouch extends StatefulWidget {
  final String sessionId;
  final bool isCaressing;
  final String partnerName;
  final VoidCallback? onComplete;
  const ThermalTouch({super.key, required this.sessionId, required this.isCaressing,
    required this.partnerName, this.onComplete});
  @override State<ThermalTouch> createState() => _ThermalTouchState();
}

class _ThermalTouchState extends State<ThermalTouch>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 120;
  _Phase _phase = _Phase.waiting;
  int _elapsed = 0;
  double _heatLevel = 0.0, _myVelocity = 0.0;
  Offset? _lastPos; DateTime? _lastTime;

  late AnimationController _heatCtrl;
  late RtdbSession _session;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _heatCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) { setState(() => _phase = _Phase.exercise); _startExercise(); }});
    if (!widget.isCaressing) {
      _session.listenPartner('caress', (val) {
        if (!mounted) return;
        final vel = (val as num).toDouble();
        Vibration.vibrate(duration: (60 + vel * 12).toInt().clamp(60, 200));
        setState(() => _heatLevel = (vel / 400).clamp(0.0, 1.0));
        _heatCtrl.forward(from: 0);
      });
    }
  }

  void _startExercise() {
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _onCaressUpdate(DragUpdateDetails d) {
    if (!widget.isCaressing || _phase != _Phase.exercise) return;
    final now = DateTime.now();
    double velocity = 0;
    if (_lastPos != null && _lastTime != null) {
      final dt = now.difference(_lastTime!).inMilliseconds / 1000.0;
      if (dt > 0) velocity = (_lastPos! - d.localPosition).distance / dt;
    }
    _lastPos = d.localPosition; _lastTime = now;
    setState(() => _myVelocity = velocity);
    _session.send('caress', velocity);
  }

  Future<void> _complete() async {
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() { _heatCtrl.dispose(); _exTimer?.cancel(); _session.dispose(); super.dispose(); }

  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:  return _buildWaiting();
      case _Phase.exercise: return widget.isCaressing ? _buildCaressing() : _buildReceiving();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_gold))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...', style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildCaressing() => GestureDetector(key: const ValueKey('caress'), onPanUpdate: _onCaressUpdate, behavior: HitTestBehavior.opaque,
    child: Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: Container(width: 180, height: 180,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _gold.withValues(alpha: 0.06),
              border: Border.all(color: _gold.withValues(alpha: 0.20))),
          child: Icon(_Ico.heart, color: _gold.withValues(alpha: 0.30), size: 60))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(padding: const EdgeInsets.only(top: 30),
          child: Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14))))),
      Align(alignment: Alignment.bottomCenter, child: SafeArea(child: Padding(padding: const EdgeInsets.only(bottom: 40),
          child: Text('Caressez lentement l\'écran', style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
              fontSize: 15, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic))))),
    ]));

  Widget _buildReceiving() => AnimatedBuilder(key: const ValueKey('recv'), animation: _heatCtrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: AnimatedContainer(duration: const Duration(milliseconds: 300), width: 200, height: 200,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _gold.withValues(alpha: 0.04 + _heatLevel * 0.14),
              boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.06 + _heatLevel * 0.24), blurRadius: 50 + _heatLevel * 40, spreadRadius: 10)]),
          child: Icon(_Ico.heart, color: _gold.withValues(alpha: 0.20 + _heatLevel * 0.50), size: 60))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(padding: const EdgeInsets.only(top: 30),
          child: Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14))))),
      Align(alignment: Alignment.bottomCenter, child: SafeArea(child: Padding(padding: const EdgeInsets.only(bottom: 40),
          child: Text('${widget.partnerName} vous touche à distance', style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
              fontSize: 14, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic))))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.heart, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'La chaleur a traversé la distance.'", textAlign: TextAlign.center,
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
