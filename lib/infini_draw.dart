import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData pen = IconData(0xe901, fontFamily: _f);
}

const _bg    = Color(0xFF0DAABA);
const _noir  = Color(0xFF121212);
const _dark  = Color(0xFF065963);
const _lilas = Color(0xFFD9CCE8);
const _ivory = Color(0xFFF8F1E9);
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
  static const int _trailMax      = 50;
  static const double _distSoft   = 30.0;
  static const double _distHard   = 70.0;

  _Phase _phase     = _Phase.countdown;
  int    _countdown = 3;
  int    _elapsed   = 0;
  bool   _paused    = false;

  final List<Offset> _path = [];
  int _pathVersion = 0;
  Offset? _currentPos;
  Offset? _velocitySamplePos;

  Timer? _cdTimer;
  Timer? _exTimer;
  Timer? _fadeTimer;
  Timer? _velocityTimer;

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
    _paused = true;
    setState(() => _phase = _Phase.exercise);
    _startFadeTimer();
  }

  void _startChrono() {
    _exTimer?.cancel();
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_paused) return;
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _startFadeTimer() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || _path.isEmpty) return;
      setState(() {
        final toRemove = (_path.length > 3) ? 3 : _path.length;
        _path.removeRange(0, toRemove);
        _pathVersion++;
      });
    });
  }

  void _startVelocityTimer() {
    _velocityTimer?.cancel();
    _velocitySamplePos = _currentPos;
    _velocityTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _paused || _currentPos == null || _velocitySamplePos == null) return;
      final dist = (_currentPos! - _velocitySamplePos!).distance;
      _velocitySamplePos = _currentPos;
      if (dist < _distSoft) return;
      if (dist > _distHard) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _stopVelocityTimer() {
    _velocityTimer?.cancel();
    _velocityTimer = null;
    _velocitySamplePos = null;
  }

  void _onPanStart(DragStartDetails d) {
    if (_phase != _Phase.exercise) return;
    _currentPos = d.localPosition;
    if (_paused) {
      setState(() => _paused = false);
      _startChrono();
    }
    _startVelocityTimer();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_phase != _Phase.exercise || _paused) return;
    _currentPos = d.localPosition;
    setState(() {
      if (_path.length > _trailMax) {
        _path.removeRange(0, _path.length - _trailMax);
      }
      _path.add(d.localPosition);
      _pathVersion++;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    _currentPos = null;
    _stopVelocityTimer();
    if (_phase != _Phase.exercise) return;
    _exTimer?.cancel();
    setState(() => _paused = true);
  }

  void _complete() {
    _fadeTimer?.cancel();
    _stopVelocityTimer();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _cdTimer?.cancel();
    _exTimer?.cancel();
    _fadeTimer?.cancel();
    _stopVelocityTimer();
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
                color: _ivory.withValues(alpha: 0.7),
                fontSize: 16, fontWeight: FontWeight.w300)),
        const SizedBox(height: 24),
        Text('$_countdown',
            style: const TextStyle(
                color: _ivory, fontSize: 100, fontWeight: FontWeight.bold)),
      ],
    )),
  );

  Widget _buildExercise() => GestureDetector(
    key: const ValueKey('ex'),
    onPanStart: _onPanStart,
    onPanUpdate: _onPanUpdate,
    onPanEnd: _onPanEnd,
    behavior: HitTestBehavior.opaque,
    child: Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Positioned.fill(child: RepaintBoundary(
        child: CustomPaint(painter: _InfiniGuidePainter()),
      )),
      Positioned.fill(child: RepaintBoundary(
        child: CustomPaint(painter: _PathPainter(path: _path, version: _pathVersion)),
      )),
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(_fmt(_remaining),
              style: TextStyle(
                  color: _paused ? _gold : _ivory, fontSize: 14)),
        )),
      ),
      if (_paused)
        Align(
          alignment: const Alignment(0.0, 0.65),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: _dark.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _elapsed == 0
                  ? 'Posez votre doigt pour commencer'
                  : 'Reposez votre doigt pour continuer',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Gelica', color: _ivory,
                  fontSize: 16, fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ),
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Text('Laissez vos gestes ralentir',
              style: TextStyle(
                  fontFamily: 'Gelica',
                  color: _ivory.withValues(alpha: 0.45),
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
              "'Felicitez-vous d'avoir\npris ce temps pour vous'",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Gelica', color: Color(0xFF232323),
                  fontSize: 22, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic, height: 1.45),
            ),
            const SizedBox(height: 16),
            const Text('2 minutes de regulation sensorimotrice completees.',
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
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.28;
    final ry = size.height * 0.12;

    final paint = Paint()
      ..color = const Color(0xFFF8F1E9).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

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
  final int version;
  const _PathPainter({required this.path, required this.version});

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    for (int i = 1; i < path.length; i++) {
      final progress = i / path.length;
      final color = Color.lerp(_gold, _lilas, progress)!;
      final p = Paint()
        ..color = color.withValues(alpha: 0.3 + progress * 0.7)
        ..strokeWidth = 6.0 - progress * 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(path[i - 1], path[i], p);
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.version != version;
}
