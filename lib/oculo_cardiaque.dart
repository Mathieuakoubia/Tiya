// Routine 24 — Réflexe oculo-cardiaque
import 'dart:async';
import 'package:flutter/material.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData eye = IconData(0xe934, fontFamily: _f); // eye closed
}

const _bg   = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { countdown, exercise, complete }

class OculoCardiaque extends StatefulWidget {
  final VoidCallback? onComplete;
  const OculoCardiaque({super.key, this.onComplete});

  @override
  State<OculoCardiaque> createState() => _OculoCardiaqueState();
}

class _OculoCardiaqueState extends State<OculoCardiaque>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 60;

  _Phase _phase     = _Phase.countdown;
  int    _countdown = 3;
  int    _elapsed   = 0;

  // Point qui descend lentement : AnimationController 10s repeat
  late AnimationController _ptCtrl;
  late Animation<Alignment> _ptAnim;

  Timer? _cdTimer;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _ptCtrl = AnimationController(
        duration: const Duration(seconds: 10), vsync: this);
    _ptAnim = AlignmentTween(
      begin: const Alignment(0, -0.5),
      end:   const Alignment(0,  0.7),
    ).animate(CurvedAnimation(parent: _ptCtrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
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
    setState(() => _phase = _Phase.exercise);
    _ptCtrl.repeat(reverse: true);
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _ptCtrl.stop();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _ptCtrl.dispose();
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
        Text('Suivez le point\nen expirant lentement',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Gelica',
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 16, fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic)),
        const SizedBox(height: 24),
        Text('$_countdown',
            style: const TextStyle(
                color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
      ],
    )),
  );

  Widget _buildExercise() => Stack(
    key: const ValueKey('ex'),
    children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      // Point descendant
      AnimatedBuilder(
        animation: _ptAnim,
        builder: (_, __) => Align(
          alignment: _ptAnim.value,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(
                color: Colors.white.withValues(alpha: 0.45),
                blurRadius: 18, spreadRadius: 4)],
            ),
          ),
        ),
      ),
      // Timer
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text(_fmt(_remaining),
              style: const TextStyle(color: _gold, fontSize: 14)),
        )),
      ),
      // Label bas
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Text('Expirez longtemps... ralentissez',
              style: const TextStyle(
                  fontFamily: 'Gelica', color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic)),
        )),
      ),
    ],
  );

  Widget _buildComplete() => Stack(
    key: const ValueKey('done'),
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
      Container(color: Colors.white.withValues(alpha: 0.10)),
      SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 88, height: 88,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.eye, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          const Text("'Votre rythme cardiaque\na ralenti.'",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Gelica', color: Color(0xFF232323),
                  fontSize: 22, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic, height: 1.45)),
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
        ]),
      ))),
    ],
  );
}
