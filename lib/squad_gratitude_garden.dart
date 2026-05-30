// Routine 51 — Squad Gratitude Garden — jardin collectif persistant
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _Ico { static const String _f = 'icomoon'; static const IconData plant = IconData(0xe95b, fontFamily: _f); }
const _bg    = Color(0xFF121212); const _teal = Color(0xFF0DAABA);
const _dark  = Color(0xFF065963); const _gold = Color(0xFFE8B86E);
const _galetColors = [Color(0xFF0DAABA), Color(0xFFE8B86E), Color(0xFFD9CCE8), Color(0xFFF2631D), Color(0xFF065963)];

class SquadGratitudeGarden extends StatefulWidget {
  final String squadId;
  final VoidCallback? onComplete;
  const SquadGratitudeGarden({super.key, required this.squadId, this.onComplete});
  @override State<SquadGratitudeGarden> createState() => _SquadGratitudeGardenState();
}

class _SquadGratitudeGardenState extends State<SquadGratitudeGarden> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  String? _myUid;
  StreamSubscription? _sub;
  List<Map<String, dynamic>> _galets = [];

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _sub = FirebaseFirestore.instance
        .collection('squad_gratitude')
        .where('squadId', isEqualTo: widget.squadId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() => _galets = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
    });
  }

  Future<void> _sendGalet() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || text.length > 30 || _sending || _myUid == null) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('squad_gratitude').add({
        'squadId'  : widget.squadId,
        'authorUid': _myUid!,
        'mot'      : text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _ctrl.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: _teal));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _sub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 0), child: Column(children: [
          Icon(_Ico.plant, color: _teal.withValues(alpha: 0.60), size: 44),
          const SizedBox(height: 16),
          const Text('Le jardin de gratitude\nde votre Squad', textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.4)),
          const SizedBox(height: 20),
          // Saisie
          Row(children: [
            Expanded(child: TextField(controller: _ctrl, maxLength: 30,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(counterText: '', hintText: 'Un mot de gratitude...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
                    filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _teal, width: 1.5))),
                onSubmitted: (_) => _sendGalet())),
            const SizedBox(width: 10),
            GestureDetector(onTap: _ctrl.text.trim().isNotEmpty && !_sending ? _sendGalet : null,
                child: Container(width: 48, height: 48,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _ctrl.text.trim().isNotEmpty ? _dark : _dark.withValues(alpha: 0.30)),
                    child: _sending
                        ? const Padding(padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Icon(_Ico.plant, color: Colors.white, size: 22))),
          ]),
        ])),
        const SizedBox(height: 16),
        // Galets
        Expanded(child: _galets.isEmpty
            ? Center(child: Text('Le jardin attend ses premiers galets.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.30), fontSize: 14)))
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.3),
                itemCount: _galets.length,
                itemBuilder: (_, i) {
                  final g = _galets[i];
                  final colorIdx = (g['authorUid']?.hashCode ?? 0) % _galetColors.length;
                  final color = _galetColors[colorIdx];
                  final isMe = g['authorUid'] == _myUid;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                        color: color.withValues(alpha: 0.08),
                        border: Border.all(color: color.withValues(alpha: isMe ? 0.50 : 0.20))),
                    child: Center(child: Text(g['mot'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: color, fontSize: 12,
                            fontWeight: isMe ? FontWeight.w700 : FontWeight.w400))));
                })),
        // Bouton fermer
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: widget.onComplete,
              style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
              child: const Text('Fermer le jardin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))))),
      ])),
    );
  }
}
