// Service biométrique SOZIA — On-Device — 100% local
// Pipeline : Caméra (6s) → Face Emotion (TFLite) → Voix (3s) → Fusion → Aura
// RGPD : seul le résultat final (AuraResult) est sauvegardé dans Firestore.
//        Aucune donnée brute (image, audio, embedding) ne quitte l'appareil.
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

  /// Pipeline complet : 6s caméra + 3s voix → AuraResult.
  /// [onProgress] reçoit les étapes : 'camera', 'voice', 'processing', 'done'
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

        // Capture une frame par seconde pendant 6s, garde le meilleur résultat
        for (int i = 0; i < 6; i++) {
          try {
            final frame = await cam.takePicture();
            final inputImage = InputImage.fromFilePath(frame.path);
            final result = await _faceAnalyzer.analyze(inputImage);
            if (result.faceDetected) {
              faceResult = result;
              break; // On a un bon résultat, pas besoin de continuer
            }
          } catch (_) {}
          await Future.delayed(const Duration(seconds: 1));
        }

        // Fermeture IMMÉDIATE de la caméra (économie batterie)
        await cam.dispose();
        cam = null;
      }
    } catch (_) {
      cam?.dispose();
      cam = null;
    }

    // ── Fallback : si pas de visage → voix seule avec poids 100% ───
    final faceWeight = faceResult.faceDetected ? 0.60 : 0.0;
    final voiceWeight = faceResult.faceDetected ? 0.40 : 1.0;

    // ── Phase 2 : Voix (3 secondes) ────────────────────────────
    onProgress?.call('voice');
    VoiceEmotionResult voiceResult = VoiceEmotionResult.noVoice;
    try {
      voiceResult = await _voiceAnalyzer.captureAndAnalyze();
    } catch (_) {}

    // ── Phase 3 : Fusion et génération de l'Aura ───────────────
    onProgress?.call('processing');

    double valence, arousal;
    bool faceUsed = faceResult.faceDetected;
    bool voiceUsed = voiceResult.captured;

    if (!faceUsed && !voiceUsed) {
      // Aucune donnée → Aura neutre
      valence = 0.0; arousal = 0.0;
    } else if (!faceUsed) {
      valence = voiceResult.valence; arousal = voiceResult.arousal;
    } else if (!voiceUsed) {
      valence = faceResult.valence; arousal = faceResult.arousal;
    } else {
      // Fusion pondérée : 60% visage + 40% voix
      valence = faceWeight * faceResult.valence + voiceWeight * voiceResult.valence;
      arousal = faceWeight * faceResult.arousal + voiceWeight * voiceResult.arousal;
    }

    valence = valence.clamp(-1.0, 1.0);
    arousal = arousal.clamp( 0.0, 1.0);

    final state    = _toAuraState(valence, arousal);
    final hexColor = _auraHex(state);
    final result   = AuraResult(
      valence: valence, arousal: arousal,
      state: state, hexColor: hexColor,
      faceUsed: faceUsed, voiceUsed: voiceUsed,
    );

    // ── Sauvegarde Firestore : résultat uniquement (RGPD) ───────
    await _persistAuraResult(result);

    onProgress?.call('done');
    return result;
  }

  /// Sauvegarde UNIQUEMENT le score Valence/Arousal et la couleur Aura.
  /// Aucune donnée brute (image, audio) n'est transmise.
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
