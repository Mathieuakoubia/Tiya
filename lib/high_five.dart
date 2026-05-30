// Routine 8 — The High-Five — synchronie tactile — Firebase RTDB
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'rtdb_session.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData checks = IconData(0xe92e, fontFamily: _f);
}

const _bg   = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

enum _Phase { waiting, countdown, tapping, result, complete }

class HighFive extends StatefulWidget {
  final String sessionId;
  final bool isInitiator;
  final String partnerName;
  final VoidCallback? onComplete;
  const HighFive({super.key, required this.sessionId, required this.isInitiator,
    required this.partnerName, this.onComplete});
  @override State<HighFive> createState() => _HighFiveState();
}

class _HighFiveState extends State<HighFive> with SingleTickerProviderStateMixin {
  static const int _maxAttempts = 5;
  static const int _windowMs    = 400;

  _Phase _phase = _Phase.waiting;
  int _countdown = 3, _attempts = 0;
  int? _myTapMs, _partnerTapMs, _diffMs;

  late AnimationController _burstCtrl;
  late Animation<double>   _burstAnim;
  late RtdbSession _session;
  Timer? _cdTimer, _totalTimer;

  @override
  void initState() {
    super.initState();
    _burstCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _burstAnim = Tween<double>(begin: 0.0, end: 3.0)
        .chain(CurveTween(curve: Curves.easeOut)).animate(_burstCtrl);
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () {
      if (!mounted) return;
      if (widget.isInitiator) _startCountdown();
      else {
        _session.listenBroadcast('countdown_start', (_) {
          if (mounted && _phase == _Phase.waiting) _startCountdown();
        });
      }
    });
    _session.listenPartner('tap', (val) {
      _partnerTapMs = (val as num).toInt();
      _checkSync();
    });
    _totalTimer = Timer(const Duration(minutes: 2), _complete);
  }

  void _startCountdown() {
    if (widget.isInitiator) _session.broadcast('countdown_start', true);
    setState(() { _phase = _Phase.countdown; _countdown = 3; });
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 1) { _countdown--; } else { t.cancel(); setState(() => _phase = _Phase.tapping); }
      });
    });
  }

  void _onTap() {
    if (_phase != _Phase.tapping) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    _myTapMs = ts;
    _session.send('tap', ts);
    Vibration.vibrate(duration: 60);
    _checkSync();
  }

  void _checkSync() {
    if (_myTapMs == null || _partnerTapMs == null) return;
    final diff = (_myTapMs! - _partnerTapMs!).abs();
    _myTapMs = _partnerTapMs = null;
    _attempts++;
    setState(() { _diffMs = diff; _phase = _Phase.result; });
    if (diff <= _windowMs) {
      Vibration.vibrate(pattern: [0, 150, 50, 150]);
      _burstCtrl.forward(from: 0);
    }
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_attempts >= _maxAttempts) { _complete(); return; }
      setState(() { _phase = _Phase.countdown; _countdown = 3; });
      _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          if (_countdown > 1) { _countdown--; } else { t.cancel(); setState(() => _phase = _Phase.tapping); }
        });
      });
    });
  }

  void _complete() {
    _totalTimer?.cancel();
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _burstCtrl.dispose();
    _cdTimer?.cancel(); _totalTimer?.cancel();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _bg,
        body: AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: _buildPhase()));
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:   return _buildWaiting();
      case _Phase.countdown: return _buildCountdown();
      case _Phase.tapping:   return _buildTapping();
      case _Phase.result:    return _buildResult();
      case _Phase.complete:  return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.7)))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildCountdown() => Container(key: ValueKey('cd$_countdown'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Préparez-vous', style: TextStyle(color: Colors.white.withValues(alpha: 0.50),
          fontSize: 18, fontWeight: FontWeight.w300)),
      const SizedBox(height: 20),
      Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
    ])));

  Widget _buildTapping() => GestureDetector(key: const ValueKey('tap'),
    onTapDown: (_) => _onTap(),
    child: Container(color: _bg, child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Touchez !', style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
            fontSize: 48, fontWeight: FontWeight.w600)),
        const SizedBox(height: 30),
        Container(width: 120, height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.40), width: 2)),
            child: const Icon(_Ico.checks, color: Colors.white, size: 48)),
        const SizedBox(height: 20),
        Text('Tentative ${_attempts + 1} / $_maxAttempts',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 13)),
      ]))));

  Widget _buildResult() {
    final synced = (_diffMs ?? 999) <= _windowMs;
    return Container(key: const ValueKey('res'), color: _bg, child: Stack(children: [
      if (synced) AnimatedBuilder(animation: _burstAnim, builder: (_, __) => Center(
        child: Container(width: 200 * _burstAnim.value, height: 200 * _burstAnim.value,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _gold.withValues(alpha: (1.0 - _burstAnim.value / 3).clamp(0.0, 0.35)))))),
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(synced ? '✦' : '○', style: TextStyle(fontSize: 60,
            color: synced ? _gold : Colors.white.withValues(alpha: 0.30))),
        const SizedBox(height: 16),
        Text(synced ? 'Parfait ! ±${_diffMs}ms' : '${_diffMs}ms d\'écart',
            style: TextStyle(fontFamily: 'Gelica',
                color: synced ? _gold : Colors.white.withValues(alpha: 0.60),
                fontSize: 20, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
      ])),
    ]));
  }

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.checks, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Vous êtes en lien.'", textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: Color(0xFF232323),
                fontSize: 24, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.45)),
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
