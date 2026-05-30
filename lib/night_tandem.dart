// Routine 49 — Night Tandem — Twin — rituel du soir partagé
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData moonStars = IconData(0xe957, fontFamily: _f); }
const _bg   = Color(0xFF060610);
const _dark = Color(0xFF065963);
const _teal = Color(0xFF0DAABA);
const _gold = Color(0xFFE8B86E);

enum _Step { waiting, breathing, bodyScan, silence, word, complete }

class NightTandem extends StatefulWidget {
  final String sessionId, partnerName;
  final String? audioUrl;
  final VoidCallback? onComplete;
  const NightTandem({super.key, required this.sessionId, required this.partnerName,
    this.audioUrl, this.onComplete});
  @override State<NightTandem> createState() => _NightTandemState();
}

class _NightTandemState extends State<NightTandem>
    with SingleTickerProviderStateMixin {
  // 3 cycles/min = 20s/cycle, 3 cycles = 60s + body scan 2min + silence 1min
  static const int _breathSec = 60, _scanSec = 120, _silenceSec = 60;

  _Step _step = _Step.waiting;
  int _stepElapsed = 0;
  bool _isInhaling = true;

  late AnimationController _ctrl;
  late Animation<double>   _aura;
  final _player = AudioPlayer();
  final _wordCtrl = TextEditingController();
  late RtdbSession _session;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: 20), vsync: this);
    _aura = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.70, end: 1.15).chain(CurveTween(curve: Curves.easeInOut)), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.70).chain(CurveTween(curve: Curves.easeInOut)), weight: 10),
    ]).animate(_ctrl);
    _ctrl.addListener(() {
      final inhale = _ctrl.value < 0.5;
      if (inhale != _isInhaling) {
        setState(() => _isInhaling = inhale);
        if (!inhale) Vibration.vibrate(duration: 30);
      }
    });
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) _startBreathing(); });
  }

  void _startBreathing() {
    setState(() { _step = _Step.breathing; _stepElapsed = 0; });
    _ctrl.repeat();
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _stepElapsed++);
      if (_stepElapsed >= _breathSec) { t.cancel(); _startBodyScan(); }
    });
  }

  Future<void> _startBodyScan() async {
    _ctrl.stop(); Vibration.cancel();
    setState(() { _step = _Step.bodyScan; _stepElapsed = 0; });
    if (widget.audioUrl?.isNotEmpty == true) {
      try { await _player.setUrl(widget.audioUrl!); await _player.play(); } catch (_) {}
    }
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _stepElapsed++);
      if (_stepElapsed >= _scanSec) { t.cancel(); _startSilence(); }
    });
  }

  void _startSilence() {
    _player.stop();
    setState(() { _step = _Step.silence; _stepElapsed = 0; });
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _stepElapsed++);
      // Haptique finale toutes les 15s
      if (_stepElapsed % 15 == 0 && _stepElapsed < _silenceSec) Vibration.vibrate(duration: 30);
      if (_stepElapsed >= _silenceSec) { t.cancel(); setState(() => _step = _Step.word); }
    });
  }

  Future<void> _sendWord(String? word) async {
    if (word?.isNotEmpty == true) _session.send('goodnight', word!);
    setState(() => _step = _Step.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _ctrl.dispose(); _wordCtrl.dispose(); _player.dispose();
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
      case _Step.bodyScan:  return _buildBodyScan();
      case _Step.silence:   return _buildSilence();
      case _Step.word:      return _buildWordInput();
      case _Step.complete:  return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha:0.30)))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...', style: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 16)),
    ])));

  Widget _buildBreathing() => AnimatedBuilder(key: const ValueKey('breath'), animation: _ctrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: Transform.scale(scale: _aura.value, child: Container(
        width: 180, height: 180,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: _teal.withValues(alpha: 0.04),
            boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.08), blurRadius: 60, spreadRadius: 12)])))),
      Center(child: Icon(_Ico.moonStars, color: Colors.white.withValues(alpha: 0.06), size: 50)),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${widget.partnerName} prépare aussi sa nuit.', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
          const SizedBox(height: 8),
          Text(_isInhaling ? 'Inspirez...' : 'Expirez...',
              style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        ])))),
    ]));

  Widget _buildBodyScan() => Container(key: const ValueKey('scan'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('Parcourez votre corps doucement.', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
              fontSize: 18, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
      const SizedBox(height: 20),
      Text('${((_scanSec - _stepElapsed) ~/ 60)}:${((_scanSec - _stepElapsed) % 60).toString().padLeft(2,'0')}',
          style: const TextStyle(color: _gold, fontSize: 14)),
    ])));

  Widget _buildSilence() => Container(key: const ValueKey('silence'), color: _bg,
    child: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_Ico.moonStars, color: Colors.white.withValues(alpha: 0.08), size: 80),
      const SizedBox(height: 24),
      Text('${((_silenceSec - _stepElapsed) ~/ 60)}:${((_silenceSec - _stepElapsed) % 60).toString().padLeft(2,'0')}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.20), fontSize: 14)),
    ]))));

  Widget _buildWordInput() => Container(key: const ValueKey('word'), color: _bg,
    child: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Un mot avant de dormir ?', style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
            fontSize: 20, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        const SizedBox(height: 20),
        TextField(controller: _wordCtrl, maxLength: 20, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(counterText: '', hintText: 'Bonne nuit ✦',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.20)),
                filled: true, fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _teal, width: 1.5)))),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _sendWord(null),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.40),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: const Text('Passer'))),
          const SizedBox(width: 14),
          Expanded(child: ElevatedButton(onPressed: () => _sendWord(_wordCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
              child: const Text('Envoyer', style: TextStyle(fontWeight: FontWeight.w600)))),
        ]),
      ])))));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.moonStars, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Bonne nuit.'", textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Color(0xFF232323),
                fontSize: 32, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
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
