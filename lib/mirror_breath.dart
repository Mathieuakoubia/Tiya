// Routine 25 — Mirror-Breath — Firebase RTDB
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData yinYang = IconData(0xe980, fontFamily: _f);
}

const _bg    = Color(0xFF121212);
const _dark  = Color(0xFF065963);
const _lilas = Color(0xFFD9CCE8);
const _gold  = Color(0xFFE8B86E);

enum _Phase { waiting, exercise, complete }

class MirrorBreath extends StatefulWidget {
  final String sessionId;
  final bool isEmitter;
  final String partnerName;
  final VoidCallback? onComplete;
  const MirrorBreath({super.key, required this.sessionId, required this.isEmitter,
    required this.partnerName, this.onComplete});
  @override State<MirrorBreath> createState() => _MirrorBreathState();
}

class _MirrorBreathState extends State<MirrorBreath>
    with SingleTickerProviderStateMixin {
  static const int _cycleSec = 10, _totalSec = 120;

  _Phase _phase = _Phase.waiting;
  int _elapsed = 0;
  double _breathPhase = 0.0;

  late AnimationController _ctrl;
  late RtdbSession _session;
  Timer? _sendTimer, _exTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: _cycleSec), vsync: this);
    if (widget.isEmitter) {
      _ctrl.addListener(() => setState(() => _breathPhase = _ctrl.value));
    }
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) { setState(() => _phase = _Phase.exercise); _startExercise(); }});
    if (!widget.isEmitter) {
      _session.listenPartner('phase', (val) {
        if (!mounted) return;
        setState(() => _breathPhase = (val as num).toDouble().clamp(0.0, 1.0));
      });
    }
  }

  void _startExercise() {
    if (widget.isEmitter) {
      _ctrl.repeat();
      _sendTimer = Timer.periodic(const Duration(milliseconds: 100), (_) =>
          _session.send('phase', _ctrl.value));
    }
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  Future<void> _complete() async {
    _ctrl.stop(); _sendTimer?.cancel();
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _ctrl.dispose(); _sendTimer?.cancel(); _exTimer?.cancel(); _session.dispose();
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

  Widget _buildExercise() => Stack(key: const ValueKey('ex'), children: [
    const Positioned.fill(child: ColoredBox(color: _bg)),
    Positioned.fill(child: CustomPaint(
        painter: _WavePainter(phase: _breathPhase, color: _lilas))),
    Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
        const SizedBox(height: 8),
        Text(widget.isEmitter
            ? 'Respirez naturellement.\n${widget.partnerName} vous suit.'
            : 'Laissez l\'onde guider votre souffle...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
      ])))),
    Center(child: Icon(_Ico.yinYang, color: _lilas.withValues(alpha: 0.08), size: 80)),
  ]);

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.yinYang, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vos souffles se sont rejoints.'", textAlign: TextAlign.center,
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

class _WavePainter extends CustomPainter {
  final double phase;
  final Color color;
  const _WavePainter({required this.phase, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final amplitude = size.height * 0.06 + phase * size.height * 0.10;
    final p1 = Paint()..color = color.withValues(alpha: 0.40)..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    for (int i = 0; i <= 150; i++) {
      final x = (i / 150) * size.width;
      final y = size.height / 2 + amplitude * sin(phase * 2 * pi + (i / 150) * 2 * pi);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, p1);
    final p2 = Paint()..color = color.withValues(alpha: 0.15)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final path2 = Path();
    for (int i = 0; i <= 150; i++) {
      final x = (i / 150) * size.width;
      final y = size.height / 2 + amplitude * 0.6 * sin(phase * 2 * pi + (i / 150) * 2 * pi + pi * 0.5);
      if (i == 0) { path2.moveTo(x, y); } else { path2.lineTo(x, y); }
    }
    canvas.drawPath(path2, p2);
  }
  @override bool shouldRepaint(_WavePainter old) => old.phase != phase;
}
