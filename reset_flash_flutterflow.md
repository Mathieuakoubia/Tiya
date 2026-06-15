# Reset Flash — Custom Widget FlutterFlow

Coller ce code dans **FF > Custom Widgets > New Widget**.

Le widget est autonome : il gère le countdown, l'exercice tactile et l'écran final.
L'action `onComplete` se déclenche quand les 3 minutes sont terminées.

**Paramètre à déclarer dans FF :**
- `onComplete` — type Action

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

// ignore: must_be_immutable
class ResetFlashWidget extends StatefulWidget {
  const ResetFlashWidget({
    super.key,
    this.width,
    this.height,
    this.onComplete,
  });

  final double? width;
  final double? height;
  final Future<dynamic> Function()? onComplete;

  @override
  State<ResetFlashWidget> createState() => _ResetFlashWidgetState();
}

class _ResetFlashWidgetState extends State<ResetFlashWidget>
    with SingleTickerProviderStateMixin {
  static const int _cycleSec  = 10;
  static const int _inhaleSec = 5;
  static const int _totalSec  = 180;

  static const _teal  = Color(0xFF0DAABA);
  static const _dark  = Color(0xFF065963);
  static const _gold  = Color(0xFFE8B86E);
  static const _light = Color(0xFFF4F3F2);

  // 0 = countdown, 1 = exercise, 2 = complete
  int    _phase      = 0;
  int    _countdown  = 3;
  int    _elapsed    = 0;
  bool   _isInhaling = true;
  bool   _isPressed  = false;
  String _phaseLabel = 'Posez votre doigt sur le cercle';

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
    if (_phase != 1 || !_isPressed) return;
    final inhale = _ctrl.value < (_inhaleSec / _cycleSec);
    if (inhale != _isInhaling) {
      setState(() {
        _isInhaling = inhale;
        _phaseLabel = inhale ? 'Inspirez...' : 'Expirez...';
      });
      Vibration.vibrate(duration: 80, amplitude: 150);
    }
  }

  void _startCountdown() {
    setState(() { _phase = 0; _countdown = 3; });
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          t.cancel();
          _phase      = 1;
          _phaseLabel = 'Posez votre doigt sur le cercle';
        }
      });
    });
  }

  void _startRoutine() {
    if (_phase != 1 || _isPressed) return;
    setState(() {
      _isPressed  = true;
      _isInhaling = true;
      _phaseLabel = 'Inspirez...';
    });
    _ctrl.repeat();
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_isPressed) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _stopRoutine() {
    if (!_isPressed) return;
    _ctrl.stop();
    _exTimer?.cancel();
    Vibration.cancel();
    setState(() {
      _isPressed  = false;
      _phaseLabel = 'Posez votre doigt pour reprendre';
    });
  }

  void _complete() {
    _ctrl.stop();
    Vibration.cancel();
    Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 400]);
    setState(() => _phase = 2);
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
    if (!_isPressed) return 0.0;
    const inhaleEnd = _inhaleSec / _cycleSec;
    final v = _ctrl.value;
    if (v <= inhaleEnd) return v / inhaleEnd;
    return 1.0 - (v - inhaleEnd) / inhaleEnd;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  widget.width  ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    if (_phase == 0) return _buildCountdown();
    if (_phase == 1) return _buildExercise();
    return _buildComplete();
  }

  // ── Countdown ────────────────────────────────────────────────────

  Widget _buildCountdown() => Container(
    key: const ValueKey('cd'),
    color: _teal,
    child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Préparez-vous',
            style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 18,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5)),
        const SizedBox(height: 24),
        Text('$_countdown',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 100,
                fontWeight: FontWeight.bold)),
      ],
    )),
  );

  // ── Exercise ─────────────────────────────────────────────────────

  Widget _buildExercise() => AnimatedBuilder(
    key: const ValueKey('ex'),
    animation: _ctrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _teal)),
      Positioned.fill(child: CustomPaint(
          painter: _BarPainter(progress: _barProgress, color: _light))),
      Center(
        child: GestureDetector(
          onTapDown:   (_) => _startRoutine(),
          onTapUp:     (_) => _stopRoutine(),
          onTapCancel: ()  => _stopRoutine(),
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 164, height: 164,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 4,
                backgroundColor: _light.withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(_light),
              ),
            ),
            Transform.scale(
              scale: _isPressed ? _auraScale.value : 1.0,
              child: Container(
                width: 114, height: 114,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _light.withOpacity(_isPressed ? 0.14 : 0.06),
                  boxShadow: [BoxShadow(
                    color: _light.withOpacity(_isPressed ? 0.32 : 0.14),
                    blurRadius: _isPressed ? 48 : 22,
                    spreadRadius: _isPressed ? 8 : 2)],
                ),
              ),
            ),
            const Icon(Icons.wb_sunny_outlined, color: _light, size: 38),
          ]),
        ),
      ),
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 42),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_phaseLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Gelica',
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            if (_isPressed)
              Text(_fmt(_remaining),
                  style: const TextStyle(color: _gold, fontSize: 14)),
          ]),
        )),
      ),
    ]),
  );

  // ── Complete ─────────────────────────────────────────────────────

  Widget _buildComplete() => Container(
    key: const ValueKey('done'),
    color: _teal,
    child: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: _dark),
            child: const Icon(Icons.wb_sunny_outlined,
                color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          const Text(
            "'Félicitez-vous d\'avoir\npris ce temps pour vous'",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Gelica',
                color: Color(0xFF232323),
                fontSize: 22,
                fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic,
                height: 1.45),
          ),
          const SizedBox(height: 16),
          const Text('3 minutes de cohérence cardiaque complétées.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Gelica',
                  color: Color(0xFF232323),
                  fontSize: 15,
                  fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic,
                  height: 1.55)),
        ],
      ),
    ))),
  );
}

// ── Barres respiratoires ──────────────────────────────────────────

class _BarPainter extends CustomPainter {
  final double progress;
  final Color  color;
  const _BarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 7.0;
    const xOff = 44.0;
    final baseY = size.height * 0.65;
    final maxH  = size.height * 0.30;
    final curH  = maxH * progress;

    final track = Paint()
      ..color = color.withOpacity(0.10)
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(xOff, baseY), Offset(xOff, baseY - maxH), track);
    canvas.drawLine(Offset(size.width - xOff, baseY),
        Offset(size.width - xOff, baseY - maxH), track);
    if (curH < 4) return;

    final bar = Paint()
      ..color = color.withOpacity(0.82)
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(xOff, baseY), Offset(xOff, baseY - curH), bar);
    canvas.drawLine(Offset(size.width - xOff, baseY),
        Offset(size.width - xOff, baseY - curH), bar);

    final glow = Paint()
      ..color = color.withOpacity(0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(xOff, baseY - curH), 7, glow);
    canvas.drawCircle(Offset(size.width - xOff, baseY - curH), 7, glow);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.progress != progress;
}
```
