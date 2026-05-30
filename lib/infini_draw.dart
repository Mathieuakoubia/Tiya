import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData pen = IconData(0xe901, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _lilas = Color(0xFFD9CCE8);
const _gold  = Color(0xFFE8B86E);

enum _Phase { countdown, exercise, complete }

class InfiniDraw extends StatefulWidget {
  final VoidCallback? onComplete;
  const InfiniDraw({super.key, this.onComplete});

  @override
  State<InfiniDraw> createState() => _InfiniDrawState();
}

class _InfiniDrawState extends State<InfiniDraw> {
  static const int _totalSec      = 120;
  static const double _speedLimit = 320.0;

  _Phase _phase     = _Phase.countdown;
  int    _countdown = 3;
  int    _elapsed   = 0;

  final List<Offset> _path = [];
  Offset? _lastPos;
  DateTime? _lastTime;
  bool _hapticCooldown = false;

  Timer? _cdTimer;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
  }

  void _startCountdown() {
    setState(() { _phase = _Phase.countdown; _countdown = 3; });
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          t.cancel();
          _startExercise();
        }
      });
    });
  }

  void _startExercise() {
    setState(() => _phase = _Phase.exercise);
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_phase != _Phase.exercise) return;
    final now = DateTime.now();
    if (_lastPos != null && _lastTime != null) {
      final dt = now.difference(_lastTime!).inMilliseconds / 1000.0;
      if (dt > 0) {
        final velocity = (_lastPos! - d.localPosition).distance / dt;
        if (velocity > _speedLimit && !_hapticCooldown) {
          Vibration.vibrate(duration: 80);
          _hapticCooldown = true;
          Future.delayed(const Duration(milliseconds: 150),
              () => _hapticCooldown = false);
        }
      }
    }
    _lastPos  = d.localPosition;
    _lastTime = now;
    setState(() {
      if (_path.length > 800) _path.removeAt(0);
      _path.add(d.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails _) {
    _lastPos  = null;
    _lastTime = null;
  }

  void _complete() {
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _cdTimer?.cancel();
    _exTimer?.cancel();
    super.dispose();
  }

  int    get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s)    => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.countdown: return _buildCountdown();
      case _Phase.exercise:  return _buildExercise();
      case _Phase.complete:  return _buildComplete();
    }
  }

  Widget _buildCountdown() => Container(
    key: const ValueKey('cd'),
    color: _bg,
    child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Dessinez l\'infini sans lever le doigt',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 16, fontWeight: FontWeight.w300)),
        const SizedBox(height: 24),
        Text('$_countdown',
            style: const TextStyle(
                color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
      ],
    )),
  );

  Widget _buildExercise() => GestureDetector(
    key: const ValueKey('ex'),
    onPanUpdate: _onPanUpdate,
    onPanEnd: _onPanEnd,
    behavior: HitTestBehavior.opaque,
    child: Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      // Guide ∞ en transparence
      Positioned.fill(child: CustomPaint(
          painter: _InfiniGuidePainter())),
      // Tracé de l'utilisatrice
      Positioned.fill(child: CustomPaint(
          painter: _PathPainter(path: _path))),
      // Timer
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(_fmt(_remaining),
              style: const TextStyle(color: _gold, fontSize: 14)),
        )),
      ),
      // Label bas
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Text('Laissez vos gestes ralentir',
              style: TextStyle(
                  fontFamily: 'Gelica',
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 15, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic)),
        )),
      ),
    ]),
  );

  Widget _buildComplete() => Stack(
    key: const ValueKey('done'),
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
      Container(color: Colors.white.withValues(alpha: 0.10)),
      SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
              child: const Icon(_Ico.pen, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 28),
            const Text(
              "'Félicitez-vous d'avoir\npris ce temps pour vous'",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Gelica', color: Color(0xFF232323),
                  fontSize: 22, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic, height: 1.45),
            ),
            const SizedBox(height: 16),
            const Text('2 minutes de régulation sensorimotrice complétées.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Gelica', color: Color(0xFF232323),
                    fontSize: 15, fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic, height: 1.55)),
            const SizedBox(height: 52),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _dark, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0),
                child: const Text('Continuer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ))),
    ],
  );
}

class _InfiniGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx  = size.width / 2;
    final cy  = size.height / 2;
    final rx  = size.width * 0.28;
    final ry  = size.height * 0.12;
    final sep = rx * 0.55;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Lemniscate de Bernoulli : x = a·cos(t)/(1+sin²t), y = a·sin(t)cos(t)/(1+sin²t)
    final path = Path();
    const steps = 200;
    for (int i = 0; i <= steps; i++) {
      final t   = (i / steps) * 2 * pi;
      final den = 1 + sin(t) * sin(t);
      final px  = cx + rx * cos(t) / den;
      final py  = cy + ry * sin(t) * cos(t) / den;
      if (i == 0) { path.moveTo(px, py); } else { path.lineTo(px, py); }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_InfiniGuidePainter _) => false;
}

class _PathPainter extends CustomPainter {
  final List<Offset> path;
  const _PathPainter({required this.path});

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    for (int i = 1; i < path.length; i++) {
      final progress = i / path.length;
      final color = Color.lerp(_teal, _lilas, progress)!;
      final p = Paint()
        ..color = color.withValues(alpha: progress * 0.85)
        ..strokeWidth = 3.5 - progress * 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(path[i - 1], path[i], p);
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.path != path;
}
