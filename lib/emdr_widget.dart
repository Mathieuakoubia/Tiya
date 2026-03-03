import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

class EyeMovementEMDR extends StatefulWidget {
  final int baseSpeedDuration;
  final Color ballColor;
  final double? width;
  final double? height;

  const EyeMovementEMDR({
    Key? key,
    this.baseSpeedDuration = 2000, // Rythme calme par defaut
    this.ballColor = Colors.cyanAccent,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  _EyeMovementEMDRState createState() => _EyeMovementEMDRState();
}

class _EyeMovementEMDRState extends State<EyeMovementEMDR>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
          enableContours: true, enableClassification: true));

  bool _isDetecting = false;

  // --- GESTION DU TEMPS ET ETATS ---
  late AnimationController _animController;
  late Animation<Alignment> _animation;

  Timer? _mainTimer;
  final int _totalSeconds = 90; // Duree de 1 minute 30
  late int _remainingSeconds;

  // Etats de l'exercice
  bool _isExerciseStarted = false;
  bool _isPaused = false;
  bool _isFinished = false;

  // Compte a rebours de depart
  int _startCountdown = 3;
  bool _isCountingDown = false;

  // Logique de progression
  String _statusMessage = "Initialisation camera...";
  int _successCombo = 0;
  int _currentTrailLength = 3;
  // On garde la duree constante maintenant
  late int _fixedDuration;
  List<Alignment> _trailPositions = [];

  _EyeMovementEMDRState() : _remainingSeconds = 90;

  @override
  void initState() {
    super.initState();
    _fixedDuration = widget.baseSpeedDuration;
    _remainingSeconds = _totalSeconds;
    _setupAnimation();
    _initializeCamera();
  }

  void _setupAnimation() {
    _animController = AnimationController(
      duration: Duration(milliseconds: _fixedDuration),
      vsync: this,
    );

    _animation = AlignmentTween(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    _animController.addListener(() {
      setState(() {
        _trailPositions.insert(0, _animation.value);
        if (_trailPositions.length > _currentTrailLength) {
          _trailPositions.removeLast();
        }
      });
    });
  }

  Future<void> _initializeCamera() async {
    var status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) setState(() => _statusMessage = "Permission Refusee");
      return;
    }

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    _cameraController!.startImageStream(_processCameraImage);
    if (mounted) {
      setState(() => _statusMessage = "Placez votre visage face camera");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _isFinished) return;
    _isDetecting = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;

        double leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
        double rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
        bool eyesOpen = (leftEyeOpen > 0.1 && rightEyeOpen > 0.1);

        if (eyesOpen) {
          if (!_isCountingDown && !_isExerciseStarted) {
            _startStartupCountdown();
          } else if (_isExerciseStarted) {
            _resumeExercise();
            _increaseIntensity(); // Juste la trainee, pas la vitesse
          }
        } else {
          if (_isExerciseStarted) _pauseExercise("Ouvrez les yeux");
        }
      } else {
        if (_isExerciseStarted) _pauseExercise("Visage non detecte");
      }
    } catch (e) {
      debugPrint("Erreur: $e");
    } finally {
      _isDetecting = false;
    }
  }

  void _startStartupCountdown() {
    _isCountingDown = true;
    setState(() => _statusMessage = "Preparation...");

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_startCountdown > 1) {
          _startCountdown--;
        } else {
          _startCountdown = 0;
          timer.cancel();
          _isCountingDown = false;
          _isExerciseStarted = true;
          _startMainTimer();
          _animController.repeat(reverse: true);
        }
      });
    });
  }

  void _startMainTimer() {
    _mainTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (!_isPaused && !_isFinished) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _finishExercise();
          }
        });
      }
    });
  }

  void _resumeExercise() {
    if (_isPaused) {
      setState(() {
        _isPaused = false;
        _statusMessage = "Suivez la bille";
      });
      if (!_animController.isAnimating) {
        _animController.repeat(reverse: true);
      }
    }
  }

  void _pauseExercise(String reason) {
    if (!_isPaused) {
      setState(() {
        _isPaused = true;
        _statusMessage = "Pause : $reason";
      });
      _animController.stop();
      if (_successCombo > 0) _successCombo -= 2;
    }
  }

  void _finishExercise() {
    _mainTimer?.cancel();
    _animController.stop();
    setState(() {
      _isFinished = true;
      _statusMessage = "Termine";
    });
  }

  void _increaseIntensity() {
    _successCombo++;
    // On augmente UNIQUEMENT la trainee visuelle pour l'effet apaisant
    if (_successCombo % 10 == 0 && _currentTrailLength < 25) {
      setState(() => _currentTrailLength++);
    }
    // L'acceleration de vitesse a ete supprimee pour rester relaxant
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _animController.dispose();
    _mainTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 400,
      color: Colors.black,
      child: Stack(
        children: [
          // INFO BARRE
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _isPaused
                          ? Colors.red.withValues(alpha: 0.3)
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _isPaused ? Colors.red : Colors.transparent)),
                  child: Row(
                    children: [
                      Icon(Icons.timer,
                          color: _isPaused ? Colors.red : Colors.white,
                          size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (_isPaused)
                  const Text("PAUSE",
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2))
              ],
            ),
          ),

          // ECRAN DE FIN
          if (_isFinished)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 80),
                  const SizedBox(height: 20),
                  const Text("Exercice Termine",
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                  const SizedBox(height: 10),
                  const Text("Scan post-routine a venir...",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Retour au menu"))
                ],
              ),
            )
          else
            Stack(
              children: [
                if (_isCountingDown && _startCountdown > 0)
                  Center(
                    child: Text(
                      "$_startCountdown",
                      style: TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                if (_isExerciseStarted || _isPaused) ...[
                  ..._trailPositions.asMap().entries.map((entry) {
                    int index = entry.key;
                    Alignment pos = entry.value;
                    double opacity = 1.0 - (index / _currentTrailLength);
                    if (opacity < 0) opacity = 0;

                    return Align(
                      alignment: pos,
                      child: Container(
                        width: 30.0 - (index * 0.8),
                        height: 30.0 - (index * 0.8),
                        decoration: BoxDecoration(
                          color:
                              widget.ballColor.withValues(alpha: opacity * 0.4),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.ballColor
                                  .withValues(alpha: opacity * 0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Align(
                        alignment: _animation.value,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: widget.ballColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      widget.ballColor.withValues(alpha: 0.9),
                                  blurRadius: 25,
                                  spreadRadius: 6)
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),

          if (!_isFinished)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      var rotationCompensation =
          _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }
}
