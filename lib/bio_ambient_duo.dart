// Routine 10 — Bio-Ambient Duo — Firebase RTDB + NoiseMeter
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData music = IconData(0xe958, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _dark = Color(0xFF065963);
const _teal = Color(0xFF0DAABA);
const _gold = Color(0xFFE8B86E);

enum _Phase { waiting, exercise, complete }

class BioAmbientDuo extends StatefulWidget {
  final String sessionId;
  final String partnerName;
  final String calmAudioUrl;
  final VoidCallback? onComplete;
  const BioAmbientDuo({super.key, required this.sessionId, required this.partnerName,
    required this.calmAudioUrl, this.onComplete});
  @override State<BioAmbientDuo> createState() => _BioAmbientDuoState();
}

class _BioAmbientDuoState extends State<BioAmbientDuo>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 240;
  static const double _noiseThreshold = 55.0;

  _Phase _phase = _Phase.waiting;
  int _elapsed = 0;
  double _myNoise = 0.0, _partnerNoise = 0.0;

  late AnimationController _seaCtrl;
  final _player = AudioPlayer();
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSub;
  late RtdbSession _session;
  Timer? _exTimer, _noiseSendTimer;

  @override
  void initState() {
    super.initState();
    _seaCtrl = AnimationController(duration: const Duration(seconds: 6), vsync: this)..repeat(reverse: true);
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) { setState(() => _phase = _Phase.exercise); _startExercise(); }});
    _session.listenPartner('noise', (val) {
      if (!mounted) return;
      setState(() => _partnerNoise = (val as num).toDouble());
    });
  }

  Future<void> _startExercise() async {
    try { await _player.setUrl(widget.calmAudioUrl); await _player.play(); } catch (_) {}
    _noiseMeter = NoiseMeter();
    _noiseSub = _noiseMeter!.noise.listen((r) => setState(() => _myNoise = r.meanDecibel));
    _noiseSendTimer = Timer.periodic(const Duration(milliseconds: 500), (_) =>
        _session.send('noise', _myNoise));
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _seaCtrl.stop(); _player.stop(); _noiseSub?.cancel(); _noiseSendTimer?.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _seaCtrl.dispose(); _player.dispose(); _noiseSub?.cancel();
    _noiseSendTimer?.cancel(); _exTimer?.cancel(); _session.dispose();
    super.dispose();
  }

  bool get _isBothCalm => _myNoise < _noiseThreshold && _partnerNoise < _noiseThreshold;
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
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(_teal))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _seaCtrl,
    builder: (_, __) => Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _SeaPainter(wave: _seaCtrl.value, calmness: _isBothCalm ? 1.0 : 0.3))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14))))),
      Center(child: Text(_isBothCalm ? 'Mer calme ✦' : 'Vagues agitées...',
          style: TextStyle(fontFamily: 'Gelica',
              color: _isBothCalm ? _teal.withValues(alpha: 0.70) : Colors.white.withValues(alpha: 0.30),
              fontSize: 16, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic))),
      Align(alignment: Alignment.bottomCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(bottom: 36),
        child: Text('Le silence vous réunit', style: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 13))))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.music, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vous étiez ensemble dans le silence.'", textAlign: TextAlign.center,
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

class _SeaPainter extends CustomPainter {
  final double wave, calmness;
  const _SeaPainter({required this.wave, required this.calmness});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height), Paint()..color = const Color(0xFF0A0F1A));
    final amplitude = size.height * 0.04 * (1.0 + (1.0 - calmness) * 3);
    for (int l = 0; l < 3; l++) {
      final yBase = size.height * (0.55 + l * 0.12);
      final path = Path();
      for (int i = 0; i <= 200; i++) {
        final x = (i / 200) * size.width;
        final y = yBase + amplitude * sin(wave * 2 * pi + (i / 200) * 2 * pi + l * 0.8);
        if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      }
      path.lineTo(size.width, size.height); path.lineTo(0, size.height); path.close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF0DAABA).withValues(alpha: 0.18 - l * 0.04)..style = PaintingStyle.fill);
    }
  }
  @override bool shouldRepaint(_SeaPainter old) => old.wave != wave || old.calmness != calmness;
}
