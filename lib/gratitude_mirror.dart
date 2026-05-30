// Routine 46 — Gratitude Mirror — Twin — gratitude interpersonnelle explicite
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData gift = IconData(0xe93c, fontFamily: _f); }
const _bg   = Color(0xFF121212); const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963); const _gold = Color(0xFFE8B86E); const _lilas = Color(0xFFD9CCE8);

enum _Phase { waiting, input, bridge, complete }

class GratitudeMirror extends StatefulWidget {
  final String sessionId, partnerName;
  final VoidCallback? onComplete;
  const GratitudeMirror({super.key, required this.sessionId, required this.partnerName, this.onComplete});
  @override State<GratitudeMirror> createState() => _GratitudeMirrorState();
}

class _GratitudeMirrorState extends State<GratitudeMirror>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.waiting;
  String? _mySent, _partnerReceived;
  final _ctrl = TextEditingController();
  bool _sending = false;

  late AnimationController _bridgeCtrl;
  late RtdbSession _session;

  @override
  void initState() {
    super.initState();
    _bridgeCtrl = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) setState(() => _phase = _Phase.input); });
    _session.listenPartner('gratitude', (val) {
      if (!mounted || val == null) return;
      final msg = val.toString();
      setState(() => _partnerReceived = msg);
      Vibration.vibrate(pattern: [0, 100, 50, 100]);
      _bridgeCtrl.forward(from: 0);
      if (_mySent != null) _complete();
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || text.length > 30) return;
    setState(() { _sending = true; _mySent = text; _phase = _Phase.bridge; });
    await _session.send('gratitude', text);
    setState(() => _sending = false);
    if (_partnerReceived != null) _complete();
  }

  Future<void> _complete() async {
    setState(() => _phase = _Phase.complete);
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    widget.onComplete?.call();
  }

  @override
  void dispose() { _ctrl.dispose(); _bridgeCtrl.dispose(); _session.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg, resizeToAvoidBottomInset: true,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting:  return _buildWaiting();
      case _Phase.input:    return _buildInput();
      case _Phase.bridge:   return _buildBridge();
      case _Phase.complete: return _buildComplete();
    }
  }

  Widget _buildWaiting() => Container(key: const ValueKey('w'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_gold))),
      const SizedBox(height: 20),
      Text('En attente de ${widget.partnerName}...', style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 16)),
    ])));

  Widget _buildInput() => SingleChildScrollView(key: const ValueKey('input'),
    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
    child: Column(children: [
      const SizedBox(height: 40),
      Icon(_Ico.gift, color: _gold.withValues(alpha: 0.70), size: 48),
      const SizedBox(height: 24),
      Text('Qu\'est-ce que ${widget.partnerName}\nvous a apporté ces derniers jours ?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
              fontSize: 19, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.4)),
      const SizedBox(height: 32),
      TextField(controller: _ctrl, maxLength: 30, autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(counterText: '', hintText: 'Sa présence, sa douceur...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 14),
              filled: true, fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _gold, width: 1.5))),
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _ctrl.text.trim().isNotEmpty && !_sending ? _send : null,
        style: ElevatedButton.styleFrom(backgroundColor: _dark,
            disabledBackgroundColor: _dark.withValues(alpha: 0.30),
            foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
        child: const Text('Envoyer ma gratitude',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
    ]));

  Widget _buildBridge() => Container(key: const ValueKey('bridge'), color: _bg,
    child: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedBuilder(animation: _bridgeCtrl, builder: (_, __) => Column(children: [
          if (_mySent != null) Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                  color: _gold.withValues(alpha: 0.08), border: Border.all(color: _gold.withValues(alpha: 0.25))),
              child: Text('"$_mySent"', textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic))),
          const SizedBox(height: 24),
          if (_partnerReceived != null) Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                  color: _teal.withValues(alpha: 0.08), border: Border.all(color: _teal.withValues(alpha: 0.25))),
              child: Text('"$_partnerReceived"', textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic)))
          else Text('En attente de ${widget.partnerName}...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14)),
        ])),
      ])))));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.gift, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'La gratitude a traversé.'", textAlign: TextAlign.center,
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
