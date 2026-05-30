// Routine 53 — Squad Night Watch — rituel collectif du soir
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData moonStars = IconData(0xe957, fontFamily: _f); }
const _bg   = Color(0xFF050810);
const _dark = Color(0xFF065963);
const _teal = Color(0xFF0DAABA);
const _gold = Color(0xFFE8B86E);
const _auraColors = [Color(0xFF0DAABA), Color(0xFFE8B86E), Color(0xFFD9CCE8), Color(0xFFF2631D), Color(0xFF065963)];

enum _Step { waiting, breathing, silence, complete }

class SquadNightWatch extends StatefulWidget {
  final String sessionId, squadId;
  final List<String> memberNames;
  final VoidCallback? onComplete;
  const SquadNightWatch({super.key, required this.sessionId, required this.squadId,
    required this.memberNames, this.onComplete});
  @override State<SquadNightWatch> createState() => _SquadNightWatchState();
}

class _SquadNightWatchState extends State<SquadNightWatch>
    with TickerProviderStateMixin {
  static const int _breathSec = 120, _silenceSec = 60;

  _Step _step = _Step.waiting;
  int _stepElapsed = 0;
  bool _isInhaling = true;
  int _connectedCount = 1;

  late AnimationController _breathCtrl;
  late Animation<double>   _auraAnim;
  final List<AnimationController> _pulseCtrls = [];
  late RtdbSession _session;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(duration: const Duration(seconds: 20), vsync: this);
    _auraAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.72, end: 1.12).chain(CurveTween(curve: Curves.easeInOut)), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.72).chain(CurveTween(curve: Curves.easeInOut)), weight: 10),
    ]).animate(_breathCtrl);
    _breathCtrl.addListener(() {
      final inhale = _breathCtrl.value < 0.5;
      if (inhale != _isInhaling) {
        setState(() => _isInhaling = inhale);
        if (!inhale) Vibration.vibrate(duration: 25);
      }
    });
    for (int i = 0; i < 5; i++) {
      _pulseCtrls.add(AnimationController(duration: Duration(seconds: 2 + i), vsync: this)..repeat(reverse: true));
    }
    _session = RtdbSession(widget.sessionId);
    _session.markReady(minUsers: 2, onReady: () {
      if (mounted) { setState(() => _connectedCount++); }
    });
    // Démarrer après 3s même si pas toutes connectées
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _step == _Step.waiting) _startBreathing();
    });
    _session.listenBroadcast('start', (_) {
      if (mounted && _step == _Step.waiting) _startBreathing();
    });
    // Écouter les présences
    _session.listenAll('ready', (map) {
      if (mounted) setState(() => _connectedCount = map.length);
    });
  }

  void _startBreathing() {
    _session.broadcast('start', true);
    setState(() { _step = _Step.breathing; _stepElapsed = 0; });
    _breathCtrl.repeat();
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _stepElapsed++);
      if (_stepElapsed >= _breathSec) { t.cancel(); _startSilence(); }
    });
  }

  void _startSilence() {
    _breathCtrl.stop(); Vibration.cancel();
    setState(() { _step = _Step.silence; _stepElapsed = 0; });
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _stepElapsed++);
      if (_stepElapsed % 20 == 0 && _stepElapsed < _silenceSec) Vibration.vibrate(duration: 25);
      if (_stepElapsed >= _silenceSec) { t.cancel(); _complete(); }
    });
  }

  Future<void> _complete() async {
    Vibration.cancel();
    setState(() => _step = _Step.complete);
    await FirebaseFirestore.instance.collection('squad_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _breathCtrl.dispose(); for (final c in _pulseCtrls) c.dispose();
    _stepTimer?.cancel(); Vibration.cancel(); _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 700), child: _buildStep()));

  Widget _buildStep() {
    switch (_step) {
      case _Step.waiting:   return _buildWaiting();
      case _Step.breathing: return _buildBreathing();
      case _Step.silence:   return _buildSilence();
      case _Step.complete:  return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.30)))),
      const SizedBox(height: 20),
      Text('$_connectedCount / ${widget.memberNames.length} connectées',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 14)),
    ]))));

  Widget _buildBreathing() => AnimatedBuilder(key: const ValueKey('breath'), animation: _breathCtrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      // 5 Auras en cercle
      Center(child: SizedBox(width: 300, height: 300, child: Stack(alignment: Alignment.center, children: [
        ...List.generate(widget.memberNames.length.clamp(0, 5), (i) {
          final angle = -pi/2 + (i / widget.memberNames.length.clamp(1,5)) * 2 * pi;
          final r = 100.0;
          return AnimatedBuilder(animation: _pulseCtrls[i % _pulseCtrls.length], builder: (_, __) {
            final scale = 0.85 + _pulseCtrls[i % _pulseCtrls.length].value * 0.30;
            return Positioned(
              left: 100 + r * cos(angle) - 28,
              top:  100 + r * sin(angle) - 28,
              child: Transform.scale(scale: scale, child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _auraColors[i % _auraColors.length].withValues(alpha: 0.12),
                    boxShadow: [BoxShadow(color: _auraColors[i % _auraColors.length].withValues(alpha: 0.20), blurRadius: 20, spreadRadius: 3)],
                    border: Border.all(color: _auraColors[i % _auraColors.length].withValues(alpha: 0.35), width: 1.5)))));
          });
        }),
        // Centre
        Transform.scale(scale: _auraAnim.value, child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: _teal.withValues(alpha: 0.10),
              boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.20), blurRadius: 30, spreadRadius: 6)]))),
      ]))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Votre Squad ferme la journée ensemble.', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
          const SizedBox(height: 8),
          Text(_isInhaling ? 'Inspirez...' : 'Expirez...',
              style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        ])))),
    ]));

  Widget _buildSilence() => Container(key: const ValueKey('silence'), color: _bg,
    child: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_Ico.moonStars, color: Colors.white.withValues(alpha: 0.06), size: 80),
      const SizedBox(height: 20),
      Text('${((_silenceSec - _stepElapsed) ~/ 60)}:${((_silenceSec - _stepElapsed) % 60).toString().padLeft(2,'0')}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 14)),
      const SizedBox(height: 8),
      Text('Vous êtes veillées.', style: TextStyle(color: Colors.white.withValues(alpha: 0.20),
          fontSize: 13, fontFamily: 'Gelica', fontStyle: FontStyle.italic)),
    ]))));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.moonStars, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Votre Squad vous protège.'", textAlign: TextAlign.center,
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
