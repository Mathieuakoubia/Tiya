import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'twin_service.dart';
import 'squad_service.dart';
import 'twin_coherence.dart';
import 'twin_coherence_rt.dart';
import 'mirror_aura.dart';
import 'silent_presence.dart';
import 'pulse_match.dart';
import 'duo_morning.dart';
import 'debrief_duo.dart';
import 'night_tandem.dart';
import 'savoring_duo.dart';
import 'bio_ambient_duo.dart';
import 'collective_shield.dart';
import 'squad_pulse.dart';
import 'squad_morning_pulse.dart';
import 'squad_gratitude_garden.dart';
import 'squad_celebration_wave.dart';
import 'squad_resonance.dart';
import 'squad_night_watch.dart';

enum _Phase { loading, celebrantInput, invite, waiting, countdown, error }

const _bg    = Color(0xFF121212);
const _teal  = Color(0xFF0DAABA);
const _dark  = Color(0xFF065963);
const _lila  = Color(0xFFD9CCE8);
const _ivory = Color(0xFFF8F1E9);
const _maxCelebrantWordLen = 30;
const _countdownFrom = 3;

/// Salle d'attente unifiée pour toutes les routines Twin et Squad.
///
/// Initiateur  : existingSessionId = null  → crée la session et attend
/// Destinataire : existingSessionId = non-null → affiche invitation Accept/Refuser
class RoutineLobby extends StatefulWidget {
  final String routineKey;
  final String routineTitle;
  final String routineType; // 'twin' | 'squad'
  final String myName;
  final String? existingSessionId; // null = initiateur

  // Initiateur twin
  final String? twinUid;
  final String? twinInviteId;
  final String? partnerName;

  // Initiateur squad
  final String? squadId;
  final List<String>? memberUids;
  final List<String>? memberNames;

  const RoutineLobby({
    super.key,
    required this.routineKey,
    required this.routineTitle,
    required this.routineType,
    required this.myName,
    this.existingSessionId,
    this.twinUid,
    this.twinInviteId,
    this.partnerName,
    this.squadId,
    this.memberUids,
    this.memberNames,
  });

  @override
  State<RoutineLobby> createState() => _RoutineLobbyState();
}

class _RoutineLobbyState extends State<RoutineLobby>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.loading;
  String _errorMsg = '';
  String? _sessionId;
  Map<String, dynamic> _sessionData = {};
  int _countdown = _countdownFrom;

  Timer? _countdownTimer;
  StreamSubscription<DocumentSnapshot>? _sessionSub;
  late final AnimationController _pulseCtrl;

  final _celebrantWordCtrl = TextEditingController();

  bool get _isInitiator => widget.existingSessionId == null;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _collection =>
      widget.routineType == 'twin' ? 'twin_sessions' : 'squad_sessions';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      if (_isInitiator) {
        if (widget.routineKey == 'squad_celebration_wave') {
          if (mounted) setState(() => _phase = _Phase.celebrantInput);
          return;
        }
        await _createSession();
      } else {
        _sessionId = widget.existingSessionId;
        final doc = await FirebaseFirestore.instance
            .collection(_collection)
            .doc(_sessionId)
            .get();
        if (!doc.exists || !mounted) {
          if (mounted) {
            setState(() {
              _phase = _Phase.error;
              _errorMsg = 'Session introuvable.';
            });
          }
          return;
        }
        _sessionData = doc.data()!;
        final acceptedBy =
            List<String>.from(_sessionData['acceptedBy'] ?? []);
        _listenSession();
        if (mounted) {
          setState(() {
            _phase =
                acceptedBy.contains(_uid) ? _Phase.waiting : _Phase.invite;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  Future<void> _createSession() async {
    try {
      String sessionId;
      if (widget.routineType == 'twin') {
        sessionId = await TwinService.createRoutineSession(
          twinUid: widget.twinUid!,
          inviteId: widget.twinInviteId!,
          routineKey: widget.routineKey,
          routineTitle: widget.routineTitle,
          initiatorName: widget.myName,
          twinName: widget.partnerName!,
        );
      } else {
        sessionId = await SquadService.createRoutineSession(
          squadId: widget.squadId!,
          routineKey: widget.routineKey,
          routineTitle: widget.routineTitle,
          initiatorName: widget.myName,
          memberUids: widget.memberUids!,
          memberNames: widget.memberNames!,
        );
        final word = _celebrantWordCtrl.text.trim();
        if (word.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('squad_sessions')
              .doc(sessionId)
              .update({'extraData.celebrantWord': word});
        }
      }
      _sessionId = sessionId;
      _listenSession();
      if (mounted) setState(() => _phase = _Phase.waiting);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  void _listenSession() {
    _sessionSub = FirebaseFirestore.instance
        .collection(_collection)
        .doc(_sessionId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data()!;
      setState(() => _sessionData = data);
      final status = data['status'] as String? ?? 'waiting';
      if (status == 'started' && _phase != _Phase.countdown) {
        _startCountdown();
        return;
      }
      if (status == 'cancelled') {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final acceptedBy = List<String>.from(data['acceptedBy'] ?? []);
      if (_phase == _Phase.invite && acceptedBy.contains(_uid)) {
        setState(() => _phase = _Phase.waiting);
      }
    });
  }

  Future<void> _acceptSession() async {
    if (_sessionId == null) return;
    try {
      final ref = FirebaseFirestore.instance
          .collection(_collection)
          .doc(_sessionId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data()!;
        final accepted = List<String>.from(data['acceptedBy'] ?? []);
        if (!accepted.contains(_uid)) accepted.add(_uid);
        final curStatus = data['status'] as String? ?? 'waiting';
        final newStatus = curStatus == 'waiting' ? 'accepted' : curStatus;
        tx.update(ref, {'acceptedBy': accepted, 'status': newStatus});
      });
      if (mounted) setState(() => _phase = _Phase.waiting);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  Future<void> _declineSession() async {
    try {
      if (_sessionId != null) {
        await FirebaseFirestore.instance
            .collection(_collection)
            .doc(_sessionId)
            .update({'status': 'declined'});
      }
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cancelSession() async {
    try {
      if (_sessionId != null) {
        await FirebaseFirestore.instance
            .collection(_collection)
            .doc(_sessionId)
            .update({'status': 'cancelled'});
      }
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _startSession() async {
    if (_sessionId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_sessionId)
          .update({'status': 'started'});
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  void _startCountdown() {
    setState(() {
      _phase = _Phase.countdown;
      _countdown = _countdownFrom;
    });
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        _navigateToRoutine();
        return;
      }
      setState(() => _countdown--);
    });
  }

  void _navigateToRoutine() {
    if (!mounted) return;
    final sid = _sessionId ?? '';
    final extraData =
        (_sessionData['extraData'] as Map<String, dynamic>?) ?? {};
    final celebrantWord =
        extraData['celebrantWord'] as String? ?? '';
    final partnerName = _isInitiator
        ? (widget.partnerName ?? '')
        : (_sessionData['initiatorName'] as String? ?? '');
    final squadId =
        widget.squadId ?? (_sessionData['squadId'] as String? ?? '');
    final memberNames = widget.memberNames ??
        List<String>.from(_sessionData['memberNames'] ?? []);

    Widget? routine;
    switch (widget.routineKey) {
      case 'twin_coherence':
        routine = const TwinCoherence();
      case 'twin_coherence_rt':
        routine = TwinCoherenceRt(
            sessionId: sid,
            isInitiator: _isInitiator,
            partnerName: partnerName);
      case 'mirror_aura':
        routine = const MirrorAura();
      case 'silent_presence':
        routine = const SilentPresence();
      case 'pulse_match':
        routine = const PulseMatch();
      case 'duo_morning':
        routine = DuoMorning(sessionId: sid, partnerName: partnerName);
      case 'debrief_duo':
        routine = DebriefDuo(sessionId: sid, partnerName: partnerName);
      case 'night_tandem':
        routine = NightTandem(sessionId: sid, partnerName: partnerName);
      case 'savoring_duo':
        routine = SavoringDuo(sessionId: sid, partnerName: partnerName);
      case 'bio_ambient_duo':
        routine = BioAmbientDuo(
            sessionId: sid, partnerName: partnerName, calmAudioUrl: '');
      case 'collective_shield':
        routine = const CollectiveShield();
      case 'squad_pulse':
        routine = const SquadPulse();
      case 'squad_morning_pulse':
        routine = SquadMorningPulse(squadId: squadId);
      case 'squad_gratitude_garden':
        routine = SquadGratitudeGarden(squadId: squadId);
      case 'squad_celebration_wave':
        routine = SquadCelebrationWave(
          sessionId: sid,
          celebrantName: _isInitiator
              ? widget.myName
              : (_sessionData['initiatorName'] as String? ?? ''),
          celebrantWord: celebrantWord,
          isCelebrant: _isInitiator,
        );
      case 'squad_resonance':
        routine = SquadResonance(
          sessionId: sid,
          squadId: squadId,
          isInCrisis: _isInitiator,
          memberNames: memberNames,
        );
      case 'squad_night_watch':
        routine = SquadNightWatch(
          sessionId: sid,
          squadId: squadId,
          memberNames: memberNames,
        );
    }

    if (routine == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => routine!),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sessionSub?.cancel();
    _pulseCtrl.dispose();
    _celebrantWordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _Phase.error ||
          _phase == _Phase.invite ||
          _phase == _Phase.celebrantInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase == _Phase.waiting && _isInitiator) {
          _cancelSession();
        } else if (!didPop && _phase == _Phase.waiting && !_isInitiator) {
          _declineSession();
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _buildPhase(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    return switch (_phase) {
      _Phase.loading        => _buildLoading(),
      _Phase.celebrantInput => _buildCelebrantInput(),
      _Phase.invite         => _buildInvite(),
      _Phase.waiting        => _buildWaiting(),
      _Phase.countdown      => _buildCountdown(),
      _Phase.error          => _buildError(),
    };
  }

  Widget _buildLoading() => Column(
    key: const ValueKey('loading'),
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(width: 40, height: 40,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_teal))),
      const SizedBox(height: 20),
      Text('Préparation...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.40),
              fontSize: 15, fontFamily: 'Poppins')),
    ],
  );

  Widget _buildCelebrantInput() => Column(
    key: const ValueKey('celebrant'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(widget.routineTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Gelica', color: _ivory,
              fontSize: 22, fontWeight: FontWeight.w300)),
      const SizedBox(height: 32),
      const Text('Choisissez un mot qui vous représente pour cette célébration',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Poppins', color: _lila, fontSize: 14,
              height: 1.5)),
      const SizedBox(height: 20),
      TextField(
        controller: _celebrantWordCtrl,
        maxLength: _maxCelebrantWordLen,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _ivory, fontFamily: 'Poppins',
            fontSize: 18),
        decoration: InputDecoration(
          hintText: 'Victoire, Gratitude...',
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.25), fontFamily: 'Poppins'),
          counterStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.25)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _teal)),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 28),
      _primaryButton(
        label: 'Inviter le Squad',
        onPressed: _celebrantWordCtrl.text.trim().isNotEmpty
            ? _createSession
            : null,
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Annuler',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontFamily: 'Poppins')),
      ),
    ],
  );

  Widget _buildInvite() {
    final inviterName = _sessionData['initiatorName'] as String? ?? 'Quelqu\'un';
    return Column(
      key: const ValueKey('invite'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _teal.withValues(alpha: 0.12),
              border: Border.all(
                  color: _teal.withValues(alpha: 0.40), width: 1.5)),
          child: const Icon(Icons.person, color: _teal, size: 36),
        ),
        const SizedBox(height: 24),
        Text('$inviterName vous invite',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 14)),
        const SizedBox(height: 8),
        Text(widget.routineTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Gelica', color: _ivory,
                fontSize: 24, fontWeight: FontWeight.w300)),
        const SizedBox(height: 36),
        _primaryButton(label: 'Accepter', onPressed: _acceptSession),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _declineSession,
          child: Text('Refuser',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontFamily: 'Poppins')),
        ),
      ],
    );
  }

  Widget _buildWaiting() {
    final acceptedBy =
        List<String>.from(_sessionData['acceptedBy'] ?? []);
    final memberNames = List<String>.from(
        _sessionData['memberNames'] ?? (widget.memberNames ?? []));
    final memberUids = List<String>.from(
        _sessionData['memberUids'] ?? (widget.memberUids ?? []));
    final otherAccepted = acceptedBy.where((uid) => uid != _uid).toList();
    final canStart = _isInitiator && otherAccepted.isNotEmpty;

    // Build members list for squad
    final List<Widget> memberRows = [];
    if (widget.routineType == 'squad' && memberUids.isNotEmpty) {
      for (int i = 0; i < memberUids.length; i++) {
        final uid = i < memberUids.length ? memberUids[i] : '';
        final name = i < memberNames.length ? memberNames[i] : '';
        if (uid == _uid) continue;
        final accepted = acceptedBy.contains(uid);
        memberRows.add(_memberRow(name, accepted));
      }
    } else if (widget.routineType == 'twin') {
      final twinName = widget.partnerName
          ?? (_sessionData['twinName'] as String? ?? 'Votre twin');
      final twinUid = widget.twinUid
          ?? (_sessionData['users'] as List?)
              ?.firstWhere((u) => u != _uid, orElse: () => '') as String? ?? '';
      final accepted = acceptedBy.contains(twinUid);
      memberRows.add(_memberRow(twinName, accepted));
    }

    return Column(
      key: const ValueKey('waiting'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.routineTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Gelica', color: _ivory,
                fontSize: 22, fontWeight: FontWeight.w300)),
        const SizedBox(height: 8),
        Text(
          _isInitiator
              ? 'En attente de réponse...'
              : 'En attente que l\'initiateur démarre',
          style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 13),
        ),
        const SizedBox(height: 28),
        if (memberRows.isNotEmpty) ...[
          ...memberRows,
          const SizedBox(height: 28),
        ],
        if (_isInitiator) ...[
          _primaryButton(
            label: 'Commencer la routine',
            onPressed: canStart ? _startSession : null,
          ),
          if (!canStart)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Attendez qu\'au moins une personne accepte',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 12,
                    fontFamily: 'Poppins'),
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _cancelSession,
            child: Text('Annuler',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontFamily: 'Poppins')),
          ),
        ],
      ],
    );
  }

  Widget _buildCountdown() => Column(
    key: const ValueKey('countdown'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$_countdown',
        style: const TextStyle(
            fontFamily: 'Gelica', color: _teal,
            fontSize: 96, fontWeight: FontWeight.w200),
      ),
      const SizedBox(height: 16),
      Text('La routine commence...',
          style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 15)),
    ],
  );

  Widget _buildError() => Column(
    key: const ValueKey('error'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.error_outline,
          color: Colors.white.withValues(alpha: 0.35), size: 48),
      const SizedBox(height: 20),
      Text('Une erreur est survenue',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontFamily: 'Poppins', fontSize: 15)),
      if (_errorMsg.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_errorMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 11, fontFamily: 'Poppins')),
        ),
      const SizedBox(height: 24),
      _primaryButton(
          label: 'Retour',
          onPressed: () => Navigator.of(context).pop()),
    ],
  );

  Widget _memberRow(String name, bool accepted) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(
          accepted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: accepted ? _teal : Colors.white.withValues(alpha: 0.25),
          size: 18,
        ),
        const SizedBox(width: 12),
        Text(name,
            style: TextStyle(
                fontFamily: 'Poppins',
                color: accepted
                    ? _ivory
                    : Colors.white.withValues(alpha: 0.40),
                fontSize: 14)),
        const Spacer(),
        Text(
          accepted ? 'Prêt' : 'En attente',
          style: TextStyle(
              fontFamily: 'Poppins',
              color: accepted
                  ? _teal
                  : Colors.white.withValues(alpha: 0.25),
              fontSize: 12),
        ),
      ],
    ),
  );

  Widget _primaryButton(
      {required String label, required VoidCallback? onPressed}) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                onPressed != null ? _dark : Colors.white.withValues(alpha: 0.06),
            foregroundColor: _ivory,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32)),
            elevation: 0,
          ),
          child: Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
        ),
      );
}
