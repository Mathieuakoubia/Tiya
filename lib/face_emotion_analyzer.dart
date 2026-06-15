// Analyse d'émotions faciales — On-Device
// Modèle : Savchenko EfficientNet-B2 integer_quant
// Fichier : assets/models/enet_b2_8_integer_quant.tflite
// Source  : github.com/HSE-asavchenko/face-emotion-recognition
// RGPD    : aucune donnée biométrique ne quitte l'appareil
//
// Note sur la version integer_quant :
//   - Entrée  : uint8 [0, 255]  (pas float [0.0, 1.0])
//   - Sortie  : uint8 → dequantifier → softmax → probabilités
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

// Mapping émotions → Russell Circumplex (Valence, Arousal)
// Ordre exact des sorties du modèle Savchenko enet_b2_8 :
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
  double _outScale    = 1.0;
  int    _outZeroPoint = 0;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
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
      // Récupérer les paramètres de quantisation pour la dequantification
      final outTensor = _interpreter!.getOutputTensor(0);
      _outScale     = outTensor.params.scale;
      _outZeroPoint = outTensor.params.zeroPoint;
      _loaded = true;
    } catch (e) {
      // Modèle introuvable ou corrompu → mode dégradé (vocal seul)
      _loaded = false;
    }
  }

  /// Analyse complète sur une InputImage (depuis caméra frontale).
  Future<FaceEmotionResult> analyze(InputImage inputImage) async {
    if (!isModelLoaded) return FaceEmotionResult.noFace;

    // 1. Détecter les visages via MLKit MediaPipe
    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isEmpty) return FaceEmotionResult.noFace;

    final box = faces.first.boundingBox;

    // 2. Décoder l'image — bytes direct ou lecture fichier si InputImage.fromFilePath
    Uint8List? rawBytes = inputImage.bytes;
    if (rawBytes == null && inputImage.filePath != null) {
      rawBytes = await File(inputImage.filePath!).readAsBytes();
    }
    if (rawBytes == null) return FaceEmotionResult.noFace;

    img.Image? fullImage = img.decodeImage(rawBytes);
    if (fullImage == null) return FaceEmotionResult.noFace;

    // 3. Crop du visage avec marge 20%
    const margin = 0.20;
    final x = (box.left   - box.width  * margin).clamp(0.0, fullImage.width.toDouble() - 1).toInt();
    final y = (box.top    - box.height * margin).clamp(0.0, fullImage.height.toDouble() - 1).toInt();
    final w = (box.width  * (1 + margin * 2)).clamp(1.0, (fullImage.width  - x).toDouble()).toInt();
    final h = (box.height * (1 + margin * 2)).clamp(1.0, (fullImage.height - y).toDouble()).toInt();

    final cropped = img.copyCrop(fullImage, x: x, y: y, width: w, height: h);
    final resized = img.copyResize(cropped,
        width: _inputSize, height: _inputSize,
        interpolation: img.Interpolation.linear);

    // 4. Construire le tenseur uint8 [1, 260, 260, 3]
    //    Version integer_quant : entrée uint8 [0, 255] (pas float)
    final input = List.generate(1, (_) =>
      List.generate(_inputSize, (row) =>
        List.generate(_inputSize, (col) {
          final pixel = resized.getPixel(col, row);
          return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        })
      )
    );

    // 5. Inférence TFLite — sortie uint8 [1, 8]
    final outputRaw = List.generate(1, (_) => List.filled(8, 0));
    _interpreter!.run(input, outputRaw);

    // 6. Dequantification : float = (uint8 - zeroPoint) * scale
    final dequant = (outputRaw[0] as List).map((v) =>
        ((v as int) - _outZeroPoint) * _outScale
    ).toList().cast<double>();

    // 7. Softmax pour obtenir des probabilités valides
    final probs = _softmax(dequant);

    // 8. Valence/Arousal pondéré
    double valence = 0.0, arousal = 0.0;
    for (int i = 0; i < 8; i++) {
      valence += probs[i] * _emotionVA[i].$1;
      arousal += probs[i] * _emotionVA[i].$2;
    }

    // 9. Émotion dominante
    int maxIdx = 0;
    for (int i = 1; i < 8; i++) {
      if (probs[i] > probs[maxIdx]) maxIdx = i;
    }

    return FaceEmotionResult(
      valence: valence.clamp(-1.0, 1.0),
      arousal: arousal.clamp( 0.0, 1.0),
      topEmotion: _emotionLabels[maxIdx],
      faceDetected: true,
    );
  }

  /// Softmax numérique stable (soustraction du max pour éviter overflow).
  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(max);
    final exps   = logits.map((v) => exp(v - maxVal)).toList();
    final sumExp = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sumExp).toList();
  }

  void close() {
    _interpreter?.close();
    _faceDetector.close();
  }
}
