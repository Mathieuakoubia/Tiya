import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AuraEmotion { surcharge, tension, equilibre, apaisement }

// Ivory base all palettes fade toward
const _ivory = Color(0xFFF4F3F2);

List<Color> _colorsFor(AuraEmotion emotion) {
  switch (emotion) {
    case AuraEmotion.surcharge:
      return const [
        Color(0xFFF2631D),
        Color(0xFFF48B5A),
        Color(0xFFF4B08A),
        _ivory,
      ];
    case AuraEmotion.tension:
      return const [
        Color(0xFFFFDE59),
        Color(0xFFF4E890),
        Color(0xFFF4EFC0),
        _ivory,
      ];
    case AuraEmotion.equilibre:
      return const [
        Color(0xFFBCAE3A),
        Color(0xFFCEBF6A),
        Color(0xFFDDD09A),
        _ivory,
      ];
    case AuraEmotion.apaisement:
      return const [
        Color(0xFF5170FF),
        Color(0xFF7A8FFF),
        Color(0xFFA0B0FF),
        _ivory,
      ];
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
  late AnimationController _morphCtrl;
  late AnimationController _shiftCtrl;

  @override
  void initState() {
    super.initState();
    _morphCtrl = AnimationController(
      duration: const Duration(seconds: 9),
      vsync: this,
    )..repeat();

    _shiftCtrl = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _morphCtrl.dispose();
    _shiftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ??
        (widget.emotion != null
            ? _colorsFor(widget.emotion!)
            : const [
                Color(0xFFFF79A8),
                Color(0xFF79D4FF),
                Color(0xFFB679FF),
                Color(0xFF79FFE8),
              ]);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_morphCtrl, _shiftCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _AuraPainter(
            morphPhase: _morphCtrl.value,
            shiftPhase: _shiftCtrl.value,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  final double morphPhase;
  final double shiftPhase;
  final List<Color> colors;

  const _AuraPainter({
    required this.morphPhase,
    required this.shiftPhase,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final R = size.width * 0.40;

    final path = _buildBlob(center, R);

    // Halo extérieur flou
    canvas.drawPath(
      path,
      Paint()
        ..color = colors[0].withValues(alpha: 0.14)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, R * 0.5),
    );

    // Clip sur la forme organique
    canvas.save();
    canvas.clipPath(path);

    final blobRect = Rect.fromCircle(center: center, radius: R * 1.15);

    // Base blanche
    canvas.drawRect(
      blobRect,
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );

    // Taches de couleur irisées en mouvement
    final spots = [
      _Spot(
        color: colors[0],
        align: Alignment(
          0.20 + math.sin(shiftPhase * math.pi * 2) * 0.50,
          -0.10 + math.cos(shiftPhase * math.pi * 2) * 0.40,
        ),
        radius: 0.75,
        alpha: 0.62,
      ),
      _Spot(
        color: colors[1],
        align: Alignment(
          -0.30 + math.cos(shiftPhase * math.pi * 2 + 1.5) * 0.50,
          0.20 + math.sin(shiftPhase * math.pi * 2 + 1.5) * 0.40,
        ),
        radius: 0.65,
        alpha: 0.55,
      ),
      _Spot(
        color: colors[2],
        align: Alignment(
          math.sin(shiftPhase * math.pi * 2 + 3.0) * 0.50,
          math.cos(shiftPhase * math.pi * 2 + 3.0) * 0.50,
        ),
        radius: 0.60,
        alpha: 0.48,
      ),
      if (colors.length > 3)
        _Spot(
          color: colors[3],
          align: Alignment(
            -0.10 + math.cos(shiftPhase * math.pi * 2 + 4.5) * 0.42,
            -0.30 + math.sin(shiftPhase * math.pi * 2 + 4.5) * 0.42,
          ),
          radius: 0.55,
          alpha: 0.40,
        ),
    ];

    for (final s in spots) {
      canvas.drawRect(
        blobRect,
        Paint()
          ..shader = RadialGradient(
            center: s.align,
            radius: s.radius,
            colors: [
              s.color.withValues(alpha: s.alpha),
              s.color.withValues(alpha: 0.0),
            ],
          ).createShader(blobRect),
      );
    }

    // Reflet blanc mobile — deux passes séparées pour éviter le scintillement
    final hx = cx + math.sin(shiftPhase * math.pi * 2 + 0.5) * R * 0.25;
    final hy = cy + math.cos(shiftPhase * math.pi * 2 + 0.5) * R * 0.20;
    final hCenter = Offset(hx, hy);
    final hRect = Rect.fromCircle(center: hCenter, radius: R * 0.32);
    // Passe 1 : flou doux
    canvas.drawCircle(
      hCenter, R * 0.32,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Passe 2 : gradient net
    canvas.drawCircle(
      hCenter, R * 0.28,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.92),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(hRect),
    );

    canvas.restore();

    // Bordure irisée scintillante
    canvas.drawPath(
      path,
      Paint()
        ..shader = SweepGradient(
          colors: [
            colors[0].withValues(alpha: 0.7),
            colors[1].withValues(alpha: 0.5),
            colors[2].withValues(alpha: 0.7),
            colors.length > 3
                ? colors[3].withValues(alpha: 0.5)
                : colors[0].withValues(alpha: 0.5),
            colors[0].withValues(alpha: 0.7),
          ],
          transform: GradientRotation(shiftPhase * math.pi * 2),
        ).createShader(Rect.fromCircle(center: center, radius: R))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  Path _buildBlob(Offset center, double R) {
    const n = 8;
    final pts = List.generate(n, (i) {
      final base = i / n * math.pi * 2;
      final perturb =
          math.sin(morphPhase * math.pi * 2 * 1 + i * 0.9) * 0.09 +
              math.sin(morphPhase * math.pi * 2 * 2 + i * 1.6) * 0.05 +
              math.sin(morphPhase * math.pi * 2 * 3 + i * 2.5) * 0.03;
      final r = R * (1.0 + perturb);
      return Offset(
        center.dx + r * math.cos(base),
        center.dy + r * math.sin(base),
      );
    });

    final path = Path();
    final mid0 = Offset(
      (pts.last.dx + pts[0].dx) / 2,
      (pts.last.dy + pts[0].dy) / 2,
    );
    path.moveTo(mid0.dx, mid0.dy);
    for (int i = 0; i < n; i++) {
      final p = pts[i];
      final next = pts[(i + 1) % n];
      final mid = Offset((p.dx + next.dx) / 2, (p.dy + next.dy) / 2);
      path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.morphPhase != morphPhase || old.shiftPhase != shiftPhase;
}

class _Spot {
  final Color color;
  final Alignment align;
  final double radius;
  final double alpha;
  const _Spot({
    required this.color,
    required this.align,
    required this.radius,
    required this.alpha,
  });
}
