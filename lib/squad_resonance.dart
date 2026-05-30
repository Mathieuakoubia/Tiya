// Routine 21 — Squad Resonance — Firebase RTDB
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData users = IconData(0xe976, fontFamily: _f); static const IconData heart = IconData(0xe940, fontFamily: _f); }
const _bg = Color(0xFF121212); const _teal = Color(0xFF0DAABA); const _dark = Color(0xFF065963); const _gold = Color(0xFFE8B86E);
const _memberColors = [Color(0xFF0DAABA), Color(0xFFE8B86E), Color(0xFFD9CCE8), Color(0xFFF2631D), Color(0xFF065963)];

enum _Phase { waiting, exercise, complete }

class SquadResonance extends StatefulWidget {
  final String sessionId, squadId;
  final bool isInCrisis;
  final List<String> memberNames;
  final VoidCallback? onComplete;
  const SquadResonance({super.key, required this.sessionId, required this.squadId,
    required this.isInCrisis, required this.memberNames, this.onComplete});
  @override State<SquadResonance> createState() => _SquadResonanceState();
}

class _SquadResonanceState extends State<SquadResonance> with TickerProviderStateMixin {
  static const int _totalSec = 120, _tapCooldownMs = 2000;
  _Phase _phase = _Phase.waiting;
  int _elapsed = 0, _tapCount = 0;
  final Map<int, int> _lastTapMs = {};
  final List<AnimationController> _ripples = [];

  late RtdbSession _session;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 5; i++) {
      _ripples.add(AnimationController(duration: const Duration(milliseconds: 600), vsync: this));
    }
    _session = RtdbSession(widget.sessionId);
    _session.markReady(minUsers: 2, onReady: () { if (mounted) { setState(() => _phase = _Phase.exercise); _startExercise(); }});
    _session.listenPartner('tap', (val) {
      if (!mounted) return;
      final map = val as Map? ?? {};
      final idx = (map['idx'] as num?)?.toInt() ?? 0;
      if (widget.isInCrisis) { Vibration.vibrate(duration: 100); setState(() => _tapCount++); }
      if (idx < _ripples.length) _ripples[idx].forward(from: 0);
    });
  }

  void _startExercise() {
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _sendTap(int idx) {
    if (widget.isInCrisis) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastTapMs[idx] ?? 0) < _tapCooldownMs) return;
    _lastTapMs[idx] = now;
    _session.send('tap', {'idx': idx});
    _ripples[idx % _ripples.length].forward(from: 0);
  }

  Future<void> _complete() async {
    Vibration.cancel();
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('squad_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() { for (final c in _ripples) c.dispose(); _exTimer?.cancel(); Vibration.cancel(); _session.dispose(); super.dispose(); }

  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:  return _buildWaiting();
      case _Phase.exercise: return widget.isInCrisis ? _buildCrisisReceive() : _buildSupportSend();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_teal))),
      const SizedBox(height: 20),
      Text('Connexion au Squad...', style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildCrisisReceive() => Stack(key: const ValueKey('crisis'), children: [
    const Positioned.fill(child: ColoredBox(color: _bg)),
    Center(child: SizedBox(width: 280, height: 280, child: Stack(alignment: Alignment.center, children: [
      ..._ripples.asMap().entries.map((e) => AnimatedBuilder(animation: e.value, builder: (_, __) {
        final v = e.value.value;
        return Opacity(opacity: (1 - v).clamp(0.0, 1.0), child: Container(
          width: 60 + 180 * v, height: 60 + 180 * v,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: _memberColors[e.key % _memberColors.length].withValues(alpha: 0.15))));
      })),
      Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle,
          color: _teal.withValues(alpha: 0.15),
          boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.25), blurRadius: 30, spreadRadius: 6)]),
          child: const Icon(_Ico.heart, color: _teal, size: 36)),
    ]))),
    Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
        const SizedBox(height: 8),
        Text('Votre Squad vous entoure — $_tapCount touches reçues',
            style: TextStyle(fontFamily: 'Gelica', color: Colors.white.withValues(alpha: 0.50),
                fontSize: 13, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
      ])))),
  ]);

  Widget _buildSupportSend() => Stack(key: const ValueKey('support'), children: [
    const Positioned.fill(child: ColoredBox(color: _bg)),
    SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Tapez le rythme — 1 tap / 2s', style: TextStyle(fontFamily: 'Gelica',
          color: Colors.white.withValues(alpha: 0.40), fontSize: 14, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
      const SizedBox(height: 32),
      Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
        children: List.generate(widget.memberNames.length.clamp(0, 5), (i) {
          final color = _memberColors[i % _memberColors.length];
          return GestureDetector(onTap: () => _sendTap(i),
            child: AnimatedBuilder(animation: _ripples[i % _ripples.length], builder: (_, __) {
              final v = _ripples[i % _ripples.length].value;
              return Container(width: 70 + v * 6, height: 70 + v * 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12 + v * 0.08),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.20 + v * 0.20), blurRadius: 20 + v * 20, spreadRadius: 2)],
                    border: Border.all(color: color.withValues(alpha: 0.40), width: 1.5)),
                child: Center(child: Text(i < widget.memberNames.length ? widget.memberNames[i][0].toUpperCase() : '?',
                    style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700))));
            }));
        })),
      const SizedBox(height: 36),
      Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
    ]))),
  ]);

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.users, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Votre Squad vous a tenue.'", textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Color(0xFF232323),
                fontSize: 24, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.45)),
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
