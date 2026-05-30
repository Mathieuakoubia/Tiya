# SOZIA — Brief Technique Biométrie
[cite_start]**Pour Mathieu** — 19 mai 2026 — *Confidentiel* [cite: 190, 245]  
[cite_start]**DEADLINE : 14 juin 2026** (Sunset de l'API Hume. Tout le code Hume doit être supprimé avant cette date)[cite: 191].

---

## Objectif
[cite_start]Remplacer Hume par une stack 100% on-device, gratuite et RGPD native[cite: 193]. [cite_start]Aucune donnée biométrique ne doit quitter le téléphone[cite: 193].

---

## Dépendances (pubspec.yaml)
Trois packages essentiels à installer :
* [cite_start]`google_mlkit_face_detection: 10.9.0` [cite: 195]
* [cite_start]`tflite_flutter: 0.10.4` [cite: 196]
* [cite_start]`record: 5.0.4` [cite: 197]

---

## Les 4 Étapes d'Implémentation

### [cite_start]Étape 1 — Détection faciale MediaPipe [Semaine 1 : 19-23 mai] [cite: 202]
* [cite_start]**Package :** `google_mlkit_face_detection` [cite: 203]
* [cite_start]**Configuration FaceDetector :** `enableLandmarks=true`, `performanceMode=accurate` [cite: 204]
* [cite_start]**Action :** Détecter et cadrer le visage directement depuis le flux de la caméra[cite: 205].
* [cite_start]**Output :** Image du visage croppée en **260x260px**, prête à être injectée dans le modèle Savchenko[cite: 206].

### [cite_start]Étape 2 — Savchenko EfficientNet-B2 TFLite [Semaine 2 : 26-30 mai] [cite: 207]
* [cite_start]**Source :** Télécharger `enet_b2_8.tflite` sur le dépôt [github.com/HSE-asavchenko/face-emotion-recognition](https://github.com/HSE-asavchenko/face-emotion-recognition)[cite: 208, 240].
* [cite_start]**Installation :** Placer le fichier dans `assets/models/` et le déclarer dans le `pubspec.yaml`[cite: 209].
* [cite_start]**Input :** Image 260x260px normalisée (valeurs de [0.0 à 1.0])[cite: 210].
* [cite_start]**Output :** Extraction de 8 émotions, mappées vers les axes **Valence** et **Arousal** (selon le modèle circumplex de Russell)[cite: 211].

### [cite_start]Étape 3 — Capture voix 3s & Analyse vocale [Semaine 3 : 2-6 juin] [cite: 212]
* [cite_start]**Action :** Capturer 3 secondes de voix au format **PCM 16kHz mono** à l'aide du package `record`[cite: 212].
* [cite_start]**Options d'analyse :** Option A (`openSMILE Flutter`) ou Option B (`Wav2Vec2 TFLite`)[cite: 212].
* [cite_start]**Output :** Extraire les scores de Valence et d'Arousal vocal[cite: 212].
* [cite_start]**Attention iOS :** Gérer correctement la transition de la caméra vers le microphone[cite: 213].

### [cite_start]Étape 4 — Fusion & Génération de l'Aura [Semaine 3 : 5-6 juin] [cite: 217]
* [cite_start]**Pondération :** Visage (**60%**) + Voix (**40%**)[cite: 218].
* [cite_start]**Temps total de traitement :** Environ 9 secondes sur un iPhone 12 [cite: 231] (incluant une latence de 200-300ms pour le micro) [cite_start][cite: 216].

#### Cartographie des couleurs de l'Aura :
* [cite_start]🟢 **Sereine :** Valence $\ge 0.2$ et Arousal $\le 0.3 \rightarrow$ `#9DD9D2` [cite: 219]
* [cite_start]🔵 **Équilibrée :** Valence de $-0.1$ à $0.2 \rightarrow$ `#C4F9FF` [cite: 220]
* [cite_start]🟠 **Tendue :** Valence $< -0.1$ et Arousal $\ge 0.3 \rightarrow$ `#E89B7A` [cite: 221]
* [cite_start]🔴 **Très tendue :** Valence $< -0.3$ et Arousal $\ge 0.5 \rightarrow$ `#D97A7A` [cite: 222]

> [cite_start]⚠️ *Note : Ces seuils initiaux sont des estimations à calibrer avec Yannick Benezeth lors de la phase bêta[cite: 223, 236].*

---

## Séquence de l'Application

1. [cite_start]**Phase 1 (6 secondes) :** Activation de la caméra et traitement faciale via MediaPipe[cite: 225].
2. [cite_start]**Transition automatique.** [cite: 225]
3. [cite_start]**Phase 2 (3 secondes) :** Enregistrement via le micro (package `record`)[cite: 226].
4. [cite_start]**Calcul parallèle TFLite :** Fusion Valence/Arousal (Facial + Vocal) $\rightarrow$ Restitution de l'Aura[cite: 227, 228, 229, 230, 231].

---

## Points Critiques & Vigilances

* [cite_start]🔋 **Batterie :** Pour éviter la surchauffe et économiser l'énergie, fermer impérativement l'instance `AVCaptureSession` immédiatement après les 6 secondes de caméra[cite: 233].
* [cite_start]🔄 **Fallback (Mode Secours) :** Si le visage n'est pas détecté au bout de la première phase (ex: à cause d'un contre-jour fort), basculer automatiquement l'analyse sur la **voix seule**[cite: 234].
* [cite_start]🧪 **Test Imentiv :** Utiliser les crédits gratuits d'Imentiv API (`imentiv.ai`) pour tester en parallèle et comparer tes résultats de Valence/Arousal avec ceux de Savchenko avant notre point de lundi[cite: 235, 244].

---

## Liens & Ressources de l'équipe
* [cite_start]**Savchenko Dépôt :** [github.com/HSE-asavchenko/face-emotion-recognition](https://github.com/HSE-asavchenko/face-emotion-recognition) [cite: 240]
* [cite_start]**TFLite Flutter :** [pub.dev/packages/tflite_flutter](https://pub.dev/packages/tflite_flutter) [cite: 241]
* [cite_start]**MediaPipe SDK :** [pub.dev/packages/google_mlkit_face_detection](https://pub.dev/packages/google_mlkit_face_detection) [cite: 242]
* [cite_start]**Record Audio :** [pub.dev/packages/record](https://pub.dev/packages/record) [cite: 243]
* [cite_start]**Imentiv API :** Profil de compte sur `imentiv.ai` pour récupérer ta clé API personnelle[cite: 244].