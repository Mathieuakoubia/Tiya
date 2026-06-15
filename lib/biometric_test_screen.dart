import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'biometric_service.dart';
import 'face_emotion_analyzer.dart';
import 'voice_stress_analyzer.dart';

const _voiceDuration = 5;

class BiometricTestScreen extends StatefulWidget {
  const BiometricTestScreen({super.key});
  @override
  State<BiometricTestScreen> createState() => _BiometricTestScreenState();
}

class _BiometricTestScreenState extends State<BiometricTestScreen>
    with TickerProviderStateMixin {

  static const _teal  = Color(0xFF0DAABA);
  static const _dark  = Color(0xFF121212);
  static const _gold  = Color(0xFFE8B86E);
  static const _ivory = Color(0xFFF8F1E9);

  late AnimationController _scanCtrl;
  late AnimationController _pulseCtrl;

  CameraController? _cam;
  // idle | camera | processing | done | error
  String _step = 'idle';
  AuraResult? _result;
  String _error = '';
  int  _camCountdown = 6;
  int  _voiceCountdown = _voiceDuration;
  bool _faceDetected  = false;
  Timer? _voiceTimer;

  FaceEmotionResult _faceResult = FaceEmotionResult.noFace;

  final _faceAnalyzer = FaceEmotionAnalyzer();

  @override
  void initState() {
    super.initState();
    _scanCtrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2400));
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 950))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cam?.dispose();
    _voiceTimer?.cancel();
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _faceAnalyzer.close();
    super.dispose();
  }

  // ─── PHASE CAMÉRA ────────────────────────────────────────────
  Future<void> _start() async {
    setState(() {
      _step         = 'camera';
      _result       = null;
      _error        = '';
      _camCountdown = 6;
      _faceDetected = false;
      _faceResult   = FaceEmotionResult.noFace;
    });

    try {
      await _faceAnalyzer.init();
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final front = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        final cam = CameraController(
            front, ResolutionPreset.medium, enableAudio: false);
        await cam.initialize();
        if (!mounted) { await cam.dispose(); return; }
        setState(() => _cam = cam);
        _scanCtrl.repeat();

        for (int i = 0; i < 6; i++) {
          if (!mounted) break;
          setState(() => _camCountdown = 6 - i);
          try {
            final frame  = await cam.takePicture();
            final result = await _faceAnalyzer
                .analyze(InputImage.fromFilePath(frame.path));
            if (result.faceDetected && !_faceResult.faceDetected) {
              _faceResult = result;
              if (mounted) setState(() => _faceDetected = true);
            }
          } catch (_) {}
          await Future.delayed(const Duration(seconds: 1));
        }

        _scanCtrl.stop();
        _scanCtrl.reset();
        setState(() => _cam = null);
        await cam.dispose();
      }
    } catch (e) {
      await _cam?.dispose();
      if (mounted) setState(() { _cam = null; _error = e.toString(); });
    }

    if (!mounted) return;

    // ─── Transition vers la phase voix ───────────────────────
    setState(() => _step = 'voice_prep');
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await _startVoice();
  }

  // ─── PHASE VOIX ───────────────────────────────────────────────
  Future<void> _startVoice() async {
    setState(() {
      _step           = 'voice';
      _voiceCountdown = _voiceDuration;
    });

    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _voiceCountdown--;
        if (_voiceCountdown <= 0) t.cancel();
      });
    });

    VoiceEmotionResult voiceResult;
    try {
      voiceResult = await biometricService.analyzeVoice(
          durationSeconds: _voiceDuration);
    } catch (_) {
      voiceResult = VoiceEmotionResult.noVoice;
    }

    if (!mounted) return;
    setState(() => _step = 'processing');

    try {
      final result = await biometricService.fuseAndSave(
          face: _faceResult, voice: voiceResult);
      if (mounted) setState(() { _step = 'done'; _result = result; });
    } catch (e) {
      if (mounted) setState(() { _step = 'error'; _error = e.toString(); });
    }
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _dark,
    appBar: AppBar(
      backgroundColor: _dark,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text('SCAN AURA',
          style: TextStyle(fontFamily: 'Gelica', fontSize: 14,
              letterSpacing: 4, fontWeight: FontWeight.w200)),
    ),
    body: SafeArea(child: _buildBody()),
  );

  Widget _buildBody() => switch (_step) {
    'camera'     => _buildCamera(),
    'voice_prep' => _buildVoicePrep(),
    'voice'      => _buildVoice(),
    'processing' => _buildProcessing(),
    'done'       => _buildDone(_result!),
    'error'      => _buildError(),
    _            => _buildIdle(),
  };

  // ─── IDLE ────────────────────────────────────────────────────
  Widget _buildIdle() => Center(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) => Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _teal.withValues(alpha: 0.06 + _pulseCtrl.value * 0.06),
            border: Border.all(
              color: _teal.withValues(alpha: 0.25 + _pulseCtrl.value * 0.35),
              width: 1.5,
            ),
          ),
          child: const Icon(Icons.face_retouching_natural, color: _teal, size: 42),
        ),
      ),
      const SizedBox(height: 36),
      const Text('ANALYSER MON AURA',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Gelica', color: _ivory,
              fontSize: 19, letterSpacing: 2, fontWeight: FontWeight.w200)),
      const SizedBox(height: 10),
      Text('6s caméra   +   ${_voiceDuration}s voix',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.28),
              fontSize: 12, letterSpacing: 1)),
      const SizedBox(height: 48),
      GestureDetector(
        onTap: _start,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: _teal.withValues(alpha: 0.55), width: 1),
            borderRadius: BorderRadius.circular(3),
            color: _teal.withValues(alpha: 0.08),
          ),
          child: const Text('LANCER LE SCAN',
              style: TextStyle(color: _teal, fontSize: 12,
                  letterSpacing: 3, fontWeight: FontWeight.w500)),
        ),
      ),
    ]),
  ));

  // ─── CAMÉRA ──────────────────────────────────────────────────
  Widget _buildCamera() {
    final cam = _cam;
    return Column(children: [
      Expanded(child: Stack(
        fit: StackFit.expand,
        children: [

          if (cam != null && cam.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / cam.value.aspectRatio,
                child: CameraPreview(cam),
              ),
            )
          else
            Container(color: const Color(0xFF080808)),

          IgnorePointer(child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center, radius: 0.85,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.60),
                ],
              ),
            ),
          )),

          if (cam != null)
            LayoutBuilder(builder: (_, box) => AnimatedBuilder(
              animation: _scanCtrl,
              builder: (_, __) {
                final y = _scanCtrl.value * box.maxHeight;
                return Positioned(
                  top: y - 35, left: 0, right: 0,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _teal.withValues(alpha: 0.04),
                          _teal.withValues(alpha: 0.65),
                          _teal.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                );
              },
            )),

          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              final a = _faceDetected
                  ? 0.55 + _pulseCtrl.value * 0.45
                  : 0.28 + _pulseCtrl.value * 0.20;
              return CustomPaint(
                painter: _ScanBrackets(color: _teal.withValues(alpha: a)),
                child: const SizedBox.expand(),
              );
            },
          ),

          if (_faceDetected)
            Positioned(
              top: 18, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.12),
                  border: Border.all(
                      color: _teal.withValues(alpha: 0.45), width: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text('VISAGE DETECTE',
                    style: TextStyle(color: _teal, fontSize: 10,
                        letterSpacing: 2.5, fontWeight: FontWeight.w500)),
              )),
            ),

          Positioned(
            bottom: 20, right: 22,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Text('$_camCountdown',
                  style: TextStyle(
                    color: _teal.withValues(alpha: 0.50 + _pulseCtrl.value * 0.40),
                    fontSize: 52, fontFamily: 'Gelica', fontWeight: FontWeight.w100,
                  )),
            ),
          ),

          Positioned(
            bottom: 22, left: 22,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ANALYSE FACIALE',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.40),
                      fontSize: 9, letterSpacing: 2.5)),
              const SizedBox(height: 3),
              Text(cam == null ? 'INIT...' : 'EN COURS',
                  style: TextStyle(color: _teal.withValues(alpha: 0.65),
                      fontSize: 9, letterSpacing: 2)),
            ]),
          ),
        ],
      )),

      LinearProgressIndicator(
        value: (6 - _camCountdown) / 6.0,
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        valueColor: const AlwaysStoppedAnimation(_teal),
        minHeight: 2,
      ),
      const SizedBox(height: 14),
    ]);
  }

  // ─── VOICE PREP ──────────────────────────────────────────────
  Widget _buildVoicePrep() => Center(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _gold.withValues(alpha: 0.10),
          border: Border.all(color: _gold.withValues(alpha: 0.45), width: 1.5),
        ),
        child: const Icon(Icons.mic_none, color: _gold, size: 36),
      ),
      const SizedBox(height: 28),
      const Text('ANALYSE VOCALE',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Gelica', color: _ivory,
              fontSize: 17, letterSpacing: 2.5, fontWeight: FontWeight.w200)),
      const SizedBox(height: 10),
      Text('Préparez-vous\nà parler ou respirer',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.30),
              fontSize: 12, letterSpacing: 0.5, height: 1.6)),
    ]),
  ));

  // ─── VOICE ENREGISTREMENT ─────────────────────────────────────
  Widget _buildVoice() => Center(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) => Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withValues(alpha: 0.07 + _pulseCtrl.value * 0.08),
            border: Border.all(
                color: _gold.withValues(alpha: 0.30 + _pulseCtrl.value * 0.40),
                width: 1.5),
          ),
          child: const Icon(Icons.mic, color: _gold, size: 36),
        ),
      ),
      const SizedBox(height: 28),
      Text('$_voiceCountdown',
          style: TextStyle(
            color: _gold.withValues(alpha: 0.70),
            fontSize: 52, fontFamily: 'Gelica', fontWeight: FontWeight.w100)),
      const SizedBox(height: 8),
      Text('ENREGISTREMENT EN COURS',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.28),
              fontSize: 9, letterSpacing: 3)),
      const SizedBox(height: 10),
      Text('Parlez, respirez ou restez silencieuse',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.22),
              fontSize: 11, letterSpacing: 0.3)),
    ]),
  ));

  // ─── PROCESSING ──────────────────────────────────────────────
  Widget _buildProcessing() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(
        width: 36, height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 1.2,
          valueColor: AlwaysStoppedAnimation(_teal),
        ),
      ),
      const SizedBox(height: 20),
      Text("CALCUL DE L'AURA...",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.28),
              fontSize: 10, letterSpacing: 3)),
    ],
  ));

  // ─── RÉSULTAT ────────────────────────────────────────────────
  Widget _buildDone(AuraResult r) {
    final color = BiometricService.auraColor(r.hexColor);
    final score = (r.auraScore * 100).round();
    final label = switch (r.state) {
      AuraState.serene    => 'SEREINE',
      AuraState.balanced  => 'EQUILIBREE',
      AuraState.tense     => 'TENDUE',
      AuraState.veryTense => 'TRES TENDUE',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(children: [

        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.08 + _pulseCtrl.value * 0.07),
              border: Border.all(
                  color: color.withValues(alpha: 0.40 + _pulseCtrl.value * 0.25),
                  width: 1.5),
              boxShadow: [BoxShadow(
                color: color.withValues(alpha: 0.20 + _pulseCtrl.value * 0.18),
                blurRadius: 28 + _pulseCtrl.value * 16,
                spreadRadius: 2,
              )],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(label,
            style: TextStyle(fontFamily: 'Gelica', color: color,
                fontSize: 20, letterSpacing: 2.5, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(r.hexColor,
            style: TextStyle(color: color.withValues(alpha: 0.30),
                fontSize: 10, fontFamily: 'monospace', letterSpacing: 1.5)),

        const SizedBox(height: 24),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.20), width: 0.5),
            borderRadius: BorderRadius.circular(3),
            color: color.withValues(alpha: 0.05),
          ),
          child: Column(children: [
            Text('SCORE AURA',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 9, letterSpacing: 3)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$score',
                      style: TextStyle(
                        color: color,
                        fontSize: 56,
                        fontFamily: 'Gelica',
                        fontWeight: FontWeight.w200,
                        height: 1,
                      )),
                  const SizedBox(width: 4),
                  Text('/ 100',
                      style: TextStyle(
                        color: color.withValues(alpha: 0.45),
                        fontSize: 14, fontFamily: 'Gelica',
                      )),
                ]),
          ]),
        ),

        const SizedBox(height: 16),
        _buildMetrics(r, color),
        const SizedBox(height: 30),

        GestureDetector(
          onTap: _start,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: _teal.withValues(alpha: 0.40), width: 1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('NOUVEAU SCAN',
                style: TextStyle(color: _teal, fontSize: 11, letterSpacing: 3)),
          ),
        ),
      ]),
    );
  }

  Widget _buildMetrics(AuraResult r, Color color) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 0.5),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Column(children: [
      _row('VALENCE', _signed(r.valence)),
      _sep(),
      _row('AROUSAL', r.arousal.toStringAsFixed(3)),
      _sep(),
      _row('VISAGE',  r.faceUsed  ? 'DETECTE' : 'NON'),
      _sep(),
      _row('VOIX',   r.voiceUsed ? 'CAPTEE'  : 'NON'),
    ]),
  );

  Widget _row(String label, String value, [Color? vc]) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.28),
          fontSize: 10, letterSpacing: 2)),
      Text(value, style: TextStyle(
          color: vc ?? Colors.white.withValues(alpha: 0.70),
          fontSize: 12, fontFamily: 'monospace', letterSpacing: 0.5)),
    ]),
  );

  Widget _sep() => Container(height: 0.5, color: Colors.white.withValues(alpha: 0.06));

  String _signed(double v) =>
      v >= 0 ? '+${v.toStringAsFixed(3)}' : v.toStringAsFixed(3);

  // ─── ERREUR ──────────────────────────────────────────────────
  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(36),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline,
          color: Colors.white.withValues(alpha: 0.25), size: 44),
      const SizedBox(height: 16),
      Text('ANALYSE IMPOSSIBLE',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13, letterSpacing: 2)),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(_error, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.18),
                fontSize: 10, fontFamily: 'monospace')),
      ],
      const SizedBox(height: 30),
      GestureDetector(
        onTap: _start,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text('REESSAYER',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 11, letterSpacing: 2.5)),
        ),
      ),
    ]),
  ));
}

// ─── BRACKETS DE CIBLAGE ─────────────────────────────────────────────────────

class _ScanBrackets extends CustomPainter {
  final Color color;
  static const double _s   = 28.0;
  static const double _pad = 28.0;
  static const double _sw  = 2.0;

  const _ScanBrackets({required this.color});

  @override
  void paint(Canvas canvas, Size sz) {
    final p = Paint()
      ..color = color
      ..strokeWidth = _sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    _bracket(canvas, p, Offset(_pad, _pad), 1, 1);
    _bracket(canvas, p, Offset(sz.width - _pad, _pad), -1, 1);
    _bracket(canvas, p, Offset(_pad, sz.height - _pad), 1, -1);
    _bracket(canvas, p, Offset(sz.width - _pad, sz.height - _pad), -1, -1);
  }

  void _bracket(Canvas c, Paint p, Offset o, double dx, double dy) {
    c.drawLine(o, o.translate(_s * dx, 0), p);
    c.drawLine(o, o.translate(0, _s * dy), p);
  }

  @override
  bool shouldRepaint(_ScanBrackets old) => old.color != color;
}
