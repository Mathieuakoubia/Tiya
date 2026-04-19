import 'dart:async';
import 'package:flutter/material.dart';
import 'widgets/routine_intro_screen.dart';

const _darkBg = Color(0xFF141414);
const _primaryPurple = Color(0xFF82667F);
const _accentPurple = Color(0xFF735983);

enum _Phase { intro, exercise, complete }

class TwinCoherence extends StatefulWidget {
  final VoidCallback? onComplete;
  const TwinCoherence({super.key, this.onComplete});

  @override
  State<TwinCoherence> createState() => _TwinCoherenceState();
}

class _TwinCoherenceState extends State<TwinCoherence>
    with TickerProviderStateMixin {
  static const _totalSec = 180;

  _Phase _phase = _Phase.intro;
  int _remainingSec = _totalSec;
  int _syncCount = 0;
  Timer? _timer;

  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;
  late AnimationController _mergeCtrl;
  late Animation<double> _mergeAnim;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );
    _mergeCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _mergeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mergeCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _mergeCtrl.dispose();
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

  void _onSync() {
    if (_phase != _Phase.exercise) return;
    final phase = _breathCtrl.value;
    // Synchronisation valide près du pic de respiration (0.4–0.6)
    final inSync = phase > 0.4 && phase < 0.65;
    if (inSync) {
      setState(() => _syncCount++);
      _mergeCtrl.forward(from: 0.0);
      if (_syncCount >= 12) _endExercise();
    }
  }

  void _endExercise() {
    _timer?.cancel();
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
      case _Phase.exercise:
        return _buildExercise();
      case _Phase.complete:
        return _buildComplete();
    }
  }

  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Twin-\nCoherence',
      badgeLabel: '3 min  •  Twin  •  Fusion des Souffles',
      scienceText: 'La cohérence cardiaque synchronisée entre deux personnes renforce le système nerveux parasympathique et crée un lien de sécurité profond. Respirer au même rythme est un acte de connexion puissant.',
      steps: const [
        'Deux sphères lumineuses apparaissent : vous et votre Twin',
        'Respirez en suivant le rythme des sphères qui gonflent',
        'Touchez l\'écran au pic de la respiration pour fusionner vos Auras',
      ],
      onStart: _startExercise,
      buttonLabel: 'Commencer',
      accentColor: _accentPurple,
    );
  }

  Widget _buildExercise() {
    return GestureDetector(
      key: const ValueKey('exercise'),
      onTapDown: (_) => _onSync(),
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: _darkBg),
        // Two breathing spheres + merge
        Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_breathAnim, _mergeAnim]),
            builder: (_, __) {
              final m = _mergeAnim.value;
              final s = _breathAnim.value;
              return Stack(alignment: Alignment.center, children: [
                // Twin sphere (gauche)
                Transform.translate(
                  offset: Offset(-(90.0 * (1 - m)), 0),
                  child: Opacity(
                    opacity: (1 - m * 0.8).clamp(0.0, 1.0),
                    child: Container(
                      width: 110 * s,
                      height: 110 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primaryPurple.withValues(alpha: 0.07),
                        boxShadow: [
                          BoxShadow(
                              color: _primaryPurple.withValues(alpha: 0.4),
                              blurRadius: 50,
                              spreadRadius: 6)
                        ],
                      ),
                    ),
                  ),
                ),
                // User sphere (droite)
                Transform.translate(
                  offset: Offset(90.0 * (1 - m), 0),
                  child: Opacity(
                    opacity: (1 - m * 0.8).clamp(0.0, 1.0),
                    child: Container(
                      width: 110 * s,
                      height: 110 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF9B7EA8).withValues(alpha: 0.07),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF9B7EA8)
                                  .withValues(alpha: 0.4),
                              blurRadius: 50,
                              spreadRadius: 6)
                        ],
                      ),
                    ),
                  ),
                ),
                // Merged golden sphere
                if (m > 0.01)
                  Opacity(
                    opacity: m,
                    child: Container(
                      width: 155 * s,
                      height: 155 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primaryPurple.withValues(alpha: 0.12),
                        boxShadow: [
                          BoxShadow(
                              color: _primaryPurple.withValues(alpha: 0.65),
                              blurRadius: 80,
                              spreadRadius: 24)
                        ],
                      ),
                    ),
                  ),
              ]);
            },
          ),
        ),
        // Labels twin / vous
        Positioned(
          bottom: 88,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text("Twin",
                  style: TextStyle(
                      color: _primaryPurple.withValues(alpha: 0.55),
                      fontSize: 13,
                      letterSpacing: 0.5)),
              Text("Vous",
                  style: TextStyle(
                      color: const Color(0xFF9B7EA8).withValues(alpha: 0.55),
                      fontSize: 13,
                      letterSpacing: 0.5)),
            ],
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
                        label: "$_syncCount / 12 fusions",
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
              child: Text("Touchez au pic pour fusionner",
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

  Widget _buildComplete() {
    return Container(
      key: const ValueKey('complete'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7A5200), Color(0xFFD4A853), Color(0xFFE8C87A)],
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
                const Text("'Vos souffles n'ont\nfait qu'un seul instant'",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        height: 1.45)),
                const SizedBox(height: 16),
                Text(
                    "$_syncCount fusions réalisées.\nVotre connexion est renforcée.",
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
