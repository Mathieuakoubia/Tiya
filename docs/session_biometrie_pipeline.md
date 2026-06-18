# Session Biometrie Pipeline — Etat au 16 juin 2026

## Problemes resolus

### 1. Camera stream supprime
- `startImageStream` / `CameraImage` / `_inputImageFromCameraImage()` supprimes de `biometric_test_screen.dart`
- Erreurs de compilation residuelles corrigees : `_lastFrame`, `_orientations`, `DeviceOrientation`, `WriteBuffer`
- La camera utilise desormais uniquement `takePicture()` (pas de stream natif)

### 2. TFLite echec silencieux (emotion toujours "ABSENTE")
- **Cause** : Buffer de sortie `List.filled(8, 0)` (int) alors que TFLite 2.14 ecrit du float32
- **Fix** : Buffer de sortie remplace par `[Float32List(8)]`
- **Fix** : tflite_flutter mis a jour 0.10.4 → 0.12.1 + `flutter clean && flutter pub get`
- **Fix** : Buffer d'entree `Uint8List [0,255]` remplace par `Float32List [0.0, 1.0]`
  (TFLite 2.14 quantifie automatiquement en uint8 a l'entree, dequantifie en float32 a la sortie)

### 3. Detection galerie ne trouve rien
- **Cause** : `analyzeFullImage()` utilisait un crop central sans ML Kit, sans gestion EXIF
- **Fix** : Galerie utilise desormais `analyzeFaceFromPath()` → ML Kit gere l'EXIF nativement
- **Fix** : `img.bakeOrientation()` applique avant le crop pour aligner les coordonnees Dart avec ML Kit

### 4. Crop imprecis
- **Avant** : Crop central aveugle (ratait le visage sur photos de profil, eclairage lateral)
- **Apres** : Crop exact de la `boundingBox` ML Kit avec marge 20%

## Architecture du pipeline (etat final)

```
InputImage.fromFilePath(path)
    ↓ ML Kit FaceDetector (accurate) → boundingBox (coords EXIF-corrigees)
    ↓ File.readAsBytes() → img.decodeImage() → img.bakeOrientation()
    ↓ _cropFace() → region exacte du visage + 20% marge
    ↓ img.copyResize(260×260, interpolation: linear)
    ↓ Float32List [0.0, 1.0] — normalisation pixel / 255.0
    ↓ EfficientNet-B2 (enet_b2_8_integer_quant.tflite)
    ↓ Float32List output [8 logits] → softmax
    ↓ Valence/Arousal via Russell Circumplex
    ↓ FaceEmotionResult(valence, arousal, topEmotion, faceDetected: true)
```

## Fichiers modifies

### `lib/face_emotion_analyzer.dart` — Reecriture complete
- `init()` : capture `_lastError` si le modele ne charge pas
- `analyze(InputImage)` : ML Kit + bakeOrientation + _cropFace + _predictEmotion
- `analyzeFullImage(String)` : fallback crop central (sans ML Kit)
- `_cropFace()` : crop exact boundingBox avec marge _cropMargin = 0.20
- `_predictEmotion()` : Float32List [0.0,1.0] → TFLite → softmax → V/A
- `_softmax()` : numerique stable (soustraction du max)
- `detectFaceOnly()` : ML Kit detection seule, sans inference TFLite
- `close()` : libere interpreter + faceDetector

### `lib/biometric_service.dart`
- Ajout getter `tfliteError` → expose `_faceAnalyzer.lastError`
- Ajout getter `isTfliteLoaded` → expose `_faceAnalyzer.isModelLoaded`
- `analyzeFaceFromPath()` : appelle `_faceAnalyzer.analyze(InputImage.fromFilePath(path))`
- `analyzeFaceNoDetect()` : fallback crop central

### `lib/biometric_test_screen.dart`
- `_takePhoto()` : utilise `analyzeFaceFromPath()` directement (une seule passe)
- `_pickFromGallery()` : utilise `analyzeFaceFromPath()` (plus `analyzeFaceNoDetect`)
- `_openCamera()` : plus de `startImageStream`
- `dispose()` : plus de `stopImageStream`
- `_buildMetrics()` : affiche `tfliteError` en rouge si emotion absente et erreur presente
- Import `google_mlkit_face_detection` supprime de ce fichier

## Dependances cles (pubspec.yaml)

| Package | Version |
|---|---|
| tflite_flutter | ^0.12.1 |
| google_mlkit_face_detection | ^0.9.0 |
| image | ^4.2.0 |

## Modele TFLite

- Fichier : `assets/models/enet_b2_8_integer_quant.tflite`
- Architecture : EfficientNet-B2 (Savchenko HSE)
- Entree : [1, 260, 260, 3] float32 normalise [0.0, 1.0]
- Sortie : [1, 8] float32 (logits avant softmax)
- Classes : anger, contempt, disgust, fear, happiness, neutral, sadness, surprise

## Etat des tests

- `dart analyze lib/face_emotion_analyzer.dart lib/biometric_service.dart lib/biometric_test_screen.dart` : **0 erreur**
- Tests sur appareil reel : **A confirmer par l'utilisateur**
- Si TFLite echoue encore : l'erreur exacte s'affiche en rouge dans le panneau de metriques

## Prochaines etapes potentielles

- iOS : `cd ios && pod install` si tflite_flutter 0.12.1 pas encore pris en compte
- Si erreur `PREDICT:` visible dans l'UI : ajuster le format d'entree (Uint8List vs Float32List)
- Si emotion fonctionne : integrer `AuraResult` dans le flux principal FlutterFlow
