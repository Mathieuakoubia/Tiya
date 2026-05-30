import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData sunDim = IconData(0xe966, fontFamily: _f);
}

const _teal  = Color(0xFF0DAABA);
const _dark  = Color(0xFF065963);
const _gold  = Color(0xFFE8B86E);
const _light = Color(0xFFF4F3F2);

enum _Phase { countdown, exercise, complete }

class ResetFlash extends StatefulWidget {
  final VoidCallback? onComplete;
  const ResetFlash({super.key, this.onComplete});

  @override
  State<ResetFlash> createState() => _ResetFlashState();
}

class _ResetFlashState extends State<ResetFlash>
    with SingleTickerProviderStateMixin {
  static const int _cycleSec  = 10;
  static const int _inhaleSec = 5;
  static const int _totalSec  = 180;

  _Phase _phase       = _Phase.countdown;
  int    _countdown   = 3;
  int    _elapsed     = 0;
  bool   _isInhaling  = true;
  String _phaseLabel  = 'Inspirez...';

  late AnimationController _ctrl;
  late Animation<double>   _auraScale;

  Timer? _cdTimer;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(seconds: _cycleSec), vsync: this);
    _auraScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.72, end: 1.32)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 5),
      TweenSequenceItem(
          tween: Tween(begin: 1.32, end: 0.72)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 5),
    ]).animate(_ctrl);
    _ctrl.addListener(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
  }

  void _onTick() {
    final inhale = _ctrl.value < (_inhaleSec / _cycleSec);
    if (inhale != _isInhaling) {
      setState(() {
        _isInhaling = inhale;
        _phaseLabel = inhale ? 'Inspirez...' : 'Expirez...';
      });
    }
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
    _ctrl.repeat();
    Vibration.vibrate(pattern: [70, 72, 70, 72], repeat: 0);
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _ctrl.stop();
    Vibration.cancel();
    Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 400]);
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    _cdTimer?.cancel();
    _exTimer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  double get _progress  => (_elapsed / _totalSec).clamp(0.0, 1.0);
  int    get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s)    => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  double get _barProgress {
    const inhaleEnd = _inhaleSec / _cycleSec;
    final v = _ctrl.value;
    if (v <= inhaleEnd) return v / inhaleEnd;
    return 1.0 - (v - inhaleEnd) / inhaleEnd;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _teal,
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
    color: _teal,
    child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Préparez-vous',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 18,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5)),
        const SizedBox(height: 24),
        Text('$_countdown',
            style: const TextStyle(
                color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
      ],
    )),
  );

  Widget _buildExercise() => AnimatedBuilder(
    key: const ValueKey('ex'),
    animation: _ctrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _teal)),
      Positioned.fill(child: CustomPaint(
          painter: _BarPainter(progress: _barProgress, color: _light))),
      Center(child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 164, height: 164,
          child: CircularProgressIndicator(
            value: _progress,
            strokeWidth: 4,
            backgroundColor: _light.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(_light),
          ),
        ),
        Transform.scale(
          scale: _auraScale.value,
          child: Container(
            width: 114, height: 114,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _light.withValues(alpha: 0.10),
              boxShadow: [BoxShadow(
                color: _light.withValues(alpha: 0.28),
                blurRadius: 42, spreadRadius: 6)],
            ),
          ),
        ),
        Icon(_Ico.sunDim, color: _light, size: 38),
      ])),
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 42),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_phaseLabel,
                style: const TextStyle(
                    fontFamily: 'Gelica',
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Text(_fmt(_remaining),
                style: const TextStyle(color: _gold, fontSize: 14)),
          ]),
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
              child: const Icon(_Ico.sunDim, color: Colors.white, size: 44),
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
            const Text('3 minutes de cohérence cardiaque complétées.',
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
                    backgroundColor: _dark,
                    foregroundColor: Colors.white,
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

class _BarPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _BarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 7.0;
    const xOff = 44.0;
    final baseY = size.height * 0.65;
    final maxH  = size.height * 0.30;
    final curH  = maxH * progress;
    final track = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(xOff, baseY), Offset(xOff, baseY - maxH), track);
    canvas.drawLine(Offset(size.width - xOff, baseY),
        Offset(size.width - xOff, baseY - maxH), track);
    if (curH < 4) return;
    final bar = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(xOff, baseY), Offset(xOff, baseY - curH), bar);
    canvas.drawLine(Offset(size.width - xOff, baseY),
        Offset(size.width - xOff, baseY - curH), bar);
    final glow = Paint()
      ..color = color.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(xOff, baseY - curH), 7, glow);
    canvas.drawCircle(Offset(size.width - xOff, baseY - curH), 7, glow);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.progress != progress;
}
