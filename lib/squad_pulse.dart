import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

const _darkBg = Color(0xFF141414);
const _lightBg = Color(0xFFF5F3FF);
const _primaryPurple = Color(0xFF82667F);
const _accentPurple = Color(0xFF735983);

enum _Phase { intro, exercise, complete }

class _Member {
  final String name;
  final Color color;
  double energy; // 0 = stressée, 1 = sereine
  double pulseSpeed; // secondes par pulsation

  _Member({
    required this.name,
    required this.color,
    required this.energy,
  }) : pulseSpeed = 1.2 + (1.0 - energy) * 1.8; // stressée = rapide
}

class SquadPulse extends StatefulWidget {
  final VoidCallback? onComplete;
  const SquadPulse({super.key, this.onComplete});

  @override
  State<SquadPulse> createState() => _SquadPulseState();
}

class _SquadPulseState extends State<SquadPulse>
    with SingleTickerProviderStateMixin {
  static const _totalSec = 60;

  _Phase _phase = _Phase.intro;
  int _remainingSec = _totalSec;
  Timer? _timer;

  final _members = [
    _Member(name: "Vous", color: const Color(0xFF4CAF50), energy: 0.6),
    _Member(name: "Alice", color: const Color(0xFF26C6DA), energy: 0.35),
    _Member(name: "Léa", color: const Color(0xFFAB47BC), energy: 0.75),
    _Member(name: "Camille", color: const Color(0xFFFF7043), energy: 0.2),
    _Member(name: "Sofia", color: const Color(0xFFFFCA28), energy: 0.55),
  ];

  late AnimationController _masterCtrl;

  @override
  void initState() {
    super.initState();
    _masterCtrl = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
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
          // Simulate all members calming down slowly
          for (final m in _members) {
            m.energy = (m.energy + 0.006).clamp(0.0, 1.0);
            m.pulseSpeed = 1.2 + (1.0 - m.energy) * 1.8;
          }
        } else {
          t.cancel();
          _endExercise();
        }
      });
    });
  }

  void _boostEnergy() {
    if (_phase != _Phase.exercise) return;
    setState(() {
      _members[0].energy = (_members[0].energy + 0.15).clamp(0.0, 1.0);
      _members[0].pulseSpeed = 1.2 + (1.0 - _members[0].energy) * 1.8;
    });
  }

  void _endExercise() {
    _timer?.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  double get _avgEnergy =>
      _members.fold(0.0, (s, m) => s + m.energy) / _members.length;

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
      case _Phase.exercise:
        return _buildExercise();
      case _Phase.complete:
        return _buildComplete();
    }
  }

  Widget _buildIntro() {
    return SafeArea(
      key: const ValueKey('intro'),
      child: Stack(children: [
        Positioned(
          bottom: -80,
          right: -80,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: _primaryPurple.withValues(alpha: 0.12), width: 48)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _accentPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("1 min  •  Squad  •  Partage d'Énergie",
                    style: TextStyle(
                        color: _accentPurple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              const Text("Squad\nPulse",
                  style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF141414),
                      height: 1.1)),
              const SizedBox(height: 28),
              const Text("Fondement scientifique :",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF141414))),
              const SizedBox(height: 8),
              Text(
                "Visualiser l'état émotionnel de son groupe sans texte réduit l'anxiété sociale tout en maintenant la connexion. Cette conscience collective silencieuse favorise l'entraide spontanée.",
                style: TextStyle(
                    fontSize: 15,
                    color: const Color(0xFF141414).withValues(alpha: 0.6),
                    height: 1.65),
              ),
              const SizedBox(height: 32),
              _IntroStep(
                  number: "1",
                  text: "5 sphères lumineuses représentent votre Squad"),
              const SizedBox(height: 14),
              _IntroStep(
                  number: "2",
                  text: "La vitesse de pulsation indique le niveau de stress"),
              const SizedBox(height: 14),
              _IntroStep(
                  number: "3",
                  text:
                      "Touchez l'écran pour partager votre énergie au groupe"),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: const Text("Voir le Squad",
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildExercise() {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      key: const ValueKey('exercise'),
      onTapDown: (_) => _boostEnergy(),
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: _darkBg),
        // Pentagon of members
        ..._buildPentagon(size),
        // Center energy display
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryPurple.withValues(alpha: 0.05 + _avgEnergy * 0.1),
              boxShadow: [
                BoxShadow(
                    color: _primaryPurple.withValues(alpha: _avgEnergy * 0.3),
                    blurRadius: 40,
                    spreadRadius: 5)
              ],
            ),
            child: Center(
              child: Text("${(_avgEnergy * 100).toInt()}%",
                  style: TextStyle(
                      color: _primaryPurple.withValues(
                          alpha: 0.6 + _avgEnergy * 0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ),
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
                        icon: Icons.favorite,
                        label: "Énergie ${(_avgEnergy * 100).toInt()}%",
                        color: _primaryPurple,
                        highlighted: true),
                  ],
                ),
              ),
            )),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Text("Touchez pour partager votre énergie",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.22),
                      fontSize: 13,
                      letterSpacing: 0.3)),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildPentagon(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 140.0;
    return List.generate(_members.length, (i) {
      final angle = (2 * pi * i / _members.length) - pi / 2;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      final m = _members[i];
      return Positioned(
        left: x - 36,
        top: y - 50,
        child: AnimatedBuilder(
          animation: _masterCtrl,
          builder: (_, __) {
            final t = _masterCtrl.value * 60; // seconds elapsed
            final pulse = 0.85 + 0.15 * sin(2 * pi * t / m.pulseSpeed);
            final stressRatio = 1.0 - m.energy;
            final glowColor = Color.lerp(
                _primaryPurple, const Color(0xFFE53935), stressRatio)!;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glowColor.withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(
                          color: glowColor.withValues(alpha: 0.45),
                          blurRadius: 24,
                          spreadRadius: 4)
                    ],
                    border: Border.all(
                        color: glowColor.withValues(alpha: 0.6), width: 2),
                  ),
                  child: Center(
                    child: Text(m.name[0],
                        style: TextStyle(
                            color: glowColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(m.name,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11)),
            ]);
          },
        ),
      );
    });
  }

  Widget _buildComplete() {
    return Container(
      key: const ValueKey('complete'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50), Color(0xFF81C784)],
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
                  child:
                      const Icon(Icons.favorite, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 28),
                const Text("'Votre Squad est\nen bonne santé'",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        height: 1.45)),
                const SizedBox(height: 16),
                Text(
                    "Énergie collective : ${(_avgEnergy * 100).toInt()}%.\nVotre contribution a renforcé le groupe.",
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

class _IntroStep extends StatelessWidget {
  final String number;
  final String text;
  const _IntroStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _accentPurple.withValues(alpha: 0.12)),
        child: Center(
            child: Text(number,
                style: const TextStyle(
                    color: _accentPurple,
                    fontSize: 13,
                    fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 12),
      Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 15, color: Color(0xFF141414)))),
    ]);
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
