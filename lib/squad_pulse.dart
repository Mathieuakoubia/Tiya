import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'squad_service.dart';
import 'widgets/routine_intro_screen.dart';

const _darkBg = Color(0xFF141414);
const _primaryPurple = Color(0xFF82667F);
const _accentPurple = Color(0xFF735983);

// Palette de couleurs fixe assignée par index de membre
const _palette = [
  Color(0xFF4CAF50),
  Color(0xFF26C6DA),
  Color(0xFFAB47BC),
  Color(0xFFFF7043),
  Color(0xFFFFCA28),
];

enum _Phase { intro, exercise, complete }

class _Member {
  final String uid;
  final String name;
  final Color color;
  double energy; // 0.0 = stressée, 1.0 = sereine
  double pulseSpeed;

  _Member({
    required this.uid,
    required this.name,
    required this.color,
    required this.energy,
  }) : pulseSpeed = 1.2 + (1.0 - energy) * 1.8;

  void updateEnergy(double e) {
    energy = e.clamp(0.0, 1.0);
    pulseSpeed = 1.2 + (1.0 - energy) * 1.8;
  }
}

class SquadPulse extends StatefulWidget {
  final VoidCallback? onComplete;
  const SquadPulse({super.key, this.onComplete});

  @override
  State<SquadPulse> createState() => _SquadPulseState();
}

class _SquadPulseState extends State<SquadPulse>
    with SingleTickerProviderStateMixin {
  static const _totalSec = 60;

  _Phase _phase = _Phase.intro;
  int _remainingSec = _totalSec;
  Timer? _timer;
  StreamSubscription? _sub;

  // Énergie initiale du joueur courant (avant que Firestore ne réponde)
  double _myEnergy = 0.6;
  final List<_Member> _members = [];
  bool _firestoreReady = false;

  late AnimationController _masterCtrl;

  @override
  void initState() {
    super.initState();
    _masterCtrl = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _initFirebase();
  }

  Future<void> _initFirebase() async {
    // Afficher au moins "Vous" immédiatement, sans attendre Firestore
    if (mounted) {
      setState(() {
        _firestoreReady = true;
        _members
          ..clear()
          ..add(_Member(
            uid: SquadService.currentUid,
            name: 'Vous',
            color: _palette[0],
            energy: _myEnergy,
          ));
      });
    }

    // Écrire l'énergie puis écouter le stream
    await SquadService.updateMyEnergy(_myEnergy);
    _sub = SquadService.membersStream().listen(_onMembersUpdate);
  }

  void _onMembersUpdate(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    final docs = snap.docs;
    setState(() {
      _firestoreReady = true;
      // Reconstruire la liste en conservant l'ordre stable (uid trié)
      final sorted = List.of(docs)..sort((a, b) => a.id.compareTo(b.id));
      _members.clear();
      for (int i = 0; i < sorted.length; i++) {
        final doc = sorted[i];
        final data = doc.data();
        final uid = doc.id;
        final isMe = uid == SquadService.currentUid;
        final energy = (data['energy'] as num?)?.toDouble() ?? 0.5;
        if (isMe) _myEnergy = energy;
        _members.add(_Member(
          uid: uid,
          name: isMe ? 'Vous' : (data['displayName'] as String? ?? '?'),
          color: _palette[i % _palette.length],
          energy: energy,
        ));
      }
    });
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _startExercise() {
    setState(() => _phase = _Phase.exercise);
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

  // Tap → boost énergie de l'utilisateur courant et écrire dans Firestore
  void _boostEnergy() {
    if (_phase != _Phase.exercise) return;
    final newEnergy = (_myEnergy + 0.15).clamp(0.0, 1.0);
    setState(() => _myEnergy = newEnergy);
    SquadService.updateMyEnergy(newEnergy);
  }

  void _endExercise() {
    _timer?.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  double get _avgEnergy => _members.isEmpty
      ? _myEnergy
      : _members.fold(0.0, (s, m) => s + m.energy) / _members.length;

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
      title: 'Squad\nPulse',
      badgeLabel: '1 min  •  Squad  •  Partage d\'Énergie',
      scienceText:
          'Visualiser l\'état émotionnel de son groupe sans texte réduit l\'anxiété sociale tout en maintenant la connexion. Cette conscience collective silencieuse favorise l\'entraide spontanée.',
      steps: const [
        '5 sphères lumineuses représentent votre Squad',
        'La vitesse de pulsation indique le niveau de stress',
        'Touchez l\'écran pour partager votre énergie au groupe',
      ],
      onStart: _startExercise,
      buttonLabel: 'Commencer',
      accentColor: _accentPurple,
    );
  }

  Widget _buildExercise() {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      key: const ValueKey('exercise'),
      onTapDown: (_) => _boostEnergy(),
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
        Container(color: Colors.white.withOpacity(0.12)),
        if (!_firestoreReady)
          const Center(child: CircularProgressIndicator(color: Colors.white54))
        else ...[
          ..._buildPentagon(size),
          // Centre : énergie moyenne
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryPurple.withValues(alpha: 0.05 + _avgEnergy * 0.1),
                boxShadow: [
                  BoxShadow(
                      color: _primaryPurple.withValues(alpha: _avgEnergy * 0.3),
                      blurRadius: 40,
                      spreadRadius: 5)
                ],
              ),
              child: Center(
                child: Text("${(_avgEnergy * 100).toInt()}%",
                    style: GoogleFonts.poppins(
                        color: _primaryPurple.withValues(
                            alpha: 0.6 + _avgEnergy * 0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],
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
                        color: Colors.white60),
                    _TopBadge(
                        icon: Icons.favorite,
                        label: "Énergie ${(_avgEnergy * 100).toInt()}%",
                        color: _primaryPurple,
                        highlighted: true),
                  ],
                ),
              ),
            )),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Text(
                  _members.length < 2
                      ? "En attente d'autres membres..."
                      : "Touchez pour partager votre énergie",
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3)),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildPentagon(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 140.0;
    final count = _members.isEmpty ? 1 : _members.length;
    return List.generate(_members.length, (i) {
      final angle = (2 * pi * i / count) - pi / 2;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      final m = _members[i];
      return Positioned(
        left: x - 36,
        top: y - 50,
        child: AnimatedBuilder(
          animation: _masterCtrl,
          builder: (_, __) {
            final t = _masterCtrl.value * 60;
            final pulse = 0.85 + 0.15 * sin(2 * pi * t / m.pulseSpeed);
            final stressRatio = 1.0 - m.energy;
            final glowColor =
                Color.lerp(_primaryPurple, const Color(0xFFE53935), stressRatio)!;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glowColor.withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(
                          color: glowColor.withValues(alpha: 0.45),
                          blurRadius: 24,
                          spreadRadius: 4)
                    ],
                    border: Border.all(
                        color: glowColor.withValues(alpha: 0.6), width: 2),
                  ),
                  child: Center(
                    child: Text(m.name[0],
                        style: GoogleFonts.poppins(
                            color: glowColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(m.name,
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ]);
          },
        ),
      );
    });
  }

  Widget _buildComplete() {
    return Container(
      key: const ValueKey('complete'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50), Color(0xFF81C784)],
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
                      color: Colors.white.withValues(alpha: 0.18)),
                  child:
                      const Icon(Icons.favorite, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 28),
                Text("'Votre Squad est\nen bonne santé'",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        height: 1.45)),
                const SizedBox(height: 16),
                Text(
                    "Énergie collective : ${(_avgEnergy * 100).toInt()}%.\nVotre contribution a renforcé le groupe.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.55)),
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
                    child: Text("Continuer",
                        style: GoogleFonts.poppins(
                            fontSize: 17, fontWeight: FontWeight.w500)),
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
            style:
                GoogleFonts.poppins(color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
