import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/routine_intro_screen.dart';

const _darkBg = Color(0xFF5B242F);
const _accentPurple = Color(0xFFF5F3F1);

enum _Phase { intro, loading, countdown, exercise, complete }

class EyeMovementEMDR extends StatefulWidget {
  final int baseSpeedDuration;
  final VoidCallback? onComplete;

  const EyeMovementEMDR({
    super.key,
    this.baseSpeedDuration = 2000,
    this.onComplete,
  });

  @override
  State<EyeMovementEMDR> createState() => _EyeMovementEMDRState();
}

class _EyeMovementEMDRState extends State<EyeMovementEMDR>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options:
        FaceDetectorOptions(enableContours: true, enableClassification: true),
  );
  bool _isDetecting = false;

  late AnimationController _animController;
  late Animation<Alignment> _ballAnim;
  final List<Alignment> _trail = [];
  int _trailLength = 25;

  _Phase _phase = _Phase.intro;
  int _countdownValue = 3;
  static const int _totalSec = 90;
  int _remainingSec = _totalSec;
  Timer? _mainTimer;

  bool _isPaused = false;
  String _statusMessage = "Suivez la bille des yeux";
  int _successCombo = 0;

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _setupBallAnimation();
  }

  void _setupBallAnimation() {
    _animController = AnimationController(
      duration: Duration(milliseconds: widget.baseSpeedDuration),
      vsync: this,
    );
    _ballAnim = AlignmentTween(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine));

    _animController.addListener(() {
      setState(() {
        _trail.insert(0, _ballAnim.value);
        if (_trail.length > _trailLength) _trail.removeLast();
      });
    });
  }

  Future<void> _startLoading() async {
    setState(() => _phase = _Phase.loading);
    await _initCamera();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.countdown;
      _countdownValue = 3;
    });
    _runCountdown();
  }

  void _runCountdown() {
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else {
          t.cancel();
          _phase = _Phase.exercise;
          _statusMessage = "Suivez la bille des yeux";
          _animController.repeat(reverse: true);
          _startMainTimer();
        }
      });
    });
  }

  void _startMainTimer() {
    _mainTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (!_isPaused && _phase == _Phase.exercise) {
        if (_remainingSec > 0) {
          setState(() => _remainingSec--);
        } else {
          t.cancel();
          _finishExercise(); // hors du setState pour éviter l'imbrication
        }
      }
    });
  }

  void _finishExercise() {
    if (!mounted) return;
    _mainTimer?.cancel();
    _animController.stop();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied || !mounted) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty || !mounted) return;
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      front,
      ResolutionPreset.low,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (!mounted) return;
    _cameraController!.startImageStream(_processCameraImage);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _phase != _Phase.exercise) return;
    _isDetecting = true;
    try {
      final input = _inputImageFromCameraImage(image);
      if (input == null) return;
      final faces = await _faceDetector.processImage(input);
      if (!mounted) return;
      if (faces.isNotEmpty) {
        final face = faces.first;
        final leftOpen = face.leftEyeOpenProbability ?? 1.0;
        final rightOpen = face.rightEyeOpenProbability ?? 1.0;
        if (leftOpen > 0.1 && rightOpen > 0.1) {
          _resumeExercise();
          _increaseTrail();
        } else {
          _pauseExercise("Ouvrez les yeux");
        }
      } else {
        _pauseExercise("Visage non détecté");
      }
    } catch (e) {
      debugPrint("Erreur ML: $e");
    } finally {
      _isDetecting = false;
    }
  }

  void _resumeExercise() {
    if (!_isPaused) return;
    setState(() {
      _isPaused = false;
      _statusMessage = "Suivez la bille des yeux";
    });
    if (!_animController.isAnimating) {
      _animController.repeat(reverse: true);
    }
  }

  void _pauseExercise(String reason) {
    if (_isPaused) return;
    setState(() {
      _isPaused = true;
      _statusMessage = reason;
    });
    _animController.stop();
    if (_successCombo > 0) _successCombo -= 2;
  }

  void _increaseTrail() {
    _successCombo++;
    if (_successCombo % 10 == 0 && _trailLength < 50 && mounted) {
      setState(() => _trailLength++);
    }
  }

  String _formatTime(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    // Stopper le stream avant de disposer pour éviter les callbacks orphelins
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _cameraController?.dispose();
    _faceDetector.close();
    _animController.dispose();
    _mainTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _Phase.exercise
          ? const Color(0xFF5B242F)
          : _phase == _Phase.intro
              ? Colors.transparent
              : _darkBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.intro:
        return _buildIntro();
      case _Phase.loading:
        return _buildLoading();
      case _Phase.countdown:
        return _buildCountdown();
      case _Phase.exercise:
        return _buildExercise();
      case _Phase.complete:
        return _buildComplete();
    }
  }

  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Saccadic\nReset',
      badgeLabel: '1 min 30  •  EMDR',
      scienceText:
          "Inspiré de l'EMDR (Eye Movement Desensitization and Reprocessing), cette méthode utilise des mouvements oculaires rythmés pour désactiver la réponse au stress et libérer les pensées bloquées.",
      steps: const [
        'Placez votre visage face à la caméra',
        'Suivez la bille lumineuse des yeux',
        "Si vous détournez le regard, la bille s'arrête",
      ],
      onStart: _startLoading,
      accentColor: _accentPurple,
    );
  }

  Widget _buildLoading() {
    return Container(
      key: const ValueKey('loading'),
      color: const Color(0xFF5B242F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Initialisation caméra...",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    return Container(
      key: const ValueKey('countdown'),
      color: const Color(0xFF5B242F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Préparez-vous",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 18,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "$_countdownValue",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 100,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercise() {
    return Stack(
      key: const ValueKey('exercise'),
      children: [
        // Timer + status bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isPaused
                          ? const Color(0xFFFF5B1F).withValues(alpha: 0.12)
                          : const Color(0xFFBCAE3A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isPaused
                            ? const Color(0xFFFF5B1F).withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer,
                            color: _isPaused
                                ? const Color(0xFFFF5B1F)
                                : const Color(0xFFBCAE3A),
                            size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(_remainingSec),
                          style: TextStyle(
                            color: _isPaused
                                ? const Color(0xFFFF5B1F)
                                : const Color(0xFFBCAE3A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isPaused)
                    const Text(
                      "PAUSE",
                      style: TextStyle(
                        color: Color(0xFFFF5B1F),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Bille principale — dégradé radial orange → rose
        AnimatedBuilder(
          animation: _ballAnim,
          builder: (context, child) {
            return Align(
              alignment: _ballAnim.value,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFF5B1F), Color(0xFFFF96B9)],
                    stops: [0.0, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5B1F).withValues(alpha: 0.55),
                      blurRadius: 22,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Message de statut
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 44),
              child: Text(
                _statusMessage,
                style: const TextStyle(
                  fontFamily: 'Gelica',
                  color: Color(0xFF232323),
                  fontSize: 16,
                  fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplete() {
    return Stack(
      key: const ValueKey('complete'),
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
        Container(color: Colors.white.withValues(alpha: 0.10)),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF5B242F),
                    ),
                    child: const Icon(Icons.favorite,
                        color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "'Félicitez-vous d'avoir\npris ce temps pour vous'",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Gelica',
                      color: Color(0xFF232323),
                      fontSize: 22,
                      fontWeight: FontWeight.w200,
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "1 min 30 de Reset Saccadique complété.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Gelica',
                      color: Color(0xFF232323),
                      fontSize: 15,
                      fontWeight: FontWeight.w200,
                      fontStyle: FontStyle.italic,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 52),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B242F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text("Continuer",
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      var comp = _orientations[_cameraController!.value.deviceOrientation];
      if (comp == null) return null;
      comp = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + comp) % 360
          : (sensorOrientation - comp + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    final buf = WriteBuffer();
    for (final p in image.planes) {
      buf.putUint8List(p.bytes);
    }
    return InputImage.fromBytes(
      bytes: buf.done().buffer.asUint8List(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }
}
