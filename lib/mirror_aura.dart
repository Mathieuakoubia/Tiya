import 'dart:async';
import 'package:flutter/material.dart';
import 'widgets/routine_intro_screen.dart';

const _darkBg = Color(0xFF141414);
const _primaryPurple = Color(0xFF82667F);
const _accentPurple = Color(0xFF735983);

enum _Phase { intro, exercise, complete }

class MirrorAura extends StatefulWidget {
  final VoidCallback? onComplete;
  const MirrorAura({super.key, this.onComplete});

  @override
  State<MirrorAura> createState() => _MirrorAuraState();
}

class _MirrorAuraState extends State<MirrorAura> with TickerProviderStateMixin {
  static const _totalSec = 120;

  _Phase _phase = _Phase.intro;
  int _remainingSec = _totalSec;
  double _userEnergy = 0.0; // 0.0 (rouge) → 1.0 (bleu)
  double _twinEnergy = 0.2; // La twin commence stressée
  bool _transferring = false;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _transferCtrl;
  late Animation<double> _transferAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _transferCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _transferAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _transferCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _transferCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startExercise() {
    setState(() => _phase = _Phase.exercise);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_remainingSec > 0) {
          _remainingSec--;
        } else {
          t.cancel();
          _endExercise();
        }
      });
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_phase != _Phase.exercise) return;
    final velocity = d.velocity.pixelsPerSecond.dy;
    // Balayage vers le haut = envoi d'énergie
    if (velocity < -400) {
      _doTransfer();
    }
  }

  void _doTransfer() {
    if (_transferring) return;
    setState(() {
      _transferring = true;
      _userEnergy = (_userEnergy - 0.12).clamp(0.0, 1.0);
      _twinEnergy = (_twinEnergy + 0.18).clamp(0.0, 1.0);
    });
    _transferCtrl.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _transferring = false);
    });
    if (_twinEnergy >= 0.95) _endExercise();
  }

  void _endExercise() {
    _timer?.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  Color _auraColor(double energy) {
    return Color.lerp(
        const Color(0xFFE53935), const Color(0xFF1565C0), energy)!;
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
      case _Phase.exercise:
        return _buildExercise();
      case _Phase.complete:
        return _buildComplete();
    }
  }

  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Mirror-\nAura',
      badgeLabel: '2 min  •  Twin  •  Don d\'Énergie',
      scienceText: 'Le transfert d\'attention bienveillante active les neurones miroirs et génère une réponse empathique mesurable. Visualiser l\'énergie que l\'on offre renforce autant le donneur que le receveur.',
      steps: const [
        'Vous voyez votre Aura (bleue/calme) et celle de votre Twin (rouge/stressée)',
        'Balayez l\'écran vers le haut pour lui envoyer de l\'énergie',
        'Son Aura change de couleur à chaque transfert',
      ],
      onStart: _startExercise,
      buttonLabel: 'Commencer',
      accentColor: _accentPurple,
    );
  }

  Widget _buildExercise() {
    return GestureDetector(
      key: const ValueKey('exercise'),
      onPanEnd: _onPanEnd,
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: _darkBg),
        // Twin aura (haut)
        Positioned(
          top: 120,
          left: 0,
          right: 0,
          child: Column(children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 130 * _pulseAnim.value,
                height: 130 * _pulseAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _auraColor(_twinEnergy).withValues(alpha: 0.08),
                  boxShadow: [
                    BoxShadow(
                        color: _auraColor(_twinEnergy).withValues(alpha: 0.55),
                        blurRadius: 60,
                        spreadRadius: 12)
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text("Twin",
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    letterSpacing: 0.5)),
          ]),
        ),
        // Transfert particle
        if (_transferring)
          AnimatedBuilder(
            animation: _transferAnim,
            builder: (_, __) {
              final h = MediaQuery.of(context).size.height;
              return Positioned(
                left: 0,
                right: 0,
                top: h * 0.55 - h * 0.35 * _transferAnim.value,
                child: Center(
                  child: Opacity(
                    opacity: (1 - _transferAnim.value * 0.8).clamp(0.0, 1.0),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primaryPurple.withValues(alpha: 0.9),
                        boxShadow: [
                          BoxShadow(
                              color: _primaryPurple.withValues(alpha: 0.7),
                              blurRadius: 20)
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        // User aura (bas)
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Column(children: [
            Text("Vous",
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 130 * _pulseAnim.value,
                height: 130 * _pulseAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _auraColor(_userEnergy).withValues(alpha: 0.08),
                  boxShadow: [
                    BoxShadow(
                        color: _auraColor(_userEnergy).withValues(alpha: 0.55),
                        blurRadius: 60,
                        spreadRadius: 12)
                  ],
                ),
              ),
            ),
          ]),
        ),
        // Top bar
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TopBadge(
                        icon: Icons.timer,
                        label:
                            '${_remainingSec ~/ 60}:${(_remainingSec % 60).toString().padLeft(2, '0')}',
                        color: Colors.white60),
                    _TopBadge(
                        icon: Icons.electric_bolt,
                        label: "${(_twinEnergy * 100).toInt()}% énergie Twin",
                        color: _primaryPurple,
                        highlighted: true),
                  ],
                ),
              ),
            )),
        Align(
          alignment: Alignment.center,
          child: Text("↑  Balayez vers le haut",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.18),
                  fontSize: 13,
                  letterSpacing: 0.5)),
        ),
      ]),
    );
  }

  Widget _buildComplete() {
    return Container(
      key: const ValueKey('complete'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFAD1457), Color(0xFFE91E8C), Color(0xFFF48FB1)],
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
                  child: const Icon(Icons.electric_bolt,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 28),
                const Text("'Votre énergie a traversé\nla distance'",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        height: 1.45)),
                const SizedBox(height: 16),
                Text(
                    "L'Aura de votre Twin est passée de rouge à bleue.\nVotre don d'énergie a été reçu.",
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

class _TopBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool highlighted;
  const _TopBadge(
      {required this.icon,
      required this.label,
      required this.color,
      this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? _primaryPurple.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
