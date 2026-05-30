// Routine 44 — Duo-Morning — Firebase RTDB
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rtdb_session.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData sun = IconData(0xe969, fontFamily: _f);
}

const _bg    = Color(0xFF121212);
const _dark  = Color(0xFF065963);
const _teal  = Color(0xFF0DAABA);
const _gold  = Color(0xFFE8B86E);
const _lilas = Color(0xFFD9CCE8);

const _intentions = [
  ('Clarté',    Color(0xFF0DAABA)),
  ('Douceur',   Color(0xFFD9CCE8)),
  ('Présence',  Color(0xFFE8B86E)),
  ('Force',     Color(0xFFF2631D)),
  ('Légèreté',  Color(0xFF065963)),
  ('Patience',  Color(0xFFD9CCE8)),
];

enum _Phase { waiting, choice, breathing, complete }

class DuoMorning extends StatefulWidget {
  final String sessionId;
  final String partnerName;
  final VoidCallback? onComplete;
  const DuoMorning({super.key, required this.sessionId, required this.partnerName, this.onComplete});
  @override State<DuoMorning> createState() => _DuoMorningState();
}

class _DuoMorningState extends State<DuoMorning>
    with SingleTickerProviderStateMixin {
  static const int _cycleSec = 10, _breathCycles = 4;

  _Phase _phase = _Phase.waiting;
  String? _myChoice; Color _myColor = _teal;
  String? _partnerChoice; Color _partnerColor = _gold;
  bool _isInhaling = true;
  int _cyclesDone = 0;

  late AnimationController _ctrl;
  late Animation<double> _aura;
  late RtdbSession _session;
  Timer? _breathTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: _cycleSec), vsync: this);
    _aura = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.78, end: 1.25).chain(CurveTween(curve: Curves.easeInOut)), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.78).chain(CurveTween(curve: Curves.easeInOut)), weight: 5),
    ]).animate(_ctrl);
    _ctrl.addListener(() {
      final inhale = _ctrl.value < 0.5;
      if (inhale != _isInhaling) {
        setState(() => _isInhaling = inhale);
        if (!inhale) Vibration.vibrate(duration: 50);
      }
    });
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) setState(() => _phase = _Phase.choice); });
    _session.listenPartner('intention', (val) {
      if (!mounted || val == null) return;
      final map = val as Map;
      final word = map['w'] as String? ?? '';
      final cidx = (map['c'] as num?)?.toInt() ?? 0;
      setState(() { _partnerChoice = word; _partnerColor = _intentions[cidx % _intentions.length].$2; });
      if (_myChoice != null) _startBreathing();
    });
  }

  void _onIntentionSelected(String word, Color color, int idx) {
    setState(() { _myChoice = word; _myColor = color; });
    _session.send('intention', {'w': word, 'c': idx});
    if (_partnerChoice != null) _startBreathing();
  }

  void _startBreathing() {
    if (_phase == _Phase.breathing) return;
    setState(() => _phase = _Phase.breathing);
    _ctrl.repeat();
    _breathTimer = Timer.periodic(const Duration(seconds: _cycleSec), (t) {
      if (!mounted) { t.cancel(); return; }
      _cyclesDone++;
      if (_cyclesDone >= _breathCycles) { t.cancel(); _complete(); }
    });
  }

  Future<void> _complete() async {
    _ctrl.stop();
    setState(() => _phase = _Phase.complete);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && _myChoice != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid)
          .set({'intentionDuJour': _myChoice}, SetOptions(merge: true));
    }
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _ctrl.dispose(); _breathTimer?.cancel(); Vibration.cancel(); _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 500), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:   return _buildWaiting();
      case _Phase.choice:    return _buildChoice();
      case _Phase.breathing: return _buildBreathing();
      case _Phase.complete:  return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(_teal))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildChoice() => Container(key: const ValueKey('choice'), color: _bg,
    child: SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(children: [
        Text('${widget.partnerName} prépare aussi sa journée.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 14)),
        const SizedBox(height: 12),
        const Text('Quelle est votre intention du jour ?', textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        if (_partnerChoice != null) ...[
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                  color: _partnerColor.withValues(alpha: 0.08),
                  border: Border.all(color: _partnerColor.withValues(alpha: 0.25))),
              child: Text('${widget.partnerName} : $_partnerChoice',
                  style: TextStyle(color: _partnerColor.withValues(alpha: 0.70), fontSize: 13))),
        ],
        const Spacer(),
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
          children: _intentions.asMap().entries.map((e) {
            final idx = e.key; final word = e.value.$1; final color = e.value.$2;
            return GestureDetector(
              onTap: _myChoice == null ? () => _onIntentionSelected(word, color, idx) : null,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
                    color: _myChoice == word ? color.withValues(alpha: 0.20) : color.withValues(alpha: 0.08),
                    border: Border.all(color: _myChoice == word ? color.withValues(alpha: 0.70) : color.withValues(alpha: 0.30),
                        width: _myChoice == word ? 2.0 : 1.0)),
                child: Text(word, style: TextStyle(fontFamily: 'Gelica', color: color,
                    fontSize: 17, fontWeight: FontWeight.w600))));
          }).toList()),
        const Spacer(),
      ]))));

  Widget _buildBreathing() => AnimatedBuilder(key: const ValueKey('breath'), animation: _ctrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _IntentionBubble(word: _myChoice ?? '', color: _myColor, scale: _aura.value, label: 'Vous'),
        _IntentionBubble(word: _partnerChoice ?? '', color: _partnerColor,
            scale: 0.78 + (_isInhaling ? 0.44 * _ctrl.value : 0.44 * (1 - _ctrl.value)),
            label: widget.partnerName),
      ]),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Text(_isInhaling ? 'Inspirez...' : 'Expirez...',
            style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic))))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.sun, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vous avez démarré ensemble.'", textAlign: TextAlign.center,
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

class _IntentionBubble extends StatelessWidget {
  final String word, label;
  final Color color;
  final double scale;
  const _IntentionBubble({required this.word, required this.color, required this.scale, required this.label});
  @override
  Widget build(BuildContext context) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Transform.scale(scale: scale.clamp(0.6, 1.4), child: Container(
      width: 100, height: 100,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.10),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 30, spreadRadius: 6)],
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5)),
      child: Center(child: Text(word, textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Gelica', color: color, fontSize: 14, fontWeight: FontWeight.w600))))),
    const SizedBox(height: 10),
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
  ]);
}
