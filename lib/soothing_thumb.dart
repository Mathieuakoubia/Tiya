import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────
const _darkBg = Color(0xFF141414);
const _lightBg = Color(0xFFF5F3FF);
const _primaryPurple = Color(0xFF82667F);
const _accentPurple = Color(0xFF735983);

enum _Phase { intro, countdown, exercise, complete }

// ─── Widget ──────────────────────────────────────────────────────────────────
class SoothingThumb extends StatefulWidget {
  final VoidCallback? onComplete;

  const SoothingThumb({super.key, this.onComplete});

  @override
  State<SoothingThumb> createState() => _SoothingThumbState();
}

class _SoothingThumbState extends State<SoothingThumb>
    with SingleTickerProviderStateMixin {
  // 4 s inhale + 6 s exhale = 10 s/cycle = 6 cycles/min
  static const int _cycleSec = 10;
  static const int _inhaleSec = 4;
  static const int _totalSec = 60;

  _Phase _phase = _Phase.intro;
  int _countdownValue = 3;
  int _elapsedSec = 0;
  bool _isPressed = false;
  bool _isInhaling = true;
  String _phaseLabel = "Inspirez...";

  late AnimationController _breathCtrl;
  late Animation<double> _breathScale;
  Timer? _vibTimer;
  Timer? _cdTimer;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      duration: const Duration(seconds: _cycleSec),
      vsync: this,
    );
    _breathScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.45)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _inhaleSec.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.45, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: (_cycleSec - _inhaleSec).toDouble(),
      ),
    ]).animate(_breathCtrl);
    _breathCtrl.addListener(_onBreathTick);
  }

  // ── Breath phase label ────────────────────────────────────────────────────
  void _onBreathTick() {
    if (_phase != _Phase.exercise || !_isPressed) return;
    final inhale = _breathCtrl.value < (_inhaleSec / _cycleSec);
    if (inhale != _isInhaling) {
      setState(() {
        _isInhaling = inhale;
        _phaseLabel = inhale ? "Inspirez..." : "Expirez...";
      });
    }
  }

  // ── Phase transitions ─────────────────────────────────────────────────────
  void _goToCountdown() {
    setState(() {
      _phase = _Phase.countdown;
      _countdownValue = 3;
    });
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else {
          t.cancel();
          _phase = _Phase.exercise;
          _phaseLabel = "Posez votre pouce sur le cercle";
        }
      });
    });
  }

  void _startRoutine() {
    if (_phase != _Phase.exercise || _isPressed) return;
    setState(() {
      _isPressed = true;
      _isInhaling = true;
      _phaseLabel = "Inspirez...";
    });
    _breathCtrl.repeat();
    _triggerHeartbeat();
    _vibTimer = Timer.periodic(
      const Duration(seconds: _cycleSec),
      (_) => _triggerHeartbeat(),
    );
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_isPressed) { t.cancel(); return; }
      setState(() => _elapsedSec++);
      if (_elapsedSec >= _totalSec) {
        t.cancel();
        _complete();
      }
    });
  }

  void _stopRoutine() {
    if (!_isPressed) return;
    _breathCtrl.stop();
    _vibTimer?.cancel();
    _exTimer?.cancel();
    Vibration.cancel();
    setState(() {
      _isPressed = false;
      _phaseLabel = "Posez votre pouce pour reprendre";
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Contact rompu",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "Gardez votre pouce sur le cercle pour continuer.",
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Reprendre",
                style: TextStyle(color: _primaryPurple)),
          ),
        ],
      ),
    );
  }

  void _complete() {
    if (!mounted) return;
    _breathCtrl.stop();
    _breathCtrl.reset();
    _vibTimer?.cancel();
    Vibration.cancel();
    Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 400]);
    setState(() {
      _isPressed = false;
      _phase = _Phase.complete;
    });
    widget.onComplete?.call();
  }

  Future<void> _triggerHeartbeat() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
          pattern: [0, 100, 100, 50], intensities: [0, 255, 0, 100]);
    }
  }

  @override
  void dispose() {
    _breathCtrl.removeListener(_onBreathTick);
    _breathCtrl.dispose();
    _vibTimer?.cancel();
    _cdTimer?.cancel();
    _exTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double get _progress => (_elapsedSec / _totalSec).clamp(0.0, 1.0);
  int get _remaining => (_totalSec - _elapsedSec).clamp(0, _totalSec);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _Phase.intro ? _lightBg : _darkBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.intro:
        return _buildIntro();
      case _Phase.countdown:
        return _buildCountdown();
      case _Phase.exercise:
        return _buildExercise();
      case _Phase.complete:
        return _buildComplete();
    }
  }

  // ── INTRO ─────────────────────────────────────────────────────────────────
  Widget _buildIntro() {
    return SafeArea(
      key: const ValueKey('intro'),
      child: Stack(
        children: [
          // Decorative organic circle
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primaryPurple.withValues(alpha: 0.12),
                  width: 48,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Back button
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  style: IconButton.styleFrom(
                    foregroundColor: _accentPurple,
                    backgroundColor: _accentPurple.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 28),
                // Duration badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accentPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "1 min  •  Nerf Vague",
                    style: TextStyle(
                      color: _accentPurple,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Pouce\nApaisant",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141414),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  "Fondement scientifique :",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF141414),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "La stimulation haptique à basse fréquence (6–10 Hz) active le nerf vague et abaisse le rythme cardiaque. En calquant votre souffle sur les vibrations, vous induisez une cohérence cardiaque en 60 secondes.",
                  style: TextStyle(
                    fontSize: 15,
                    color: const Color(0xFF141414).withValues(alpha: 0.6),
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 32),
                const _IntroStep(number: "1", text: "Posez votre pouce sur le cercle"),
                const SizedBox(height: 14),
                const _IntroStep(number: "2", text: "Suivez le rythme : Inspirez / Expirez"),
                const SizedBox(height: 14),
                const _IntroStep(number: "3", text: "Maintenez le contact pendant 1 minute"),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _goToCountdown,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text("Commencer",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── COUNTDOWN ─────────────────────────────────────────────────────────────
  Widget _buildCountdown() {
    return Center(
      key: const ValueKey('countdown'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Préparez-vous",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 18,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "$_countdownValue",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 100,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── EXERCISE ──────────────────────────────────────────────────────────────
  Widget _buildExercise() {
    return Stack(
      key: const ValueKey('exercise'),
      children: [
        // Status + timer
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _phaseLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (_elapsedSec > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      "${_remaining}s",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Thumb circle
        Center(
          child: GestureDetector(
            onTapDown: (_) => _startRoutine(),
            onTapUp: (_) => _stopRoutine(),
            onTapCancel: () => _stopRoutine(),
            child: AnimatedBuilder(
              animation: _breathCtrl,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress ring
                    SizedBox(
                      width: 148,
                      height: 148,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _primaryPurple.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    // Breathing halo
                    Transform.scale(
                      scale: _isPressed ? _breathScale.value : 1.0,
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primaryPurple.withValues(
                            alpha: _isPressed ? 0.22 : 0.07,
                          ),
                        ),
                      ),
                    ),
                    // Main circle
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primaryPurple,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryPurple.withValues(alpha: 0.45),
                            blurRadius: _isPressed ? 32 : 18,
                            spreadRadius: _isPressed ? 8 : 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.fingerprint,
                          size: 50, color: Colors.white),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // Bottom hint
        if (!_isPressed && _elapsedSec == 0)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Text(
                "Touchez et maintenez",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── COMPLETE ──────────────────────────────────────────────────────────────
  Widget _buildComplete() {
    return Container(
      key: const ValueKey('complete'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF735983), Color(0xFF82667F), Color(0xFF9B7EA8)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  child:
                      const Icon(Icons.check, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 28),
                const Text(
                  "'Félicitez-vous d'avoir\npris ce temps pour vous'",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "1 minute de cohérence cardiaque complétée.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 52),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _accentPurple,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text("Continuer",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step indicator ───────────────────────────────────────────────────────────
class _IntroStep extends StatelessWidget {
  final String number;
  final String text;

  const _IntroStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF735983).withValues(alpha: 0.12),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF735983),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF141414),
            ),
          ),
        ),
      ],
    );
  }
}
