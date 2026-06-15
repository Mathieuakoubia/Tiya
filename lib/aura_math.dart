// Fonctions mathématiques pures de l'Aura — sans dépendances Flutter/Firebase.
// Extraites pour être testables unitairement (flutter test).
import 'dart:math';

enum AuraState { serene, balanced, tense, veryTense }

/// Détermine l'état Aura selon les seuils du modèle Russell Circumplex.
AuraState toAuraState(double valence, double arousal) {
  if (valence < -0.3 && arousal >= 0.5) return AuraState.veryTense;
  if (valence < -0.1 && arousal >= 0.3) return AuraState.tense;
  if (valence >= 0.2 && arousal <= 0.3) return AuraState.serene;
  return AuraState.balanced;
}

/// Couleur hex associée à chaque état Aura.
String auraHex(AuraState state) => switch (state) {
  AuraState.serene    => '#9DD9D2',
  AuraState.balanced  => '#C4F9FF',
  AuraState.tense     => '#E89B7A',
  AuraState.veryTense => '#D97A7A',
};

/// Score normalisé [0.0 – 1.0] : 0 = très tendue, 1 = sereine.
/// Formule : 60% valence normalisée + 40% calm (inverse de l'arousal).
double auraScore(double valence, double arousal) =>
    ((valence + 1.0) / 2.0 * 0.6 + (1.0 - arousal) * 0.4).clamp(0.0, 1.0);

/// Softmax numériquement stable (soustraction du max avant exp).
List<double> softmax(List<double> logits) {
  final maxVal = logits.reduce(max);
  final exps   = logits.map((v) => exp(v - maxVal)).toList();
  final sumExp = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / sumExp).toList();
}

/// Fusion biométrique face (60%) + voix (40%) — modèle Russell Circumplex.
({double valence, double arousal}) fusionBiometrique({
  required bool faceDetected,
  required double faceValence,
  required double faceArousal,
  required bool voiceDetected,
  required double voiceValence,
  required double voiceArousal,
}) {
  if (!faceDetected && !voiceDetected) return (valence: 0.0, arousal: 0.0);
  if (!faceDetected) return (valence: voiceValence, arousal: voiceArousal);
  if (!voiceDetected) return (valence: faceValence, arousal: faceArousal);
  const fw = 0.60;
  const vw = 0.40;
  return (
    valence: (fw * faceValence + vw * voiceValence).clamp(-1.0, 1.0),
    arousal: (fw * faceArousal + vw * voiceArousal).clamp( 0.0, 1.0),
  );
}
