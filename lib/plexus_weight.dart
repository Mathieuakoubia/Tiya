// Routine 26 — Deep Pressure Stimulation — Introduction différée J30
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData lotus = IconData(0xe93b, fontFamily: _f);
}

const _bg   = Color(0xFF080810);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { setup, exercise, complete }

class PlexusWeight extends StatefulWidget {
  final VoidCallback? onComplete;
  const PlexusWeight({super.key, this.onComplete});

  @override
  State<PlexusWeight> createState() => _PlexusWeightState();
}

class _PlexusWeightState extends State<PlexusWeight>
    with SingleTickerProviderStateMixin {
  static const int _totalSec   = 180;
  static const int _maxSec     = 300;

  _Phase _phase   = _Phase.setup;
  int    _elapsed = 0;

  late AnimationController _waveCtrl;
  late Animation<double>   _waveAnim;

  Timer? _exTimer;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
        duration: const Duration(seconds: 8), vsync: this);
    _waveAnim = Tween<double>(begin: 0.88, end: 1.12)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_waveCtrl);
  }

  void _startExercise() {
    setState(() => _phase = _Phase.exercise);
    _waveCtrl.repeat(reverse: true);
    // Vibrations profondes — longues et lentes
    Vibration.vibrate(pattern: [0, 1800, 600, 1800, 600, 1800], repeat: 5);
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
    // Timer de sécurité : arrêt forcé à 5 minutes
    _safetyTimer = Timer(const Duration(seconds: _maxSec), () {
      if (mounted && _phase == _Phase.exercise) _complete();
    });
  }

  void _complete() {
    _waveCtrl.stop();
    Vibration.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _exTimer?.cancel();
    _safetyTimer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  int    get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s)    => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.setup:    return _buildSetup();
      case _Phase.exercise: return _buildExercise();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildSetup() => Container(
    key: const ValueKey('setup'),
    color: _bg,
    child: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_Ico.lotus, color: _teal.withValues(alpha: 0.60), size: 52),
        const SizedBox(height: 28),
        const Text(
          'Pression profonde',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Gelica', color: Colors.white,
              fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Text(
          'Allongez-vous.\nPosez l\'appareil à plat sur votre plexus solaire\n(centre de l\'abdomen).',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Gelica',
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 15, fontWeight: FontWeight.w200,
              fontStyle: FontStyle.italic, height: 1.6),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startExercise,
            style: ElevatedButton.styleFrom(
                backgroundColor: _dark, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0),
            child: const Text('Je suis prête',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ))),
  );

  Widget _buildExercise() => AnimatedBuilder(
    key: const ValueKey('ex'),
    animation: _waveAnim,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      // Vagues très lentes
      Center(child: Transform.scale(
        scale: _waveAnim.value,
        child: Container(
          width: 260, height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _teal.withValues(alpha: 0.04),
            boxShadow: [BoxShadow(
              color: _teal.withValues(alpha: 0.08),
              blurRadius: 80, spreadRadius: 20)],
          ),
        ),
      )),
      Center(child: Icon(_Ico.lotus,
          color: Colors.white.withValues(alpha: 0.06), size: 60)),
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text(_fmt(_remaining),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.20), fontSize: 13)),
        )),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Laissez la pression vous ancrer',
                style: TextStyle(
                    fontFamily: 'Gelica',
                    color: Colors.white.withValues(alpha: 0.18),
                    fontSize: 14, fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _complete,
              child: Text('Terminer',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.20),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.20))),
            ),
          ]),
        )),
      ),
    ]),
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
            child: const Icon(_Ico.lotus, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          const Text("'Vous avez posé\nle poids du monde.'",
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
