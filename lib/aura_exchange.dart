// Routine 9 — Aura-Exchange — Firebase RTDB
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData send = IconData(0xe95a, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);
const _teal = Color(0xFF0DAABA);

enum _Phase { waiting, exercise, complete }

class AuraExchange extends StatefulWidget {
  final String sessionId;
  final bool isEmitter;
  final String partnerName;
  final VoidCallback? onComplete;
  const AuraExchange({super.key, required this.sessionId, required this.isEmitter,
    required this.partnerName, this.onComplete});
  @override State<AuraExchange> createState() => _AuraExchangeState();
}

class _AuraExchangeState extends State<AuraExchange>
    with TickerProviderStateMixin {
  static const int _totalSec = 300;

  _Phase _phase = _Phase.waiting;
  double _energySent = 0.0, _energyReceived = 0.5;
  int _elapsed = 0;

  late AnimationController _auraCtrl, _trailCtrl;
  late RtdbSession _session;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _auraCtrl = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(reverse: true);
    _auraCtrl = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(reverse: true);
    _trailCtrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () {
      if (mounted) { setState(() => _phase = _Phase.exercise); _startExercise(); }
    });
    if (!widget.isEmitter) {
      _session.listenPartner('energy', (val) {
        if (!mounted) return;
        setState(() => _energyReceived = (val as num).toDouble().clamp(0.0, 1.0));
        _trailCtrl.forward(from: 0);
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

  void _onEnergyChanged(double val) {
    setState(() => _energySent = val);
    _session.send('energy', val);
  }

  Future<void> _complete() async {
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _auraCtrl.dispose(); _trailCtrl.dispose(); _exTimer?.cancel(); _session.dispose();
    super.dispose();
  }

  Color get _receivedColor => Color.lerp(const Color(0xFFF2631D), _teal, _energyReceived)!;
  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _bg,
        body: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: _buildPhase()));
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:  return _buildWaiting();
      case _Phase.exercise: return widget.isEmitter ? _buildEmitter() : _buildReceiver();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(_gold))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildEmitter() => AnimatedBuilder(key: const ValueKey('emit'), animation: _auraCtrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: Transform.scale(scale: 0.88 + _auraCtrl.value * 0.24,
        child: Container(width: 180, height: 180,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.06 + _energySent * 0.14),
              boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.10 + _energySent * 0.30),
                  blurRadius: 60, spreadRadius: 12)],
              border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1.5)),
          child: Icon(_Ico.send, color: _gold.withValues(alpha: 0.50), size: 40)))),
      Positioned(right: 36, top: 0, bottom: 0, child: RotatedBox(quarterTurns: 3,
          child: Slider(value: _energySent, onChanged: _onEnergyChanged,
              activeColor: _gold, inactiveColor: Colors.white.withValues(alpha: 0.12)))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Envoyez de la lumière à ${widget.partnerName}', textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        ])))),
    ]));

  Widget _buildReceiver() => AnimatedBuilder(key: const ValueKey('recv'), animation: _trailCtrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: AnimatedContainer(duration: const Duration(milliseconds: 600),
        width: 200, height: 200,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: _receivedColor.withValues(alpha: 0.08),
            boxShadow: [BoxShadow(color: _receivedColor.withValues(alpha: 0.20), blurRadius: 70, spreadRadius: 15)],
            border: Border.all(color: _receivedColor.withValues(alpha: 0.35), width: 1.5)))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
          const SizedBox(height: 8),
          Text('${widget.partnerName} vous envoie de l\'énergie...', textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        ])))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.send, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'L\'énergie a traversé la distance.'", textAlign: TextAlign.center,
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
