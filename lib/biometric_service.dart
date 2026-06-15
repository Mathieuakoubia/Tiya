// Service biométrique SOZIA — On-Device — 100% local
// Pipeline : Caméra (6s) → Face Emotion (TFLite) → Aura
// RGPD : seul le résultat final (AuraResult) est sauvegardé dans Firestore.
//        Aucune donnée brute (image, embedding) ne quitte l'appareil.
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'face_emotion_analyzer.dart';
import 'voice_stress_analyzer.dart';

/// Couleurs de l'Aura selon les seuils V/A définis dans info biometrie.md
enum AuraState {
  serene,    // Valence ≥ 0.2 et Arousal ≤ 0.3 → #9DD9D2
  balanced,  // Valence -0.1 à 0.2             → #C4F9FF
  tense,     // Valence < -0.1 et Arousal ≥ 0.3 → #E89B7A
  veryTense, // Valence < -0.3 et Arousal ≥ 0.5 → #D97A7A
}

class AuraResult {
  final double valence;
  final double arousal;
  final AuraState state;
  final String hexColor;
  final bool faceUsed;
  final bool voiceUsed;

  const AuraResult({
    required this.valence,
    required this.arousal,
    required this.state,
    required this.hexColor,
    required this.faceUsed,
    required this.voiceUsed,
  });

  /// Valeur numérique simple pour l'App State (0.0 = très tendue, 1.0 = sereine)
  double get auraScore => ((valence + 1.0) / 2.0 * 0.6 + (1.0 - arousal) * 0.4).clamp(0.0, 1.0);
}

class BiometricService {
  final FaceEmotionAnalyzer _faceAnalyzer = FaceEmotionAnalyzer();
  final VoiceStressAnalyzer _voiceAnalyzer = VoiceStressAnalyzer();

  CameraController? _camera;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _faceAnalyzer.init();
    _initialized = true;
  }

  /// Pipeline complet : 6s caméra → AuraResult.
  /// [onProgress] reçoit les étapes : 'camera', 'processing', 'done'
  Future<AuraResult> runFullAnalysis({
    void Function(String step)? onProgress,
  }) async {
    await init();

    // ── Phase 1 : Caméra (6 secondes) ──────────────────────────
    onProgress?.call('camera');
    FaceEmotionResult faceResult = FaceEmotionResult.noFace;
    CameraController? cam;

    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final front = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        cam = CameraController(front, ResolutionPreset.medium, enableAudio: false);
        await cam.initialize();

        for (int i = 0; i < 6; i++) {
          try {
            final frame = await cam.takePicture();
            final inputImage = InputImage.fromFilePath(frame.path);
            final result = await _faceAnalyzer.analyze(inputImage);
            if (result.faceDetected) {
              faceResult = result;
              break;
            }
          } catch (_) {}
          await Future.delayed(const Duration(seconds: 1));
        }

        await cam.dispose();
        cam = null;
      }
    } catch (_) {
      cam?.dispose();
      cam = null;
    }

    // ── Phase 2 : Voix (3 secondes) ────────────────────────────
    onProgress?.call('voice');
    VoiceEmotionResult voiceResult = VoiceEmotionResult.noVoice;
    try {
      voiceResult = await _voiceAnalyzer.captureAndAnalyze();
    } catch (_) {}

    // ── Phase 3 : Fusion et génération de l'Aura ───────────────
    onProgress?.call('processing');

    final bool faceUsed  = faceResult.faceDetected;
    final bool voiceUsed = voiceResult.captured;

    double valence, arousal;
    if (!faceUsed && !voiceUsed) {
      valence = 0.0; arousal = 0.0;
    } else if (!faceUsed) {
      valence = voiceResult.valence; arousal = voiceResult.arousal;
    } else if (!voiceUsed) {
      valence = faceResult.valence; arousal = faceResult.arousal;
    } else {
      valence = (0.60 * faceResult.valence + 0.40 * voiceResult.valence).clamp(-1.0, 1.0);
      arousal = (0.60 * faceResult.arousal + 0.40 * voiceResult.arousal).clamp( 0.0, 1.0);
    }

    final state    = _toAuraState(valence.clamp(-1.0, 1.0), arousal.clamp(0.0, 1.0));
    final hexColor = _auraHex(state);
    final result   = AuraResult(
      valence: valence.clamp(-1.0, 1.0),
      arousal: arousal.clamp( 0.0, 1.0),
      state: state, hexColor: hexColor,
      faceUsed: faceUsed, voiceUsed: voiceUsed,
    );

    await _persistAuraResult(result);

    onProgress?.call('done');
    return result;
  }

  Future<void> _persistAuraResult(AuraResult result) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({
          'auraState'  : result.hexColor,
          'auraScore'  : result.auraScore,
          'lastAuraAt' : FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// Capture et analyse la voix (public pour BiometricTestScreen).
  Future<VoiceEmotionResult> analyzeVoice({int durationSeconds = 3}) =>
      _voiceAnalyzer.captureAndAnalyze(durationSeconds: durationSeconds);

  /// Fusionne le résultat facial, sauvegarde en Firestore et retourne l'AuraResult.
  Future<AuraResult> fuseAndSave({
    required FaceEmotionResult face,
    required VoiceEmotionResult voice,
  }) async {
    final faceUsed  = face.faceDetected;
    final voiceUsed = voice.captured;

    double valence, arousal;
    if (!faceUsed && !voiceUsed) {
      valence = 0.0; arousal = 0.0;
    } else if (!faceUsed) {
      valence = voice.valence; arousal = voice.arousal;
    } else if (!voiceUsed) {
      valence = face.valence; arousal = face.arousal;
    } else {
      valence = (0.60 * face.valence + 0.40 * voice.valence).clamp(-1.0, 1.0);
      arousal = (0.60 * face.arousal + 0.40 * voice.arousal).clamp( 0.0, 1.0);
    }

    final state  = _toAuraState(valence.clamp(-1.0, 1.0), arousal.clamp(0.0, 1.0));
    final hex    = _auraHex(state);
    final result = AuraResult(
      valence: valence.clamp(-1.0, 1.0),
      arousal: arousal.clamp( 0.0, 1.0),
      state: state, hexColor: hex,
      faceUsed: faceUsed, voiceUsed: voiceUsed,
    );
    await _persistAuraResult(result);
    return result;
  }

  void dispose() {
    _faceAnalyzer.close();
    _voiceAnalyzer.dispose();
    _camera?.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────

  static AuraState _toAuraState(double v, double a) {
    if (v < -0.3 && a >= 0.5) return AuraState.veryTense;
    if (v < -0.1 && a >= 0.3) return AuraState.tense;
    if (v >= 0.2 && a <= 0.3) return AuraState.serene;
    return AuraState.balanced;
  }

  static String _auraHex(AuraState state) => switch (state) {
    AuraState.serene    => '#9DD9D2',
    AuraState.balanced  => '#C4F9FF',
    AuraState.tense     => '#E89B7A',
    AuraState.veryTense => '#D97A7A',
  };

  static Color auraColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }
}

// Instance singleton partagée dans toute l'app
final biometricService = BiometricService();
