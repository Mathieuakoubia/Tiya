import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/routine_intro_screen.dart';

const _bg = Color(0xFF5B242F);
const _rosePoudre = Color(0xFFFFD7E7);
const _vertAcide = Color(0xFFBCAE3A);
const _accentPurple = Color(0xFF735983);

class _Item {
  final IconData icon;
  final String label;
  double x;
  double y;
  final double fallSpeed;
  bool grabbed = false;

  _Item({
    required this.icon,
    required this.label,
    required this.x,
    required this.y,
    required this.fallSpeed,
  });
}

enum _Phase { intro, countdown, exercise, complete }

const _stressors = [
  (Icons.email_outlined, "Email"),
  (Icons.notifications_outlined, "Notif"),
  (Icons.calendar_today_outlined, "Réunion"),
  (Icons.phone_outlined, "Appel"),
  (Icons.assignment_outlined, "Tâche"),
  (Icons.chat_bubble_outline, "Message"),
  (Icons.alarm_outlined, "Alarme"),
  (Icons.work_outline, "Boulot"),
  (Icons.receipt_long_outlined, "Facture"),
  (Icons.psychology_outlined, "Stress"),
  (Icons.shopping_cart_outlined, "Courses"),
  (Icons.fitness_center, "Sport"),
];

class CognitiveSorting extends StatefulWidget {
  final VoidCallback? onComplete;

  const CognitiveSorting({super.key, this.onComplete});

  @override
  State<CognitiveSorting> createState() => _CognitiveSortingState();
}

class _CognitiveSortingState extends State<CognitiveSorting> {
  static const _itemSize = 68.0;
  static const _totalSec = 90;
  static const _maxItems = 40; // objectif à atteindre
  static const _poolSize = 16; // items simultanés à l'écran

  _Phase _phase = _Phase.intro;
  int _countdownValue = 3;
  int _remainingSec = _totalSec;
  int _cleared = 0;

  Timer? _cdTimer;
  Timer? _exTimer;
  Timer? _gameLoopTimer;

  final _rng = Random();
  final List<_Item> _items = [];

  double _screenW = 0;
  double _screenH = 0;

  int? _dragIndex;

  // Aura intensity 0.0 → 1.0
  double get _aura => (_cleared / _maxItems).clamp(0.0, 1.0);

  @override
  void dispose() {
    _cdTimer?.cancel();
    _exTimer?.cancel();
    _gameLoopTimer?.cancel();
    super.dispose();
  }

  void _goToCountdown() {
    // Capture screen size now while context is available
    final size = MediaQuery.of(context).size;
    _screenW = size.width;
    _screenH = size.height;

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
          _startExercise();
        }
      });
    });
  }

  void _startExercise() {
    _spawnAllItems();
    setState(() => _phase = _Phase.exercise);

    // Game loop ~30fps
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_phase != _Phase.exercise || !mounted) return;
      setState(_updatePositions);
    });

    // Countdown timer
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
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

  // Vitesse globale : démarre à 1×, monte à 2.5× sur 90 secondes
  double get _speedMult =>
      1.0 + ((_totalSec - _remainingSec) / _totalSec) * 1.5;

  // Pool fixe de _poolSize items qui recyclent indéfiniment
  void _spawnAllItems() {
    _items.clear();
    for (int i = 0; i < _poolSize; i++) {
      final type = _stressors[i % _stressors.length];
      _items.add(_Item(
        icon: type.$1,
        label: type.$2,
        x: _rng.nextDouble() * (_screenW - _itemSize - 40) + 20,
        y: -_itemSize - (i * 110.0), // échelonnement initial
        fallSpeed: 60 + _rng.nextDouble() * 40,
      ));
    }
  }

  void _updatePositions() {
    const dt = 0.033;
    final mult = _speedMult;
    for (final item in _items) {
      if (item.grabbed) continue;
      item.y += item.fallSpeed * mult * dt;
      // Item sorti par le bas → recycle en haut
      if (item.y > _screenH + _itemSize) {
        item.x = _rng.nextDouble() * (_screenW - _itemSize - 40) + 20;
        item.y = -_itemSize - _rng.nextDouble() * 200;
      }
    }
  }

  void _endExercise() {
    if (!mounted) return;
    _exTimer?.cancel();
    _gameLoopTimer?.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  void _onPanStart(int index, DragStartDetails d) {
    if (index < 0 || index >= _items.length) return;
    setState(() {
      _dragIndex = index;
      _items[index].grabbed = true;
    });
  }

  void _onPanUpdate(int index, DragUpdateDetails d) {
    if (_dragIndex != index || index >= _items.length) return;
    setState(() {
      _items[index].x += d.delta.dx;
      _items[index].y += d.delta.dy;
    });
  }

  void _onPanEnd(int index, DragEndDetails d) {
    if (_dragIndex != index || index >= _items.length) return;
    final speed = d.velocity.pixelsPerSecond.distance;
    if (speed > 380) {
      // Balayage rapide → éjecté, recycle en haut
      setState(() {
        _cleared++;
        _items[index].grabbed = false;
        _items[index].y = -_itemSize - _rng.nextDouble() * 300;
        _items[index].x = _rng.nextDouble() * (_screenW - _itemSize - 40) + 20;
      });
      if (_cleared >= _maxItems) _endExercise();
    } else {
      // Lâché trop lentement → retombe
      setState(() => _items[index].grabbed = false);
    }
    _dragIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _Phase.intro ? Colors.transparent : _bg,
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

  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Vide-Poubelle\nMental',
      badgeLabel: '1 min 30  •  Décharge Mentale',
      scienceText:
          "Externaliser ses sources de stress par un geste physique (balayage) active le cortex préfrontal et réduit la charge cognitive. Chaque icône jetée symbolise une libération mentale réelle.",
      steps: const [
        "Des icônes de stress tombent sur l'écran",
        'Balayez-les rapidement hors de l\'écran',
        'Chaque icône jetée libère votre Aura',
      ],
      onStart: _goToCountdown,
      accentColor: _accentPurple,
    );
  }

  Widget _buildCountdown() {
    return Container(
      key: const ValueKey('countdown'),
      color: const Color(0xFF5B242F),
      child: Center(
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
      ),
    );
  }

  Widget _buildExercise() {
    return Stack(
      key: const ValueKey('exercise'),
      children: [
        // Aura glow — s'intensifie au fil des items jetés
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            width: 180 + (_aura * 160),
            height: 180 + (_aura * 160),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.lerp(_rosePoudre, _vertAcide, _aura)!
                      .withValues(alpha: 0.08 + _aura * 0.12),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(_rosePoudre, _vertAcide, _aura)!
                      .withValues(alpha: 0.08 + _aura * 0.30),
                  blurRadius: 50 + _aura * 90,
                  spreadRadius: 8,
                ),
              ],
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TopBadge(
                    icon: Icons.timer,
                    label:
                        '${_remainingSec ~/ 60}:${(_remainingSec % 60).toString().padLeft(2, '0')}',
                    color: const Color(0xFFBCAE3A),
                  ),
                  _TopBadge(
                    icon: Icons.delete_sweep_outlined,
                    label: "$_cleared / $_maxItems",
                    color: _rosePoudre,
                    highlighted: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Falling stress items
        ..._items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Positioned(
            left: item.x,
            top: item.y,
            child: GestureDetector(
              onPanStart: (d) => _onPanStart(i, d),
              onPanUpdate: (d) => _onPanUpdate(i, d),
              onPanEnd: (d) => _onPanEnd(i, d),
              child: _StressChip(
                icon: item.icon,
                label: item.label,
                grabbed: item.grabbed,
              ),
            ),
          );
        }),
        // Bottom hint
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Text(
                "Balayez vite pour libérer",
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFF5B242F)),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 44),
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
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "$_cleared icône${_cleared > 1 ? 's' : ''} éliminée${_cleared > 1 ? 's' : ''}.\nVotre espace mental est plus léger.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Gelica',
                      color: Color(0xFF232323),
                      fontSize: 15,
                      fontWeight: FontWeight.w200,
                      fontStyle: FontStyle.italic,
                      height: 1.55,
                    ),
                  ),
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

class _StressChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool grabbed;

  const _StressChip(
      {required this.icon, required this.label, required this.grabbed});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: grabbed ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: grabbed
                ? _rosePoudre.withValues(alpha: 0.80)
                : _rosePoudre.withValues(alpha: 0.22),
            width: grabbed ? 2 : 1,
          ),
          boxShadow: grabbed
              ? [
                  BoxShadow(
                    color: _rosePoudre.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_rosePoudre, _vertAcide],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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

  const _TopBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? _rosePoudre.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
