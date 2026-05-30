import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData shootingStar = IconData(0xe961, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { countdown, exercise, complete }

class _Dot {
  Offset pos;
  bool hit = false;
  _Dot(this.pos);
}

class TapSync extends StatefulWidget {
  final VoidCallback? onComplete;
  const TapSync({super.key, this.onComplete});

  @override
  State<TapSync> createState() => _TapSyncState();
}

class _TapSyncState extends State<TapSync> {
  static const int _totalSec  = 60;
  static const double _dotR   = 26.0;

  _Phase _phase     = _Phase.countdown;
  int    _countdown = 3;
  int    _elapsed   = 0;
  int    _score     = 0;
  _Dot?  _dot;

  final _rng = Random();
  Size _screen = Size.zero;
  Timer? _cdTimer;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screen = MediaQuery.of(context).size;
      _startCountdown();
    });
  }

  void _startCountdown() {
    setState(() { _phase = _Phase.countdown; _countdown = 3; });
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          t.cancel();
          _startExercise();
        }
      });
    });
  }

  void _startExercise() {
    setState(() { _phase = _Phase.exercise; });
    _spawnDot();
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _spawnDot() {
    final margin = _dotR + 20;
    setState(() {
      _dot = _Dot(Offset(
        margin + _rng.nextDouble() * (_screen.width  - margin * 2),
        margin + _rng.nextDouble() * (_screen.height - margin * 2),
      ));
    });
  }

  void _onTap(TapDownDetails d) {
    if (_phase != _Phase.exercise || _dot == null) return;
    final dist = (_dot!.pos - d.localPosition).distance;
    if (dist <= _dotR + 12) {
      setState(() { _score++; _dot!.hit = true; });
      Future.delayed(const Duration(milliseconds: 80), _spawnDot);
    }
  }

  void _complete() {
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _cdTimer?.cancel();
    _exTimer?.cancel();
    super.dispose();
  }

  int    get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s)    => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.countdown: return _buildCountdown();
      case _Phase.exercise:  return _buildExercise();
      case _Phase.complete:  return _buildComplete();
    }
  }

  Widget _buildCountdown() => Container(
    key: const ValueKey('cd'),
    color: _bg,
    child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Tapez chaque point dès qu\'il apparaît',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 16, fontWeight: FontWeight.w300)),
        const SizedBox(height: 24),
        Text('$_countdown',
            style: const TextStyle(
                color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
      ],
    )),
  );

  Widget _buildExercise() {
    final dot = _dot;
    return GestureDetector(
      key: const ValueKey('ex'),
      onTapDown: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(children: [
        const Positioned.fill(child: ColoredBox(color: _bg)),
        // Timer
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Badge(icon: _Ico.shootingStar,
                    label: '$_score', color: _gold, highlighted: true),
                _Badge(icon: Icons.timer_outlined,
                    label: _fmt(_remaining), color: _teal),
              ],
            ),
          )),
        ),
        // Point à taper
        if (dot != null && !dot.hit)
          Positioned(
            left: dot.pos.dx - _dotR,
            top:  dot.pos.dy - _dotR,
            child: AnimatedScale(
              scale: dot.hit ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 80),
              child: Container(
                width: _dotR * 2, height: _dotR * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [_teal, _gold]),
                  boxShadow: [BoxShadow(
                    color: _teal.withValues(alpha: 0.55),
                    blurRadius: 24, spreadRadius: 4)],
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildComplete() => Stack(
    key: const ValueKey('done'),
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
      Container(color: Colors.white.withValues(alpha: 0.10)),
      SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
              child: const Icon(_Ico.shootingStar, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 28),
            Text("'$_score points en 60 secondes.'",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Gelica', color: Color(0xFF232323),
                    fontSize: 22, fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic, height: 1.45)),
            const SizedBox(height: 16),
            const Text('Votre esprit est plus libre.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Gelica', color: Color(0xFF232323),
                    fontSize: 15, fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic, height: 1.55)),
            const SizedBox(height: 52),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _dark, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0),
                child: const Text('Continuer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ))),
    ],
  );
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool highlighted;
  const _Badge({required this.icon, required this.label,
    required this.color, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}
