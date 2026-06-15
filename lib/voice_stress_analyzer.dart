// Analyse de stress vocal — On-Device — 100% local
// Approche : features acoustiques (RMS, ZCR, pitch) → Valence/Arousal
// Source de référence : openSMILE feature set (IS09_emotion)
// RGPD : l'audio PCM est traité en mémoire et détruit immédiatement
// TODO Phase 2 : remplacer par Wav2Vec2 TFLite quand le modèle sera disponible
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceEmotionResult {
  final double valence;   // -1.0 à +1.0
  final double arousal;   // 0.0 à 1.0
  final bool captured;

  const VoiceEmotionResult({
    required this.valence,
    required this.arousal,
    required this.captured,
  });

  static const VoiceEmotionResult noVoice = VoiceEmotionResult(
    valence: 0.0, arousal: 0.0, captured: false,
  );

  /// Indique si la voix semble tendue (remplace le filtrage Hume)
  bool get isStressed => arousal > 0.55 && valence < -0.15;
}

class VoiceStressAnalyzer {
  final _recorder = AudioRecorder();

  /// Capture 3 secondes de voix en PCM 16kHz mono puis analyse.
  Future<VoiceEmotionResult> captureAndAnalyze({int durationSeconds = 3}) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return VoiceEmotionResult.noVoice;

    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/sozia_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: path,
      );
      await Future.delayed(Duration(seconds: durationSeconds));
      await _recorder.stop();

      final result = await _analyzeWavFile(path);

      // Suppression immédiate du fichier — aucun audio persistant
      final file = File(path);
      if (await file.exists()) await file.delete();

      return result;
    } catch (_) {
      // Nettoyage en cas d'erreur
      try { await File(path).delete(); } catch (_) {}
      return VoiceEmotionResult.noVoice;
    }
  }

  Future<VoiceEmotionResult> _analyzeWavFile(String path) async {
    final file  = File(path);
    if (!await file.exists()) return VoiceEmotionResult.noVoice;

    final bytes = await file.readAsBytes();
    // WAV header = 44 octets, reste = PCM int16 little-endian
    if (bytes.length < 44) return VoiceEmotionResult.noVoice;

    final pcm = bytes.buffer.asInt16List(44);
    if (pcm.isEmpty) return VoiceEmotionResult.noVoice;

    // ── Feature 1 : RMS Energy ──────────────────────────────────
    double sumSq = 0;
    for (final s in pcm) { sumSq += s * s; }
    final rms = sqrt(sumSq / pcm.length) / 32768.0; // normalisé [0,1]

    // ── Feature 2 : Zero-Crossing Rate ─────────────────────────
    int zcr = 0;
    for (int i = 1; i < pcm.length; i++) {
      if ((pcm[i] >= 0) != (pcm[i - 1] >= 0)) zcr++;
    }
    final zcrNorm = zcr / pcm.length; // [0, 1]

    // ── Feature 3 : Pitch (autocorrélation simplifiée) ─────────
    // Fenêtre 1024 samples ≈ 64ms à 16kHz
    const windowSize = 1024;
    final window = pcm.length > windowSize ? pcm.sublist(0, windowSize) : pcm;
    double pitch = _estimatePitch(window, 16000);
    final pitchNorm = (pitch.clamp(50.0, 500.0) - 50.0) / 450.0; // [0, 1]

    // ── Feature 4 : Silence ratio ──────────────────────────────
    int silentFrames = 0;
    const silenceThreshold = 0.02;
    for (final s in pcm) {
      if (s.abs() / 32768.0 < silenceThreshold) silentFrames++;
    }
    final silenceRatio = silentFrames / pcm.length;

    // ── Mapping vers Valence/Arousal ────────────────────────────
    // Modèle heuristique basé sur la littérature de phonétique affective :
    // - Arousal corrèle positivement avec énergie, ZCR, pitch élevé
    // - Valence corrèle négativement avec tension vocale (ZCR élevé + énergie haute)
    // - Silence élevé → faible Arousal, légèrement négatif Valence

    double arousal = (rms * 0.45 + zcrNorm * 0.30 + pitchNorm * 0.25)
        .clamp(0.0, 1.0);

    // Voix douce (rms faible, zcr faible) → Valence positive
    // Voix tendue (rms+zcr élevés) → Valence négative
    double tension = (rms * 0.6 + zcrNorm * 0.4).clamp(0.0, 1.0);
    double valence = ((0.5 - tension) * 2.0).clamp(-1.0, 1.0);

    // Correction silence : beaucoup de silence = pas stressé
    if (silenceRatio > 0.6) {
      arousal *= 0.5;
      valence  = (valence + 0.2).clamp(-1.0, 1.0);
    }

    return VoiceEmotionResult(
      valence: valence,
      arousal: arousal,
      captured: true,
    );
  }

  /// Estimation du pitch par autocorrélation (Yin algorithm simplifié).
  double _estimatePitch(List<int> samples, int sampleRate) {
    const minLag =  32; //  500 Hz max
    const maxLag = 320; //   50 Hz min
    if (samples.length < maxLag * 2) return 150.0;

    double minDiff = double.infinity;
    int bestLag = minLag;

    for (int lag = minLag; lag <= maxLag; lag++) {
      double diff = 0;
      for (int i = 0; i < maxLag; i++) {
        final d = samples[i] - (lag + i < samples.length ? samples[lag + i] : 0);
        diff += d * d;
      }
      if (diff < minDiff) {
        minDiff = diff;
        bestLag = lag;
      }
    }
    return sampleRate / bestLag.toDouble();
  }

  void dispose() => _recorder.dispose();
}
