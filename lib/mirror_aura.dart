import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'twin_service.dart';
import 'widgets/routine_intro_screen.dart';

const _darkBg = Color(0xFF0DAABA);
const _primaryPurple = Color(0xFFD9CCE8);
const _accentPurple = Color(0xFFF8F1E9);

enum _Phase { intro, exercise, complete }

class MirrorAura extends StatefulWidget {
  final VoidCallback? onComplete;
  const MirrorAura({super.key, this.onComplete});

  @override
  State<MirrorAura> createState() => _MirrorAuraState();
}

class _MirrorAuraState extends State<MirrorAura> with TickerProviderStateMixin {
  static const _totalSec = 120;

  static const _threshold = 0.80;

  _Phase _phase = _Phase.intro;
  int _remainingSec = _totalSec;
  // Ce que MOI j'ai donné à mon twin (mes balayages) → sphère du haut
  double _myGiven = 0.0;
  // Ce que mon TWIN m'a donné (son signal Firestore) → sphère du bas
  double _twinGiven = 0.0;
  bool _transferring = false;
  Timer? _timer;

  String? _twinUid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _twinSub;
  bool _twinOnline = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _transferCtrl;
  late Animation<double> _transferAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _transferCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _transferAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _transferCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _transferCtrl.dispose();
    _timer?.cancel();
    _twinSub?.cancel();
    TwinService.leaveRoutine();
    super.dispose();
  }

  Future<void> _startExercise() async {
    setState(() => _phase = _Phase.exercise);

    _twinUid = await TwinService.getTwinUid();
    if (_twinUid != null) {
      _twinSub = TwinService.twinSignalStream(_twinUid!).listen((snap) {
        if (!mounted) return;
        final data = snap.data();
        setState(() {
          _twinOnline = data?['status'] == 'active';
          final given = (data?['routineData']?['givenEnergy'] as num?)?.toDouble();
          if (given != null) {
            _twinGiven = given;
            if (_myGiven >= _threshold && _twinGiven >= _threshold) {
              _endExercise();
            }
          }
        });
      });
    }
    await TwinService.sendSignal(energy: 0.0, status: 'active');

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_remainingSec > 0) {
          _remainingSec--;
        } else {
          t.cancel();
          _endExercise();
        }
      });
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_phase != _Phase.exercise) return;
    final velocity = d.velocity.pixelsPerSecond.dy;
    // Balayage vers le haut = envoi d'énergie
    if (velocity < -400) {
      _doTransfer();
    }
  }

  void _doTransfer() {
    if (_transferring || _phase != _Phase.exercise) return;
    setState(() {
      _transferring = true;
      _myGiven = (_myGiven + 0.18).clamp(0.0, 1.0);
    });
    TwinService.sendSignal(
      energy: _myGiven,
      status: 'active',
      routineData: {'givenEnergy': _myGiven},
    );
    _transferCtrl.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _transferring = false);
    });
    if (_myGiven >= _threshold && _twinGiven >= _threshold) _endExercise();
  }

  void _endExercise() {
    _timer?.cancel();
    setState(() => _phase = _Phase.complete);
    TwinService.leaveRoutine();
    widget.onComplete?.call();
  }

  Color _auraColor(double energy) {
    return Color.lerp(
        const Color(0xFFE53935), const Color(0xFF1565C0), energy)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _Phase.intro ? Colors.transparent : _darkBg,
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
      case _Phase.exercise:
        return _buildExercise();
      case _Phase.complete:
        return _buildComplete();
    }
  }

  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Mirror-\nAura',
      badgeLabel: '2 min  •  Twin  •  Don d\'Énergie',
      scienceText: 'Le transfert d\'attention bienveillante active les neurones miroirs et génère une réponse empathique mesurable. Visualiser l\'énergie que l\'on offre renforce autant le donneur que le receveur.',
      steps: const [
        'Vous voyez votre Aura (bleue/calme) et celle de votre Twin (rouge/stressée)',
        'Balayez l\'écran vers le haut pour lui envoyer de l\'énergie',
        'Son Aura change de couleur à chaque transfert',
      ],
      onStart: _startExercise,
      buttonLabel: 'Commencer',
      accentColor: _accentPurple,
    );
  }

  Widget _buildExercise() {
    return GestureDetector(
      key: const ValueKey('exercise'),
      onPanEnd: _onPanEnd,
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: _darkBg),
        // Sphère Twin (haut) — bleuit via MES balayages
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Column(children: [
            Opacity(
              opacity: _twinOnline ? 1.0 : 0.35,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  width: 130 * _pulseAnim.value,
                  height: 130 * _pulseAnim.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _auraColor(_myGiven).withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                          color: _auraColor(_myGiven).withValues(alpha: 0.55),
                          blurRadius: 60,
                          spreadRadius: 12)
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _twinOnline
                      ? const Color(0xFF4CAF50)
                      : Colors.white.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "Twin  •  ${(_myGiven * 100).toInt()}% reçu",
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    letterSpacing: 0.3)),
            ]),
            if (_myGiven >= _threshold)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("✓ Don complet",
                    style: TextStyle(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                        fontSize: 11,
                        letterSpacing: 0.5)),
              ),
          ]),
        ),
        // Transfert particle
        if (_transferring)
          AnimatedBuilder(
            animation: _transferAnim,
            builder: (_, __) {
              final h = MediaQuery.of(context).size.height;
              return Positioned(
                left: 0,
                right: 0,
                top: h * 0.55 - h * 0.35 * _transferAnim.value,
                child: Center(
                  child: Opacity(
                    opacity: (1 - _transferAnim.value * 0.8).clamp(0.0, 1.0),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primaryPurple.withValues(alpha: 0.9),
                        boxShadow: [
                          BoxShadow(
                              color: _primaryPurple.withValues(alpha: 0.7),
                              blurRadius: 20)
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        // Sphère Vous (bas) — bleuit via les balayages du Twin
        Positioned(
          bottom: 90,
          left: 0,
          right: 0,
          child: Column(children: [
            if (_twinGiven >= _threshold)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("✓ Don reçu",
                    style: TextStyle(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                        fontSize: 11,
                        letterSpacing: 0.5)),
              ),
            Text(
              "Vous  •  ${(_twinGiven * 100).toInt()}% reçu",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                  letterSpacing: 0.3)),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 130 * _pulseAnim.value,
                height: 130 * _pulseAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _auraColor(_twinGiven).withValues(alpha: 0.08),
                  boxShadow: [
                    BoxShadow(
                        color: _auraColor(_twinGiven).withValues(alpha: 0.55),
                        blurRadius: 60,
                        spreadRadius: 12)
                  ],
                ),
              ),
            ),
          ]),
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
                        color: const Color(0xFFE8B86E)),
                    _TopBadge(
                        icon: Icons.electric_bolt,
                        label: "↑${(_myGiven * 100).toInt()}%  ↓${(_twinGiven * 100).toInt()}%",
                        color: _primaryPurple,
                        highlighted: _myGiven >= _threshold && _twinGiven >= _threshold),
                  ],
                ),
              ),
            )),
        Align(
          alignment: Alignment.center,
          child: Text(
            _myGiven >= _threshold
                ? "En attente du don de votre Twin…"
                : "↑  Balayez vers le haut pour donner",
            style: TextStyle(
                color: Colors.white.withValues(
                    alpha: _myGiven >= _threshold ? 0.40 : 0.18),
                fontSize: 13,
                letterSpacing: 0.5)),
        ),
      ]),
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
                        shape: BoxShape.circle, color: Color(0xFF065963)),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 28),
                  const Text("'Votre énergie a traversé\nla distance'",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Gelica',
                          color: Color(0xFF232323),
                          fontSize: 22,
                          fontWeight: FontWeight.w200,
                          fontStyle: FontStyle.italic,
                          height: 1.45)),
                  const SizedBox(height: 16),
                  Text(
                      "Vous avez donné ${(_myGiven * 100).toInt()}% à votre Twin.\nVotre Twin vous a donné ${(_twinGiven * 100).toInt()}%.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Gelica',
                          color: Color(0xFF232323),
                          fontSize: 15,
                          fontWeight: FontWeight.w200,
                          fontStyle: FontStyle.italic,
                          height: 1.55)),
                  const SizedBox(height: 52),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065963),
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
  const _TopBadge(
      {required this.icon,
      required this.label,
      required this.color,
      this.highlighted = false});

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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
