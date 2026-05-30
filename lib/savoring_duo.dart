// Routine 47 — Savoring Duo — Twin — capsule partagée
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rtdb_session.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData sparkle = IconData(0xe964, fontFamily: _f); }
const _bg = Color(0xFF121212); const _dark = Color(0xFF065963); const _gold = Color(0xFFE8B86E); const _lilas = Color(0xFFD9CCE8);

enum _Phase { waiting, input, saving, complete }

class SavoringDuo extends StatefulWidget {
  final String sessionId, partnerName;
  final VoidCallback? onComplete;
  const SavoringDuo({super.key, required this.sessionId, required this.partnerName, this.onComplete});
  @override State<SavoringDuo> createState() => _SavoringDuoState();
}

class _SavoringDuoState extends State<SavoringDuo> {
  _Phase _phase = _Phase.waiting;
  String? _myResponse, _partnerResponse;
  final _ctrl = TextEditingController();

  late RtdbSession _session;

  @override
  void initState() {
    super.initState();
    _session = RtdbSession(widget.sessionId);
    _session.markReady(onReady: () { if (mounted) setState(() => _phase = _Phase.input); });
    _session.listenPartner('savoring', (val) {
      if (!mounted || val == null) return;
      setState(() => _partnerResponse = val.toString());
      if (_myResponse != null) _saveCapsule();
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || text.length > 120) return;
    setState(() => _myResponse = text);
    await _session.send('savoring', text);
    if (_partnerResponse != null) _saveCapsule();
  }

  Future<void> _saveCapsule() async {
    if (_phase == _Phase.saving || _phase == _Phase.complete) return;
    setState(() => _phase = _Phase.saving);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Capsule partagée dans twin_capsules
      final docRef = await FirebaseFirestore.instance.collection('twin_capsules').add({
        'user1Uid' : _session.myUid,
        'user2Uid' : uid == _session.myUid ? null : uid, // sera complété par la partenaire
        'reponse1' : _myResponse,
        'reponse2' : _partnerResponse,
        'createdAt': FieldValue.serverTimestamp(),
        'sessionId': widget.sessionId,
      });
    }
    await FirebaseFirestore.instance.collection('twin_sessions').doc(widget.sessionId)
        .set({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    setState(() => _phase = _Phase.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() { _ctrl.dispose(); _session.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg, resizeToAvoidBottomInset: true,
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: _buildPhase()));

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.waiting: return _buildWaiting();
      case _Phase.input:   return _buildInput();
      case _Phase.saving:  return _buildSaving();
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
      Icon(_Ico.sparkle, color: _gold.withValues(alpha: 0.70), size: 48),
      const SizedBox(height: 24),
      const Text('Vous venez de vivre quelque chose ensemble.\nCapturons-le.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
              fontSize: 19, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.4)),
      const SizedBox(height: 12),
      Text('Qu\'est-ce que vous voulez retenir ?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14)),
      const SizedBox(height: 28),
      TextField(controller: _ctrl, maxLength: 120, maxLines: 3, autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(counterText: '',
              filled: true, fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _gold, width: 1.5))),
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 28),
      if (_partnerResponse != null) ...[
        Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                color: _lilas.withValues(alpha: 0.06),
                border: Border.all(color: _lilas.withValues(alpha: 0.20))),
            child: Text('${widget.partnerName} : "$_partnerResponse"',
                style: TextStyle(color: _lilas.withValues(alpha: 0.70), fontSize: 13,
                    fontStyle: FontStyle.italic))),
        const SizedBox(height: 20),
      ],
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _ctrl.text.trim().isNotEmpty ? _send : null,
        style: ElevatedButton.styleFrom(backgroundColor: _dark,
            disabledBackgroundColor: _dark.withValues(alpha: 0.30),
            foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
        child: const Text('Archiver notre capsule',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
    ]));

  Widget _buildSaving() => Container(key: const ValueKey('saving'), color: _bg,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(_gold))),
      const SizedBox(height: 20),
      const Text('Archivage en cours...', style: TextStyle(color: Colors.white, fontSize: 15)),
    ])));

  Widget _buildComplete() => Stack(key: const ValueKey('done'), fit: StackFit.expand, children: [
    Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
    Container(color: Colors.white.withValues(alpha: 0.10)),
    SafeArea(child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.sparkle, color: Colors.white, size: 44)),
        const SizedBox(height: 28),
        const Text("'Ce moment est maintenant\nvôtre pour toujours.'", textAlign: TextAlign.center,
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
