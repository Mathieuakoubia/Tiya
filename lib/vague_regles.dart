// Routine 38 — Vague de Règles — Deep Pressure + audio
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:just_audio/just_audio.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData lotus = IconData(0xe93b, fontFamily: _f); }
const _bg   = Color(0xFF0E0508);
const _red  = Color(0xFF8B1A2A);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { setup, exercise, complete }

class VagueRegles extends StatefulWidget {
  final String? audioUrl;
  final VoidCallback? onComplete;
  const VagueRegles({super.key, this.audioUrl, this.onComplete});
  @override State<VagueRegles> createState() => _VagueReglesState();
}

class _VagueReglesState extends State<VagueRegles>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 120;
  _Phase _phase = _Phase.setup;
  int _elapsed = 0;

  late AnimationController _waveCtrl;
  final _player = AudioPlayer();
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(duration: const Duration(seconds: 6), vsync: this);
  }

  Future<void> _startExercise() async {
    setState(() => _phase = _Phase.exercise);
    _waveCtrl.repeat(reverse: true);
    Vibration.vibrate(pattern: [0, 1500, 500, 1500, 500, 1500], repeat: 4);
    if (widget.audioUrl?.isNotEmpty == true) {
      try { await _player.setUrl(widget.audioUrl!); await _player.play(); } catch (_) {}
    }
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _waveCtrl.stop(); _player.stop(); Vibration.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _waveCtrl.dispose(); _player.dispose(); _exTimer?.cancel(); Vibration.cancel();
    super.dispose();
  }

  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 600), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.setup:    return _buildSetup();
      case _Phase.exercise: return _buildExercise();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildSetup() => Container(key: const ValueKey('setup'), color: _bg,
    child: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_Ico.lotus, color: _red.withValues(alpha: 0.60), size: 52),
        const SizedBox(height: 28),
        const Text('Votre énergie est différente aujourd\'hui.\nEt c\'est juste.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
                fontSize: 19, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.5)),
        const SizedBox(height: 16),
        Text('Posez l\'appareil sur votre bas-ventre si possible.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 14)),
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _startExercise,
          style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
          child: const Text('Commencer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
      ])))));

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _waveCtrl,
    builder: (_, __) => Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _RedWavePainter(phase: _waveCtrl.value))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14))))),
      Center(child: Icon(_Ico.lotus, color: Colors.white.withValues(alpha: 0.05), size: 60)),
      Align(alignment: Alignment.bottomCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Text('Respirez lentement.\nVotre corps fait son travail.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Colors.white.withValues(alpha: 0.30),
                fontSize: 14, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.5))))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.lotus, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Votre corps mérite cette attention.'", textAlign: TextAlign.center,
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

class _RedWavePainter extends CustomPainter {
  final double phase;
  const _RedWavePainter({required this.phase});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height), Paint()..color = const Color(0xFF0E0508));
    for (int l = 0; l < 3; l++) {
      final yBase = size.height * (0.45 + l * 0.15);
      final amplitude = 20.0 + l * 10;
      final path = Path();
      for (int i = 0; i <= 200; i++) {
        final x = (i / 200) * size.width;
        final y = yBase + amplitude * sin(phase * 2 * pi + (i / 200) * 2 * pi + l * 0.7);
        if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      }
      path.lineTo(size.width, size.height); path.lineTo(0, size.height); path.close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF8B1A2A).withValues(alpha: 0.12 - l * 0.03)..style = PaintingStyle.fill);
    }
  }
  @override bool shouldRepaint(_RedWavePainter old) => old.phase != phase;
}
