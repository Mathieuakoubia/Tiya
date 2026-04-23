import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'widgets/routine_intro_screen.dart';
import 'package:flutter/services.dart';

const _darkBg = Color(0xFF5B242F);
const _primaryPurple = Color(0xFFFED7E6);
const _accentPurple = Color(0xFFF5F3F1);

enum _Phase { intro, choose, breathing, complete }

const _words = ["Calme", "Force", "Clarté", "Courage", "Paix"];
const _wordColors = [
  Color(0xFF00BCD4),
  Color(0xFFFF5722),
  Color(0xFFFFCA28),
  Color(0xFF4CAF50),
  Color(0xFF9C27B0),
];

class MorningRitual extends StatefulWidget {
  final VoidCallback? onComplete;
  const MorningRitual({super.key, this.onComplete});

  @override
  State<MorningRitual> createState() => _MorningRitualState();
}

class _MorningRitualState extends State<MorningRitual>
    with TickerProviderStateMixin {
  static const _breathCycles = 5;

  _Phase _phase = _Phase.intro;
  int? _selectedIdx;
  int _cycle = 0;
  Timer? _timer;
  bool _inhaling = true;
  double _breathProgress = 0.0;

  late AnimationController _wheelCtrl;
  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _wheelCtrl = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
    _breathCtrl = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _breathAnim = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );
    _glowCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    _breathCtrl.dispose();
    _glowCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _selectWord(int idx) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIdx = idx;
      _phase = _Phase.choose;
    });
  }

  void _confirmWord() {
    setState(() => _phase = _Phase.breathing);
    _startBreathing();
  }

  void _startBreathing() {
    _inhaling = true;
    _breathCtrl.forward(from: 0.0);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _breathProgress = _breathCtrl.value;
        if (_breathProgress >= 0.99) {
          if (_inhaling) {
            // Start exhale
            _inhaling = false;
            _breathCtrl.reverse();
          } else {
            // Cycle done
            _cycle++;
            if (_cycle >= _breathCycles) {
              t.cancel();
              _endExercise();
            } else {
              _inhaling = true;
              _breathCtrl.forward(from: 0.0);
            }
          }
        }
      });
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
      case _Phase.choose:
        return _buildChoose();
      case _Phase.breathing:
        return _buildBreathing();
      case _Phase.complete:
        return _buildComplete();
    }
  }

  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Morning\nRitual',
      badgeLabel: '2 min  •  Squad  •  Alignement du Groupe',
      scienceText: 'Choisir une intention matinale active le cortex préfrontal et oriente l\'attention sélective de la journée. Partager cette intention au groupe crée une motivation collective mesurable.',
      steps: const [
        'Choisissez un mot d\'intention pour votre journée',
        'Votre mot brille sur la Roue du Squad',
        '5 respirations conscientes pour ancrer l\'intention',
      ],
      onStart: () => setState(() => _phase = _Phase.choose),
      buttonLabel: 'Commencer le Rituel',
      accentColor: _accentPurple,
    );
  }

  Widget _buildChoose() {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height * 0.45;
    const r = 130.0;

    return Stack(
      key: const ValueKey('choose'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _darkBg),
        // Wheel center glow
        Positioned(
          left: cx - 55,
          top: cy - 55,
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryPurple.withValues(alpha: 0.07 * _glowAnim.value),
                boxShadow: [
                  BoxShadow(
                      color: _primaryPurple.withValues(
                          alpha: 0.25 * _glowAnim.value),
                      blurRadius: 50,
                      spreadRadius: 8)
                ],
              ),
              child: Center(
                child: Text("T",
                    style: TextStyle(
                        color: _primaryPurple.withValues(alpha: 0.5),
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
        // Word slots
        ...List.generate(_words.length, (i) {
          final angle = (2 * pi * i / _words.length) - pi / 2;
          final x = cx + r * cos(angle);
          final y = cy + r * sin(angle);
          final selected = _selectedIdx == i;
          final col = _wordColors[i];
          return Positioned(
            left: x - 44,
            top: y - 22,
            child: GestureDetector(
              onTap: () => _selectWord(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: selected
                      ? col.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                      color: selected
                          ? col.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.15),
                      width: selected ? 2 : 1),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: col.withValues(alpha: 0.45),
                              blurRadius: 20,
                              spreadRadius: 2)
                        ]
                      : null,
                ),
                child: Text(_words[i],
                    style: TextStyle(
                      color:
                          selected ? col : Colors.white.withValues(alpha: 0.55),
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
            ),
          );
        }),
        // Top label
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text("Choisissez votre intention",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                      letterSpacing: 0.3)),
            ),
          ),
        ),
        // Confirm button
        if (_selectedIdx != null)
          Positioned(
            bottom: 0,
            left: 28,
            right: 28,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      "\"${_words[_selectedIdx!]}\" — votre mot pour aujourd'hui",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _wordColors[_selectedIdx!]
                              .withValues(alpha: 0.75),
                          fontSize: 14,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmWord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _wordColors[_selectedIdx!],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text("Ancrer cette intention",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBreathing() {
    final word = _words[_selectedIdx!];
    final color = _wordColors[_selectedIdx!];
    return Stack(
      key: const ValueKey('breathing'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _darkBg),
        Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedBuilder(
              animation: _breathAnim,
              builder: (_, __) => Container(
                width: 180 * _breathAnim.value,
                height: 180 * _breathAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.06),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(
                            alpha: 0.35 + _breathAnim.value * 0.2),
                        blurRadius: 60 + _breathAnim.value * 40,
                        spreadRadius: 10)
                  ],
                ),
                child: Center(
                  child: Text(word,
                      style: TextStyle(
                          color: color.withValues(
                              alpha: 0.7 + _breathAnim.value * 0.3),
                          fontSize: 22 + _breathAnim.value * 6,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _inhaling ? "Inspirez…" : "Expirez…",
                key: ValueKey(_inhaling),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 16,
                    letterSpacing: 0.5),
              ),
            ),
          ]),
        ),
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
                        icon: Icons.air,
                        label: "Cycle ${_cycle + 1} / $_breathCycles",
                        color: Colors.white60),
                    _TopBadge(
                        icon: Icons.auto_awesome,
                        label: word,
                        color: color,
                        highlighted: true),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildComplete() {
    final word = _words[_selectedIdx!];
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
                  Text("'Votre journée commence\nsous le signe du $word'",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Gelica',
                          color: Color(0xFF232323),
                          fontSize: 22,
                          fontWeight: FontWeight.w200,
                          fontStyle: FontStyle.italic,
                          height: 1.45)),
                  const SizedBox(height: 16),
                  const Text(
                      "Votre intention brille sur la Roue du Squad.\nVos amies peuvent voir votre engagement.",
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
