import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData music = IconData(0xe958, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { countdown, exercise, complete }

class BioAmbient extends StatefulWidget {
  final String audioUrl;
  final VoidCallback? onComplete;
  const BioAmbient({super.key, required this.audioUrl, this.onComplete});

  @override
  State<BioAmbient> createState() => _BioAmbientState();
}

class _BioAmbientState extends State<BioAmbient>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 180;

  _Phase _phase     = _Phase.countdown;
  int    _countdown = 3;
  int    _elapsed   = 0;

  late AnimationController _auraCtrl;
  late Animation<double>   _auraAnim;

  final _player = AudioPlayer();
  Timer? _cdTimer;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _auraCtrl = AnimationController(
        duration: const Duration(seconds: 8), vsync: this);
    _auraAnim = Tween<double>(begin: 0.85, end: 1.15)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_auraCtrl);
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

  Future<void> _startExercise() async {
    setState(() => _phase = _Phase.exercise);
    _auraCtrl.repeat(reverse: true);
    try {
      await _player.setUrl(widget.audioUrl);
      await _player.play();
    } catch (_) {
      // URL invalide — continue sans audio
    }
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _auraCtrl.stop();
    _player.stop();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _auraCtrl.dispose();
    _cdTimer?.cancel();
    _exTimer?.cancel();
    _player.dispose();
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
        Text('Préparez-vous',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 0.5)),
        const SizedBox(height: 24),
        Text('$_countdown',
            style: const TextStyle(
                color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
      ],
    )),
  );

  Widget _buildExercise() => AnimatedBuilder(
    key: const ValueKey('ex'),
    animation: _auraAnim,
    builder: (_, __) => Stack(children: [
      // Fond animé dégradé radial
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: _auraAnim.value,
              colors: [
                _teal.withValues(alpha: 0.18),
                _dark.withValues(alpha: 0.10),
                _bg,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
      // Cercle central lumineux
      Center(
        child: Container(
          width: 140 * _auraAnim.value,
          height: 140 * _auraAnim.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _teal.withValues(alpha: 0.06),
            boxShadow: [BoxShadow(
              color: _teal.withValues(alpha: 0.22),
              blurRadius: 60, spreadRadius: 10)],
          ),
          child: Icon(_Ico.music,
              color: Colors.white.withValues(alpha: 0.25), size: 40),
        ),
      ),
      // Timer et label
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 42),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_fmt(_remaining),
                style: const TextStyle(color: _gold, fontSize: 14)),
          ]),
        )),
      ),
      // Label bas
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Text('Fermez les yeux',
              style: TextStyle(
                  fontFamily: 'Gelica',
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 16,
                  fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic)),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
              child: const Icon(_Ico.music, color: Colors.white, size: 44),
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
            const Text('3 minutes d\'immersion sensorielle complétées.',
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
