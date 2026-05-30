// Routine 13 — Audio-Capsule — côté enregistrement et envoi
// Note : la réception/lecture est dans audio_capsule.dart existant
// Validation du ton : VoiceStressAnalyzer (remplace Hume AI — sunset 14 juin 2026)
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'voice_stress_analyzer.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData mic  = IconData(0xe955, fontFamily: _f);
  static const IconData send = IconData(0xe95a, fontFamily: _f);
  static const IconData warn = IconData(0xe978, fontFamily: _f);
}

const _bg   = Color(0xFF121212);
const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _gold = Color(0xFFE8B86E);

const _maxRecordSec = 15;

enum _CapsuleState { ready, recording, stressAlert, reviewing, sending, sent, error }

class AudioCapsuleSend extends StatefulWidget {
  final String squadId;
  final String recipientUid;
  final String recipientName;
  final VoidCallback? onComplete;

  const AudioCapsuleSend({
    super.key,
    required this.squadId,
    required this.recipientUid,
    required this.recipientName,
    this.onComplete,
  });

  @override
  State<AudioCapsuleSend> createState() => _AudioCapsuleSendState();
}

class _AudioCapsuleSendState extends State<AudioCapsuleSend> {
  _CapsuleState _state    = _CapsuleState.ready;
  int           _recSec   = 0;
  String?       _filePath;
  String        _errorMsg = '';

  final _recorder    = AudioRecorder();
  final _voiceAnalyzer = VoiceStressAnalyzer();
  Timer? _recTimer;

  @override
  void dispose() {
    _recTimer?.cancel();
    _recorder.dispose();
    _voiceAnalyzer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() { _state = _CapsuleState.error; _errorMsg = 'Microphone non autorisé.'; });
      return;
    }
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/capsule_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _filePath = path;
    setState(() { _state = _CapsuleState.recording; _recSec = 0; });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _recSec++);
      if (_recSec >= _maxRecordSec) { t.cancel(); _stopRecording(); }
    });
  }

  Future<void> _stopRecording() async {
    _recTimer?.cancel();
    await _recorder.stop();
    // Validation du ton — VoiceStressAnalyzer (on-device, remplace Hume)
    // Analyse le fichier déjà enregistré pour évaluer si la voix est tendue
    final stressResult = _filePath != null
        ? await _voiceAnalyzer.captureAndAnalyze()
        : null;
    if (stressResult?.isStressed == true) {
      setState(() => _state = _CapsuleState.stressAlert);
    } else {
      setState(() => _state = _CapsuleState.reviewing);
    }
  }

  void _retry() {
    _filePath = null;
    setState(() { _state = _CapsuleState.ready; _recSec = 0; });
  }

  Future<void> _send() async {
    if (_filePath == null) return;
    setState(() => _state = _CapsuleState.sending);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Non authentifié');
      final today = _todayKey();
      // ID idempotent — 1 capsule par paire par jour
      final docId = '${uid}_${widget.recipientUid}_$today';
      // Upload Storage
      final storageRef = FirebaseStorage.instance
          .ref('audio_capsules/$uid/$docId.m4a');
      await storageRef.putFile(File(_filePath!));
      final audioUrl = await storageRef.getDownloadURL();
      // Écriture Firestore — vérification préalable (rate limit)
      final existing = await FirebaseFirestore.instance
          .collection('audio_capsules')
          .doc(docId)
          .get();
      if (existing.exists) throw Exception('Capsule déjà envoyée aujourd\'hui.');
      await FirebaseFirestore.instance
          .collection('audio_capsules')
          .doc(docId)
          .set({
        'senderUid'   : uid,
        'recipientUid': widget.recipientUid,
        'squadId'     : widget.squadId,
        'audioUrl'    : audioUrl,
        'status'      : 'pending', // → 'delivered' par Cloud Function
        'createdAt'   : FieldValue.serverTimestamp(),
      });
      setState(() => _state = _CapsuleState.sent);
      await Future.delayed(const Duration(seconds: 2));
      widget.onComplete?.call();
    } catch (e) {
      setState(() {
        _state    = _CapsuleState.error;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  int    get _remaining => (_maxRecordSec - _recSec).clamp(0, _maxRecordSec);
  String _fmt(int s)    => '0:${s.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildState(),
        ),
      ),
    );
  }

  Widget _buildState() {
    switch (_state) {
      case _CapsuleState.ready:       return _buildReady();
      case _CapsuleState.recording:   return _buildRecording();
      case _CapsuleState.stressAlert: return _buildStressAlert();
      case _CapsuleState.reviewing:   return _buildReviewing();
      case _CapsuleState.sending:     return _buildSending();
      case _CapsuleState.sent:        return _buildSent();
      case _CapsuleState.error:       return _buildError();
    }
  }

  Widget _buildReady() => _Center(
    key: const ValueKey('ready'),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _teal.withValues(alpha: 0.10),
          border: Border.all(color: _teal.withValues(alpha: 0.35)),
        ),
        child: const Icon(_Ico.mic, color: _teal, size: 46),
      ),
      const SizedBox(height: 28),
      Text('Enregistrer une capsule\npour ${widget.recipientName}',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Gelica', color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w200,
              fontStyle: FontStyle.italic, height: 1.4)),
      const SizedBox(height: 12),
      Text('Max 15 secondes — enregistrez quand vous êtes calme.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40), fontSize: 13)),
      const SizedBox(height: 36),
      GestureDetector(
        onTap: _startRecording,
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _teal,
            boxShadow: [BoxShadow(
                color: _teal.withValues(alpha: 0.35),
                blurRadius: 20, spreadRadius: 4)],
          ),
          child: const Icon(_Ico.mic, color: Colors.white, size: 32),
        ),
      ),
      const SizedBox(height: 14),
      Text('Appuyez pour enregistrer',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30), fontSize: 12)),
    ]),
  );

  Widget _buildRecording() => _Center(
    key: const ValueKey('rec'),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF2631D).withValues(alpha: 0.15),
          border: Border.all(
              color: const Color(0xFFF2631D).withValues(alpha: 0.60), width: 2),
        ),
        child: const Icon(_Ico.mic, color: Color(0xFFF2631D), size: 46),
      ),
      const SizedBox(height: 20),
      Text(_fmt(_remaining),
          style: const TextStyle(color: _gold, fontSize: 28,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Enregistrement en cours...',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50), fontSize: 14)),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        onPressed: _stopRecording,
        icon: const Icon(Icons.stop, size: 20),
        label: const Text('Arrêter'),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF2631D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
            elevation: 0),
      ),
    ]),
  );

  Widget _buildStressAlert() => _Center(
    key: const ValueKey('stress'),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_Ico.warn, color: _gold, size: 52),
      const SizedBox(height: 24),
      const Text(
        'Votre voix semble tendue.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: 'Gelica', color: Colors.white,
            fontSize: 20, fontWeight: FontWeight.w200,
            fontStyle: FontStyle.italic),
      ),
      const SizedBox(height: 12),
      Text(
        'La capsule sera plus apaisante si vous enregistrez\nquand vous êtes calme.',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45), fontSize: 14,
            height: 1.5),
      ),
      const SizedBox(height: 36),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton(
          onPressed: _retry,
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.50),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30))),
          child: const Text('Re-enregistrer'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () => setState(() => _state = _CapsuleState.reviewing),
          style: ElevatedButton.styleFrom(
              backgroundColor: _dark, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0),
          child: const Text('Envoyer quand même'),
        ),
      ]),
    ]),
  );

  Widget _buildReviewing() => _Center(
    key: const ValueKey('review'),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _dark.withValues(alpha: 0.40),
          border: Border.all(color: _teal.withValues(alpha: 0.35)),
        ),
        child: const Icon(_Ico.send, color: _teal, size: 42),
      ),
      const SizedBox(height: 24),
      Text('${_recSec}s enregistrées',
          style: const TextStyle(color: _gold, fontSize: 18,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Prête à envoyer à ${widget.recipientName}',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50), fontSize: 14)),
      const SizedBox(height: 36),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton(
          onPressed: _retry,
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.40),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30))),
          child: const Text('Recommencer'),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _send,
          icon: const Icon(_Ico.send, size: 18),
          label: const Text('Envoyer'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _dark, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0),
        ),
      ]),
    ]),
  );

  Widget _buildSending() => _Center(
    key: const ValueKey('sending'),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 48, height: 48,
          child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(_teal))),
      const SizedBox(height: 24),
      const Text('Envoi en cours...',
          style: TextStyle(color: Colors.white, fontSize: 16)),
    ]),
  );

  Widget _buildSent() => Stack(
    key: const ValueKey('sent'),
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
      Container(color: Colors.white.withValues(alpha: 0.10)),
      _Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 88, height: 88,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
          child: const Icon(_Ico.send, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 24),
        const Text("'Votre capsule est envoyée.\nElle sera là au bon moment.'",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Gelica', color: Color(0xFF232323),
                fontSize: 20, fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic, height: 1.5)),
      ])),
    ],
  );

  Widget _buildError() => _Center(
    key: const ValueKey('err'),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_Ico.warn, color: _gold, size: 48),
      const SizedBox(height: 20),
      Text(_errorMsg.isNotEmpty ? _errorMsg : 'Une erreur est survenue.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60), fontSize: 14)),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _retry,
        style: ElevatedButton.styleFrom(
            backgroundColor: _dark, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
            elevation: 0),
        child: const Text('Réessayer'),
      ),
    ]),
  );
}

class _Center extends StatelessWidget {
  final Widget child;
  const _Center({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: child,
    )));
  }
}
