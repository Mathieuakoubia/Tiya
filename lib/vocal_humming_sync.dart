// Routine 27 — Vocal Humming Sync — Firebase RTDB
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData mic = IconData(0xe955, fontFamily: _f); }
const _bg = Color(0xFF121212); const _dark = Color(0xFF065963);
const _teal = Color(0xFF0DAABA); const _gold = Color(0xFFE8B86E); const _lilas = Color(0xFFD9CCE8);
const _hummingThreshold = 52.0;

enum _Phase { waiting, exercise, complete }

class VocalHummingSync extends StatefulWidget {
  final String sessionId, partnerName;
  final VoidCallback? onComplete;
  const VocalHummingSync({super.key, required this.sessionId, required this.partnerName, this.onComplete});
  @override State<VocalHummingSync> createState() => _VocalHummingSyncState();
}

class _VocalHummingSyncState extends State<VocalHummingSync>
    with SingleTickerProviderStateMixin {
  static const int _totalSec = 120;
  _Phase _phase = _Phase.waiting;
  int _elapsed = 0, _syncSeconds = 0;
  bool _iHumming = false, _partnerHumming = false;
  bool get _bothHumming => _iHumming && _partnerHumming;

  late AnimationController _waveCtrl;
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSub;
  late RtdbSession _session;
  Timer? _sendTimer, _exTimer;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) { setState(() => _phase = _Phase.exercise); _startExercise(); }});
    _session.listenPartner('humming', (val) {
      if (!mounted) return;
      setState(() => _partnerHumming = val == true || val == 1);
      if (_bothHumming) { if (!_waveCtrl.isAnimating) _waveCtrl.repeat(reverse: true); Vibration.vibrate(duration: 80); }
      else { _waveCtrl.stop(); _waveCtrl.reset(); }
    });
  }

  Future<void> _startExercise() async {
    _noiseMeter = NoiseMeter();
    _noiseSub = _noiseMeter!.noise.listen((r) {
      final h = r.meanDecibel > _hummingThreshold;
      if (h != _iHumming) setState(() => _iHumming = h);
    });
    _sendTimer = Timer.periodic(const Duration(milliseconds: 300), (_) => _session.send('humming', _iHumming));
    _exTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { _elapsed++; if (_bothHumming) _syncSeconds++; });
      if (_elapsed >= _totalSec) { t.cancel(); _complete(); }
    });
  }

  Future<void> _complete() async {
    _waveCtrl.stop(); _noiseSub?.cancel(); _sendTimer?.cancel(); Vibration.cancel();
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'syncSeconds': _syncSeconds, 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _waveCtrl.dispose(); _noiseSub?.cancel(); _sendTimer?.cancel(); _exTimer?.cancel();
    Vibration.cancel(); _session.dispose();
    super.dispose();
  }

  int get _remaining => (_totalSec - _elapsed).clamp(0, _totalSec);
  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:  return _buildWaiting();
      case _Phase.exercise: return _buildExercise();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_lilas))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...', style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildExercise() => AnimatedBuilder(key: const ValueKey('ex'), animation: _waveCtrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Positioned(left: MediaQuery.of(context).size.width * 0.15, top: 0, bottom: 0,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            _HumBubble(active: _iHumming, label: 'Vous', color: _teal)])),
      Positioned(right: MediaQuery.of(context).size.width * 0.15, top: 0, bottom: 0,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            _HumBubble(active: _partnerHumming, label: widget.partnerName, color: _gold)])),
      if (_bothHumming) Center(child: SizedBox(width: 120, height: 120,
          child: CustomPaint(painter: _HumWavePainter(phase: _waveCtrl.value, color: _lilas)))),
      Align(alignment: Alignment.topCenter, child: SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmt(_remaining), style: const TextStyle(color: _gold, fontSize: 14)),
          const SizedBox(height: 6),
          Text(_bothHumming ? 'En résonance ✦' : 'Fredonnez Hmmmm...',
              style: TextStyle(fontFamily: 'Gelica',
                  color: _bothHumming ? _lilas.withValues(alpha: 0.80) : Colors.white.withValues(alpha: 0.30),
                  fontSize: 14, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)),
        ])))),
    ]));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.mic, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        Text("'$_syncSeconds secondes en résonance.'", textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Gelica', color: Color(0xFF232323),
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

class _HumBubble extends StatelessWidget {
  final bool active; final String label; final Color color;
  const _HumBubble({required this.active, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    AnimatedContainer(duration: const Duration(milliseconds: 200),
      width: active ? 70 : 56, height: active ? 70 : 56,
      decoration: BoxDecoration(shape: BoxShape.circle,
          color: color.withValues(alpha: active ? 0.18 : 0.05),
          boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 4)] : null,
          border: Border.all(color: color.withValues(alpha: active ? 0.60 : 0.18), width: active ? 2.0 : 1.0))),
    const SizedBox(height: 8),
    Text(label, style: TextStyle(color: active ? color : color.withValues(alpha: 0.30), fontSize: 11, fontWeight: FontWeight.w500)),
  ]);
}

class _HumWavePainter extends CustomPainter {
  final double phase; final Color color;
  const _HumWavePainter({required this.phase, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(size.width/2, size.height/2), 20.0 + i * 20 + phase * 15,
          Paint()..color = color.withValues(alpha: 0.25 - i * 0.07)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }
  @override bool shouldRepaint(_HumWavePainter old) => old.phase != phase;
}
