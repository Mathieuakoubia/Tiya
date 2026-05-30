// Routine 52 — Squad Celebration Wave — Firebase RTDB
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData star = IconData(0xe961, fontFamily: _f); }
const _bg = Color(0xFF121212); const _dark = Color(0xFF065963); const _gold = Color(0xFFE8B86E);
const _waveColors = [Color(0xFFE8B86E), Color(0xFF0DAABA), Color(0xFFD9CCE8), Color(0xFFF2631D), Color(0xFF065963)];

enum _Phase { connecting, wave, complete }

class SquadCelebrationWave extends StatefulWidget {
  final String sessionId, celebrantName, celebrantWord;
  final bool isCelebrant;
  final VoidCallback? onComplete;
  const SquadCelebrationWave({super.key, required this.sessionId, required this.celebrantName,
    required this.celebrantWord, required this.isCelebrant, this.onComplete});
  @override State<SquadCelebrationWave> createState() => _SquadCelebrationWaveState();
}

class _SquadCelebrationWaveState extends State<SquadCelebrationWave> with TickerProviderStateMixin {
  static const int _totalSec = 90, _tapCooldownMs = 1500;
  _Phase _phase = _Phase.connecting;
  int _elapsed = 0, _signalsReceived = 0;
  final Map<int, int> _lastTap = {};
  final List<AnimationController> _waveCtrls = [];
  late AnimationController _centerCtrl;
  late RtdbSession _session;
  Timer? _exTimer;

  @override
  void initState() {
    super.initState();
    _centerCtrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    for (int i = 0; i < 4; i++) _waveCtrls.add(AnimationController(duration: Duration(milliseconds: 500 + i * 100), vsync: this));
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) { setState(() => _phase = _Phase.wave); _startExercise(); }});
    _session.listenPartner('signal', (val) {
      if (!mounted) return;
      final map = val as Map? ?? {};
      final idx = (map['idx'] as num?)?.toInt() ?? 0;
      if (widget.isCelebrant) { Vibration.vibrate(duration: 150); setState(() => _signalsReceived++); }
      if (idx < _waveCtrls.length) _waveCtrls[idx].forward(from: 0);
      _centerCtrl.forward(from: 0);
    });
  }

  void _startExercise() {
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _elapsed++);
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  void _sendSignal(int idx) {
    if (widget.isCelebrant) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastTap[idx] ?? 0) < _tapCooldownMs) return;
    _lastTap[idx] = now;
    _session.send('signal', {'idx': idx});
    _waveCtrls[idx % _waveCtrls.length].forward(from: 0);
  }

  void _complete() { Vibration.cancel(); setState(() => _phase = _Phase.complete); widget.onComplete?.call(); }

  @override
  void dispose() {
    _centerCtrl.dispose(); for (final c in _waveCtrls) c.dispose();
    _exTimer?.cancel(); Vibration.cancel(); _session.dispose();
    super.dispose();
  }

  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.connecting: return _buildWaiting();
      case _Phase.wave: return widget.isCelebrant ? _buildReceive() : _buildSend();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_gold))),
      const SizedBox(height: 20),
      Text('Connexion au Squad...', style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildReceive() => Stack(key: const ValueKey('recv'), children: [
    const Positioned.fill(child: ColoredBox(color: _bg)),
    Center(child: SizedBox(width: 300, height: 300, child: Stack(alignment: Alignment.center, children: [
      ..._waveCtrls.asMap().entries.map((e) => AnimatedBuilder(animation: e.value, builder: (_, __) {
        final v = e.value.value;
        return Opacity(opacity: (1-v).clamp(0.0,1.0), child: Container(
          width: 80 + 200*v, height: 80 + 200*v,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: _waveColors[e.key % _waveColors.length].withValues(alpha: 0.15))));
      })),
      AnimatedBuilder(animation: _centerCtrl, builder: (_, __) => Container(
        width: 100, height: 100,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: _gold.withValues(alpha: 0.10 + _centerCtrl.value * 0.15),
            boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.20 + _centerCtrl.value * 0.20),
                blurRadius: 30 + _centerCtrl.value * 20, spreadRadius: 4)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(_Ico.star, color: _gold, size: 32),
          Text('×$_signalsReceived', style: const TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w700)),
        ]))),
    ]))),
    Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
        const SizedBox(height: 8),
        Text('"${widget.celebrantWord}"', style: const TextStyle(fontFamily: 'Gelica', color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Votre Squad célèbre avec vous ✦', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
      ])))),
  ]);

  Widget _buildSend() {
    return Stack(key: const ValueKey('send'), children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(children: [
          Text('${widget.celebrantName} célèbre :', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
          const SizedBox(height: 4),
          Text('"${widget.celebrantWord}"', style: const TextStyle(fontFamily: 'Gelica', color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 13)),
        ])))),
      Center(child: SizedBox(width: 280, height: 280, child: Stack(alignment: Alignment.center, children: [
        ...List.generate(_waveCtrls.length, (i) {
          final angle = -pi/2 + (i/_waveCtrls.length)*2*pi;
          return AnimatedBuilder(animation: _waveCtrls[i], builder: (_, __) => Positioned(
            left: 90 + 90*cos(angle) - 32, top: 90 + 90*sin(angle) - 32,
            child: GestureDetector(onTap: () => _sendSignal(i),
              child: Container(width: 64, height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: _waveColors[i%_waveColors.length].withValues(alpha: 0.12 + _waveCtrls[i].value*0.10),
                      boxShadow: [BoxShadow(color: _waveColors[i%_waveColors.length].withValues(alpha: 0.20+_waveCtrls[i].value*0.20), blurRadius: 16, spreadRadius: 2)],
                      border: Border.all(color: _waveColors[i%_waveColors.length].withValues(alpha: 0.40))),
                  child: const Icon(_Ico.star, color: Colors.white, size: 24)))));
        }),
        const Icon(_Ico.star, color: _gold, size: 32),
      ]))),
      Align(alignment: Alignment.bottomCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Text('Tapez pour envoyer un Signal', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12))))),
    ]);
  }

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.star, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Le Squad célèbre avec vous.'", textAlign: TextAlign.center,
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
