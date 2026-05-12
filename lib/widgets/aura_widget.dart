import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AuraEmotion { surcharge, tension, equilibre, apaisement }

Color _glowFor(AuraEmotion? emotion) {
  switch (emotion) {
    case AuraEmotion.surcharge:  return const Color(0xFFF2631D);
    case AuraEmotion.tension:    return const Color(0xFFFFDE59);
    case AuraEmotion.equilibre:  return const Color(0xFFE8B86E);
    case AuraEmotion.apaisement: return const Color(0xFF5170FF);
    case null:                   return const Color(0xFFFF79A8);
  }
}

class AuraWidget extends StatefulWidget {
  final double size;
  final List<Color>? colors;
  final AuraEmotion? emotion;

  const AuraWidget({
    super.key,
    this.size = 280,
    this.colors,
    this.emotion,
  });

  @override
  State<AuraWidget> createState() => _AuraWidgetState();
}

class _AuraWidgetState extends State<AuraWidget> with TickerProviderStateMixin {
  // Rotation — 23s, non-rond pour ne pas s'aligner avec la dérive
  late final AnimationController _rotateCtrl;
  // Deux controllers à durées premières (43s et 67s)
  // Leur LCM = 2881s (~48 min) : la boucle est imperceptible
  late final AnimationController _driftA;
  late final AnimationController _driftB;
  // Battement cardiaque au centre — lub-dub à ~72 BPM (833ms)
  late final AnimationController _heartCtrl;
  late final Animation<double> _heartAnim;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      duration: const Duration(seconds: 23), vsync: this)..repeat();
    _driftA = AnimationController(
      duration: const Duration(seconds: 43), vsync: this)..repeat();
    _driftB = AnimationController(
      duration: const Duration(seconds: 67), vsync: this)..repeat();

    // Battement lub-dub : lub fort, micro-pause, dub plus doux, longue diastole
    _heartCtrl = AnimationController(
      duration: const Duration(milliseconds: 833), vsync: this)..repeat();
    _heartAnim = TweenSequence<double>([
      // lub — montée rapide
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      // lub — descente rapide
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      // micro-pause entre lub et dub
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 6),
      // dub — montée
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.65)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 9,
      ),
      // dub — descente
      TweenSequenceItem(
        tween: Tween(begin: 0.65, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 9,
      ),
      // diastole — repos jusqu'au prochain bat
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 56),
    ]).animate(_heartCtrl);
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _driftA.dispose();
    _driftB.dispose();
    _heartCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = _glowFor(widget.emotion);
    final s = widget.size;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotateCtrl, _driftA, _driftB]),
        builder: (_, __) {
          final tA = _driftA.value * 2 * math.pi;
          final tB = _driftB.value * 2 * math.pi;

          final dx = (
            math.sin(tA)          * 0.048 +
            math.sin(tB * 1.618)  * 0.022
          ) * s;

          final dy = (
            math.cos(tA * 0.618)  * 0.036 +
            math.cos(tB)          * 0.018
          ) * s;

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: _rotateCtrl.value * 2 * math.pi,
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.30),
                      blurRadius: s * 0.45,
                      spreadRadius: s * 0.05,
                    ),
                    BoxShadow(
                      color: glow.withValues(alpha: 0.18),
                      blurRadius: s * 0.12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/AURA tiyia.png',
                        fit: BoxFit.cover,
                        width: s,
                        height: s,
                      ),
                      // Battement de cœur au centre uniquement
                      AnimatedBuilder(
                        animation: _heartAnim,
                        builder: (_, __) {
                          final h = _heartAnim.value;
                          if (h == 0.0) return const SizedBox.shrink();
                          final radius = s * (0.22 + h * 0.18);
                          return Container(
                            width: radius,
                            height: radius,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  glow.withValues(alpha: 0.10 + h * 0.55),
                                  Colors.white.withValues(alpha: h * 0.20),
                                  glow.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
