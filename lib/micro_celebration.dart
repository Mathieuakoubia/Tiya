// Routine 35 — 30 secondes — Célébration micro-succès
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData star = IconData(0xe961, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

class MicroCelebration extends StatefulWidget {
  final VoidCallback? onComplete;
  // Si true, affiche option de partage Squad
  final bool canShareToSquad;
  final VoidCallback? onShareToSquad;

  const MicroCelebration({
    super.key,
    this.onComplete,
    this.canShareToSquad = false,
    this.onShareToSquad,
  });

  @override
  State<MicroCelebration> createState() => _MicroCelebrationState();
}

class _MicroCelebrationState extends State<MicroCelebration>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  bool _celebrating = false;

  final List<AnimationController> _particles = [];
  final List<Animation<double>>   _scales    = [];
  final List<Animation<Offset>>   _positions = [];
  final _rng = Random();

  @override
  void dispose() {
    _ctrl.dispose();
    for (final c in _particles) c.dispose();
    super.dispose();
  }

  bool get _canCelebrate => _ctrl.text.trim().isNotEmpty;

  void _celebrate() {
    if (!_canCelebrate || _celebrating) return;
    setState(() => _celebrating = true);
    Vibration.vibrate(pattern: [0, 80, 40, 120, 40, 200]);
    _launchParticles();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) widget.onComplete?.call();
    });
  }

  void _launchParticles() {
    final size = MediaQuery.of(context).size;
    for (int i = 0; i < 12; i++) {
      final ctrl = AnimationController(
          duration: Duration(milliseconds: 600 + _rng.nextInt(400)),
          vsync: this);
      final angle = _rng.nextDouble() * 2 * pi;
      final dist  = 80.0 + _rng.nextDouble() * 120;
      final endX  = size.width / 2 + dist * cos(angle);
      final endY  = size.height * 0.45 + dist * sin(angle);
      final scale = Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.elasticOut)).animate(ctrl);
      final pos = Tween<Offset>(
        begin: Offset(size.width / 2, size.height * 0.45),
        end: Offset(endX, endY),
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _particles.add(ctrl);
      _scales.add(scale);
      _positions.add(pos);
      Future.delayed(Duration(milliseconds: i * 40), () {
        if (mounted) ctrl.forward();
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _celebrating ? _buildCelebration() : _buildInput(),
        ),
      ),
    );
  }

  Widget _buildInput() => Padding(
    key: const ValueKey('input'),
    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
    child: Column(children: [
      const Spacer(),
      Icon(_Ico.star, color: _gold.withValues(alpha: 0.70), size: 48),
      const SizedBox(height: 24),
      const Text(
        'Qu\'est-ce que vous avez bien fait,\nmême petit, même banal ?',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: 'Gelica', color: Colors.white,
            fontSize: 19, fontWeight: FontWeight.w200,
            fontStyle: FontStyle.italic, height: 1.45),
      ),
      const SizedBox(height: 32),
      TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: 15, // Maximum 15 caractères pour forcer la synthèse
        textCapitalization: TextCapitalization.sentences,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: 22,
            fontWeight: FontWeight.w600, letterSpacing: 0.5),
        decoration: InputDecoration(
          counterText: '',
          hintText: 'J\'ai...',
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.20),
              fontSize: 22, fontWeight: FontWeight.w200),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _gold, width: 1.5)),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _celebrate(),
      ),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canCelebrate ? _celebrate : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              disabledBackgroundColor: _dark.withValues(alpha: 0.30),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0),
          child: const Text('Célébrer ✦',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ),
      const Spacer(),
    ]),
  );

  Widget _buildCelebration() => Stack(
    key: const ValueKey('celeb'),
    children: [
      Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover,
          width: double.infinity, height: double.infinity),
      Container(color: Colors.white.withValues(alpha: 0.10)),
      // Particules
      ..._particles.asMap().entries.map((e) {
        final i = e.key;
        if (i >= _scales.length) return const SizedBox.shrink();
        return AnimatedBuilder(
          animation: _particles[i],
          builder: (_, __) {
            final pos = _positions[i].value;
            return Positioned(
              left: pos.dx - 8,
              top: pos.dy - 8,
              child: Transform.scale(
                scale: _scales[i].value,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: [_gold, _teal, const Color(0xFFD9CCE8),
                        const Color(0xFFF2631D)][i % 4],
                  ),
                ),
              ),
            );
          },
        );
      }),
      // Message
      SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('"${_ctrl.text.trim()}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Gelica', color: Color(0xFF232323),
                  fontSize: 28, fontWeight: FontWeight.w600,
                  height: 1.3)),
          const SizedBox(height: 16),
          Text('Ça compte.',
              style: TextStyle(
                  fontFamily: 'Gelica',
                  color: const Color(0xFF232323).withValues(alpha: 0.60),
                  fontSize: 18, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic)),
          if (widget.canShareToSquad) ...[
            const SizedBox(height: 32),
            TextButton(
              onPressed: widget.onShareToSquad,
              child: Text('Partager au Squad →',
                  style: TextStyle(
                      color: _dark.withValues(alpha: 0.60),
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: _dark.withValues(alpha: 0.40))),
            ),
          ],
        ]),
      ))),
    ],
  );
}
