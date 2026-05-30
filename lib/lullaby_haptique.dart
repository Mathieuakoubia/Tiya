// Routine 19 — Lullaby Haptique — Firebase RTDB + gyroscope
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData moon = IconData(0xe957, fontFamily: _f);
}

const _bg    = Color(0xFF060812);
const _dark  = Color(0xFF065963);
const _gold  = Color(0xFFE8B86E);
const _lilas = Color(0xFFD9CCE8);

enum _Phase { waiting, exercise, complete }

class LullabyHaptique extends StatefulWidget {
  final String sessionId;
  final bool isEmitter;
  final String partnerName;
  final VoidCallback? onComplete;
  const LullabyHaptique({super.key, required this.sessionId, required this.isEmitter,
    required this.partnerName, this.onComplete});
  @override State<LullabyHaptique> createState() => _LullabyHaptiqueState();
}

class _LullabyHaptiqueState extends State<LullabyHaptique>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 120;

  _Phase _phase = _Phase.waiting;
  int _elapsed = 0;
  double _tiltX = 0.0, _receivedX = 0.0;

  late AnimationController _sandCtrl;
  late RtdbSession _session;
  StreamSubscription? _gyroSub;
  Timer? _sendTimer, _exTimer;

  @override
  void initState() {
    super.initState();
    _sandCtrl = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(reverse: true);
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) { setState(() => _phase = _Phase.exercise); _startExercise(); }});
    if (!widget.isEmitter) {
      _session.listenPartner('tilt', (val) {
        if (!mounted) return;
        final x = (val as num).toDouble();
        setState(() => _receivedX = x);
        final intensity = x.abs().clamp(0.0, 9.8);
        if (intensity > 1.5) Vibration.vibrate(duration: (30 + intensity * 10).toInt().clamp(30, 130));
      });
    }
  }

  void _startExercise() {
    if (widget.isEmitter) {
      _gyroSub = accelerometerEventStream().listen((e) => setState(() => _tiltX = e.x));
      _sendTimer = Timer.periodic(const Duration(milliseconds: 80), (_) =>
          _session.send('tilt', _tiltX));
    }
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  Future<void> _complete() async {
    _gyroSub?.cancel(); _sendTimer?.cancel(); Vibration.cancel();
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _sandCtrl.dispose(); _gyroSub?.cancel(); _sendTimer?.cancel(); _exTimer?.cancel();
    Vibration.cancel(); _session.dispose();
    super.dispose();
  }

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
          valueColor: AlwaysStoppedAnimation(_lilas))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _sandCtrl,
    builder: (_, __) {
      final tilt = widget.isEmitter ? _tiltX : _receivedX;
      return Stack(children: [
        const Positioned.fill(child: ColoredBox(color: _bg)),
        Positioned.fill(child: CustomPaint(painter: _SandWavePainter(tilt: tilt, phase: _sandCtrl.value))),
        Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
            const SizedBox(height: 10),
            Text(widget.isEmitter ? 'Bercez lentement...' : 'Laissez le balancement vous calmer...',
                style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
          ])))),
        Center(child: Icon(_Ico.moon, color: Colors.white.withValues(alpha: 0.06), size: 60)),
      ]);
    });

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.moon, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vous vous êtes bercées à distance.'", textAlign: TextAlign.center,
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

class _SandWavePainter extends CustomPainter {
  final double tilt, phase;
  const _SandWavePainter({required this.tilt, required this.phase});
  @override
  void paint(Canvas canvas, Size size) {
    final amplitude = 12.0 + tilt.abs() * 3;
    for (int l = 0; l < 4; l++) {
      final yBase = size.height * (0.50 + l * 0.12);
      final path = Path();
      for (int i = 0; i <= 200; i++) {
        final x = (i / 200) * size.width;
        final y = yBase + amplitude * sin(phase * 2 * pi + (i / 200) * 2 * pi + tilt * 0.5 + l * 0.8);
        if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      }
      path.lineTo(size.width, size.height); path.lineTo(0, size.height); path.close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFD9CCE8).withValues(alpha: 0.08 + l * 0.04)..style = PaintingStyle.fill);
    }
  }
  @override bool shouldRepaint(_SandWavePainter old) => old.tilt != tilt || old.phase != phase;
}
