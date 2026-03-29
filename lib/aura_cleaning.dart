import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _darkBg = Color(0xFF141414);
const _lightBg = Color(0xFFF5F3FF);
const _primaryPurple = Color(0xFF82667F);
const _accentPurple = Color(0xFF735983);

// Couleurs de stress → disparaissent au nettoyage
const _mistColors = [
  Color(0xFFE53935),
  Color(0xFFEF6C00),
  Color(0xFFAD1457),
  Color(0xFFD81B60),
  Color(0xFFFF7043),
];

const _clearRadius = 78.0;   // rayon de nettoyage (px)
const _clearSpeed  = 0.055;  // vitesse de disparition par passage
const _blobCount   = 58;     // nombre de blobs de brume

enum _Phase { intro, loading, exercise, complete }

// ─── Modèle de brume (ChangeNotifier pour repaint efficace) ──────────────────
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

// ─── Painter (n'utilise que le modèle comme Listenable) ───────────────────────
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
            _primaryPurple.withValues(alpha: 0.12 + auraProgress * 0.45),
            _primaryPurple.withValues(alpha: 0.0),
          ],
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
          ..color = _primaryPurple.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        tp,
        _clearRadius * 0.45,
        Paint()
          ..color = _primaryPurple.withValues(alpha: 0.09)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
  }

  @override
  bool shouldRepaint(_MistPainter old) =>
      old.breathScale != breathScale || old.auraProgress != auraProgress;
}

// ─── Widget principal ─────────────────────────────────────────────────────────
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

  // ── Phase transitions ─────────────────────────────────────────────────────
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

  // ── Touch ─────────────────────────────────────────────────────────────────
  void _onTouch(Offset localPos) {
    if (_phase != _Phase.exercise) return;
    _mist.clearAt(localPos);
    // Vérification de seuil sans setState (le modèle notifie le painter)
    if (_mist.cleanedRatio >= _completionThreshold) {
      _timer?.cancel();
      _endExercise();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _phase == _Phase.intro ? _lightBg : _darkBg,
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

  // ── LOADING ───────────────────────────────────────────────────────────────
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

  // ── INTRO ─────────────────────────────────────────────────────────────────
  Widget _buildIntro() {
    return SafeArea(
      key: const ValueKey('intro'),
      child: Stack(
        children: [
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primaryPurple.withValues(alpha: 0.12),
                  width: 48,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  style: IconButton.styleFrom(
                    foregroundColor: _accentPurple,
                    backgroundColor: _accentPurple.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accentPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "1 min  •  Reset Visuel",
                    style: TextStyle(
                        color: _accentPurple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Aura\nCleaning",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141414),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  "Fondement scientifique :",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF141414)),
                ),
                const SizedBox(height: 8),
                Text(
                  "Le geste de \"balayage\" combiné à une visualisation colorée active la mémoire procédurale et crée une rupture émotionnelle mesurable. La brume rouge symbolise le stress ; effacer physiquement les taches renforce la sensation de contrôle.",
                  style: TextStyle(
                    fontSize: 15,
                    color: const Color(0xFF141414).withValues(alpha: 0.6),
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 32),
                const _IntroStep(
                    number: "1",
                    text: "Une brume rouge de stress recouvre l'écran"),
                const SizedBox(height: 14),
                const _IntroStep(
                    number: "2",
                    text: "Frottez avec votre doigt pour la dissiper"),
                const SizedBox(height: 14),
                const _IntroStep(
                    number: "3",
                    text: "Votre Aura apparaît au fil du nettoyage"),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startLoading,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text("Commencer",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── EXERCISE ──────────────────────────────────────────────────────────────
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
                    color: Colors.white60,
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

  // ── COMPLETE ──────────────────────────────────────────────────────────────
  Widget _buildComplete() {
    return Container(
      key: const ValueKey('complete'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF735983), Color(0xFF82667F), Color(0xFF9B7EA8)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 28),
                const Text(
                  "'Félicitez-vous d'avoir\npris ce temps pour vous'",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Votre Aura est nettoyée.\n1 minute de reset visuel complétée.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 52),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _accentPurple,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text("Continuer",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers partagés ─────────────────────────────────────────────────────────
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

class _IntroStep extends StatelessWidget {
  final String number;
  final String text;

  const _IntroStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF735983).withValues(alpha: 0.12),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF735983),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: Color(0xFF141414)),
          ),
        ),
      ],
    );
  }
}
