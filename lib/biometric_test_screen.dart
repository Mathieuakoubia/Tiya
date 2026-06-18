import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
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

  late AnimationController _pulseCtrl;

  CameraController? _cam;
  // idle | camera | face_checking | camera_no_face
  // voice_prep | voice | processing | done | error
  String _step = 'idle';
  AuraResult? _result;
  String _error = '';
  int  _voiceCountdown = _voiceDuration;
  Timer? _voiceTimer;

  FaceEmotionResult  _faceResult    = FaceEmotionResult.noFace;
  VoiceEmotionResult _voiceResult   = VoiceEmotionResult.noVoice;
  String?            _lastPhotoPath;
  bool               _photoFromGallery = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 950))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _clearLastPhoto();
    _cam?.dispose();
    _voiceTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _clearLastPhoto() {
    final path        = _lastPhotoPath;
    final fromGallery = _photoFromGallery;
    _lastPhotoPath    = null;
    _photoFromGallery = false;
    if (path != null && !fromGallery) {
      File(path).delete().ignore();
    }
  }

  // ── Ouvrir la caméra ─────────────────────────────────────────────

  Future<void> _openCamera() async {
    _clearLastPhoto();
    setState(() {
      _step        = 'camera';
      _result      = null;
      _error       = '';
      _faceResult  = FaceEmotionResult.noFace;
      _voiceResult = VoiceEmotionResult.noVoice;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { setState(() => _step = 'voice_prep'); return; }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      // medium = ~1280x720 — suffisant pour ML Kit et EfficientNet 260x260
      // high sur Samsung S21 FE génère des frames NV21 de ~24MB → OOM
      final cam = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await cam.initialize();
      if (!mounted) { await cam.dispose(); return; }
      setState(() => _cam = cam);
    } catch (e) {
      if (mounted) setState(() { _step = 'error'; _error = e.toString(); });
    }
  }

  // ── Photo avec la caméra ─────────────────────────────────────────

  Future<void> _takePhoto() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    setState(() => _step = 'face_checking');
    try {
      final file = await cam.takePicture();
      setState(() => _cam = null);
      await cam.dispose();

      _faceResult = await biometricService.analyzeFaceFromPath(file.path);
      // RGPD : fichier temporaire supprime immediatement apres inference.
      File(file.path).delete().ignore();

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!mounted) return;
      // Toujours passer par voice_prep : l'utilisatrice demarre l'enregistrement manuellement.
      setState(() => _step = _faceResult.faceDetected ? 'voice_prep' : 'camera_no_face');
    } catch (e) {
      if (mounted) setState(() { _step = 'error'; _error = e.toString(); });
    }
  }

  void _startVoiceCountdown() {
    _voiceTimer?.cancel();
    _voiceCountdown = _voiceDuration;
    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _voiceCountdown--;
        if (_voiceCountdown <= 0) t.cancel();
      });
    });
  }

  // ── Choisir depuis la galerie ────────────────────────────────────

  Future<void> _pickFromGallery() async {
    try {
      // maxWidth/maxHeight : reduit immediatement le fichier avant decode RAM.
      // Sans cette limite, une photo galerie 12MP (36 MB RGB) peut provoquer un OOM.
      final xfile = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
          maxWidth: 800,
          maxHeight: 800);
      if (xfile == null) return;

      await _cam?.dispose();
      _clearLastPhoto();

      _lastPhotoPath    = xfile.path;
      _photoFromGallery = true;

      setState(() { _cam = null; _step = 'face_checking'; });

      // ML Kit + EfficientNet — InputImage.fromFilePath gere l'EXIF nativement
      _faceResult = await biometricService.analyzeFaceFromPath(xfile.path);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!mounted) return;
      if (_faceResult.faceDetected) {
        // _lastPhotoPath est un fichier galerie (photoFromGallery=true) : ne pas supprimer
        setState(() => _step = 'voice_prep');
      } else {
        // Garder _lastPhotoPath pour le fallback "Analyser quand meme"
        setState(() => _step = 'camera_no_face');
      }
    } catch (_) {
      if (mounted) setState(() => _step = 'camera_no_face');
    }
  }

  // ── Analyser sans détection ML Kit (fallback biais) ──────────────

  Future<void> _analyzeWithoutDetection() async {
    final path = _lastPhotoPath;
    setState(() => _step = 'face_checking');
    try {
      if (path != null) {
        _faceResult = await biometricService.analyzeFaceNoDetect(path);
      } else {
        _faceResult = FaceEmotionResult.noFace;
      }
    } catch (_) {
      _faceResult = FaceEmotionResult.noFace;
    }
    _clearLastPhoto();
    if (mounted) setState(() => _step = 'voice_prep');
  }

  void _skipFace() {
    _clearLastPhoto();
    _faceResult = FaceEmotionResult.noFace;
    setState(() => _step = 'voice_prep');
  }

  // ── Enregistrement voix ──────────────────────────────────────────

  Future<void> _startVoice() async {
    setState(() => _step = 'voice');
    _startVoiceCountdown();

    VoiceEmotionResult voiceResult;
    try {
      voiceResult = await biometricService.analyzeVoice(
          durationSeconds: _voiceDuration);
    } catch (_) {
      voiceResult = VoiceEmotionResult.noVoice;
    }
    _voiceResult = voiceResult;

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

  // ── Build ────────────────────────────────────────────────────────

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
    'camera'          => _buildCamera(),
    'face_checking'   => _buildFaceChecking(),
    'camera_no_face'  => _buildNoFace(),
    'voice_prep'      => _buildVoicePrep(),
    'voice'           => _buildVoice(),
    'processing'      => _buildProcessing(),
    'done'            => _buildDone(_result!),
    'error'           => _buildError(),
    _                 => _buildIdle(),
  };

  // ── Idle ─────────────────────────────────────────────────────────

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
      Text('Photo   +   ${_voiceDuration}s voix',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.28),
              fontSize: 12, letterSpacing: 1)),
      const SizedBox(height: 48),
      GestureDetector(
        onTap: _openCamera,
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

  // ── Caméra — preview + bouton ────────────────────────────────────

  Widget _buildCamera() {
    final cam = _cam;
    return Column(children: [
      Expanded(child: Stack(fit: StackFit.expand, children: [

        if (cam != null && cam.value.isInitialized)
          Center(child: AspectRatio(
            aspectRatio: 1 / cam.value.aspectRatio,
            child: CameraPreview(cam),
          ))
        else
          Container(color: const Color(0xFF080808)),

        IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center, radius: 0.85,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
            ),
          ),
        )),

        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => CustomPaint(
            painter: _ScanBrackets(
                color: _teal.withValues(alpha: 0.35 + _pulseCtrl.value * 0.30)),
            child: const SizedBox.expand(),
          ),
        ),

        Positioned(
          bottom: 22, left: 22,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ANALYSE FACIALE',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 9, letterSpacing: 2.5)),
            const SizedBox(height: 3),
            Text(cam == null ? 'INIT...' : 'PRET',
                style: TextStyle(color: _teal.withValues(alpha: 0.65),
                    fontSize: 9, letterSpacing: 2)),
          ]),
        ),

        Positioned(
          bottom: 22, right: 22,
          child: Text('Centrez votre visage',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10, letterSpacing: 0.5)),
        ),
      ])),

      Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(children: [
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _takePhoto,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.12),
                  border: Border.all(color: _teal.withValues(alpha: 0.60), width: 1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.camera_alt_outlined, color: _teal, size: 20),
                  const SizedBox(width: 10),
                  const Text('PRENDRE UNE PHOTO',
                      style: TextStyle(color: _teal, fontSize: 12,
                          letterSpacing: 3, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickFromGallery,
            child: Text('Choisir depuis la galerie',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.32),
                    fontSize: 11, letterSpacing: 0.5)),
          ),
        ]),
      ),
    ]);
  }

  // ── Analyse visage en cours ──────────────────────────────────────

  Widget _buildFaceChecking() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(width: 40, height: 40,
          child: CircularProgressIndicator(strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(_teal))),
      const SizedBox(height: 20),
      Text('DETECTION DU VISAGE...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10, letterSpacing: 2.5)),
    ],
  ));

  // ── Aucun visage détecté ─────────────────────────────────────────

  Widget _buildNoFace() {
    final diag = biometricService.tfliteError;
    return Center(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 36),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.face_retouching_off,
          color: Colors.white.withValues(alpha: 0.40), size: 52),
      const SizedBox(height: 24),
      const Text('AUCUN VISAGE DETECTE',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Gelica', color: _ivory,
              fontSize: 16, letterSpacing: 2, fontWeight: FontWeight.w300)),
      const SizedBox(height: 12),
      Text(
        'Assurez-vous d\'être bien face à la caméra\n'
        'dans un endroit correctement éclairé.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12, letterSpacing: 0.3, height: 1.6),
      ),
      if (diag != null) ...[
        const SizedBox(height: 12),
        Text(diag,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.65),
                fontSize: 9, fontFamily: 'monospace', height: 1.4)),
      ],
      const SizedBox(height: 36),
      GestureDetector(
        onTap: _openCamera,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: _teal.withValues(alpha: 0.55), width: 1),
            borderRadius: BorderRadius.circular(3),
            color: _teal.withValues(alpha: 0.08),
          ),
          child: const Text('REESSAYER',
              style: TextStyle(color: _teal, fontSize: 11,
                  letterSpacing: 3, fontWeight: FontWeight.w500)),
        ),
      ),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: _analyzeWithoutDetection,
        child: Text('Analyser quand meme',
            style: TextStyle(color: _teal.withValues(alpha: 0.50),
                fontSize: 11, letterSpacing: 0.3)),
      ),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: _skipFace,
        child: Text('Continuer sans visage',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.28),
                fontSize: 11, letterSpacing: 0.3)),
      ),
    ]),
  ));
  }

  // ── Voice prep — instructions + bouton ──────────────────────────

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
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 0.5),
          borderRadius: BorderRadius.circular(3),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: Column(children: [
          _voiceTip('Parlez normalement pendant $_voiceDuration secondes'),
          const SizedBox(height: 8),
          _voiceTip('Prononcez une phrase ou comptez jusqu\'à 10'),
          const SizedBox(height: 8),
          _voiceTip('Ni chuchoter, ni crier — voix naturelle'),
        ]),
      ),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        child: GestureDetector(
        onTap: _startVoice,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.12),
            border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.mic, color: _gold, size: 18),
            const SizedBox(width: 10),
            const Text('COMMENCER L\'ENREGISTREMENT',
                style: TextStyle(color: _gold, fontSize: 11,
                    letterSpacing: 2, fontWeight: FontWeight.w500)),
          ]),
        ),
      )),
    ]),
  ));

  Widget _voiceTip(String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('— ', style: TextStyle(
          color: _gold.withValues(alpha: 0.60), fontSize: 12)),
      Expanded(child: Text(text, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 12, height: 1.5, letterSpacing: 0.2))),
    ],
  );

  // ── Voice enregistrement ─────────────────────────────────────────

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

  // ── Processing ───────────────────────────────────────────────────

  Widget _buildProcessing() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(width: 36, height: 36,
          child: CircularProgressIndicator(strokeWidth: 1.2,
              valueColor: AlwaysStoppedAnimation(_teal))),
      const SizedBox(height: 20),
      Text("CALCUL DE L'AURA...",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.28),
              fontSize: 10, letterSpacing: 3)),
    ],
  ));

  // ── Résultat ─────────────────────────────────────────────────────

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
                blurRadius: 28 + _pulseCtrl.value * 16, spreadRadius: 2,
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
                      style: TextStyle(color: color, fontSize: 56,
                          fontFamily: 'Gelica', fontWeight: FontWeight.w200,
                          height: 1)),
                  const SizedBox(width: 4),
                  Text('/ 100',
                      style: TextStyle(color: color.withValues(alpha: 0.45),
                          fontSize: 14, fontFamily: 'Gelica')),
                ]),
          ]),
        ),
        const SizedBox(height: 16),
        _buildMetrics(r),
        const SizedBox(height: 30),
        GestureDetector(
          onTap: _openCamera,
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

  Widget _buildMetrics(AuraResult r) {
    final tfliteErr = biometricService.tfliteError;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(children: [
        _row('VALENCE', _signed(r.valence)),
        _sep(),
        _row('AROUSAL', r.arousal.toStringAsFixed(3)),
        _sep(),
        _row('EMOTION FACIALE',
            r.faceUsed ? _emotionFr(_faceResult.topEmotion) : 'ABSENTE'),
        _sep(),
        _row('STRESS VOCAL',
            r.voiceUsed ? _stressLabel(_voiceResult.arousal) : 'NON CAPTE'),
        if (!r.faceUsed && tfliteErr != null) ...[
          _sep(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(tfliteErr,
                style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.70),
                    fontSize: 9, fontFamily: 'monospace', height: 1.4)),
          ),
        ],
      ]),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.28),
          fontSize: 10, letterSpacing: 2)),
      Text(value, style: TextStyle(color: Colors.white.withValues(alpha: 0.70),
          fontSize: 12, fontFamily: 'monospace', letterSpacing: 0.5)),
    ]),
  );

  Widget _sep() =>
      Container(height: 0.5, color: Colors.white.withValues(alpha: 0.06));

  String _signed(double v) =>
      v >= 0 ? '+${v.toStringAsFixed(3)}' : v.toStringAsFixed(3);

  String _emotionFr(String emotion) => switch (emotion) {
    'anger'     => 'Colere',
    'contempt'  => 'Mepris',
    'disgust'   => 'Degout',
    'fear'      => 'Peur',
    'happiness' => 'Joie',
    'neutral'   => 'Neutre',
    'sadness'   => 'Tristesse',
    'surprise'  => 'Surprise',
    _           => emotion,
  };

  String _stressLabel(double arousal) {
    if (arousal < 0.25) return 'Calme';
    if (arousal < 0.50) return 'Modere';
    if (arousal < 0.75) return 'Eleve';
    return 'Intense';
  }

  // ── Erreur ───────────────────────────────────────────────────────

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(36),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline,
          color: Colors.white.withValues(alpha: 0.25), size: 44),
      const SizedBox(height: 16),
      const Text('ANALYSE IMPOSSIBLE',
          style: TextStyle(color: Colors.white60, fontSize: 13, letterSpacing: 2)),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(_error, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.18),
                fontSize: 10, fontFamily: 'monospace')),
      ],
      const SizedBox(height: 30),
      GestureDetector(
        onTap: _openCamera,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.20), width: 1),
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

// ── Scan brackets ─────────────────────────────────────────────────────────────

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
