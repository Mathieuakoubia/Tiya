import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class SoothingThumb extends StatefulWidget {
  final Color baseColor;
  final Duration duration;
  final VoidCallback? onComplete;

  const SoothingThumb({
    super.key,
    this.baseColor = Colors.teal,
    this.duration = const Duration(seconds: 60),
    this.onComplete,
  });

  @override
  State<SoothingThumb> createState() => _SoothingThumbState();
}

class _SoothingThumbState extends State<SoothingThumb>
    with SingleTickerProviderStateMixin {
  // Breathing animation : 4s inspirez + 6s expirez = 10s = 6 cycles/min
  static const int _cycleDuration = 10;
  static const int _inhaleDuration = 4;

  late AnimationController _breathController;
  late Animation<double> _breathScale;

  Timer? _vibrationTimer;
  Timer? _countdownTimer;

  bool _isPressed = false;
  bool _isCompleted = false;
  bool _isInhaling = true;
  int _elapsedSeconds = 0;

  String _statusMessage = "Posez votre pouce sur le cercle";

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      duration: const Duration(seconds: _cycleDuration),
      vsync: this,
    );

    // Cercle gonfle à l'inspiration, se dégonfle à l'expiration
    _breathScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.45)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _inhaleDuration.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.45, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: (_cycleDuration - _inhaleDuration).toDouble(),
      ),
    ]).animate(_breathController);

    _breathController.addListener(_onBreathTick);
  }

  void _onBreathTick() {
    if (!_isPressed) return;
    final isInhale = _breathController.value < (_inhaleDuration / _cycleDuration);
    if (isInhale != _isInhaling) {
      setState(() {
        _isInhaling = isInhale;
        _statusMessage = isInhale ? "Inspirez..." : "Expirez...";
      });
    }
  }

  void _startRoutine() {
    if (_isCompleted || _isPressed) return;
    setState(() {
      _isPressed = true;
      _isInhaling = true;
      _statusMessage = "Inspirez...";
    });

    _breathController.repeat();
    _startCountdown();
    _triggerHeartbeat();
    // Vibration calée sur le cycle respiratoire
    _vibrationTimer = Timer.periodic(
      const Duration(seconds: _cycleDuration),
      (_) => _triggerHeartbeat(),
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPressed) {
        timer.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= widget.duration.inSeconds) {
        timer.cancel();
        _completeRoutine();
      }
    });
  }

  Future<void> _triggerHeartbeat() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
        pattern: [0, 100, 100, 50],
        intensities: [0, 255, 0, 100],
      );
    }
  }

  void _stopRoutine() {
    if (!_isPressed) return;

    _breathController.stop();
    _vibrationTimer?.cancel();
    _countdownTimer?.cancel();
    Vibration.cancel();

    setState(() {
      _isPressed = false;
      _statusMessage = "Contact rompu";
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          "Contact rompu",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Gardez votre pouce sur le cercle pour continuer.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(
                () => _statusMessage = "Posez votre pouce pour reprendre",
              );
            },
            child: const Text("Reprendre"),
          ),
        ],
      ),
    );
  }

  void _completeRoutine() {
    _breathController.stop();
    _breathController.reset();
    _vibrationTimer?.cancel();
    Vibration.cancel();

    // Vibration de succès
    Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 400]);

    setState(() {
      _isPressed = false;
      _isCompleted = true;
      _statusMessage = "Routine terminée !";
    });

    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _breathController.removeListener(_onBreathTick);
    _breathController.dispose();
    _vibrationTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  double get _progress =>
      (_elapsedSeconds / widget.duration.inSeconds).clamp(0.0, 1.0);

  int get _remainingSeconds =>
      (widget.duration.inSeconds - _elapsedSeconds).clamp(0, widget.duration.inSeconds);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: const Text("Pouce Apaisant"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Message de phase (Inspirez / Expirez)
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 50.0),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
          // Compte à rebours
          if (_elapsedSeconds > 0 && !_isCompleted)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 90.0),
                child: Text(
                  "${_remainingSeconds}s",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          // Cercle central avec anneau de progression
          Center(
            child: GestureDetector(
              onTapDown: (_) => _startRoutine(),
              onTapUp: (_) => _stopRoutine(),
              onTapCancel: () => _stopRoutine(),
              child: AnimatedBuilder(
                animation: _breathController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Anneau de progression (1 minute)
                      SizedBox(
                        width: 148,
                        height: 148,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isCompleted
                                ? Colors.greenAccent
                                : widget.baseColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      // Halo respiratoire (onde de choc)
                      Transform.scale(
                        scale: _isPressed ? _breathScale.value : 1.0,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.baseColor.withValues(
                              alpha: _isPressed ? 0.25 : 0.08,
                            ),
                          ),
                        ),
                      ),
                      // Cercle principal
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCompleted
                              ? Colors.greenAccent.withValues(alpha: 0.85)
                              : widget.baseColor,
                          boxShadow: [
                            BoxShadow(
                              color: (_isCompleted
                                      ? Colors.greenAccent
                                      : widget.baseColor)
                                  .withValues(alpha: 0.5),
                              blurRadius: _isPressed ? 28 : 18,
                              spreadRadius: _isPressed ? 6 : 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isCompleted ? Icons.check : Icons.fingerprint,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          // Overlay de succès
          if (_isCompleted)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.greenAccent,
                      size: 80,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Routine terminée !",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "1 minute de cohérence cardiaque\ncomplétée avec succès.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Continuer",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
