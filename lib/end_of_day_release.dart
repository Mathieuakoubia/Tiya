import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData moon = IconData(0xe956, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

const _labels = [
  'Réunion', 'Email', 'Appel', 'Tension',
  'Fatigue', 'Boulot', 'Inquiétude', 'Message',
];

enum _Phase { exercise, complete }

class _FloatItem {
  final String label;
  double x, y;
  bool deposited = false;
  _FloatItem({required this.label, required this.x, required this.y});
}

class EndOfDayRelease extends StatefulWidget {
  final VoidCallback? onComplete;
  const EndOfDayRelease({super.key, this.onComplete});

  @override
  State<EndOfDayRelease> createState() => _EndOfDayReleaseState();
}

class _EndOfDayReleaseState extends State<EndOfDayRelease>
    with TickerProviderStateMixin {
  static const int _totalSec   = 180;
  static const double _itemSize = 72.0;
  static const double _boxSize  = 110.0;

  _Phase _phase   = _Phase.exercise;
  int    _elapsed = 0;
  bool   _boxFull = false;

  late AnimationController _bgCtrl;
  late Animation<Color?>    _bgAnim;

  final List<_FloatItem>           _items       = [];
  final Map<int, AnimationController> _fadeAnims = {};
  final _rng = Random();

  Timer? _exTimer;
  Timer? _floatTimer;
  int?   _dragging;
  Size   _screen = Size.zero;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        duration: const Duration(seconds: _totalSec), vsync: this);
    _bgAnim = ColorTween(begin: _bg, end: const Color(0xFF0A0610))
        .animate(_bgCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screen = MediaQuery.of(context).size;
      _spawnItems();
      _bgCtrl.forward();
      _startTimers();
    });
  }

  void _spawnItems() {
    final margin = _itemSize + 20;
    final boxY   = _screen.height * 0.50;
    final used   = _labels.take(5).toList()..shuffle(_rng);
    for (int i = 0; i < used.length; i++) {
      _items.add(_FloatItem(
        label: used[i],
        x: margin + _rng.nextDouble() * (_screen.width - margin * 2),
        y: 80 + _rng.nextDouble() * (boxY - 120),
      ));
    }
  }

  void _startTimers() {
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec || _allDeposited) {
        t.cancel();
        _complete();
      }
    });
    // flottement lent
    _floatTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _items.length; i++) {
          if (_items[i].deposited || i == _dragging) continue;
          _items[i].y += sin(_elapsed * 0.8 + i * 1.5) * 0.4;
        }
      });
    });
  }

  bool get _allDeposited => _items.every((e) => e.deposited);

  Offset get _boxCenter =>
      Offset(_screen.width / 2, _screen.height * 0.68);

  bool _inBox(Offset pos) =>
      (pos - _boxCenter).distance < _boxSize * 0.6;

  void _onPanStart(int idx, DragStartDetails _) =>
      setState(() => _dragging = idx);

  void _onPanUpdate(int idx, DragUpdateDetails d) {
    if (_dragging != idx) return;
    setState(() {
      _items[idx].x += d.delta.dx;
      _items[idx].y += d.delta.dy;
    });
  }

  void _onPanEnd(int idx, DragEndDetails _) {
    if (_dragging != idx) return;
    final pos = Offset(_items[idx].x + _itemSize / 2,
        _items[idx].y + _itemSize / 2);
    if (_inBox(pos)) {
      setState(() => _items[idx].deposited = true);
      if (_allDeposited) _complete();
    }
    setState(() => _dragging = null);
  }

  void _complete() {
    _bgCtrl.stop();
    _exTimer?.cancel();
    _floatTimer?.cancel();
    setState(() { _phase = _Phase.complete; _boxFull = true; });
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _exTimer?.cancel();
    _floatTimer?.cancel();
    for (final c in _fadeAnims.values) c.dispose();
    super.dispose();
  }

  int    get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s)    => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _phase == _Phase.exercise ? _buildExercise() : _buildComplete(),
      ),
    );
  }

  Widget _buildExercise() => AnimatedBuilder(
    key: const ValueKey('ex'),
    animation: _bgAnim,
    builder: (_, __) => Stack(children: [
      Positioned.fill(child: ColoredBox(color: _bgAnim.value ?? _bg)),
      // Boîte centrale
      Positioned(
        left: _boxCenter.dx - _boxSize / 2,
        top:  _boxCenter.dy - _boxSize / 2,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _boxSize, height: _boxSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(
                color: _teal.withValues(alpha: _allDeposited ? 0.8 : 0.25),
                width: 1.5),
            boxShadow: _allDeposited
                ? [BoxShadow(
                    color: _teal.withValues(alpha: 0.25),
                    blurRadius: 40, spreadRadius: 6)]
                : null,
          ),
          child: Center(
            child: Icon(_Ico.moon,
                color: Colors.white.withValues(alpha: 0.20), size: 30),
          ),
        ),
      ),
      // Items flottants
      ..._items.asMap().entries.map((e) {
        final i    = e.key;
        final item = e.value;
        if (item.deposited) return const SizedBox.shrink();
        return Positioned(
          left: item.x, top: item.y,
          child: GestureDetector(
            onPanStart: (d) => _onPanStart(i, d),
            onPanUpdate: (d) => _onPanUpdate(i, d),
            onPanEnd: (d) => _onPanEnd(i, d),
            child: _ItemChip(label: item.label,
                grabbed: _dragging == i),
          ),
        );
      }),
      // Timer
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(_fmt(_remaining),
              style: const TextStyle(color: _gold, fontSize: 14)),
        )),
      ),
      // Label
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Text('Déposez ce que vous voulez laisser ici',
              style: TextStyle(
                  fontFamily: 'Gelica',
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 14, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic)),
        )),
      ),
    ]),
  );

  Widget _buildComplete() => Stack(
    key: const ValueKey('done'),
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
      Container(color: Colors.white.withValues(alpha: 0.10)),
      SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
              child: const Icon(_Ico.moon, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 28),
            const Text(
              "'La journée est déposée.\nBonne soirée.'",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Gelica', color: Color(0xFF232323),
                  fontSize: 22, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic, height: 1.45),
            ),
            const SizedBox(height: 52),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _dark, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0),
                child: const Text('Continuer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ))),
    ],
  );
}

class _ItemChip extends StatelessWidget {
  final String label;
  final bool grabbed;
  const _ItemChip({required this.label, required this.grabbed});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: grabbed ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: grabbed
                ? _teal.withValues(alpha: 0.70)
                : Colors.white.withValues(alpha: 0.15),
            width: grabbed ? 1.5 : 1.0,
          ),
          boxShadow: grabbed
              ? [BoxShadow(
                  color: _teal.withValues(alpha: 0.20),
                  blurRadius: 20, spreadRadius: 2)]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 13, fontWeight: FontWeight.w400)),
      ),
    );
  }
}
