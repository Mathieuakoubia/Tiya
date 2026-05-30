// Routine 40 — 8 minutes — Rituel du soir — la plus longue du catalogue
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData moon  = IconData(0xe957, fontFamily: _f);
  static const IconData lotus = IconData(0xe93b, fontFamily: _f);
}

const _bg   = Color(0xFF060812);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

const _steps = [
  _SleepStep('Body Scan', 'Parcourez votre corps des pieds à la tête.\nRelâchez chaque zone.', 180, true),
  _SleepStep('Respiration', 'Ralentissez. Inspirez sur 4.\nExpirez sur 8.', 120, false),
  _SleepStep('Narration apaisante', 'Laissez Aria vous accompagner.', 120, false),
  _SleepStep('Silence haptique', 'Aucune interaction requise.', 60, false),
];

class _SleepStep {
  final String name;
  final String instruction;
  final int    durationSec;
  final bool   bodyScan;
  const _SleepStep(this.name, this.instruction, this.durationSec, this.bodyScan);
}

enum _Phase { countdown, exercise, complete }

class PreparationSommeil extends StatefulWidget {
  final String? narrationUrl;
  final VoidCallback? onComplete;

  const PreparationSommeil({
    super.key,
    this.narrationUrl,
    this.onComplete,
  });

  @override
  State<PreparationSommeil> createState() => _PreparationSommeilState();
}

class _PreparationSommeilState extends State<PreparationSommeil>
    with SingleTickerProviderStateMixin {
  _Phase _phase      = _Phase.countdown;
  int    _countdown  = 3;
  int    _stepIndex  = 0;
  int    _stepElapsed = 0;

  // Body scan zones
  final _scanZones = [
    'Pieds...', 'Mollets...', 'Genoux...', 'Cuisses...',
    'Abdomen...', 'Poitrine...', 'Épaules...', 'Bras...',
    'Mains...', 'Nuque...', 'Visage...',
  ];
  int _scanZoneIndex = 0;

  // Respiration
  bool   _isInhaling = true;
  late AnimationController _breathCtrl;
  late Animation<double>   _breathAnim;

  final _player = AudioPlayer();
  Timer? _cdTimer;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
        duration: const Duration(seconds: 12), vsync: this); // 4s inhale + 8s exhale
    _breathAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.75, end: 1.20)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 4),
      TweenSequenceItem(
          tween: Tween(begin: 1.20, end: 0.75)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 8),
    ]).animate(_breathCtrl);
    _breathCtrl.addListener(() {
      final inhale = _breathCtrl.value < (4 / 12);
      if (inhale != _isInhaling) setState(() => _isInhaling = inhale);
    });
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
          _startStep(0);
        }
      });
    });
  }

  void _startStep(int index) {
    if (index >= _steps.length) { _complete(); return; }
    _stepTimer?.cancel();
    setState(() {
      _stepIndex   = index;
      _stepElapsed = 0;
    });
    final step = _steps[index];
    // Audio pour l'étape narration
    if (step.name == 'Narration apaisante' &&
        widget.narrationUrl?.isNotEmpty == true) {
      _player.setUrl(widget.narrationUrl!).then((_) => _player.play());
    }
    // Respiration pour l'étape respiration
    if (step.name == 'Respiration') {
      _breathCtrl.repeat();
    }
    // Silence haptique — vibration très douce toutes les 4s
    if (step.name == 'Silence haptique') {
      _breathCtrl.stop();
      _player.stop();
    }

    _stepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _stepElapsed++);
      // Body scan : avancer les zones
      if (step.bodyScan) {
        final zoneInterval = step.durationSec / _scanZones.length;
        final newZone = (_stepElapsed / zoneInterval).floor()
            .clamp(0, _scanZones.length - 1);
        if (newZone != _scanZoneIndex) {
          setState(() => _scanZoneIndex = newZone);
          Vibration.vibrate(duration: 60);
        }
      }
      // Silence haptique — pulse léger
      if (step.name == 'Silence haptique' && _stepElapsed % 4 == 0) {
        Vibration.vibrate(duration: 40);
      }
      if (_stepElapsed >= step.durationSec) {
        t.cancel();
        _startStep(index + 1);
      }
    });
  }

  void _complete() {
    _breathCtrl.stop();
    _player.stop();
    Vibration.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _player.dispose();
    _cdTimer?.cancel();
    _stepTimer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  _SleepStep get _currentStep => _steps[_stepIndex];
  double get _stepProgress =>
      _stepElapsed / _currentStep.durationSec.toDouble();

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
        Text('Installez-vous confortablement',
            style: TextStyle(
                fontFamily: 'Gelica',
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 15, fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic)),
        const SizedBox(height: 24),
        Text('$_countdown',
            style: const TextStyle(
                color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
      ],
    )),
  );

  Widget _buildExercise() {
    final step = _currentStep;
    return AnimatedBuilder(
      key: const ValueKey('ex'),
      animation: _breathCtrl,
      builder: (_, __) => Stack(children: [
        const Positioned.fill(child: ColoredBox(color: _bg)),
        // Halo central doux
        Center(child: Transform.scale(
          scale: step.name == 'Respiration' ? _breathAnim.value : 1.0,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _teal.withValues(alpha: 0.04),
              boxShadow: [BoxShadow(
                color: _teal.withValues(alpha: 0.08),
                blurRadius: 80, spreadRadius: 20)],
            ),
          ),
        )),
        // Étapes en haut
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_steps.length, (i) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i < _stepIndex
                          ? _teal.withValues(alpha: 0.70)
                          : i == _stepIndex
                              ? _gold
                              : Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 10),
              Text(step.name,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11, letterSpacing: 1.5,
                      fontWeight: FontWeight.w500)),
            ]),
          )),
        ),
        // Instruction principale
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  step.bodyScan
                      ? _scanZones[_scanZoneIndex]
                      : step.name == 'Respiration'
                          ? (_isInhaling ? 'Inspirez — 4' : 'Expirez — 8')
                          : step.instruction,
                  key: ValueKey('$_stepIndex-$_scanZoneIndex-$_isInhaling'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Gelica', color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w200,
                      fontStyle: FontStyle.italic, height: 1.5),
                ),
              ),
            ]),
          ),
        ),
        // Progress bar étape
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 36, 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _stepProgress,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(
                    _teal.withValues(alpha: 0.40)),
              ),
            ),
          )),
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 88, height: 88,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.moon, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          const Text("'Bonne nuit.'",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Gelica', color: Color(0xFF232323),
                  fontSize: 28, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic)),
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
