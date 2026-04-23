import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/routine_intro_screen.dart';
import 'package:flutter/services.dart';

const _darkBg = Color(0xFF5B242F);
const _primaryPurple = Color(0xFFFED7E6);
const _accentPurple = Color(0xFFF5F3F1);

enum _Phase { intro, countdown, waiting, result, complete }

class PulseMatch extends StatefulWidget {
  final VoidCallback? onComplete;
  const PulseMatch({super.key, this.onComplete});

  @override
  State<PulseMatch> createState() => _PulseMatchState();
}

class _PulseMatchState extends State<PulseMatch> with TickerProviderStateMixin {
  static const _rounds = 5;
  static const _waitMs = 3000; // durée de la fenêtre de tap

  _Phase _phase = _Phase.intro;
  int _round = 0;
  int _countdownVal = 3;
  int _score = 0;
  int? _lastDeltaMs;

  // Timestamp du "0" idéal
  int _targetMs = 0;
  Timer? _cdTimer;
  Timer? _waitTimer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _flashCtrl;
  late Animation<double> _flashAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _flashCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flashAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _flashCtrl.dispose();
    _cdTimer?.cancel();
    _waitTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    if (_round >= _rounds) {
      setState(() => _phase = _Phase.complete);
      widget.onComplete?.call();
      return;
    }
    setState(() {
      _phase = _Phase.countdown;
      _countdownVal = 3;
    });
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdownVal > 1) {
          _countdownVal--;
        } else {
          t.cancel();
          _launchWaiting();
        }
      });
    });
  }

  void _launchWaiting() {
    _targetMs = DateTime.now().millisecondsSinceEpoch + _waitMs ~/ 2;
    setState(() => _phase = _Phase.waiting);
    // Après la fenêtre, on termine si pas de tap
    _waitTimer = Timer(const Duration(milliseconds: _waitMs), () {
      if (_phase == _Phase.waiting && mounted) _recordTap(missed: true);
    });
  }

  void _onTap() {
    if (_phase != _Phase.waiting) return;
    _waitTimer?.cancel();
    _recordTap(missed: false);
  }

  void _recordTap({required bool missed}) {
    final delta = missed
        ? 999
        : (DateTime.now().millisecondsSinceEpoch - _targetMs).abs();
    final success = delta < 200;
    if (success) {
      HapticFeedback.heavyImpact();
      _flashCtrl.forward(from: 0.0);
    }
    setState(() {
      _lastDeltaMs = missed ? null : delta;
      _phase = _Phase.result;
      if (success) _score++;
      _round++;
    });
    _pulseCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _phase == _Phase.intro ? Colors.transparent : const Color(0xFF5B242F),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.intro:
        return _buildIntro();
      case _Phase.countdown:
        return _buildCountdown();
      case _Phase.waiting:
        return _buildWaiting();
      case _Phase.result:
        return _buildResult();
      case _Phase.complete:
        return _buildComplete();
    }
  }

  Widget _buildIntro() {
    return RoutineIntroScreen(
      key: const ValueKey('intro'),
      title: 'Pulse\nMatch',
      badgeLabel: '1 min 30  •  Twin  •  Contact à Distance',
      scienceText: 'La synchronisation temporelle précise entre deux personnes active les circuits de récompense et génère une sensation de connexion physique réelle.',
      steps: const [
        'Un compte à rebours : 3, 2, 1…',
        'Touchez l\'écran exactement quand le cercle explose',
        'Moins de 200ms d\'écart = synchronisation parfaite',
      ],
      onStart: _startRound,
      buttonLabel: 'Commencer',
      accentColor: _accentPurple,
    );
  }

  Widget _buildCountdown() {
    return Container(
      key: const ValueKey('countdown'),
      color: const Color(0xFF5B242F),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Manche ${_round + 1} / $_rounds",
              style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 24),
          Text("$_countdownVal",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 110,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Text("Préparez-vous",
              style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildWaiting() {
    return GestureDetector(
      key: const ValueKey('waiting'),
      onTapDown: (_) => _onTap(),
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Color(0xFF5B242F)),
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.5, end: 1.0),
              duration: Duration(milliseconds: _waitMs ~/ 2),
              curve: Curves.easeInExpo,
              builder: (_, v, __) => Container(
                width: 180 * v,
                height: 180 * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFBCAE3A), Color(0xFFF4F3F2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFBCAE3A).withOpacity(0.35),
                        blurRadius: 40 + v * 60,
                        spreadRadius: 5 + v * 15)
                  ],
                ),
                child: Center(
                  child: Text("TOUCHEZ",
                      style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(v),
                          fontSize: 18 + v * 6,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2)),
                ),
              ),
            ),
          ),
        ),
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
                        icon: Icons.bolt,
                        label: "Manche ${_round + 1} / $_rounds",
                        color: Colors.white60),
                    _TopBadge(
                        icon: Icons.stars,
                        label: "$_score pts",
                        color: _primaryPurple,
                        highlighted: true),
                  ],
                ),
              ),
            )),
      ]),
    );
  }

  Widget _buildResult() {
    final delta = _lastDeltaMs;
    final perfect = delta != null && delta < 200;
    final missed = delta == null;

    return Stack(
      key: const ValueKey('result'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF5B242F)),
        // Flash on success
        if (perfect)
          AnimatedBuilder(
            animation: _flashAnim,
            builder: (_, __) => Opacity(
              opacity: (1 - _flashAnim.value) * 0.35,
              child: Container(color: _primaryPurple),
            ),
          ),
        Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 100 * _pulseAnim.value.clamp(1.0, 1.6),
                height: 100 * _pulseAnim.value.clamp(1.0, 1.6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFF5B1F), Color(0xFFFF96B9)],
                    stops: [0.0, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFFF5B1F).withOpacity(0.45),
                        blurRadius: 50)
                  ],
                ),
                child: Icon(
                    perfect
                        ? Icons.flash_on
                        : (missed ? Icons.close : Icons.timer),
                    color: Colors.white,
                    size: 44),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              perfect
                  ? "PARFAIT !"
                  : missed
                      ? "Trop tard !"
                      : delta < 400
                          ? "Proche !"
                          : "Essayez encore",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (!missed)
              Text("${delta}ms d'écart",
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startRound,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF232323),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: Text(
                  _round >= _rounds ? "Voir le résultat" : "Manche suivante",
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ],
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
                  const Text("'Vos rythmes\nse sont rencontrés'",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Gelica',
                          color: Color(0xFF232323),
                          fontSize: 22,
                          fontWeight: FontWeight.w200,
                          fontStyle: FontStyle.italic,
                          height: 1.45)),
                  const SizedBox(height: 16),
                  Text("$_score / $_rounds synchronisations parfaites.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
