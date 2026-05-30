import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vibration/vibration.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData sun    = IconData(0xe968, fontFamily: _f);
  static const IconData users  = IconData(0xe976, fontFamily: _f);
  static const IconData sparkle = IconData(0xe964, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

const _auraColors = [
  Color(0xFF0DAABA),
  Color(0xFFE8B86E),
  Color(0xFFD9CCE8),
  Color(0xFFF2631D),
  Color(0xFF065963),
];

class SquadMorningPulse extends StatefulWidget {
  final String squadId;
  final VoidCallback? onComplete;

  const SquadMorningPulse({
    super.key,
    required this.squadId,
    this.onComplete,
  });

  @override
  State<SquadMorningPulse> createState() => _SquadMorningPulseState();
}

class _SquadMorningPulseState extends State<SquadMorningPulse>
    with TickerProviderStateMixin {
  static const int _totalSec    = 60;
  static const double _activeThresholdMin = 30.0;

  List<Map<String, dynamic>> _members    = [];
  String? _myUid;
  int     _elapsed    = 0;
  bool    _signalSent = false;

  late List<AnimationController> _pulseCtrl;
  StreamSubscription? _membersSub;
  Timer? _exTimer;
  Timer? _lastActivityThrottle;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _pulseCtrl = List.generate(5, (i) => AnimationController(
      duration: Duration(milliseconds: 1200 + i * 200), vsync: this)
      ..repeat(reverse: true));
    _loadMembers();
    _updateLastActive();
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  Future<void> _loadMembers() async {
    _membersSub = FirebaseFirestore.instance
        .collection('squads')
        .doc(widget.squadId)
        .snapshots()
        .asyncMap((snap) async {
          final uids = List<String>.from(snap.data()?['users'] ?? []);
          if (uids.isEmpty) return <Map<String, dynamic>>[];
          final docs = await Future.wait(
              uids.map((uid) => FirebaseFirestore.instance
                  .collection('users').doc(uid).get()));
          return docs
              .where((d) => d.exists)
              .map((d) => {'uid': d.id, ...d.data()!})
              .toList();
        })
        .listen((list) {
          if (!mounted) return;
          setState(() => _members = list);
        });
  }

  Future<void> _updateLastActive() async {
    if (_myUid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(_myUid!)
        .set({'lastActive': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
  }

  bool _isActive(Map<String, dynamic> member) {
    final lastActive = member['lastActive'] as Timestamp?;
    if (lastActive == null) return false;
    final diff = DateTime.now().difference(lastActive.toDate()).inMinutes;
    return diff <= _activeThresholdMin;
  }

  Future<void> _sendSignalAura(String toUid) async {
    if (_signalSent || _myUid == null) return;
    setState(() => _signalSent = true);
    Vibration.vibrate(duration: 150);
    // Écriture Firestore du signal (rate limited : 1 par paire par session)
    await FirebaseFirestore.instance
        .collection('squad_signals')
        .doc('${_myUid!}_${toUid}_${DateTime.now().millisecondsSinceEpoch}')
        .set({
      'fromUid'   : _myUid!,
      'toUid'     : toUid,
      'squadId'   : widget.squadId,
      'createdAt' : FieldValue.serverTimestamp(),
    });
    Future.delayed(const Duration(seconds: 3),
        () => mounted ? setState(() => _signalSent = false) : null);
  }

  void _complete() {
    setState(() {});
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    for (final c in _pulseCtrl) c.dispose();
    _membersSub?.cancel();
    _exTimer?.cancel();
    _lastActivityThrottle?.cancel();
    super.dispose();
  }

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
            padding: const EdgeInsets.only(top: 24),
            child: Text(_fmt(_remaining),
                style: const TextStyle(color: _gold, fontSize: 14)),
          ),
          const SizedBox(height: 16),
          // Label
          const Text(
            'Votre Squad se lève aussi.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Gelica', color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic),
          ),
          const Spacer(),
          // Cercle des 5 Auras
          SizedBox(
            width: 280, height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cercle central (logo)
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _dark.withValues(alpha: 0.60),
                    border: Border.all(
                        color: _teal.withValues(alpha: 0.30), width: 1),
                  ),
                  child: Icon(_Ico.users,
                      color: Colors.white.withValues(alpha: 0.50), size: 24),
                ),
                // 5 Auras en anneau
                ..._buildAuraRing(),
              ],
            ),
          ),
          const Spacer(),
          // Instructions
          Text(
            _members.isEmpty
                ? 'Chargement...'
                : 'Appuyez longtemps sur une Aura\npour envoyer un Signal',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.30),
                fontSize: 13),
          ),
          const SizedBox(height: 32),
          // Bouton fermer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _complete,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _dark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0),
                child: const Text('Commencer ma journée',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  List<Widget> _buildAuraRing() {
    const ringR  = 100.0;
    const count  = 5;
    final result = <Widget>[];
    for (int i = 0; i < count; i++) {
      final angle   = -pi / 2 + (i / count) * 2 * pi;
      final x       = 140 + ringR * cos(angle);
      final y       = 140 + ringR * sin(angle);
      final member  = i < _members.length ? _members[i] : null;
      final active  = member != null && _isActive(member);
      final isMe    = member?['uid'] == _myUid;
      final color   = _auraColors[i % _auraColors.length];

      result.add(Positioned(
        left: x - 28,
        top:  y - 28,
        child: _AuraBubble(
          ctrl: i < _pulseCtrl.length ? _pulseCtrl[i] : null,
          color: color,
          active: active,
          isMe: isMe,
          initial: member != null
              ? (member['prenom'] as String? ?? '?')[0].toUpperCase()
              : '?',
          onLongPress: (!isMe && member != null)
              ? () => _sendSignalAura(member['uid'] as String)
              : null,
        ),
      ));
    }
    return result;
  }
}

class _AuraBubble extends StatelessWidget {
  final AnimationController? ctrl;
  final Color color;
  final bool active;
  final bool isMe;
  final String initial;
  final VoidCallback? onLongPress;

  const _AuraBubble({
    this.ctrl, required this.color, required this.active,
    required this.isMe, required this.initial, this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (ctrl == null) {
      return _bubble(scale: 1.0);
    }
    return AnimatedBuilder(
      animation: ctrl!,
      builder: (_, __) => _bubble(scale: active ? 0.88 + ctrl!.value * 0.24 : 1.0),
    );
  }

  Widget _bubble({required double scale}) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: active ? 0.18 : 0.05),
            boxShadow: active
                ? [BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 18, spreadRadius: 3)]
                : null,
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.60)
                  : color.withValues(alpha: 0.15),
              width: isMe ? 2.0 : 1.2,
            ),
          ),
          child: Center(
            child: Text(initial,
                style: TextStyle(
                    color: active
                        ? color
                        : color.withValues(alpha: 0.30),
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
