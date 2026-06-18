import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'biometric_service.dart';
import 'face_emotion_analyzer.dart';

class SelfieFlash extends StatefulWidget {
  final String moment;
  final VoidCallback? onComplete;
  final void Function(AuraResult result)? onAuraReady;

  const SelfieFlash({
    super.key,
    this.moment = 'before',
    this.onComplete,
    this.onAuraReady,
  });

  @override
  State<SelfieFlash> createState() => _SelfieFlashState();
}

class _SelfieFlashState extends State<SelfieFlash> {
  // camera_init | camera_ready | face_checking | camera_no_face
  // voice_prep  | voice_recording | processing | done | error
  String _step           = 'camera_init';
  int    _voiceCountdown = 5;
  AuraResult? _result;

  CameraController?  _cam;
  FaceEmotionResult? _faceResult;
  Timer?             _voiceTimer;

  static const int _voiceSec = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  // ── Camera init ─────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { setState(() => _step = 'voice_prep'); return; }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final cam = CameraController(front, ResolutionPreset.medium,
          enableAudio: false);
      await cam.initialize();
      if (!mounted) { await cam.dispose(); return; }
      setState(() { _cam = cam; _step = 'camera_ready'; });
    } catch (_) {
      if (mounted) setState(() => _step = 'voice_prep');
    }
  }

  // ── Photo capture ────────────────────────────────────────────────

  Future<void> _takePhoto() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    setState(() => _step = 'face_checking');
    try {
      final file = await cam.takePicture();
      final path = file.path;
      final face = await biometricService.analyzeFaceFromPath(path);
      try { await File(path).delete(); } catch (_) {}

      if (!mounted) return;
      if (face.faceDetected) {
        _faceResult = face;
        await cam.dispose();
        _cam = null;
        setState(() => _step = 'voice_prep');
      } else {
        setState(() => _step = 'camera_no_face');
      }
    } catch (_) {
      if (mounted) setState(() => _step = 'camera_no_face');
    }
  }

  void _skipFace() {
    _faceResult = FaceEmotionResult.noFace;
    _cam?.dispose();
    _cam = null;
    setState(() => _step = 'voice_prep');
  }

  // ── Voice ────────────────────────────────────────────────────────

  Future<void> _startVoice() async {
    setState(() { _step = 'voice_recording'; _voiceCountdown = _voiceSec; });
    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_voiceCountdown > 1) { _voiceCountdown--; } else { t.cancel(); }
      });
    });

    final voiceResult =
        await biometricService.analyzeVoice(durationSeconds: _voiceSec);
    _voiceTimer?.cancel();

    if (!mounted) return;
    setState(() => _step = 'processing');

    final result = await biometricService.fuseAndSave(
      face:  _faceResult ?? FaceEmotionResult.noFace,
      voice: voiceResult,
    );

    if (!mounted) return;
    setState(() { _step = 'done'; _result = result; });
    widget.onAuraReady?.call(result);
    await Future.delayed(const Duration(milliseconds: 1500));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 'camera_init':     return _buildCameraInit();
      case 'camera_ready':    return _buildCameraReady();
      case 'face_checking':   return _buildFaceChecking();
      case 'camera_no_face':  return _buildNoFace();
      case 'voice_prep':      return _buildVoicePrep();
      case 'voice_recording': return _buildVoiceRecording();
      case 'processing':      return _buildProcessing();
      case 'done':            return _buildDone();
      default:                return _buildError();
    }
  }

  // ── Screens ──────────────────────────────────────────────────────

  Widget _buildCameraInit() => Center(
    key: const ValueKey('ci'),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 48, height: 48,
          child: CircularProgressIndicator(strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                  const Color(0xFF0DAABA).withValues(alpha: 0.60)))),
      const SizedBox(height: 20),
      Text('Ouverture de la caméra...',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40), fontSize: 14)),
    ]),
  );

  Widget _buildCameraReady() {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return _buildCameraInit();
    return Stack(
      key: const ValueKey('cr'),
      fit: StackFit.expand,
      children: [
        CameraPreview(cam),
        Container(color: Colors.black.withValues(alpha: 0.30)),
        SafeArea(child: Column(children: [
          const SizedBox(height: 40),
          Text(
            widget.moment == 'before'
                ? 'Scan Aura — Avant'
                : 'Scan Aura — Après la routine',
            style: const TextStyle(
                fontFamily: 'Gelica', color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 0.5),
          ),
          const Spacer(),
          Text('Centrez votre visage dans le cadre',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65), fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt_outlined, size: 22),
            label: const Text('Prendre une photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0DAABA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0),
          ),
          const SizedBox(height: 52),
        ])),
      ],
    );
  }

  Widget _buildFaceChecking() {
    final cam = _cam;
    return Stack(
      key: const ValueKey('fc'),
      fit: StackFit.expand,
      children: [
        if (cam != null && cam.value.isInitialized) CameraPreview(cam),
        Container(color: Colors.black.withValues(alpha: 0.65)),
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          SizedBox(width: 48, height: 48,
              child: CircularProgressIndicator(strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(
                      const Color(0xFF0DAABA).withValues(alpha: 0.80)))),
          const SizedBox(height: 20),
          Text('Détection du visage...',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 14)),
        ])),
      ],
    );
  }

  Widget _buildNoFace() {
    final cam = _cam;
    return Stack(
      key: const ValueKey('nf'),
      fit: StackFit.expand,
      children: [
        if (cam != null && cam.value.isInitialized) CameraPreview(cam),
        Container(color: Colors.black.withValues(alpha: 0.75)),
        SafeArea(child: Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.face_retouching_off,
                color: Colors.white.withValues(alpha: 0.55), size: 56),
            const SizedBox(height: 24),
            const Text('Aucun visage détecté',
                style: TextStyle(
                    fontFamily: 'Gelica', color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.w300)),
            const SizedBox(height: 12),
            Text(
              'Assurez-vous d\'être face à la caméra\n'
              'dans un endroit bien éclairé.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _step = 'camera_ready'),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Réessayer',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0DAABA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skipFace,
              child: Text('Continuer sans visage',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 13)),
            ),
          ]),
        ))),
      ],
    );
  }

  Widget _buildVoicePrep() => SafeArea(
    key: const ValueKey('vp'),
    child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8B86E).withValues(alpha: 0.12),
              border: Border.all(
                  color: const Color(0xFFE8B86E).withValues(alpha: 0.50),
                  width: 1.5)),
          child: const Icon(Icons.mic_none_outlined,
              color: Color(0xFFE8B86E), size: 36),
        ),
        const SizedBox(height: 28),
        const Text('Analyse vocale',
            style: TextStyle(
                fontFamily: 'Gelica', color: Colors.white,
                fontSize: 24, fontWeight: FontWeight.w300)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _tip('Parlez normalement pendant 5 secondes'),
            const SizedBox(height: 10),
            _tip('Prononcez une phrase ou comptez jusqu\'à 10'),
            const SizedBox(height: 10),
            _tip('Voix naturelle — ni chuchoter, ni crier'),
          ]),
        ),
        const SizedBox(height: 12),
        Text('Durée : $_voiceSec secondes',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startVoice,
            icon: const Icon(Icons.mic, size: 20),
            label: const Text('Commencer l\'enregistrement',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8B86E),
                foregroundColor: const Color(0xFF121212),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0),
          ),
        ),
      ]),
    )),
  );

  Widget _tip(String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('• ',
          style: TextStyle(color: Color(0xFFE8B86E), fontSize: 14)),
      Expanded(child: Text(text,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 14, height: 1.4))),
    ],
  );

  Widget _buildVoiceRecording() => Center(
    key: const ValueKey('vr'),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 88, height: 88,
          child: CircularProgressIndicator(strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation(
                  const Color(0xFFE8B86E).withValues(alpha: 0.85)))),
      const SizedBox(height: 24),
      Text('$_voiceCountdown',
          style: const TextStyle(
              color: Color(0xFFE8B86E), fontSize: 52,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Parlez maintenant...',
          style: TextStyle(
              fontFamily: 'Gelica', color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w200,
              fontStyle: FontStyle.italic)),
    ]),
  );

  Widget _buildProcessing() => Center(
    key: const ValueKey('proc'),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 48, height: 48,
          child: CircularProgressIndicator(strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(
                  const Color(0xFFD9CCE8).withValues(alpha: 0.80)))),
      const SizedBox(height: 24),
      Text('Calcul de votre Aura...',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45), fontSize: 15)),
    ]));

  Widget _buildDone() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();
    final color = BiometricService.auraColor(result.hexColor);
    final label = switch (result.state) {
      AuraState.serene    => 'Sereine',
      AuraState.balanced  => 'Equilibrée',
      AuraState.tense     => 'Tendue',
      AuraState.veryTense => 'Très tendue',
    };
    return Column(
      key: const ValueKey('done'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.20),
                boxShadow: [BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 40, spreadRadius: 8)],
                border: Border.all(
                    color: color.withValues(alpha: 0.60), width: 2))),
        const SizedBox(height: 24),
        Text('Votre Aura : $label',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: color,
                fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(result.hexColor,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.30),
                fontSize: 12, fontFamily: 'monospace')),
      ]);
  }

  Widget _buildError() => Padding(
    key: const ValueKey('err'),
    padding: const EdgeInsets.symmetric(horizontal: 36),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline,
          color: Colors.white.withValues(alpha: 0.40), size: 48),
      const SizedBox(height: 20),
      Text('Analyse indisponible.\nVotre routine continue normalement.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 14, height: 1.5)),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: widget.onComplete,
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF065963),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
            elevation: 0),
        child: const Text('Continuer quand même'),
      ),
    ]),
  );
}
