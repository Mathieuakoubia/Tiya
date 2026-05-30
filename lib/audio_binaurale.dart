// Routine 17 — Introduction différée J40 — Casque stéréo obligatoire
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData music = IconData(0xe958, fontFamily: _f);
  static const IconData warn  = IconData(0xe978, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { checkHeadphones, countdown, exercise, complete }

class AudioBinaurale extends StatefulWidget {
  final String audioAlphaUrl;
  final String audioThetaUrl;
  final VoidCallback? onComplete;

  const AudioBinaurale({
    super.key,
    required this.audioAlphaUrl,
    required this.audioThetaUrl,
    this.onComplete,
  });

  @override
  State<AudioBinaurale> createState() => _AudioBinauraleState();
}

class _AudioBinauraleState extends State<AudioBinaurale>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 180;

  _Phase _phase         = _Phase.checkHeadphones;
  bool   _headphones    = false;
  bool   _checking      = false;
  int    _countdown     = 3;
  int    _elapsed       = 0;

  late AnimationController _waveCtrl;
  late Animation<double>   _waveAnim;

  final _player = AudioPlayer();
  Timer? _cdTimer;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
        duration: const Duration(seconds: 4), vsync: this);
    _waveAnim = Tween<double>(begin: 0.0, end: 2 * pi)
        .animate(_waveCtrl);
    _checkHeadphones();
  }

  Future<void> _checkHeadphones() async {
    setState(() => _checking = true);
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      final devices = await session.getDevices();
      final hasHeadphones = devices.any((d) =>
          d.type == AudioDeviceType.wiredHeadphones ||
          d.type == AudioDeviceType.bluetoothA2dp ||
          d.type == AudioDeviceType.wiredHeadset);
      setState(() { _headphones = hasHeadphones; _checking = false; });
    } catch (_) {
      setState(() { _headphones = false; _checking = false; });
    }
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
    _waveCtrl.repeat();
    try {
      // Choisir alpha (relaxation) ou thêta (méditation profonde) selon heure
      final hour = DateTime.now().hour;
      final url = hour >= 14 ? widget.audioThetaUrl : widget.audioAlphaUrl;
      await _player.setUrl(url);
      await _player.play();
    } catch (_) {}
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    _waveCtrl.stop();
    _player.stop();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _player.dispose();
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
      case _Phase.checkHeadphones: return _buildHeadphoneCheck();
      case _Phase.countdown:       return _buildCountdown();
      case _Phase.exercise:        return _buildExercise();
      case _Phase.complete:        return _buildComplete();
    }
  }

  Widget _buildHeadphoneCheck() => Container(
    key: const ValueKey('hp'),
    color: _bg,
    child: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: _checking
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 36, height: 36,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(_teal))),
              const SizedBox(height: 20),
              Text('Détection du casque...',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 15)),
            ])
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                _headphones ? _Ico.music : _Ico.warn,
                color: _headphones ? _teal : _gold,
                size: 52,
              ),
              const SizedBox(height: 24),
              Text(
                _headphones
                    ? 'Casque détecté ✦\nPrêt pour l\'audio binaural.'
                    : 'Casque stéréo requis.\nConnectez un casque pour continuer.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Gelica', color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic, height: 1.45),
              ),
              const SizedBox(height: 36),
              if (_headphones) SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startCountdown,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _dark, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0),
                  child: const Text('Commencer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ) else SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _checkHeadphones,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _teal,
                      side: BorderSide(color: _teal.withValues(alpha: 0.40)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30))),
                  child: const Text('Revérifier',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ]),
    ))),
  );

  Widget _buildCountdown() => Container(
    key: const ValueKey('cd'),
    color: _bg,
    child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Fermez les yeux et installez-vous',
            textAlign: TextAlign.center,
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

  Widget _buildExercise() => AnimatedBuilder(
    key: const ValueKey('ex'),
    animation: _waveAnim,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      // Onde sonore animée
      Positioned.fill(child: CustomPaint(
          painter: _SoundWavePainter(phase: _waveAnim.value, color: _teal))),
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text(_fmt(_remaining),
              style: const TextStyle(color: _gold, fontSize: 14)),
        )),
      ),
      Center(child: Icon(_Ico.music,
          color: Colors.white.withValues(alpha: 0.08), size: 80)),
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Text('Laissez les sons guider votre esprit',
              style: TextStyle(
                  fontFamily: 'Gelica',
                  color: Colors.white.withValues(alpha: 0.22),
                  fontSize: 13, fontWeight: FontWeight.w200,
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 88, height: 88,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.music, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          const Text("'3 minutes d\'immersion\nsonore complétées.'",
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

class _SoundWavePainter extends CustomPainter {
  final double phase;
  final Color color;
  const _SoundWavePainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const lines = 5;
    for (int l = 0; l < lines; l++) {
      final yOffset = size.height * (0.3 + l * 0.1);
      final amplitude = 6.0 + l * 4.0;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.06 + l * 0.02)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (int i = 0; i <= 200; i++) {
        final x = (i / 200) * size.width;
        final y = yOffset + amplitude *
            sin(phase + (i / 200) * 4 * pi + l * 0.6);
        if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SoundWavePainter old) => old.phase != phase;
}
