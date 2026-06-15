import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'squad_service.dart';
import 'routine_lobby.dart';

const _teal = Color(0xFF0DAABA);
const _dark = Color(0xFF065963);
const _bg   = Color(0xFF121212);

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  Map<String, dynamic>? _squad;
  String _myName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSquad();
  }

  Future<void> _loadSquad() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final results = await Future.wait([
        SquadService.getMySquad(),
        if (uid.isNotEmpty)
          FirebaseFirestore.instance.collection('users').doc(uid).get()
        else
          Future.value(null),
      ]);
      final squad  = results[0] as Map<String, dynamic>?;
      final myDoc  = results[1] as DocumentSnapshot?;
      if (mounted) {
        setState(() {
          _squad  = squad;
          _myName = (myDoc?.data() as Map<String, dynamic>?)?['prenom']
                      as String? ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Mon Squad',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _squad == null
              ? _NoSquadView(onSquadCreated: _loadSquad)
              : _HasSquadView(
                  squad: _squad!,
                  myName: _myName,
                  onLeft: _loadSquad,
                ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAS ENCORE DE SQUAD
// ══════════════════════════════════════════════════════════════════════════════

class _NoSquadView extends StatefulWidget {
  final VoidCallback onSquadCreated;
  const _NoSquadView({required this.onSquadCreated});

  @override
  State<_NoSquadView> createState() => _NoSquadViewState();
}

class _NoSquadViewState extends State<_NoSquadView> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      final r = await SquadService.searchUsers(_searchCtrl.text);
      if (mounted) setState(() => _results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _createSquad() async {
    final name = await _showNameDialog(context);
    if (name == null || name.trim().isEmpty) return;
    try {
      await SquadService.createSquad(name.trim());
      widget.onSquadCreated();
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: _teal));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        _PendingInvites(onAccepted: widget.onSquadCreated),
        const SizedBox(height: 28),
        Text('Créer un Squad',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Lance ton Squad et invite tes amies (2 à 5 membres).',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _createSquad,
            style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: Text('Créer mon Squad',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 36),
        const Divider(color: Colors.white12),
        const SizedBox(height: 24),
        Text('Rejoindre via une amie',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          'Cherche une amie par email ou prénom pour qu\'elle t\'invite.',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Email ou prénom...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _teal, width: 1.5)),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _teal))
                : const Icon(Icons.search, color: _teal),
          ),
        ]),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._results.map((u) => _UserTile(
                user: u,
                action: const Text('Profil trouvé',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 12)),
              )),
        ] else if (!_searching && _searchCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Aucun résultat.',
              style: GoogleFonts.poppins(color: Colors.white38)),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// A DÉJÀ UN SQUAD
// ══════════════════════════════════════════════════════════════════════════════

class _HasSquadView extends StatefulWidget {
  final Map<String, dynamic> squad;
  final String myName;
  final VoidCallback onLeft;
  const _HasSquadView({
    required this.squad,
    required this.myName,
    required this.onLeft,
  });

  @override
  State<_HasSquadView> createState() => _HasSquadViewState();
}

class _HasSquadViewState extends State<_HasSquadView> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  static const _routines = [
    {
      'icon': Icons.wb_sunny_outlined,
      'routineKey': 'squad_morning_pulse',
      'routineTitle': 'Morning Pulse',
      'sublabel': '3 min  •  Énergie du matin',
    },
    {
      'icon': Icons.favorite_border,
      'routineKey': 'squad_gratitude_garden',
      'routineTitle': 'Gratitude Garden',
      'sublabel': '5 min  •  Gratitude partagée',
    },
    {
      'icon': Icons.shield_outlined,
      'routineKey': 'collective_shield',
      'routineTitle': 'Collective Shield',
      'sublabel': '5 min  •  Protection collective',
    },
    {
      'icon': Icons.electric_bolt,
      'routineKey': 'squad_pulse',
      'routineTitle': 'Squad Pulse',
      'sublabel': '2 min  •  Synchronie d\'énergie',
    },
    {
      'icon': Icons.celebration_outlined,
      'routineKey': 'squad_celebration_wave',
      'routineTitle': 'Celebration Wave',
      'sublabel': '5 min  •  Célébrer ensemble',
    },
    {
      'icon': Icons.support_outlined,
      'routineKey': 'squad_resonance',
      'routineTitle': 'Squad Resonance',
      'sublabel': '8 min  •  Soutien en crise',
    },
    {
      'icon': Icons.nightlight_round,
      'routineKey': 'squad_night_watch',
      'routineTitle': 'Night Watch',
      'sublabel': '5 min  •  Veille nocturne',
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      final r = await SquadService.searchUsers(_searchCtrl.text);
      if (mounted) setState(() => _results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _invite(String toUid, String name) async {
    try {
      await SquadService.sendInvite(toUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Invitation envoyée à $name !'),
        backgroundColor: Colors.green.shade700,
      ));
      setState(() {
        _results = [];
        _searchCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: _teal));
    }
  }

  Future<void> _leaveSquad() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Quitter le Squad ?',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Text(
          'Tu devras être réinvité pour rejoindre un nouveau Squad.',
          style: GoogleFonts.poppins(color: Colors.white60),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quitter',
                  style: TextStyle(color: _teal))),
        ],
      ),
    );
    if (confirm != true) return;
    await SquadService.leaveSquad();
    widget.onLeft();
  }

  @override
  Widget build(BuildContext context) {
    final members = List<String>.from(widget.squad['users'] ?? []);
    final isFull  = members.length >= 5;
    final squadId = widget.squad['id'] as String;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        // Header squad
        Row(children: [
          Expanded(
              child: Text(
            widget.squad['name'] as String? ?? 'Mon Squad',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700),
          )),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _teal.withValues(alpha: 0.4)),
            ),
            child: Text('${members.length}/5',
                style: GoogleFonts.poppins(
                    color: _teal,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 20),

        // Sessions de routine en attente
        _SquadIncomingBanner(squadId: squadId, myName: widget.myName),

        // Membres
        Text('Membres',
            style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5)),
        const SizedBox(height: 10),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: SquadService.mySquadMembersStream(squadId),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const LinearProgressIndicator(color: _teal);
            }
            final list = snap.data!;
            return Column(
                children: list
                    .map((m) => _UserTile(
                          user: m,
                          action: m['uid'] == SquadService.currentUid
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _teal.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('Vous',
                                      style: GoogleFonts.poppins(
                                          color: _teal,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                )
                              : const SizedBox.shrink(),
                        ))
                    .toList());
          },
        ),

        const SizedBox(height: 28),

        // Routines
        Text('LANCER UNE ROUTINE',
            style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ..._routines.map((r) => _SquadRoutineTile(
              icon: r['icon'] as IconData,
              routineKey: r['routineKey'] as String,
              routineTitle: r['routineTitle'] as String,
              sublabel: r['sublabel'] as String,
              squadId: squadId,
              myName: widget.myName,
            )),

        const SizedBox(height: 28),

        // Inviter quelqu'un
        if (!isFull) ...[
          Text('Inviter une amie',
              style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Email ou prénom...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: _teal, width: 1.5)),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: _searching ? null : _search,
              icon: _searching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _teal))
                  : const Icon(Icons.search, color: _teal),
            ),
          ]),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._results.map((u) => _UserTile(
                  user: u,
                  action: TextButton(
                    onPressed: () => _invite(
                        u['uid'] as String,
                        u['prenom'] as String? ??
                            u['email'] as String? ?? '?'),
                    child: Text('Inviter',
                        style: GoogleFonts.poppins(
                            color: _teal,
                            fontWeight: FontWeight.w600)),
                  ),
                )),
          ],
          const SizedBox(height: 28),
        ],

        // Quitter
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _leaveSquad,
          icon: const Icon(Icons.exit_to_app,
              color: Colors.white38, size: 18),
          label: Text('Quitter le Squad',
              style: GoogleFonts.poppins(
                  color: Colors.white38, fontSize: 14)),
        ),
      ],
    );
  }
}

// ── Sessions entrantes squad ──────────────────────────────────────────────────

class _SquadIncomingBanner extends StatelessWidget {
  final String squadId;
  final String myName;
  const _SquadIncomingBanner({
    required this.squadId,
    required this.myName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: SquadService.incomingRoutineSessionsStream(squadId),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final incoming = snap.data!.docs.where((doc) {
          final data     = doc.data() as Map<String, dynamic>;
          final launched = data['launchedBy'] as String? ?? '';
          final accepted = List<String>.from(data['acceptedBy'] ?? []);
          return launched != currentUid && !accepted.contains(currentUid);
        }).toList();

        if (incoming.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('INVITATION REÇUE',
                style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            ...incoming.map((doc) {
              final data   = doc.data() as Map<String, dynamic>;
              final rKey   = data['routineKey']    as String? ?? '';
              final rTitle = data['routineTitle']  as String? ?? rKey;
              final from   = data['initiatorName'] as String? ?? 'Quelqu\'un';
              return _SquadIncomingCard(
                sessionId: doc.id,
                routineKey: rKey,
                routineTitle: rTitle,
                initiatorName: from,
                squadId: squadId,
                myName: myName,
              );
            }),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _SquadIncomingCard extends StatelessWidget {
  final String sessionId;
  final String routineKey;
  final String routineTitle;
  final String initiatorName;
  final String squadId;
  final String myName;

  const _SquadIncomingCard({
    required this.sessionId,
    required this.routineKey,
    required this.routineTitle,
    required this.initiatorName,
    required this.squadId,
    required this.myName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _teal.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.notifications_active,
            color: _teal.withValues(alpha: 0.80), size: 22),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(routineTitle,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            Text('$initiatorName t\'invite',
                style: GoogleFonts.poppins(
                    color: Colors.white54, fontSize: 12)),
          ],
        )),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoutineLobby(
                routineKey: routineKey,
                routineTitle: routineTitle,
                routineType: 'squad',
                myName: myName,
                existingSessionId: sessionId,
                squadId: squadId,
              ),
            ),
          ),
          style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
          child: Text('Rejoindre',
              style: GoogleFonts.poppins(
                  color: _teal,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      ]),
    );
  }
}

// ── Tuile routine squad ───────────────────────────────────────────────────────

class _SquadRoutineTile extends StatelessWidget {
  final IconData icon;
  final String routineKey;
  final String routineTitle;
  final String sublabel;
  final String squadId;
  final String myName;

  const _SquadRoutineTile({
    required this.icon,
    required this.routineKey,
    required this.routineTitle,
    required this.sublabel,
    required this.squadId,
    required this.myName,
  });

  Future<void> _launch(BuildContext context) async {
    try {
      // Load squad members at launch time
      final squadData = await SquadService.getMySquad();
      if (squadData == null || !context.mounted) return;

      final memberUids =
          List<String>.from(squadData['users'] ?? []);
      final memberDocs = await Future.wait(
        memberUids.map((uid) => FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()),
      );
      final memberNames = memberDocs
          .map((d) =>
              (d.data()?['prenom']) as String? ??
              '?')
          .toList();

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoutineLobby(
            routineKey: routineKey,
            routineTitle: routineTitle,
            routineType: 'squad',
            myName: myName,
            squadId: squadId,
            memberUids: memberUids,
            memberNames: memberNames,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: _teal));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _launch(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _teal.withValues(alpha: 0.15)),
                child: Icon(icon, color: _teal, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(routineTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12)),
                ],
              )),
              Icon(Icons.send,
                  color: _teal.withValues(alpha: 0.6), size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Invitations reçues (rejoindre un squad) ───────────────────────────────────

class _PendingInvites extends StatelessWidget {
  final VoidCallback onAccepted;
  const _PendingInvites({required this.onAccepted});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SquadService.myPendingInvitesStream(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final invites = snap.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invitations reçues',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...invites.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _teal.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['squadName'] as String? ?? 'Un Squad',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      Text('de ${data['fromName'] ?? '?'}',
                          style: GoogleFonts.poppins(
                              color: Colors.white54, fontSize: 13)),
                    ],
                  )),
                  TextButton(
                    onPressed: () => SquadService.declineInvite(doc.id),
                    child: Text('Refuser',
                        style: GoogleFonts.poppins(
                            color: Colors.white38, fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await SquadService.acceptInvite(
                            doc.id, data['squadId'] as String);
                        onAccepted();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: _teal));
                        }
                      }
                    },
                    child: Text('Rejoindre',
                        style: GoogleFonts.poppins(
                            color: _teal,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 8),
            const Divider(color: Colors.white12),
          ],
        );
      },
    );
  }
}

// ── Tuile utilisateur ─────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final Widget action;
  const _UserTile({required this.user, required this.action});

  @override
  Widget build(BuildContext context) {
    final name  = user['prenom'] as String? ?? '?';
    final email = user['email']  as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _teal.withValues(alpha: 0.2),
          child: Text(name[0].toUpperCase(),
              style: GoogleFonts.poppins(
                  color: _teal,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            Text(email,
                style: GoogleFonts.poppins(
                    color: Colors.white38, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ],
        )),
        action,
      ]),
    );
  }
}

// ── Dialog nom du squad ───────────────────────────────────────────────────────

Future<String?> _showNameDialog(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text('Nom de ton Squad',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Les Guerrières...',
          hintStyle: TextStyle(color: Colors.white38),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _teal)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Annuler',
              style: GoogleFonts.poppins(color: Colors.white38)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text('Créer',
              style: GoogleFonts.poppins(
                  color: _teal, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
