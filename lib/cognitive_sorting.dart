import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

const _darkBg = Color(0xFF141414);
const _lightBg = Color(0xFFF5F3FF);
const _primaryPurple = Color(0xFF82667F);
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

  Widget _buildIntro() {
    return SafeArea(
      key: const ValueKey('intro'),
      child: Stack(
        children: [
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
                  child: Text(
                    "1 min 30  •  Décharge Mentale",
                    style: TextStyle(
                        color: _accentPurple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Vide-Poubelle\nMental",
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
                      color: Color(0xFF141414)),
                ),
                const SizedBox(height: 8),
                Text(
                  "Externaliser ses sources de stress par un geste physique (balayage) active le cortex préfrontal et réduit la charge cognitive. Chaque icône jetée symbolise une libération mentale réelle.",
                  style: TextStyle(
                    fontSize: 15,
                    color: const Color(0xFF141414).withValues(alpha: 0.6),
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 32),
                const _IntroStep(
                    number: "1",
                    text: "Des icônes de stress tombent sur l'écran"),
                const SizedBox(height: 14),
                const _IntroStep(
                    number: "2",
                    text: "Balayez-les rapidement hors de l'écran"),
                const SizedBox(height: 14),
                const _IntroStep(
                    number: "3", text: "Chaque icône jetée libère votre Aura"),
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
              color: _primaryPurple.withValues(alpha: 0.03 + _aura * 0.1),
              boxShadow: [
                BoxShadow(
                  color: _primaryPurple.withValues(alpha: 0.06 + _aura * 0.28),
                  blurRadius: 50 + _aura * 80,
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
                    color: Colors.white60,
                  ),
                  _TopBadge(
                    icon: Icons.delete_sweep_outlined,
                    label: "$_cleared / $_maxItems",
                    color: _primaryPurple,
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
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.22),
                  fontSize: 13,
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
                  child: const Icon(Icons.delete_sweep,
                      color: Colors.white, size: 48),
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
                  "$_cleared icône${_cleared > 1 ? 's' : ''} éliminée${_cleared > 1 ? 's' : ''}.\nVotre espace mental est plus léger.",
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
          color: const Color(0xFF1C1728),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: grabbed
                ? _primaryPurple.withValues(alpha: 0.85)
                : _primaryPurple.withValues(alpha: 0.18),
            width: grabbed ? 2 : 1,
          ),
          boxShadow: grabbed
              ? [
                  BoxShadow(
                    color: _primaryPurple.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _primaryPurple, size: 26),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
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
            ? _primaryPurple.withValues(alpha: 0.14)
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
            style: const TextStyle(fontSize: 15, color: Color(0xFF141414)),
          ),
        ),
      ],
    );
  }
}
