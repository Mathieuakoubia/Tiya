import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

const _darkBg = Color(0xFF141414);
const _lightBg = Color(0xFFF5F3FF);
const _primaryPurple = Color(0xFF82667F);
const _accentPurple = Color(0xFF735983);

enum _Phase { intro, exercise, complete }

class _WavePainter extends CustomPainter {
  final double wavePhase;
  final double agitation; // 0.0 = calme, 1.0 = agitée

  _WavePainter({required this.wavePhase, required this.agitation});

  @override
  void paint(Canvas canvas, Size size) {
    final amplitude = 8.0 + agitation * 32.0;
    final frequency = 0.012 + agitation * 0.008;
    final paint = Paint()
      ..color = _primaryPurple.withValues(alpha: 0.18 - agitation * 0.05)
      ..style = PaintingStyle.fill;

    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final baseY = size.height * (0.55 + layer * 0.12);
      final phaseOff = layer * 1.2;
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x++) {
        final y = baseY +
            amplitude *
                sin(x * frequency + wavePhase + phaseOff) *
                (1 - layer * 0.2);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.wavePhase != wavePhase || old.agitation != agitation;
}

class SilentPresence extends StatefulWidget {
  final VoidCallback? onComplete;
  const SilentPresence({super.key, this.onComplete});

  @override
  State<SilentPresence> createState() => _SilentPresenceState();
}

class _SilentPresenceState extends State<SilentPresence>
    with SingleTickerProviderStateMixin {
  static const _totalSec = 300; // 5 min

  _Phase _phase = _Phase.intro;
  int _remainingSec = _totalSec;
  double _agitation = 0.0;
  Timer? _timer;
  Timer? _calmTimer;

  late AnimationController _waveCtrl;
  late Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    _waveAnim = Tween<double>(begin: 0.0, end: 2 * pi).animate(_waveCtrl);
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _timer?.cancel();
    _calmTimer?.cancel();
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
          // Diminue l'agitation progressivement si calme
          if (_agitation > 0) _agitation = (_agitation - 0.01).clamp(0.0, 1.0);
        } else {
          t.cancel();
          _endExercise();
        }
      });
    });
  }

  // Simule une perturbation (bruit détecté)
  void _onNoise() {
    if (_phase != _Phase.exercise) return;
    setState(() => _agitation = (_agitation + 0.4).clamp(0.0, 1.0));
    _calmTimer?.cancel();
    _calmTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _agitation = 0.0);
    });
  }

  void _endExercise() {
    _timer?.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

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
                child: Text("5 min  •  Twin  •  Silence Partagé",
                    style: TextStyle(
                        color: _accentPurple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              const Text("Silent-\nPresence",
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
                "Le silence partagé réduit les niveaux de cortisol plus efficacement que la conversation. La co-présence silencieuse avec une personne de confiance active le système nerveux parasympathique des deux participants.",
                style: TextStyle(
                    fontSize: 15,
                    color: const Color(0xFF141414).withValues(alpha: 0.6),
                    height: 1.65),
              ),
              const SizedBox(height: 32),
              _IntroStep(
                  number: "1",
                  text:
                      "Une mer calme apparaît — vous et votre Twin êtes présentes"),
              const SizedBox(height: 14),
              _IntroStep(
                  number: "2", text: "Restez silencieuses pendant 5 minutes"),
              const SizedBox(height: 14),
              _IntroStep(
                  number: "3",
                  text: "Si un bruit est détecté, les vagues s'agitent"),
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
                  child: const Text("Commencer",
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
    return Stack(
      key: const ValueKey('exercise'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _darkBg),
        // Wave animation
        AnimatedBuilder(
          animation: _waveAnim,
          builder: (_, __) => CustomPaint(
            painter:
                _WavePainter(wavePhase: _waveAnim.value, agitation: _agitation),
            size: Size.infinite,
          ),
        ),
        // Aura glow central
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryPurple.withValues(
                  alpha: 0.04 + (1 - _agitation) * 0.06),
              boxShadow: [
                BoxShadow(
                    color: _primaryPurple.withValues(
                        alpha: 0.2 + (1 - _agitation) * 0.25),
                    blurRadius: 80,
                    spreadRadius: 20)
              ],
            ),
          ),
        ),
        // Agitation warning
        if (_agitation > 0.3)
          Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.volume_up,
                  color: Colors.white.withValues(alpha: 0.5), size: 28),
              const SizedBox(height: 8),
              Text("Bruit détecté…",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13)),
            ]),
          ),
        // Two presence dots
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TopBadge(
                      icon: Icons.timer,
                      label:
                          '${_remainingSec ~/ 60}:${(_remainingSec % 60).toString().padLeft(2, '0')}',
                      color: Colors.white60),
                  _TopBadge(
                      icon: Icons.people,
                      label: "2 présentes",
                      color: _primaryPurple,
                      highlighted: true),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text("Restez silencieuses ensemble",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.22),
                        fontSize: 13,
                        letterSpacing: 0.3)),
                const SizedBox(height: 12),
                // Bouton test bruit (pour le prototype)
                TextButton(
                  onPressed: _onNoise,
                  child: Text("Simuler bruit",
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.18),
                          fontSize: 11)),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplete() {
    final minutes = (_totalSec - _remainingSec) ~/ 60;
    return Container(
      key: const ValueKey('complete'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF006064), Color(0xFF00BCD4), Color(0xFF80DEEA)],
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
                  child: const Icon(Icons.water, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 28),
                const Text("'Le silence partagé\nest un cadeau rare'",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        height: 1.45)),
                const SizedBox(height: 16),
                Text(
                    "$minutes minutes de présence silencieuse.\nVotre lien est renforcé.",
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
