// Routine 23 — Stimulation nerf vague via vibration au tragus
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData mic = IconData(0xe955, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { instructions, exercise, complete }

class VagusEar extends StatefulWidget {
  final VoidCallback? onComplete;
  const VagusEar({super.key, this.onComplete});

  @override
  State<VagusEar> createState() => _VagusEarState();
}

class _VagusEarState extends State<VagusEar>
    with SingleTickerProviderStateMixin {
  // 90s max — recharge de 15min entre utilisations gérée par l'App State FF
  static const int _totalSec = 90;

  _Phase _phase     = _Phase.instructions;
  int    _elapsed   = 0;
  bool   _proximity = false;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  StreamSubscription? _proxSub;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.12)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseCtrl);
  }

  void _startExercise() {
    setState(() => _phase = _Phase.exercise);
    // Écouter le capteur de proximité via proximity_sensor package
    _proxSub = ProximitySensor.events.listen((int event) {
      if (!mounted) return;
      setState(() => _proximity = event > 0); // >0 = objet proche (oreille)
      if (_proximity) {
        // Téléphone contre l'oreille → démarrer les vibrations
        if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
        Vibration.vibrate(pattern: [0, 20, 10, 20], repeat: 0);
      } else {
        _pulseCtrl.stop();
        Vibration.cancel();
      }
    });
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (!_proximity) return; // ne compte que quand en contact
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _pulseCtrl.stop();
    Vibration.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _proxSub?.cancel();
    _exTimer?.cancel();
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
        duration: const Duration(milliseconds: 450),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.instructions: return _buildInstructions();
      case _Phase.exercise:     return _buildExercise();
      case _Phase.complete:     return _buildComplete();
    }
  }

  Widget _buildInstructions() => Container(
    key: const ValueKey('inst'),
    color: _bg,
    child: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_Ico.mic, color: _teal.withValues(alpha: 0.60), size: 52),
        const SizedBox(height: 28),
        const Text('Stimulation du nerf vague',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Gelica', color: Colors.white,
                fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Text(
          'Placez le bord supérieur du téléphone\ncontre le cartilage de votre oreille (tragus).\n\nLes vibrations vont ralentir votre rythme cardiaque.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Gelica',
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14, fontWeight: FontWeight.w200,
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
            child: const Text('Démarrer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ))),
  );

  Widget _buildExercise() => AnimatedBuilder(
    key: const ValueKey('ex'),
    animation: _pulseAnim,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: Transform.scale(
        scale: _proximity ? _pulseAnim.value : 1.0,
        child: Container(
          width: 150, height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _teal.withValues(alpha: _proximity ? 0.14 : 0.04),
            boxShadow: _proximity
                ? [BoxShadow(
                    color: _teal.withValues(alpha: 0.25),
                    blurRadius: 50, spreadRadius: 10)]
                : null,
          ),
          child: Icon(_Ico.mic,
              color: _teal.withValues(alpha: _proximity ? 0.60 : 0.20),
              size: 48),
        ),
      )),
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text(_fmt(_remaining),
              style: const TextStyle(color: _gold, fontSize: 14)),
        )),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Text(
            _proximity
                ? 'Contact détecté — vibrations actives'
                : 'Placez le téléphone contre le tragus',
            style: TextStyle(
                fontFamily: 'Gelica',
                color: _proximity
                    ? _teal.withValues(alpha: 0.70)
                    : Colors.white.withValues(alpha: 0.30),
                fontSize: 14, fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic),
          ),
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
            child: const Icon(_Ico.mic, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          const Text("'90 secondes de stimulation\nvagale complétées.'",
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
