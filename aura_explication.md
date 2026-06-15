# Comment Tiyia calcule ton Aura

## Ce que l'app mesure

L'analyse repose sur **deux axes psychologiques** issus de la recherche en neurosciences affectives (modèle Russell Circumplex) :

### Valence — de -1.0 a +1.0
> "Comment tu te sens ?"

| Valeur | Signification |
|--------|--------------|
| -1.0   | Tres negatif (colere, peur, tristesse) |
|  0.0   | Neutre |
| +1.0   | Tres positif (joie, contentement) |

### Arousal — de 0.0 a 1.0
> "A quel point tu es activee ?"

| Valeur | Signification |
|--------|--------------|
|  0.0   | Tres calme, detendue |
|  0.5   | Moderement alertee |
|  1.0   | Tres tendue, agitee, excitee |

---

## Pipeline d'analyse (9 secondes)

### Etape 1 : Ton visage (6 secondes)

La camera frontale prend une photo par seconde.
Un modele d'IA local (**EfficientNet-B2**, 5 Mo, 100% sur l'appareil) reconnaît 8 emotions :

```
Colere / Mepris / Degout / Peur / Joie / Neutre / Tristesse / Surprise
```

Chaque emotion correspond a des valeurs Valence + Arousal connues.
Le modele calcule une probabilite pour chaque emotion, puis fait une moyenne ponderee.

Exemple :
- Joie a 70% + Surprise a 30%
- Valence = 0.70 x (+0.80) + 0.30 x (+0.20) = **+0.62**
- Arousal = 0.70 x (0.50) + 0.30 x (0.70) = **0.56**

### Etape 2 : Ta voix (3 secondes)

L'app enregistre 3 secondes de son (efface immediatement apres analyse).
Elle calcule 4 caracteristiques acoustiques :

| Feature | Ce que ca mesure | Poids |
|---------|-----------------|-------|
| RMS (energie) | Intensite de la voix | 45% de l'Arousal |
| ZCR (zero-crossing) | Tension vocale (voix aigue vs grave) | 30% |
| Pitch | Hauteur de la voix | 25% |
| Silence ratio | Proportion de silence | Correction finale |

```
Arousal vocal = Energie x 45% + Tension x 30% + Hauteur x 25%
Valence vocale = inverse de la tension (voix douce = +, voix tendue = -)
```

### Etape 3 : Fusion

Si les deux signaux sont disponibles :
```
Valence finale = Visage x 60% + Voix x 40%
Arousal final  = Visage x 60% + Voix x 40%
```

Si un seul signal : il prend 100% du poids.

---

## Les 4 etats Aura

| Couleur | Etat | Condition |
|---------|------|-----------|
| `#9DD9D2` (turquoise clair) | Sereine | Valence >= +0.2 ET Arousal <= 0.3 |
| `#C4F9FF` (bleu pale) | Equilibree | Valence entre -0.1 et +0.2 |
| `#E89B7A` (orange doux) | Tendue | Valence < -0.1 ET Arousal >= 0.3 |
| `#D97A7A` (rouge doux) | Tres tendue | Valence < -0.3 ET Arousal >= 0.5 |

---

## Le Score Aura (0.0 a 1.0)

Un seul chiffre qui resume l'etat :

```
Score = ((Valence + 1) / 2) x 0.6   +   (1 - Arousal) x 0.4
           ^                                  ^
    60% : est-ce positif ?           40% : est-ce calme ?
```

| Score | Etat |
|-------|------|
| 0.0   | Tres tendue (colere intense) |
| 0.5   | Neutre / equilibree |
| 1.0   | Parfaitement sereine |

---

## Confidentialite (RGPD)

- Aucune image ni audio n'est sauvegarde ou transmis
- Seul le resultat final (`hexColor`, `auraScore`, `lastAuraAt`) est ecrit dans Firestore
- Tout le traitement se passe sur l'appareil (modele TFLite embarque)
