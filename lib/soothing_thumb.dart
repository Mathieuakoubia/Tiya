import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'widgets/routine_intro_screen.dart';
import 'package:vibration/vibration.dart';

const _accentPurple = Color(0xFFF5F3F1);

enum _Phase { intro, countdown, exercise, complete }

// ──────────────────────────────────────────────────────────────────
// Ripple rings : 4 cercles concentriques qui s'expandent depuis
// le centre (là où le pouce est posé). Pilotés par breathPhase.
// Plus d'onde lors de l'inspiration, plus apaisé lors de l'expiration.
// ──────────────────────────────────────────────────────────────────
class _RipplePainter extends CustomPainter {
  final double breathPhase; // 0.0→1.0, suit _breathCtrl.value
  final bool active;
  final bool isInhaling; // true = inspiration, false = expiration
  final Color color;

  _RipplePainter({
    required this.breathPhase,
    required this.active,
    required this.isInhaling,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final center = Offset(size.width / 2, size.height / 2);

    // L'inspiration crée des ondes plus rapides et marquées
    // L'expiration crée des ondes plus lentes et apaisantes
    const minR = 58.0;
    const maxR = 220.0;
    const ringsInhale = 5;
    const ringsExhale = 3;
    final rings = isInhaling ? ringsInhale : ringsExhale;

    for (int i = 0; i < rings; i++) {
      final phase = (breathPhase + i / rings) % 1.0;
      final radius = minR + phase * (maxR - minR);
      final alpha =
          pow(1.0 - phase, 1.6).toDouble() * (isInhaling ? 0.65 : 0.45);
      if (alpha < 0.01) continue;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 - phase * 1.8,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.breathPhase != breathPhase ||
      old.active != active ||
      old.isInhaling != isInhaling;
}

// ──────────────────────────────────────────────────────────────────
// Barres respiratoires : deux barres verticales symétriques.
// Montée (inspiration 4 s) et descente lente (expiration 6 s).
// ──────────────────────────────────────────────────────────────────
class _BarPainter extends CustomPainter {
  final double progress; // 0.0 = bas → 1.0 = haut
  final Color color;

  _BarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 7.0;
    const xOff = 44.0;
    final xLeft = xOff;
    final xRight = size.width - xOff;

    // Ancre en bas à 65 % de l'écran, voyage de 30 % vers le haut
    final baseY = size.height * 0.65;
    final maxH = size.height * 0.30;
    final currentH = maxH * progress;

    // Piste fantôme (montre la plage complète)
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(xLeft, baseY), Offset(xLeft, baseY - maxH), trackPaint);
    canvas.drawLine(
        Offset(xRight, baseY), Offset(xRight, baseY - maxH), trackPaint);

    if (currentH < 4) return;

    // Barre active
    final barPaint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..strokeWidth = barW
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(xLeft, baseY), Offset(xLeft, baseY - currentH), barPaint);
    canvas.drawLine(
        Offset(xRight, baseY), Offset(xRight, baseY - currentH), barPaint);

    // Lueur au sommet de chaque barre
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(xLeft, baseY - currentH), 7, glowPaint);
    canvas.drawCircle(Offset(xRight, baseY - currentH), 7, glowPaint);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.progress != progress;
}

// ──────────────────────────────────────────────────────────────────
// Widget principal
// ──────────────────────────────────────────────────────────────────
class SoothingThumb extends StatefulWidget {
  final VoidCallback? onComplete;
  const SoothingThumb({super.key, this.onComplete});

  @override
  State<SoothingThumb> createState() => _SoothingThumbState();
}

class _SoothingThumbState extends State<SoothingThumb>
    with SingleTickerProviderStateMixin {
  // 4 s inspiration + 6 s expiration = 10 s / cycle = 6 cycles / min
  static const int _cycleSec = 10;
  static const int _inhaleSec = 4;
  static const int _exhaleSec = 6;
  static const int _totalSec = 120; // 2 min

  _Phase _phase = _Phase.intro;
  int _countdownValue = 3;
  int _elapsedSec = 0;
  bool _isPressed = false;
  bool _isInhaling = true;
  String _phaseLabel = "Inspirez...";

  late AnimationController _breathCtrl;
  late Animation<double> _breathHalo; // halo autour du cercle : 1.0→1.45→1.0

  Timer? _microVibTimer; // micro-vibrations 8 Hz
  Timer? _cdTimer;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      duration: const Duration(seconds: _cycleSec),
      vsync: this,
    );
    // Halo du pouce : s'agrandit à l'inspiration, se rétracte à l'expiration
    _breathHalo = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.45)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: _inhaleSec.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.45, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: _exhaleSec.toDouble(),
      ),
    ]).animate(_breathCtrl);
    _breathCtrl.addListener(_onBreathTick);
  }

  // Détecte le changement de phase inspiration/expiration
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

  // Progression des barres : 0→1 pendant l'inspiration, 1→0 pendant l'expiration
  double get _barProgress {
    if (!_isPressed) return 0.0;
    const inhaleEnd = _inhaleSec / _cycleSec; // 0.40
    const exhaleLen = _exhaleSec / _cycleSec; // 0.60
    final v = _breathCtrl.value;
    if (v <= inhaleEnd) return v / inhaleEnd;
    return 1.0 - (v - inhaleEnd) / exhaleLen;
  }

  void _goToCountdown() {
    setState(() {
      _phase = _Phase.countdown;
      _countdownValue = 3;
    });
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
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

    // Pattern cardiaque continu à 7-10 Hz pendant tout le contact.
    // Simule les battements du cœur: LUB-DUB avec variations selon le rythme respiratoire.
    // 6 cycles/minute = 1 cycle toutes les 10 secondes (4s inspiration + 6s expiration)
    _microVibTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || !_isPressed) return;
      _triggerCardiacHaptics();
    });

    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_isPressed) {
        t.cancel();
        return;
      }
      setState(() => _elapsedSec++);
      if (_elapsedSec >= _totalSec) {
        t.cancel();
        _complete();
      }
    });
  }

  // Simule le battement du cœur avec pattern LUB-DUB
  // A l'inspiration: pattern plus intense (battement marqué)
  // A l'expiration: pattern plus doux (battement apaisé)
  void _triggerCardiacHaptics() {
    if (!_isPressed) return;

    // Pattern cardiaque LUB-DUB:
    // [0: start, 50: LUB (vibration), 100: pause, 30: DUB (vibration), 320: pause avant prochain]
    // Total: ~500ms pour imiter un battement cardiaque (120 bpm)
    final pattern = <int>[0, 50, 100, 30, 320];

    // A l'inspiration: vibration plus intense
    // A l'expiration: vibration plus douce
    if (_isInhaling) {
      Vibration.vibrate(pattern: pattern);
    } else {
      // A l'expiration: pattern allégé (pause plus longue)
      Vibration.vibrate(pattern: [0, 30, 130, 20, 320]);
    }
  }

  void _stopRoutine() {
    if (!_isPressed) return;
    _breathCtrl.stop();
    _microVibTimer?.cancel();
    _exTimer?.cancel();
    Vibration.cancel();
    setState(() {
      _isPressed = false;
      _phaseLabel = "Posez votre pouce pour reprendre";
    });
  }

  void _complete() {
    if (!mounted) return;
    _breathCtrl.stop();
    _breathCtrl.reset();
    _microVibTimer?.cancel();
    Vibration.cancel();
    // Vibration de fin : pattern "succès"
    Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 400]);
    setState(() {
      _isPressed = false;
      _phase = _Phase.complete;
    });
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _breathCtrl.removeListener(_onBreathTick);
    _breathCtrl.dispose();
    _microVibTimer?.cancel();
    _cdTimer?.cancel();
    _exTimer?.cancel();
    super.dispose();
  }

  double get _progress => (_elapsedSec / _totalSec).clamp(0.0, 1.0);
  int get _remaining => (_totalSec - _elapsedSec).clamp(0, _totalSec);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _Phase.countdown
          ? const Color(0xFF5B242F)
          : Colors.transparent,
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

  // ── Intro ─────────────────────────────────────────────────────────
  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Pouce\nApaisant',
      badgeLabel: '2 min  •  Nerf Vague',
      scienceText:
          'La stimulation haptique à basse fréquence (7–10 Hz) active le nerf vague et abaisse le rythme cardiaque. En calquant votre souffle sur les barres latérales, vous induisez une cohérence cardiaque en 2 minutes.',
      steps: const [
        'Posez et maintenez votre pouce sur le cercle',
        'Suivez les barres latérales : montée = inspirez, descente = expirez',
        'Des micro-vibrations imitent un cœur sous votre pouce',
      ],
      onStart: _goToCountdown,
      buttonLabel: 'Commencer',
      accentColor: _accentPurple,
    );
  }

  // ── Countdown ─────────────────────────────────────────────────────
  Widget _buildCountdown() {
    return Container(
      key: const ValueKey('countdown'),
      color: const Color(0xFF5B242F),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Préparez-vous",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5)),
          const SizedBox(height: 24),
          Text("$_countdownValue",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 100,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  // ── Exercise ───────────────────────────────────────────────────────
  Widget _buildExercise() {
    return AnimatedBuilder(
      key: const ValueKey('exercise'),
      animation: _breathCtrl,
      builder: (context, _) {
        const btnColor = Color(0xFFF4F3F2);
        return Stack(children: [
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFF5B242F)),
          ),
          // Barres respiratoires (gauche et droite)
          Positioned.fill(
            child: CustomPaint(
              painter: _BarPainter(progress: _barProgress, color: btnColor),
            ),
          ),
          // Ondes de choc depuis le centre
          Positioned.fill(
            child: CustomPaint(
              painter: _RipplePainter(
                breathPhase: _breathCtrl.value,
                active: _isPressed,
                isInhaling: _isInhaling,
                color: btnColor,
              ),
            ),
          ),
          // Texte de phase + timer (en haut)
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 200,
                    child: Text(
                      _phaseLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Gelica',
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w200,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                  if (_isPressed) ...[
                    const SizedBox(height: 8),
                    Text(
                      "${_remaining ~/ 60}:${(_remaining % 60).toString().padLeft(2, '0')}",
                      style: const TextStyle(
                          color: Color(0xFFBCAE3A), fontSize: 14),
                    ),
                  ],
                ]),
              ),
            ),
          ),
          // Cercle du pouce (centré)
          Center(
            child: GestureDetector(
              onTapDown: (_) => _startRoutine(),
              onTapUp: (_) => _stopRoutine(),
              onTapCancel: () => _stopRoutine(),
              child: Stack(alignment: Alignment.center, children: [
                // Anneau de progression
                SizedBox(
                  width: 148,
                  height: 148,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 4,
                    backgroundColor: btnColor.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(btnColor),
                  ),
                ),
                // Halo respiratoire
                Transform.scale(
                  scale: _isPressed ? _breathHalo.value : 1.0,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          btnColor.withValues(alpha: _isPressed ? 0.18 : 0.06),
                    ),
                  ),
                ),
                // Cercle principal
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: btnColor,
                    boxShadow: [
                      BoxShadow(
                        color: btnColor.withValues(alpha: 0.40),
                        blurRadius: _isPressed ? 32 : 18,
                        spreadRadius: _isPressed ? 8 : 2,
                      )
                    ],
                  ),
                  child: const Icon(Icons.fingerprint,
                      size: 50, color: Color(0xFF5B242F)),
                ),
              ]),
            ),
          ),
          // Indication initiale
          if (!_isPressed && _elapsedSec == 0)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Text("Touchez et maintenez",
                    style: TextStyle(
                        fontFamily: 'Gelica',
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                        fontWeight: FontWeight.w200,
                        fontStyle: FontStyle.italic)),
              ),
            ),
        ]);
      },
    );
  }

  // ── Complete ───────────────────────────────────────────────────────
  Widget _buildComplete() {
    return Stack(
      key: const ValueKey('complete'),
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
        Container(color: Colors.white.withValues(alpha: 0.10)),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFF5B242F)),
                    child: const Icon(Icons.favorite,
                        color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                      "'Félicitez-vous d'avoir\npris ce temps pour vous'",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Gelica',
                          color: Color(0xFF232323),
                          fontSize: 22,
                          fontWeight: FontWeight.w200,
                          fontStyle: FontStyle.italic,
                          height: 1.45)),
                  const SizedBox(height: 16),
                  const Text("2 minutes de cohérence cardiaque complétées.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Gelica',
                          color: Color(0xFF232323),
                          fontSize: 15,
                          fontWeight: FontWeight.w200,
                          fontStyle: FontStyle.italic,
                          height: 1.55)),
                  const SizedBox(height: 52),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B242F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
      ],
    );
  }
}
