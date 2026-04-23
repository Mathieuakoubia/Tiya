import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'widgets/routine_intro_screen.dart';

const _darkBg        = Color(0xFF5B242F);
const _primaryPurple = Color(0xFFFED7E6);

enum _Phase { intro, exercise, complete }

class _Member {
  final String name;
  double stress; // 0 = calme, 1 = stressée
  bool contributed = false;

  _Member({required this.name, required this.stress});
}

class _ShieldPainter extends CustomPainter {
  final double solidity; // 0.0 → 1.0
  final double pulse;

  _ShieldPainter({required this.solidity, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    if (solidity <= 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = 90.0 + pulse * 8;

    // Dome layers
    for (int i = 3; i >= 0; i--) {
      final alpha = (solidity * 0.18 - i * 0.03).clamp(0.0, 0.22);
      canvas.drawCircle(
        Offset(cx, cy),
        r + i * 14.0,
        Paint()
          ..color = _primaryPurple.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 - i * 0.4,
      );
    }

    // Filled glow
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = _primaryPurple.withValues(alpha: solidity * 0.07)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  @override
  bool shouldRepaint(_ShieldPainter old) =>
      old.solidity != solidity || old.pulse != pulse;
}

class CollectiveShield extends StatefulWidget {
  final VoidCallback? onComplete;
  const CollectiveShield({super.key, this.onComplete});

  @override
  State<CollectiveShield> createState() => _CollectiveShieldState();
}

class _CollectiveShieldState extends State<CollectiveShield>
    with SingleTickerProviderStateMixin {
  static const _totalSec = 120;
  final _rng = Random();

  _Phase _phase      = _Phase.intro;
  int _remainingSec  = _totalSec;
  Timer? _timer;
  Timer? _simTimer;

  final _members = [
    _Member(name: "Vous",    stress: 0.75),
    _Member(name: "Alice",   stress: 0.62),
    _Member(name: "Léa",     stress: 0.50),
    _Member(name: "Camille", stress: 0.80),
    _Member(name: "Sofia",   stress: 0.45),
  ];

  double get _shieldSolidity =>
      _members.where((m) => m.contributed).length / _members.length;

  late AnimationController _pulseCtrl;
  late Animation<double>    _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timer?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }

  void _startExercise() {
    setState(() => _phase = _Phase.exercise);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_remainingSec > 0) {
          _remainingSec--;
        } else {
          t.cancel();
          _endExercise();
        }
      });
    });
    // Simulate other members contributing over time
    _simTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      setState(() {
        for (final m in _members) {
          if (!m.contributed && m.name != "Vous" && _rng.nextDouble() > 0.4) {
            m.contributed = true;
            m.stress = (m.stress - 0.35).clamp(0.0, 1.0);
            break;
          }
        }
      });
    });
  }

  void _doReset() {
    setState(() {
      _members[0].contributed = true;
      _members[0].stress = (_members[0].stress - 0.4).clamp(0.0, 1.0);
    });
    if (_shieldSolidity >= 1.0) _endExercise();
  }

  void _endExercise() {
    _timer?.cancel();
    _simTimer?.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  Color _stressColor(double stress) =>
      Color.lerp(const Color(0xFF43A047), const Color(0xFFE53935), stress)!;

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
      case _Phase.intro:    return _buildIntro();
      case _Phase.exercise: return _buildExercise();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Collective\nShield',
      badgeLabel: '2 min  •  Squad  •  Protection Groupée',
      scienceText: 'Les actions collectives synchronisées renforcent le sentiment d\'appartenance et réduisent la charge de stress individuelle. Savoir que son groupe agit ensemble active les mécanismes de sécurité sociale.',
      steps: const [
        'Le stress moyen du Squad est élevé — le Bouclier s\'active',
        'Chaque membre fait un Reset Flash pour renforcer le dôme',
        'Quand les 5 membres ont contribué, le badge Squad Invincible est débloqué',
      ],
      onStart: _startExercise,
      buttonLabel: 'Activer le Bouclier',
      accentColor: _primaryPurple,
    );
  }

  Widget _buildExercise() {
    final size = MediaQuery.of(context).size;
    return Stack(
      key: const ValueKey('exercise'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _darkBg),
        // Shield
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => CustomPaint(
            painter: _ShieldPainter(
                solidity: _shieldSolidity, pulse: _pulseAnim.value),
            size: Size(size.width, size.height),
          ),
        ),
        // Member avatars in pentagon
        ..._buildMemberAvatars(size),
        // Center TIYIA logo
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryPurple.withValues(alpha: 0.1 + _shieldSolidity * 0.15),
              border: Border.all(
                color: _primaryPurple.withValues(alpha: 0.3 + _shieldSolidity * 0.4),
                width: 2),
            ),
            child: Center(
              child: Text("T",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5 + _shieldSolidity * 0.5),
                  fontSize: 26, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        // Top bar
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TopBadge(icon: Icons.timer,
                  label: '${_remainingSec ~/ 60}:${(_remainingSec % 60).toString().padLeft(2, '0')}',
                  color: const Color(0xFFBCAE3A)),
                _TopBadge(icon: Icons.shield,
                  label: "${(_shieldSolidity * 100).toInt()}% protégées",
                  color: _primaryPurple, highlighted: true),
              ],
            ),
          ),
        )),
        // Reset button
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32, left: 28, right: 28),
              child: _members[0].contributed
                  ? Center(child: Text("Reset effectué ✓",
                    style: TextStyle(color: _primaryPurple.withValues(alpha: 0.7),
                        fontSize: 15, fontWeight: FontWeight.w600)))
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.flash_on),
                        label: const Text("Faire mon Reset Flash"),
                        onPressed: _doReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF232323),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMemberAvatars(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r  = 150.0;
    return List.generate(_members.length, (i) {
      final angle = (2 * pi * i / _members.length) - pi / 2;
      final x = cx + r * cos(angle) - 28;
      final y = cy + r * sin(angle) - 28;
      final m = _members[i];
      return Positioned(
        left: x, top: y,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) {
            final pulse = m.contributed ? 1.0 + _pulseAnim.value * 0.1 : 1.0;
            return Transform.scale(
              scale: pulse,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _stressColor(m.stress).withValues(alpha: 0.18),
                    border: Border.all(
                      color: m.contributed
                          ? _primaryPurple.withValues(alpha: 0.85)
                          : _stressColor(m.stress).withValues(alpha: 0.55),
                      width: m.contributed ? 2.5 : 1.5),
                    boxShadow: [BoxShadow(
                      color: _stressColor(m.stress).withValues(alpha: 0.35),
                      blurRadius: 14)],
                  ),
                  child: m.contributed
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : Center(
                          child: Text(m.name[0],
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 18))),
                ),
                const SizedBox(height: 4),
                Text(m.name,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10)),
              ]),
            );
          },
        ),
      );
    });
  }

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
                    width: 88, height: 88,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFF5B242F)),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B242F).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(30)),
                    child: const Text("🏅 Squad Invincible",
                      style: TextStyle(color: Color(0xFF5B242F), fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 24),
                  const Text("'Ensemble, vous êtes\nimpénétrables'",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Gelica',
                        color: Color(0xFF232323),
                        fontSize: 22,
                        fontWeight: FontWeight.w200,
                        fontStyle: FontStyle.italic,
                        height: 1.45)),
                  const SizedBox(height: 16),
                  const Text("Les 5 membres ont contribué au Bouclier.\nVotre Squad est protégée.",
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
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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

class _TopBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool highlighted;
  const _TopBadge({required this.icon, required this.label,
    required this.color, this.highlighted = false});

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
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
