import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'widgets/routine_intro_screen.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

const _darkBg = Color(0xFF5B242F);
const _primaryPurple = Color(0xFFFED7E6);
const _accentPurple = Color(0xFFF5F3F1);

// Couleurs de stress → disparaissent au nettoyage
const _mistColors = [
  Color(0xFF5B242F),
  Color(0xFFFFD7E7),
  Color(0xFFBCAE3A),
  Color(0xFFF2631D),
  Color(0xFFF4F3F2),
];

const _clearRadius = 78.0;   // rayon de nettoyage (px)
const _clearSpeed  = 0.055;  // vitesse de disparition par passage
const _blobCount   = 58;     // nombre de blobs de brume

enum _Phase { intro, loading, exercise, complete }

class _Blob {
  final double x;      // normalisé 0.0–1.0
  final double y;
  final double radius; // normalisé
  final Color color;
  double opacity = 1.0;

  _Blob({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
  });
}

class _MistModel extends ChangeNotifier {
  final List<_Blob> _blobs = [];
  Offset? touchPoint;
  Size screenSize = Size.zero;

  List<_Blob> get blobs => List.unmodifiable(_blobs);

  void generate(Size size, Random rng) {
    screenSize = size;
    _blobs.clear();
    for (int i = 0; i < _blobCount; i++) {
      _blobs.add(_Blob(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.07 + rng.nextDouble() * 0.12,
        color: _mistColors[rng.nextInt(_mistColors.length)],
      ));
    }
    notifyListeners();
  }

  /// Efface la brume autour du point [pos]. Retourne true si un blob a changé.
  bool clearAt(Offset pos) {
    touchPoint = pos;
    bool changed = false;
    for (final blob in _blobs) {
      if (blob.opacity <= 0.0) continue;
      final bx = blob.x * screenSize.width;
      final by = blob.y * screenSize.height;
      final dist = (Offset(bx, by) - pos).distance;
      if (dist < _clearRadius) {
        final factor = 1.0 - (dist / _clearRadius);
        blob.opacity = (blob.opacity - _clearSpeed * factor).clamp(0.0, 1.0);
        changed = true;
      }
    }
    if (changed) notifyListeners();
    return changed;
  }

  /// 0.0 = rien nettoyé, 1.0 = tout nettoyé
  double get cleanedRatio {
    if (_blobs.isEmpty) return 0.0;
    final total = _blobs.fold(0.0, (s, b) => s + b.opacity);
    return 1.0 - (total / _blobs.length);
  }

  @override
  void dispose() {
    _blobs.clear();
    super.dispose();
  }
}

class _MistPainter extends CustomPainter {
  final _MistModel model;
  final double breathScale;
  final double auraProgress;

  _MistPainter({
    required this.model,
    required this.breathScale,
    required this.auraProgress,
  }) : super(repaint: model);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1 – Aura calme sous la brume (s'intensifie au fil du nettoyage)
    final auraR = size.width * 0.42 * (0.75 + auraProgress * 0.5);
    canvas.drawCircle(
      center,
      auraR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF2631D).withValues(alpha: 0.10 + auraProgress * 0.35),
            const Color(0xFF5B242F).withValues(alpha: 0.06 + auraProgress * 0.20),
            const Color(0xFFFFD7E7).withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: auraR)),
    );

    // 2 – Blobs de brume de stress
    for (final blob in model.blobs) {
      if (blob.opacity <= 0.01) continue;
      final bx = blob.x * size.width;
      final by = blob.y * size.height;
      final br = blob.radius * size.width * breathScale;
      canvas.drawCircle(
        Offset(bx, by),
        br,
        Paint()
          ..color = blob.color.withValues(alpha: blob.opacity * 0.48)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, br * 0.55),
      );
    }

    // 3 – Cercle de nettoyage sous le doigt
    final tp = model.touchPoint;
    if (tp != null) {
      canvas.drawCircle(
        tp,
        _clearRadius,
        Paint()
          ..color = const Color(0xFF5B242F).withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        tp,
        _clearRadius * 0.45,
        Paint()
          ..color = const Color(0xFFBCAE3A).withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
  }

  @override
  bool shouldRepaint(_MistPainter old) =>
      old.breathScale != breathScale || old.auraProgress != auraProgress;
}

class AuraCleaning extends StatefulWidget {
  final VoidCallback? onComplete;

  const AuraCleaning({super.key, this.onComplete});

  @override
  State<AuraCleaning> createState() => _AuraCleaningState();
}

class _AuraCleaningState extends State<AuraCleaning>
    with SingleTickerProviderStateMixin {
  static const _totalSec = 60;
  static const _completionThreshold = 0.78; // 78% nettoyé = réussi

  final _mist = _MistModel();
  final _rng = Random();

  _Phase _phase = _Phase.intro;
  int _remainingSec = _totalSec;
  Timer? _timer;

  CameraController? _cameraController;

  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _timer?.cancel();
    _mist.dispose();
    try { _cameraController?.stopImageStream(); } catch (_) {}
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _startLoading() async {
    setState(() => _phase = _Phase.loading);
    await _initCamera();
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    _mist.generate(size, _rng);
    setState(() => _phase = _Phase.exercise);
    _startTimer();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied || !mounted) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty || !mounted) return;
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController!.initialize();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _remainingSec--;
        if (_mist.cleanedRatio >= _completionThreshold || _remainingSec <= 0) {
          t.cancel();
          _endExercise();
        }
      });
    });
  }

  void _endExercise() {
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  void _onTouch(Offset localPos) {
    if (_phase != _Phase.exercise) return;
    _mist.clearAt(localPos);
    // Vérification de seuil sans setState (le modèle notifie le painter)
    if (_mist.cleanedRatio >= _completionThreshold) {
      _timer?.cancel();
      _endExercise();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _phase == _Phase.intro ? Colors.transparent : _darkBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.intro:
        return _buildIntro();
      case _Phase.loading:
        return _buildLoading();
      case _Phase.exercise:
        return _buildExercise();
      case _Phase.complete:
        return _buildComplete();
    }
  }

  Widget _buildLoading() {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryPurple),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Initialisation caméra...",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 16,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Aura\nCleaning',
      badgeLabel: '1 min  •  Reset Visuel',
      scienceText: 'Le geste de balayage combiné à une visualisation colorée active la mémoire procédurale et crée une rupture émotionnelle mesurable. La brume rouge symbolise le stress ; effacer physiquement les taches renforce la sensation de contrôle.',
      steps: const [
        'Une brume rouge de stress recouvre l\'écran',
        'Frottez avec votre doigt pour la dissiper',
        'Votre Aura apparaît au fil du nettoyage',
      ],
      onStart: _startLoading,
      buttonLabel: 'Commencer',
      accentColor: _accentPurple,
    );
  }

  Widget _buildExercise() {
    final cam = _cameraController;
    return GestureDetector(
      key: const ValueKey('exercise'),
      onPanUpdate: (d) => _onTouch(d.localPosition),
      onPanStart: (d) => _onTouch(d.localPosition),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fond : flux caméra frontale (ou noir si permission refusée)
          if (cam != null && cam.value.isInitialized)
            CameraPreview(cam)
          else
            const ColoredBox(color: _darkBg),
          // Brume de stress par-dessus la caméra
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _breathAnim,
              builder: (_, __) => CustomPaint(
                painter: _MistPainter(
                  model: _mist,
                  breathScale: _breathAnim.value,
                  auraProgress: _mist.cleanedRatio,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TopBadge(
                    icon: Icons.timer,
                    label:
                        '${_remainingSec ~/ 60}:${(_remainingSec % 60).toString().padLeft(2, '0')}',
                    color: const Color(0xFFBCAE3A),
                  ),
                  // Progress aura nettoyée
                  ListenableBuilder(
                    listenable: _mist,
                    builder: (_, __) => _TopBadge(
                      icon: Icons.auto_awesome,
                      label:
                          "${(_mist.cleanedRatio * 100).toStringAsFixed(0)}%",
                      color: _primaryPurple,
                      highlighted: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Bottom hint
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Text(
                "Frottez la brume pour libérer votre Aura",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.22),
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildComplete() {
    return Stack(
      key: const ValueKey('complete'),
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
        Container(color: Colors.white.withValues(alpha: 0.10)),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFF5B242F)),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "'Félicitez-vous d'avoir\npris ce temps pour vous'",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Gelica',
                      color: Color(0xFF232323),
                      fontSize: 22,
                      fontWeight: FontWeight.w200,
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Votre Aura est nettoyée.\n1 minute de reset visuel complétée.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Gelica',
                      color: Color(0xFF232323),
                      fontSize: 15,
                      fontWeight: FontWeight.w200,
                      fontStyle: FontStyle.italic,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 52),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B242F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text("Continuer",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool highlighted;

  const _TopBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? _primaryPurple.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style:
                  TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
