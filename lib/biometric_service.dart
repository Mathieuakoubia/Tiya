// Service biometrique SOZIA -- On-Device -- 100% local
// Pipeline : imagePath (fourni par l'ecran) -> Face Emotion (TFLite) -> Voix -> Aura
// RGPD : seul le resultat final (AuraResult) est sauvegarde dans Firestore.
//        Aucune donnee brute (image, embedding) ne quitte l'appareil.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'face_emotion_analyzer.dart';
import 'voice_stress_analyzer.dart';

enum AuraState {
  serene,    // Valence >= 0.2 et Arousal <= 0.3 -> #9DD9D2
  balanced,  // Valence -0.1 a 0.2               -> #C4F9FF
  tense,     // Valence < -0.1 et Arousal >= 0.3  -> #E89B7A
  veryTense, // Valence < -0.3 et Arousal >= 0.5  -> #D97A7A
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

  // 0.0 = tres tendue, 1.0 = sereine
  double get auraScore =>
      ((valence + 1.0) / 2.0 * 0.6 + (1.0 - arousal) * 0.4).clamp(0.0, 1.0);
}

class BiometricService {
  final FaceEmotionAnalyzer _faceAnalyzer = FaceEmotionAnalyzer();
  final VoiceStressAnalyzer _voiceAnalyzer = VoiceStressAnalyzer();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _faceAnalyzer.init();
    _initialized = true;
  }

  /// Pipeline complet a partir d'une photo deja capturee par l'ecran.
  /// [imagePath] : chemin du fichier temporaire fourni par CameraController.takePicture().
  /// [onProgress] : etapes 'face', 'voice', 'processing', 'done'.
  /// RGPD : le fichier [imagePath] est supprime apres inference.
  Future<AuraResult> runFullAnalysis({
    required String imagePath,
    void Function(String step)? onProgress,
  }) async {
    await init();

    if (!isTfliteLoaded) {
      throw Exception('Le modele TensorFlow Lite n\'est pas encore alloue en RAM.');
    }

    // -- Phase 1 : Analyse faciale ------------------------------------------
    onProgress?.call('face');
    FaceEmotionResult faceResult = FaceEmotionResult.noFace;
    try {
      faceResult = await _faceAnalyzer.analyze(InputImage.fromFilePath(imagePath));
    } catch (_) {}
    // RGPD : suppression immediate du fichier temporaire apres inference.
    File(imagePath).delete().ignore();

    // -- Phase 2 : Analyse vocale -------------------------------------------
    onProgress?.call('voice');
    VoiceEmotionResult voiceResult = VoiceEmotionResult.noVoice;
    try {
      voiceResult = await _voiceAnalyzer.captureAndAnalyze();
    } catch (_) {}

    // -- Phase 3 : Fusion et generation de l'Aura --------------------------
    onProgress?.call('processing');
    final result = _fuse(faceResult, voiceResult);
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
          'auraState' : result.hexColor,
          'auraScore' : result.auraScore,
          'lastAuraAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  AuraResult _fuse(FaceEmotionResult face, VoiceEmotionResult voice) {
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
      valence = (0.60 * face.valence  + 0.40 * voice.valence).clamp(-1.0, 1.0);
      arousal = (0.60 * face.arousal  + 0.40 * voice.arousal).clamp( 0.0, 1.0);
    }

    final v     = valence.clamp(-1.0, 1.0);
    final a     = arousal.clamp( 0.0, 1.0);
    final state = _toAuraState(v, a);
    return AuraResult(
      valence: v, arousal: a,
      state: state, hexColor: _auraHex(state),
      faceUsed: faceUsed, voiceUsed: voiceUsed,
    );
  }

  /// Erreur de chargement/inference TFLite (null si tout va bien).
  String? get tfliteError => _faceAnalyzer.lastError;

  /// Vrai si le modele EfficientNet est charge.
  bool get isTfliteLoaded => _faceAnalyzer.isModelLoaded;

  /// Detection de presence de visage uniquement.
  Future<bool> detectFace(InputImage inputImage) async {
    await init();
    return _faceAnalyzer.detectFaceOnly(inputImage);
  }

  /// Analyse le visage depuis un chemin de fichier (photo deja capturee).
  Future<FaceEmotionResult> analyzeFaceFromPath(String imagePath) async {
    await init();
    return _faceAnalyzer.analyze(InputImage.fromFilePath(imagePath));
  }

  /// Analyse sans detection ML Kit -- crop central -> EfficientNet directement.
  /// Fallback quand le detecteur rate (faible contraste, biais peau foncee).
  Future<FaceEmotionResult> analyzeFaceNoDetect(String imagePath) async {
    await init();
    return _faceAnalyzer.analyzeFullImage(imagePath);
  }

  /// Capture et analyse la voix.
  Future<VoiceEmotionResult> analyzeVoice({int durationSeconds = 3}) =>
      _voiceAnalyzer.captureAndAnalyze(durationSeconds: durationSeconds);

  /// Fusionne les resultats, sauvegarde en Firestore et retourne l'AuraResult.
  Future<AuraResult> fuseAndSave({
    required FaceEmotionResult face,
    required VoiceEmotionResult voice,
  }) async {
    final result = _fuse(face, voice);
    await _persistAuraResult(result);
    return result;
  }

  void dispose() {
    _faceAnalyzer.close();
    _voiceAnalyzer.dispose();
  }

  // -- Helpers ---------------------------------------------------------------

  static AuraState _toAuraState(double v, double a) {
    if (v < -0.3 && a >= 0.5) return AuraState.veryTense;
    if (v < -0.1 && a >= 0.3) return AuraState.tense;
    if (v >= 0.2  && a <= 0.3) return AuraState.serene;
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

// Instance singleton partagee dans toute l'app
final biometricService = BiometricService();
