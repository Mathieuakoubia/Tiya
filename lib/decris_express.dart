import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData fire = IconData(0xe93a, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

const _zones = [
  _Zone('Mâchoire',   'Serrez fort...\npuis relâchez tout.',   'mâchoire'),
  _Zone('Épaules',    'Montez vers les oreilles...\npuis laissez tomber.', 'épaules'),
  _Zone('Cou',        'Tournez doucement à gauche...\npuis à droite.', 'cou'),
  _Zone('Mains',      'Fermez les poings...\npuis ouvrez grand.', 'mains'),
];

class _Zone {
  final String name;
  final String instruction;
  final String bodyLabel;
  const _Zone(this.name, this.instruction, this.bodyLabel);
}

enum _Phase { countdown, exercise, complete }

class DecrisExpress extends StatefulWidget {
  final VoidCallback? onComplete;
  const DecrisExpress({super.key, this.onComplete});

  @override
  State<DecrisExpress> createState() => _DecrisExpressState();
}

class _DecrisExpressState extends State<DecrisExpress>
    with SingleTickerProviderStateMixin {
  static const int _zoneSec    = 20;
  static const int _totalZones = 4;

  _Phase _phase      = _Phase.countdown;
  int    _countdown  = 3;
  int    _zoneIndex  = 0;
  int    _zoneTick   = 0;
  bool   _contracting = true; // true = contraction, false = relâchement

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  Timer? _cdTimer;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseCtrl);
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
    setState(() {
      _phase        = _Phase.exercise;
      _zoneIndex    = 0;
      _zoneTick     = 0;
      _contracting  = true;
    });
    _pulseCtrl.repeat(reverse: true);
    Vibration.vibrate(duration: 200); // signal début contraction

    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _zoneTick++;
        // mi-zone : passage contraction → relâchement
        if (_zoneTick == _zoneSec ~/ 2 && _contracting) {
          _contracting = false;
          Vibration.vibrate(duration: 100);
        }
        if (_zoneTick >= _zoneSec) {
          _zoneTick    = 0;
          _contracting = true;
          _zoneIndex++;
          if (_zoneIndex >= _totalZones) {
            t.cancel();
            _complete();
          } else {
            Vibration.vibrate(duration: 200);
          }
        }
      });
    });
  }

  void _complete() {
    _pulseCtrl.stop();
    Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 400]);
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _cdTimer?.cancel();
    _exTimer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  double get _zoneProgress =>
      _zoneIndex < _totalZones ? _zoneTick / _zoneSec : 1.0;

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
        Text('4 zones • 20 secondes chacune',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 15, fontWeight: FontWeight.w300)),
        const SizedBox(height: 24),
        Text('$_countdown',
            style: const TextStyle(
                color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
      ],
    )),
  );

  Widget _buildExercise() {
    if (_zoneIndex >= _totalZones) return const SizedBox.shrink();
    final zone = _zones[_zoneIndex];
    return AnimatedBuilder(
      key: const ValueKey('ex'),
      animation: _pulseAnim,
      builder: (_, __) => Stack(children: [
        const Positioned.fill(child: ColoredBox(color: _bg)),
        // Halo zone active
        Center(
          child: Transform.scale(
            scale: _contracting ? _pulseAnim.value : 1.0,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _teal.withValues(
                    alpha: _contracting ? 0.15 : 0.06),
                boxShadow: [BoxShadow(
                  color: _teal.withValues(
                      alpha: _contracting ? 0.25 : 0.08),
                  blurRadius: 50, spreadRadius: 10)],
              ),
              child: Icon(_Ico.fire,
                  color: _teal.withValues(alpha: 0.50), size: 42),
            ),
          ),
        ),
        // Nom de la zone
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(zone.name,
                  style: const TextStyle(
                      fontFamily: 'Gelica',
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(_contracting ? zone.instruction.split('\n').first
                               : zone.instruction.split('\n').last,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Gelica',
                      color: Color(0xFFD9CCE8),
                      fontSize: 16,
                      fontWeight: FontWeight.w200,
                      fontStyle: FontStyle.italic)),
            ]),
          )),
        ),
        // Indicateur de zones
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Barre de progression zone
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _zoneProgress,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(_teal),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Pastilles zones
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalZones, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: i < _zoneIndex ? 10 : 8,
                  height: i < _zoneIndex ? 10 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _zoneIndex
                        ? _teal
                        : i == _zoneIndex
                            ? _gold
                            : Colors.white.withValues(alpha: 0.18),
                  ),
                )),
              ),
            ]),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
              child: const Icon(_Ico.fire, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 28),
            const Text(
              "'Félicitez-vous d'avoir\npris ce temps pour vous'",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Gelica', color: Color(0xFF232323),
                  fontSize: 22, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic, height: 1.45),
            ),
            const SizedBox(height: 16),
            const Text('90 secondes de relâchement musculaire complétées.',
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
