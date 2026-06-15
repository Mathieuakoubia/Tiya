import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

const _wordChoices = [
  'Calme', 'Force', 'Présence', 'Légèreté', 'Clarté', 'Courage',
  'Douceur', 'Joie', 'Patience', 'Gratitude',
];

const _sectionColors = [
  Color(0xFF0DAABA), Color(0xFFE8B86E),
  Color(0xFFD9CCE8), Color(0xFFF8F1E9), Color(0xFF065963),
];

class IntentionWheel extends StatefulWidget {
  final String squadId;
  final String userId;
  final VoidCallback? onComplete;

  const IntentionWheel({
    super.key,
    required this.squadId,
    required this.userId,
    this.onComplete,
  });

  @override
  State<IntentionWheel> createState() => _IntentionWheelState();
}

class _IntentionWheelState extends State<IntentionWheel>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 120;

  int    _elapsed     = 0;
  String? _myWord;
  bool   _saving      = false;
  Timer? _exTimer;
  StreamSubscription? _wheelSub;

  // Données de la roue : [{userUid, prenom, mot, completed}]
  final List<Map<String, dynamic>> _members = [];

  late AnimationController _glowCtrl;
  late Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
        duration: const Duration(seconds: 2), vsync: this)
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.8, end: 1.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_glowCtrl);
    _listenWheel();
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _listenWheel() {
    final today = _todayKey();
    _wheelSub = FirebaseFirestore.instance
        .collection('squad_intentions')
        .where('squadId', isEqualTo: widget.squadId)
        .where('date', isEqualTo: today)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final list = snap.docs.map((d) => d.data()).toList();
      setState(() {
        _members.clear();
        _members.addAll(list);
      });
    });
  }

  String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  Future<void> _saveWord(String word) async {
    if (_saving) return;
    setState(() { _saving = true; _myWord = word; });
    final today = _todayKey();
    // ID déterministe — idempotent
    await FirebaseFirestore.instance
        .collection('squad_intentions')
        .doc('${widget.squadId}_${widget.userId}_$today')
        .set({
      'squadId'   : widget.squadId,
      'userUid'   : widget.userId,
      'prenom'    : FirebaseAuth.instance.currentUser?.displayName ?? '',
      'mot'       : word,
      'date'      : today,
      'completed' : false,
      'updatedAt' : FieldValue.serverTimestamp(),
    });
    setState(() => _saving = false);
  }

  void _complete() {
    setState(() {});
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _exTimer?.cancel();
    _wheelSub?.cancel();
    super.dispose();
  }

  bool get _allSet => _members.length >= 5;
  bool get _allCompleted =>
      _members.isNotEmpty && _members.every((m) => m['completed'] == true);

  int    get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s)    => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // Timer
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(_fmt(_remaining),
                style: const TextStyle(color: _gold, fontSize: 14)),
          ),
          const SizedBox(height: 12),
          // Roue
          Expanded(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Center(
                child: SizedBox(
                  width: 280, height: 280,
                  child: CustomPaint(
                    painter: _WheelPainter(
                      members: _members,
                      glowScale: _glowAnim.value,
                      allCompleted: _allCompleted,
                    ),
                    child: Center(
                      child: _allCompleted
                          ? Icon(Icons.stars,
                              color: _gold.withValues(alpha: 0.85), size: 40)
                          : Icon(Icons.stars,
                              color: Colors.white.withValues(alpha: 0.15), size: 36),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Choix du mot (si pas encore choisi)
          if (_myWord == null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Choisissez votre intention du jour',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Gelica', color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w200,
                      fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _wordChoices.map((w) => GestureDetector(
                  onTap: () => _saveWord(w),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _teal.withValues(alpha: 0.08),
                      border: Border.all(
                          color: _teal.withValues(alpha: 0.25)),
                    ),
                    child: Text(w,
                        style: const TextStyle(
                            color: _teal, fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ),
                )).toList(),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Votre intention : $_myWord\n${_allCompleted ? '✦ Squad en synergie ✦' : '${_members.length}/5 membres ont choisi'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Gelica',
                    color: _allCompleted ? _gold : Colors.white.withValues(alpha: 0.50),
                    fontSize: 15, fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Bouton terminer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _myWord != null ? _complete : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _dark,
                    disabledBackgroundColor: _dark.withValues(alpha: 0.30),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0),
                child: const Text('Continuer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> members;
  final double glowScale;
  final bool allCompleted;
  const _WheelPainter({
    required this.members, required this.glowScale,
    required this.allCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 10;

    // 5 sections
    const sections = 5;
    final sweepAngle = 2 * pi / sections;

    for (int i = 0; i < sections; i++) {
      final startAngle = -pi / 2 + i * sweepAngle;
      final hasData    = i < members.length;
      final completed  = hasData && (members[i]['completed'] == true);
      final color      = _sectionColors[i % _sectionColors.length];

      final alpha = completed
          ? allCompleted ? 0.80 : 0.55
          : hasData ? 0.20 : 0.08;

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          startAngle, sweepAngle - 0.04, true, paint);

      // Label du mot si disponible
      if (hasData) {
        final word = members[i]['mot'] as String? ?? '';
        final prenom = (members[i]['prenom'] as String? ?? '').split(' ').first;
        final labelAngle = startAngle + sweepAngle / 2;
        final labelR     = r * 0.62;
        final lx = cx + labelR * cos(labelAngle);
        final ly = cy + labelR * sin(labelAngle);
        final tp = TextPainter(
          text: TextSpan(
            text: word.length > 8 ? '${word.substring(0, 7)}.' : word,
            style: TextStyle(
                color: completed ? Colors.white : color.withValues(alpha: 0.70),
                fontSize: 10,
                fontWeight: completed ? FontWeight.w700 : FontWeight.w400),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(lx, ly);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }

    // Cercle central
    final centerPaint = Paint()
      ..color = allCompleted
          ? const Color(0xFFE8B86E).withValues(alpha: 0.20 * glowScale)
          : Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r * 0.32, centerPaint);

    // Glow si tous complétés
    if (allCompleted) {
      canvas.drawCircle(Offset(cx, cy), r * glowScale,
          Paint()
            ..color = const Color(0xFFE8B86E).withValues(alpha: 0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.members != members || old.glowScale != glowScale ||
      old.allCompleted != allCompleted;
}

