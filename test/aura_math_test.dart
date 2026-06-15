import 'package:flutter_test/flutter_test.dart';
import 'package:tiyia_mvp/aura_math.dart';

void main() {

  // ══════════════════════════════════════════════════════════════════════
  // GROUPE 1 — auraScore
  // Formule : ((v + 1.0) / 2.0 * 0.6 + (1.0 - a) * 0.4).clamp(0,1)
  // ══════════════════════════════════════════════════════════════════════
  group('auraScore', () {
    test('état maximal serein : valence=+1.0, arousal=0.0 → 1.0', () {
      expect(auraScore(1.0, 0.0), closeTo(1.0, 1e-9));
    });

    test('état maximal tendu : valence=-1.0, arousal=1.0 → 0.0', () {
      expect(auraScore(-1.0, 1.0), closeTo(0.0, 1e-9));
    });

    test('neutre : valence=0.0, arousal=0.0 → 0.70', () {
      // ((0+1)/2)*0.6 + (1-0)*0.4 = 0.5*0.6 + 0.4 = 0.30 + 0.40 = 0.70
      expect(auraScore(0.0, 0.0), closeTo(0.70, 1e-9));
    });

    test('intermédiaire : valence=0.5, arousal=0.5 → 0.65', () {
      // ((0.5+1)/2)*0.6 + (1-0.5)*0.4 = 0.75*0.6 + 0.5*0.4 = 0.45 + 0.20 = 0.65
      expect(auraScore(0.5, 0.5), closeTo(0.65, 1e-9));
    });

    test('légèrement tendu : valence=-0.5, arousal=0.8', () {
      // ((−0.5+1)/2)*0.6 + (1−0.8)*0.4 = (0.25)*0.6 + 0.2*0.4 = 0.15 + 0.08 = 0.23
      expect(auraScore(-0.5, 0.8), closeTo(0.23, 1e-9));
    });

    test('clamp : entrées hors bornes ne produisent pas de valeur > 1 ou < 0', () {
      expect(auraScore(2.0, -1.0), closeTo(1.0, 1e-9));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // GROUPE 2 — toAuraState
  // ══════════════════════════════════════════════════════════════════════
  group('toAuraState', () {
    test('veryTense : v=-0.5, a=0.6', () {
      expect(toAuraState(-0.5, 0.6), AuraState.veryTense);
    });

    test('tense : v=-0.2, a=0.4', () {
      expect(toAuraState(-0.2, 0.4), AuraState.tense);
    });

    test('serene : v=0.5, a=0.1', () {
      expect(toAuraState(0.5, 0.1), AuraState.serene);
    });

    test('balanced : v=0.0, a=0.0 (neutre)', () {
      expect(toAuraState(0.0, 0.0), AuraState.balanced);
    });

    test('frontière veryTense : v=-0.3 (exclusif) → tense', () {
      // v < -0.3 requis pour veryTense → v=-0.3 ne passe pas
      expect(toAuraState(-0.3, 0.5), AuraState.tense);
    });

    test('frontière serene : v=0.2 ET a=0.3 → serene', () {
      expect(toAuraState(0.2, 0.3), AuraState.serene);
    });

    test('proche serein mais v insuffisant : v=0.1, a=0.2 → balanced', () {
      expect(toAuraState(0.1, 0.2), AuraState.balanced);
    });

    test('proche serein mais arousal trop haut : v=0.3, a=0.4 → balanced', () {
      expect(toAuraState(0.3, 0.4), AuraState.balanced);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // GROUPE 3 — auraHex
  // ══════════════════════════════════════════════════════════════════════
  group('auraHex', () {
    test('serene → #9DD9D2', () {
      expect(auraHex(AuraState.serene), '#9DD9D2');
    });

    test('balanced → #C4F9FF', () {
      expect(auraHex(AuraState.balanced), '#C4F9FF');
    });

    test('tense → #E89B7A', () {
      expect(auraHex(AuraState.tense), '#E89B7A');
    });

    test('veryTense → #D97A7A', () {
      expect(auraHex(AuraState.veryTense), '#D97A7A');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // GROUPE 4 — softmax
  // ══════════════════════════════════════════════════════════════════════
  group('softmax', () {
    test('la somme des probas vaut 1.0', () {
      final probs = softmax([1.0, 2.0, 3.0, 0.5, -1.0, 0.0, 1.5, 2.5]);
      final sum = probs.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 1e-9));
    });

    test('toutes les probas sont >= 0', () {
      final probs = softmax([-5.0, 0.0, 5.0, 10.0, -10.0, 3.0, -2.0, 1.0]);
      for (final p in probs) {
        expect(p, greaterThanOrEqualTo(0.0));
      }
    });

    test('un seul logit dominant → proba > 0.99', () {
      final logits = [0.0, 0.0, 0.0, 100.0, 0.0, 0.0, 0.0, 0.0];
      final probs = softmax(logits);
      expect(probs[3], greaterThan(0.99));
    });

    test('tous les logits égaux → chaque proba ≈ 0.125 (1/8)', () {
      final probs = softmax(List.filled(8, 5.0));
      for (final p in probs) {
        expect(p, closeTo(0.125, 1e-6));
      }
    });

    test('grands logits ne produisent pas NaN (stabilité numérique)', () {
      final probs = softmax([1000.0, 999.0, 998.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      for (final p in probs) {
        expect(p.isNaN, false);
        expect(p.isInfinite, false);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // GROUPE 5 — fusionBiometrique
  // ══════════════════════════════════════════════════════════════════════
  group('fusionBiometrique', () {
    test('face + voix → 60% face + 40% voix', () {
      final r = fusionBiometrique(
        faceDetected: true,  faceValence: 0.8,  faceArousal: 0.4,
        voiceDetected: true, voiceValence: 0.2, voiceArousal: 0.6,
      );
      // valence = 0.8*0.6 + 0.2*0.4 = 0.48 + 0.08 = 0.56
      // arousal = 0.4*0.6 + 0.6*0.4 = 0.24 + 0.24 = 0.48
      expect(r.valence, closeTo(0.56, 1e-9));
      expect(r.arousal, closeTo(0.48, 1e-9));
    });

    test('sans visage → voix 100%', () {
      final r = fusionBiometrique(
        faceDetected: false, faceValence: 0.0, faceArousal: 0.0,
        voiceDetected: true, voiceValence: 0.3, voiceArousal: 0.5,
      );
      expect(r.valence, closeTo(0.3, 1e-9));
      expect(r.arousal, closeTo(0.5, 1e-9));
    });

    test('sans voix → face 100%', () {
      final r = fusionBiometrique(
        faceDetected: true,  faceValence: 0.5,  faceArousal: 0.2,
        voiceDetected: false, voiceValence: 0.0, voiceArousal: 0.0,
      );
      expect(r.valence, closeTo(0.5, 1e-9));
      expect(r.arousal, closeTo(0.2, 1e-9));
    });

    test('aucune donnée → Aura neutre (0.0, 0.0)', () {
      final r = fusionBiometrique(
        faceDetected: false, faceValence: 0.0, faceArousal: 0.0,
        voiceDetected: false, voiceValence: 0.0, voiceArousal: 0.0,
      );
      expect(r.valence, closeTo(0.0, 1e-9));
      expect(r.arousal, closeTo(0.0, 1e-9));
    });

    test('fusion clampée : résultat ne sort jamais de [-1,1] x [0,1]', () {
      final r = fusionBiometrique(
        faceDetected: true,  faceValence: 1.0,  faceArousal: 1.0,
        voiceDetected: true, voiceValence: 1.0, voiceArousal: 1.0,
      );
      expect(r.valence, lessThanOrEqualTo(1.0));
      expect(r.arousal, lessThanOrEqualTo(1.0));
      expect(r.arousal, greaterThanOrEqualTo(0.0));
    });
  });
}
