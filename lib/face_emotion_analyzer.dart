// Analyse d'emotions faciales — On-Device
// Modele : Savchenko EfficientNet-B2 integer_quant
// Fichier : assets/models/enet_b2_8_integer_quant.tflite
// Source  : github.com/HSE-asavchenko/face-emotion-recognition
// RGPD    : aucune donnee biometrique ne quitte l'appareil
//
// Pipeline TFLite 2.14 / tflite_flutter 0.12.1 :
//   Entree  : Float32List [0.0, 1.0] — quantisation uint8 automatique
//   Sortie  : Float32List — dequantification float32 automatique
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

// Mapping emotions → Russell Circumplex (Valence, Arousal)
// Ordre exact des sorties du modele Savchenko enet_b2_8 :
// anger, contempt, disgust, fear, happiness, neutral, sadness, surprise
const _emotionVA = [
  (-0.70,  0.80), // anger
  (-0.40,  0.20), // contempt
  (-0.60,  0.40), // disgust
  (-0.65,  0.80), // fear
  ( 0.80,  0.50), // happiness
  ( 0.00,  0.00), // neutral
  (-0.50, -0.20), // sadness
  ( 0.20,  0.70), // surprise
];

const _emotionLabels = [
  'anger', 'contempt', 'disgust', 'fear',
  'happiness', 'neutral', 'sadness', 'surprise',
];

const int _inputSize = 260;
const double _cropMargin = 0.30;
// Temperature scaling : amplifier l'ecart entre logits avant le softmax.
// Valeur > 1 rend la distribution plus piquee (emotion dominante plus marquee).
// Compense le biais "neutral" des modeles integer_quant sur micro-expressions.
const double _logitScale = 1.5;
// Dimension maximale apres decode et orientation.
// A 640px : une image 640x480 ARGB = 1.2 MB peak au lieu de 7.4 MB a 1280px.
// Suffisant pour ML Kit (detection) et le crop EfficientNet-B2 (260x260).
const int _maxDecodeSize = 640;

class FaceEmotionResult {
  final double valence;
  final double arousal;
  final String topEmotion;
  final bool faceDetected;

  const FaceEmotionResult({
    required this.valence,
    required this.arousal,
    required this.topEmotion,
    required this.faceDetected,
  });

  static const FaceEmotionResult noFace = FaceEmotionResult(
    valence: 0.0, arousal: 0.0, topEmotion: 'neutral', faceDetected: false,
  );
}

class FaceEmotionAnalyzer {
  Interpreter? _interpreter;
  String? _lastError;
  String? get lastError => _lastError;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.05,
    ),
  );

  bool _loaded = false;
  bool get isModelLoaded => _loaded && _interpreter != null;

  Future<void> init() async {
    if (_loaded) return;
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/enet_b2_8_integer_quant.tflite',
        options: options,
      );
      // LiteRT 1.4.0 : forcer la forme 4D avant allocateTensors().
      // Sans resizeInputTensor, le tenseur d'entree est vu comme 1D [202800]
      // et le noeud PAD echoue a prepare() avec "4 != 1".
      _interpreter!.resizeInputTensor(0, [1, _inputSize, _inputSize, 3]);
      _interpreter!.allocateTensors();
      debugPrint('TFLITE in[0]: type=${_interpreter!.getInputTensor(0).type} '
          'bytes=${_interpreter!.getInputTensor(0).data.lengthInBytes}');
      debugPrint('TFLITE out[0]: type=${_interpreter!.getOutputTensor(0).type} '
          'bytes=${_interpreter!.getOutputTensor(0).data.lengthInBytes}');
      _loaded = true;
    } catch (e) {
      _lastError = 'INIT: $e';
      _loaded = false;
    }
  }

  /// Analyse complete : detection ML Kit → crop exact de la boundingBox → EfficientNet.
  ///
  /// Les Samsung (et autres OEM) capturent en JPEG progressif que libjpeg de ML Kit
  /// ne peut pas decoder (erreur 122 "Invalid SOS parameters for sequential JPEG").
  /// On re-encode en JPEG sequentiel standard via le package Dart `image` avant ML Kit.
  Future<FaceEmotionResult> analyze(InputImage inputImage) async {
    String? tempPath;
    try {
      // Lire les octets bruts de l'image source.
      Uint8List? rawBytes = inputImage.bytes;
      if (rawBytes == null && inputImage.filePath != null) {
        rawBytes = await File(inputImage.filePath!).readAsBytes();
      }
      if (rawBytes == null) return FaceEmotionResult.noFace;

      // Decoder avec le package Dart (supporte JPEG progressif, PNG, EXIF).
      img.Image? full = img.decodeImage(rawBytes);
      // Liberer les bytes JPEG compresses immediatement : plus necessaires apres decode.
      // Sans ce null, rawBytes + full ARGB + full oriente coexistent en RAM = pic OOM.
      rawBytes = null;
      if (full == null) {
        _lastError = 'DECODE: format non supporte';
        return FaceEmotionResult.noFace;
      }
      // Appliquer la rotation EXIF pour que le crop EfficientNet coincide
      // avec les coordonnees boundingBox de ML Kit.
      full = img.bakeOrientation(full);

      // Contraindre la plus grande dimension a _maxDecodeSize sur les deux axes.
      // L'ancienne limite 1280px ne contraignait que la largeur — une photo portrait
      // 720x1280 passait sans resize. A 640px, le pic ARGB descend de 7 MB a 1.2 MB.
      if (full.width > _maxDecodeSize || full.height > _maxDecodeSize) {
        full = full.width >= full.height
            ? img.copyResize(full, width: _maxDecodeSize,
                interpolation: img.Interpolation.linear)
            : img.copyResize(full, height: _maxDecodeSize,
                interpolation: img.Interpolation.linear);
      }

      // Re-encoder en JPEG sequentiel standard → ML Kit peut le decoder.
      final dir = await getTemporaryDirectory();
      tempPath = '${dir.path}/mlkit_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(tempPath).writeAsBytes(img.encodeJpg(full, quality: 90));

      final faces = await _faceDetector.processImage(
          InputImage.fromFilePath(tempPath));
      if (faces.isEmpty) {
        _lastError = 'MLKIT: 0 face';
        return FaceEmotionResult.noFace;
      }

      if (!isModelLoaded) {
        return const FaceEmotionResult(
          valence: 0.0, arousal: 0.0, topEmotion: 'neutral', faceDetected: true,
        );
      }

      // L'image `full` est deja decodee et orientee — pas besoin de relire le fichier.
      final box = faces.first.boundingBox;
      final cropped = _cropFace(full,
        left: box.left, top: box.top, width: box.width, height: box.height,
      );
      return _predictEmotion(cropped);
    } catch (e) {
      _lastError = 'ANALYZE: $e';
      return FaceEmotionResult.noFace;
    } finally {
      if (tempPath != null) File(tempPath).delete().ignore();
    }
  }

  /// Analyse sans detection ML Kit — crop central de l'image.
  /// Fallback quand le detecteur echoue (biais contraste, photo galerie atypique).
  Future<FaceEmotionResult> analyzeFullImage(String imagePath) async {
    if (!isModelLoaded) return FaceEmotionResult.noFace;
    try {
      final rawBytes = await File(imagePath).readAsBytes();
      img.Image? full = img.decodeImage(rawBytes);
      if (full == null) return FaceEmotionResult.noFace;

      full = img.bakeOrientation(full);

      // Carre central a 75% de la plus petite dimension, legerement vers le haut (selfie).
      final side = (full.width < full.height ? full.width : full.height) * 3 ~/ 4;
      final x    = (full.width  - side) ~/ 2;
      final y    = (full.height - side) ~/ 4;
      final cropped = img.copyCrop(full,
          x:      x.clamp(0, full.width  - 1),
          y:      y.clamp(0, full.height - 1),
          width:  side.clamp(1, full.width  - x),
          height: side.clamp(1, full.height - y));

      return _predictEmotion(cropped);
    } catch (e) {
      _lastError = 'INFER: $e';
      return FaceEmotionResult.noFace;
    }
  }

  // ── Helpers internes ────────────────────────────────────────────────────────

  /// Crop du visage selon les coordonnees ML Kit avec marge de 20%.
  img.Image _cropFace(img.Image full, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final x = (left   - width  * _cropMargin).clamp(0.0, full.width.toDouble()  - 1).toInt();
    final y = (top    - height * _cropMargin).clamp(0.0, full.height.toDouble() - 1).toInt();
    final w = (width  * (1 + _cropMargin * 2)).clamp(1.0, (full.width  - x).toDouble()).toInt();
    final h = (height * (1 + _cropMargin * 2)).clamp(1.0, (full.height - y).toDouble()).toInt();
    return img.copyCrop(full, x: x, y: y, width: w, height: h);
  }

  /// Inference EfficientNet-B2 sur un crop de visage deja extrait.
  ///
  /// Normalisation [0.0, 1.0] via Float32List :
  ///   TFLite 2.14 quantifie automatiquement en uint8 a l'entree,
  ///   et dequantifie automatiquement en float32 a la sortie.
  FaceEmotionResult _predictEmotion(img.Image faceImage) {
    try {
      final resized = img.copyResize(faceImage,
          width:  _inputSize,
          height: _inputSize,
          interpolation: img.Interpolation.linear);

      // Normalisation [0.0, 1.0] — robuste au changement de format image v4.x.
      // copyResize avec Interpolation.linear peut produire un Format.float32
      // ou un uint16 selon la source ; maxChannelValue varie de 1.0 a 65535.
      // On divise par maxChannelValue reel plutot que par 255 fixe pour couvrir
      // tous les cas, et on clamp pour neutraliser les artefacts d'interpolation.
      final maxVal = resized.maxChannelValue.toDouble();
      final scale  = maxVal > 0 ? maxVal : 255.0;
      final inputBuf = Float32List(_inputSize * _inputSize * 3);
      int idx = 0;
      for (int row = 0; row < _inputSize; row++) {
        for (int col = 0; col < _inputSize; col++) {
          final px = resized.getPixel(col, row);
          inputBuf[idx++] = (px.r.toDouble() / scale).clamp(0.0, 1.0);
          inputBuf[idx++] = (px.g.toDouble() / scale).clamp(0.0, 1.0);
          inputBuf[idx++] = (px.b.toDouble() / scale).clamp(0.0, 1.0);
        }
      }
      debugPrint('PIXEL scale=$scale sample_r=${resized.getPixel(130, 130).r}');

      // Ecriture de l'entree : adapter au type reel du tenseur.
      // Si float32 (4 bytes/element) : ecrire les bytes bruts du Float32List.
      // Si uint8/int8 (1 byte/element) : convertir [0.0, 1.0] → [0, 255] d'abord.
      // Le mismatch float32↔uint8 est la cause la plus frequente du "always anger" :
      // les bytes IEEE-754 d'un float [0,1] interpretes en uint8 donnent des pixels
      // faux (~0) et le modele sort une distribution quasi-uniforme biaisee index 0.
      final inTensor = _interpreter!.getInputTensor(0);
      if (inTensor.data.lengthInBytes == inputBuf.lengthInBytes) {
        inTensor.data = inputBuf.buffer.asUint8List();
      } else {
        final pixelBuf = Uint8List(inputBuf.length);
        for (int i = 0; i < inputBuf.length; i++) {
          pixelBuf[i] = (inputBuf[i] * 255.0).round().clamp(0, 255);
        }
        inTensor.data = pixelBuf;
      }
      _interpreter!.invoke();

      // Lecture de la sortie [1, 8] : float32 = 32 bytes, int8 = 8 bytes.
      // Si int8, dequantifier avec les parametres du tenseur avant le softmax.
      final outTensor = _interpreter!.getOutputTensor(0);
      final int nOut = _emotionLabels.length;
      final List<double> logits;
      if (outTensor.data.lengthInBytes == nOut * 4) {
        logits = outTensor.data.buffer.asFloat32List().toList();
      } else {
        final scale = outTensor.params.scale;
        final zp    = outTensor.params.zeroPoint;
        logits = outTensor.data.buffer.asInt8List()
            .map<double>((v) => (v - zp) * scale)
            .toList();
      }
      debugPrint('TFLITE RAW  [${logits.map((v) => v.toStringAsFixed(3)).join(', ')}]');

      final probs = _softmax(logits.map((v) => v * _logitScale).toList());
      debugPrint('TFLITE PROB [${probs.map((v) => v.toStringAsFixed(3)).join(', ')}]');

      double valence = 0.0, arousal = 0.0;
      for (int i = 0; i < probs.length; i++) {
        valence += probs[i] * _emotionVA[i].$1;
        arousal += probs[i] * _emotionVA[i].$2;
      }
      int maxIdx = 0;
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > probs[maxIdx]) maxIdx = i;
      }
      return FaceEmotionResult(
        valence:     valence.clamp(-1.0, 1.0),
        arousal:     arousal.clamp( 0.0, 1.0),
        topEmotion:  _emotionLabels[maxIdx],
        faceDetected: true,
      );
    } catch (e) {
      _lastError = 'PREDICT: $e';
      return FaceEmotionResult.noFace;
    }
  }

  /// Softmax numerique stable (soustraction du max pour eviter l'overflow).
  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(max);
    final exps   = logits.map((v) => exp(v - maxVal)).toList();
    final sumExp = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sumExp).toList();
  }

  /// Detection de presence de visage uniquement (sans inference TFLite).
  Future<bool> detectFaceOnly(InputImage inputImage) async {
    try {
      final faces = await _faceDetector.processImage(inputImage);
      return faces.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void close() {
    _interpreter?.close();
    _faceDetector.close();
  }
}
