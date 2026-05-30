// Routine 45 — Debrief Duo — Firebase RTDB
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData moon = IconData(0xe956, fontFamily: _f); }
const _bg = Color(0xFF0D0D18); const _dark = Color(0xFF065963); const _gold = Color(0xFFE8B86E);
const _labels = ['Réunion', 'Appel', 'Tension', 'Fatigue', 'Email', 'Boulot', 'Inquiétude', 'Surcharge'];

enum _Phase { waiting, exercise, wordInput, complete }

class DebriefDuo extends StatefulWidget {
  final String sessionId, partnerName;
  final VoidCallback? onComplete;
  const DebriefDuo({super.key, required this.sessionId, required this.partnerName, this.onComplete});
  @override State<DebriefDuo> createState() => _DebriefDuoState();
}

class _DebriefDuoState extends State<DebriefDuo> with TickerProviderStateMixin {
  static const int _totalSec = 180;
  _Phase _phase = _Phase.waiting;
  int _elapsed = 0;
  bool _myBoxClosed = false, _partnerBoxClosed = false;
  final List<_FloatItem> _items = [];
  int? _dragging;
  final _rng = Random();
  Size _screen = Size.zero;
  late AnimationController _bgCtrl; late Animation<Color?> _bgAnim;
  late RtdbSession _session;
  Timer? _exTimer, _floatTimer;
  final _wordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(duration: const Duration(seconds: _totalSec), vsync: this);
    _bgAnim = ColorTween(begin: _bg, end: const Color(0xFF050508)).animate(_bgCtrl);
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () {
      if (!mounted) return;
      setState(() => _phase = _Phase.exercise);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _screen = MediaQuery.of(context).size;
        _spawnItems(); _bgCtrl.forward(); _startTimers();
      });
    });
    _session.listenPartner('closed', (_) {
      if (!mounted) return;
      setState(() => _partnerBoxClosed = true);
      _checkBothClosed();
    });
  }

  void _spawnItems() {
    final margin = 60.0; final maxY = _screen.height * 0.55;
    for (int i = 0; i < 5; i++) _items.add(_FloatItem(
      label: _labels[i % _labels.length],
      x: margin + _rng.nextDouble() * (_screen.width - margin * 2),
      y: 80 + _rng.nextDouble() * (maxY - 100)));
  }

  void _startTimers() {
    _floatTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _items.length; i++) {
          if (_items[i].deposited || i == _dragging) continue;
          _items[i].y += sin(_elapsed * 0.8 + i * 1.5) * 0.3;
        }
      });
    });
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _forceComplete(); }
    });
  }

  bool get _myAllDeposited => _items.every((i) => i.deposited);
  Offset get _boxCenter => Offset(_screen.width / 2, _screen.height * 0.70);
  bool _inBox(Offset pos) => (pos - _boxCenter).distance < 55;

  void _onPanStart(int idx, DragStartDetails _) => setState(() => _dragging = idx);
  void _onPanUpdate(int idx, DragUpdateDetails d) {
    if (_dragging != idx) return;
    setState(() { _items[idx].x += d.delta.dx; _items[idx].y += d.delta.dy; });
  }
  void _onPanEnd(int idx, DragEndDetails _) {
    if (_dragging != idx) return;
    if (_inBox(Offset(_items[idx].x + 30, _items[idx].y + 18))) {
      setState(() => _items[idx].deposited = true);
      if (_myAllDeposited && !_myBoxClosed) _closeMyBox();
    }
    setState(() => _dragging = null);
  }

  void _closeMyBox() {
    setState(() => _myBoxClosed = true);
    _session.send('closed', true);
    _checkBothClosed();
  }

  void _checkBothClosed() {
    if (_myBoxClosed && _partnerBoxClosed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _phase = _Phase.wordInput);
      });
    }
  }

  void _sendWord() {
    final word = _wordCtrl.text.trim();
    if (word.isNotEmpty && word.length <= 15) _session.send('word', word);
    _forceComplete();
  }

  void _forceComplete() {
    _bgCtrl.stop(); _floatTimer?.cancel(); _exTimer?.cancel();
    _saveAndComplete();
  }

  Future<void> _saveAndComplete() async {
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _bgCtrl.dispose(); _wordCtrl.dispose(); _floatTimer?.cancel(); _exTimer?.cancel(); _session.dispose();
    super.dispose();
  }

  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 500), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:   return _buildWaiting();
      case _Phase.exercise:  return _buildExercise();
      case _Phase.wordInput: return _buildWordInput();
      case _Phase.complete:  return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_gold))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...', style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _bgAnim,
    builder: (_, __) => Stack(children: [
      Positioned.fill(child: ColoredBox(color: _bgAnim.value ?? _bg)),
      Positioned(left: _boxCenter.dx - 55, top: _boxCenter.dy - 55,
          child: AnimatedContainer(duration: const Duration(milliseconds: 400), width: 110, height: 110,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(color: _myBoxClosed ? _gold.withValues(alpha: 0.60) : Colors.white.withValues(alpha: 0.15), width: 1.5)),
              child: Center(child: Icon(_Ico.moon, color: Colors.white.withValues(alpha: _myBoxClosed ? 0.50 : 0.15), size: 32)))),
      ..._items.asMap().entries.map((e) {
        final i = e.key;
        if (_items[i].deposited) return const SizedBox.shrink();
        return Positioned(left: _items[i].x, top: _items[i].y,
          child: GestureDetector(
            onPanStart: (d) => _onPanStart(i, d), onPanUpdate: (d) => _onPanUpdate(i, d), onPanEnd: (d) => _onPanEnd(i, d),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(color: _dragging == i ? _gold.withValues(alpha: 0.60) : Colors.white.withValues(alpha: 0.12))),
                child: Text(_items[i].label, style: TextStyle(color: Colors.white.withValues(alpha: 0.60), fontSize: 13)))));
      }),
      Positioned(bottom: 100, left: 0, right: 0, child: Center(child: Text(
          _partnerBoxClosed ? '${widget.partnerName} a déposé ✦' : '${widget.partnerName} dépose...',
          style: TextStyle(color: _partnerBoxClosed ? _gold.withValues(alpha: 0.70) : Colors.white.withValues(alpha: 0.20), fontSize: 12)))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14))))),
    ]));

  Widget _buildWordInput() => Container(key: const ValueKey('word'), color: _bg,
    child: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Vous avez toutes les deux\ndéposé la journée.', textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.4)),
        const SizedBox(height: 28),
        const Text('Un mot pour l\'autre ? (optionnel)', style: TextStyle(color: Color(0xFFD9CCE8), fontSize: 13)),
        const SizedBox(height: 16),
        TextField(controller: _wordCtrl, maxLength: 15, textAlign: TextAlign.center, autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(counterText: '', hintText: 'Courage, Merci...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.20)),
                filled: true, fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _gold, width: 1.5)))),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _forceComplete,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.40),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: const Text('Passer'))),
          const SizedBox(width: 16),
          Expanded(child: ElevatedButton(onPressed: _sendWord,
              style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
              child: const Text('Envoyer', style: TextStyle(fontWeight: FontWeight.w600)))),
        ]),
      ])))));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.moon, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vous avez fermé la journée ensemble.'", textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Color(0xFF232323),
                fontSize: 22, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.45)),
        const SizedBox(height: 52),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
          child: const Text('Continuer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)))),
      ])))),
  ]);
}

class _FloatItem { final String label; double x, y; bool deposited = false; _FloatItem({required this.label, required this.x, required this.y}); }
