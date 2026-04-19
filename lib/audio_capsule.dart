import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'widgets/routine_intro_screen.dart';

const _darkBg = Color(0xFF141414);
const _primaryPurple = Color(0xFF82667F);
const _accentPurple = Color(0xFF735983);

enum _Phase { intro, locked, unlocking, playing, complete }

class _WaveformPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0 lecture
  final double phase;

  _WaveformPainter({required this.progress, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const bars = 36;
    final barW = size.width / bars;
    final rng = Random(42); // seed fixe pour waveform cohérente

    for (int i = 0; i < bars; i++) {
      final x = i * barW + barW / 2;
      final baseH = 10.0 + rng.nextDouble() * (size.height * 0.6);
      final h = baseH * (0.7 + 0.3 * sin(i * 0.4 + phase));
      final played = i / bars <= progress;
      paint.color = played
          ? _primaryPurple.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.2);
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.phase != phase;
}

class AudioCapsule extends StatefulWidget {
  final VoidCallback? onComplete;
  const AudioCapsule({super.key, this.onComplete});

  @override
  State<AudioCapsule> createState() => _AudioCapsuleState();
}

class _AudioCapsuleState extends State<AudioCapsule>
    with TickerProviderStateMixin {
  static const _playDurationSec = 30;
  // Score de stress simulé — dans la vraie app, vient de Hume
  final int _stressScore = 74;

  _Phase _phase = _Phase.intro;
  double _playProgress = 0.0;
  Timer? _playTimer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _waveCtrl;
  late Animation<double> _waveAnim;
  late AnimationController _unlockCtrl;
  late Animation<double> _unlockAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _waveCtrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _waveAnim = Tween<double>(begin: 0.0, end: 2 * pi).animate(_waveCtrl);
    _unlockCtrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _unlockAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _unlockCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _unlockCtrl.dispose();
    _playTimer?.cancel();
    super.dispose();
  }

  void _showLocked() => setState(() => _phase = _Phase.locked);

  void _unlock() {
    setState(() => _phase = _Phase.unlocking);
    _unlockCtrl.forward().then((_) {
      if (mounted) {
        setState(() => _phase = _Phase.playing);
        _startPlaying();
      }
    });
  }

  void _startPlaying() {
    const interval = Duration(milliseconds: 500);
    const steps = _playDurationSec * 2; // 2 steps/sec
    int tick = 0;
    _playTimer = Timer.periodic(interval, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      tick++;
      setState(() => _playProgress = tick / steps);
      if (tick >= steps) {
        t.cancel();
        _endExercise();
      }
    });
  }

  void _endExercise() {
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _Phase.intro ? Colors.transparent : _darkBg,
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
      case _Phase.locked:
        return _buildLocked();
      case _Phase.unlocking:
        return _buildUnlocking();
      case _Phase.playing:
        return _buildPlaying();
      case _Phase.complete:
        return _buildComplete();
    }
  }

  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Audio\nCapsule',
      badgeLabel: '30 sec  •  Squad  •  Murmure de Sécurité',
      scienceText:
          'La voix d\'une personne de confiance active l\'amygdale de façon apaisante. Un message vocal enregistré dans un moment de calme transporte cette sérénité et déclenche une réponse de régulation émotionnelle.',
      steps: const [
        'Une amie de votre Squad a enregistré un message pour vous',
        'Il se déverrouille quand votre score de stress dépasse 70',
        'Écoutez et laissez les mots vous envelopper',
      ],
      onStart: _showLocked,
      buttonLabel: 'Commencer',
      accentColor: _accentPurple,
    );
  }

  Widget _buildLocked() {
    final canUnlock = _stressScore > 70;
    return Stack(
      key: const ValueKey('locked'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _darkBg),
        Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryPurple.withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                          color: _primaryPurple.withValues(
                              alpha: canUnlock ? 0.5 : 0.2),
                          blurRadius: 60,
                          spreadRadius: 10)
                    ],
                  ),
                  child: Icon(canUnlock ? Icons.lock_open : Icons.lock,
                      color: _primaryPurple.withValues(
                          alpha: canUnlock ? 0.9 : 0.4),
                      size: 52),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text("Score de stress : $_stressScore / 100",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
                canUnlock
                    ? "Une capsule de soutien est disponible"
                    : "Score insuffisant pour déverrouiller",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: canUnlock
                        ? _primaryPurple.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.35),
                    fontSize: 15)),
            const SizedBox(height: 8),
            Text("De : Alice  •  \"Respire, je pense à toi\"",
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 13,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 48),
            if (canUnlock)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Écouter la capsule"),
                onPressed: _unlock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
              ),
          ]),
        ),
      ],
    );
  }

  Widget _buildUnlocking() {
    return Stack(
      key: const ValueKey('unlocking'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _darkBg),
        Center(
          child: AnimatedBuilder(
            animation: _unlockAnim,
            builder: (_, __) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryPurple.withValues(
                        alpha: 0.08 + _unlockAnim.value * 0.1),
                    boxShadow: [
                      BoxShadow(
                          color: _primaryPurple.withValues(
                              alpha: 0.2 + _unlockAnim.value * 0.4),
                          blurRadius: 40 + _unlockAnim.value * 60,
                          spreadRadius: _unlockAnim.value * 20)
                    ],
                  ),
                  child: const Icon(Icons.lock_open,
                      color: _primaryPurple, size: 52),
                ),
                const SizedBox(height: 32),
                Opacity(
                  opacity: _unlockAnim.value,
                  child: const Text("Capsule déverrouillée",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaying() {
    final remaining = (_playDurationSec * (1 - _playProgress)).ceil();
    return Stack(
      key: const ValueKey('playing'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _darkBg),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryPurple.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                          color: _primaryPurple.withValues(alpha: 0.35),
                          blurRadius: 30)
                    ],
                  ),
                  child:
                      const Icon(Icons.person, color: _primaryPurple, size: 38),
                ),
                const SizedBox(height: 12),
                const Text("Alice",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text("\"Respire, je pense à toi, tu es capable de gérer ça\"",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _primaryPurple.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.5)),
                const SizedBox(height: 40),
                // Waveform
                AnimatedBuilder(
                  animation: _waveAnim,
                  builder: (_, __) => SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: CustomPaint(
                      painter: _WaveformPainter(
                          progress: _playProgress, phase: _waveAnim.value),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text("$remaining s",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplete() {
    return Container(
      key: const ValueKey('complete'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF57C00), Color(0xFFFF8F00), Color(0xFFFFCC02)],
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
                      color: Colors.white.withValues(alpha: 0.18)),
                  child: const Icon(Icons.headphones,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 28),
                const Text("'Les mots de vos amies\nvous portent toujours'",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        height: 1.45)),
                const SizedBox(height: 16),
                Text("Capsule écoutée.\nVotre Squad veille sur vous.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 15,
                        height: 1.55)),
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
