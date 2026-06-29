import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'twin_service.dart';
import 'routine_lobby.dart';

const _gold     = Color(0xFFD4A853);
const _bg       = Color(0xFF121212);
const _teal     = Color(0xFF0DAABA);

class TwinScreen extends StatefulWidget {
  const TwinScreen({super.key});

  @override
  State<TwinScreen> createState() => _TwinScreenState();
}

class _TwinScreenState extends State<TwinScreen> {
  Map<String, dynamic>? _twinProfile;
  Map<String, dynamic>? _matchedInvite;
  String _myName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final futures = await Future.wait([
        TwinService.getMyMatchedTwin(),
        if (uid.isNotEmpty)
          FirebaseFirestore.instance.collection('users').doc(uid).get()
        else
          Future.value(null),
      ]);
      final invite = futures[0] as Map<String, dynamic>?;
      final myDoc  = futures[1] as DocumentSnapshot?;
      final profile = invite != null ? await TwinService.getMyTwinProfile() : null;
      if (mounted) {
        setState(() {
          _matchedInvite = invite;
          _twinProfile   = profile;
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
        title: Text('Mon Twin',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _twinProfile == null
              ? _NoTwinView(onMatched: _load)
              : _HasTwinView(
                  twin: _twinProfile!,
                  invite: _matchedInvite!,
                  myName: _myName,
                ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAS ENCORE DE TWIN
// ══════════════════════════════════════════════════════════════════════════════

class _NoTwinView extends StatefulWidget {
  final VoidCallback onMatched;
  const _NoTwinView({required this.onMatched});

  @override
  State<_NoTwinView> createState() => _NoTwinViewState();
}

class _NoTwinViewState extends State<_NoTwinView> {
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
      final r = await TwinService.searchUsers(_searchCtrl.text);
      if (mounted) setState(() => _results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _invite(String toUid, String name) async {
    try {
      await TwinService.sendTwinRequest(toUid);
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        _PendingMatchRequests(onAccepted: widget.onMatched),
        const SizedBox(height: 28),
        Text('Trouver un twin',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          'Cherche par email ou prénom et invite quelqu\'un à devenir ton twin.',
          style: GoogleFonts.poppins(
              color: Colors.white54, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 20),
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
                        const BorderSide(color: _gold, width: 1.5)),
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
                        strokeWidth: 2, color: _gold))
                : const Icon(Icons.search, color: _gold),
          ),
        ]),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._results.map((u) {
            final name =
                u['prenom'] as String? ?? u['email'] as String? ?? '?';
            return _UserTile(
              user: u,
              action: TextButton(
                onPressed: () => _invite(u['uid'] as String, name),
                child: Text('Inviter',
                    style: GoogleFonts.poppins(
                        color: _gold, fontWeight: FontWeight.w600)),
              ),
            );
          }),
        ] else if (!_searching && _searchCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Aucun résultat.',
              style: GoogleFonts.poppins(color: Colors.white38)),
        ],
        const SizedBox(height: 32),
        const Divider(color: Colors.white12),
        const SizedBox(height: 20),
        Text('ROUTINES DISPONIBLES',
            style: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text('Invite un twin pour les débloquer.',
            style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12)),
        const SizedBox(height: 14),
        ..._HasTwinView._routines.map((r) => _LockedRoutineTile(
              icon: r['icon'] as IconData,
              routineTitle: r['routineTitle'] as String,
              sublabel: r['sublabel'] as String,
            )),
      ],
    );
  }
}

class _PendingMatchRequests extends StatelessWidget {
  final VoidCallback onAccepted;
  const _PendingMatchRequests({required this.onAccepted});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: TwinService.myPendingTwinRequestsStream(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final incoming = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['fromUid'] != TwinService.currentUid;
        }).toList();
        if (incoming.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demandes reçues',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...incoming.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final fromUid = data['fromUid'] as String? ?? '';
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(fromUid)
                    .get(),
                builder: (_, userSnap) {
                  final userName = userSnap.hasData && userSnap.data!.exists
                      ? (userSnap.data!.data()
                              as Map<String, dynamic>)['prenom']
                          as String? ?? '?'
                      : '...';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: _gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: _gold.withValues(alpha: 0.2),
                        child: Text(userName[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                                color: _gold,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName,
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          Text('veut être ton twin',
                              style: GoogleFonts.poppins(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      )),
                      TextButton(
                        onPressed: () =>
                            TwinService.declineTwinRequest(doc.id),
                        child: Text('Refuser',
                            style: GoogleFonts.poppins(
                                color: Colors.white38, fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await TwinService.acceptTwinRequest(doc.id);
                            onAccepted();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(e.toString()),
                                      backgroundColor: _teal));
                            }
                          }
                        },
                        child: Text('Accepter',
                            style: GoogleFonts.poppins(
                                color: _gold,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ]),
                  );
                },
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

class _LockedRoutineTile extends StatelessWidget {
  final IconData icon;
  final String routineTitle;
  final String sublabel;
  const _LockedRoutineTile({
    required this.icon,
    required this.routineTitle,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05)),
            child: Icon(icon, color: Colors.white24, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(routineTitle,
                  style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: GoogleFonts.poppins(
                      color: Colors.white24, fontSize: 11)),
            ],
          )),
          const Icon(Icons.lock_outline, color: Colors.white24, size: 16),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TWIN MATCHÉ
// ══════════════════════════════════════════════════════════════════════════════

class _HasTwinView extends StatelessWidget {
  final Map<String, dynamic> twin;
  final Map<String, dynamic> invite;
  final String myName;
  const _HasTwinView({
    required this.twin,
    required this.invite,
    required this.myName,
  });

  static const _routines = [
    {
      'icon': Icons.air,
      'routineKey': 'twin_coherence_rt',
      'routineTitle': 'Cohérence Twin',
      'sublabel': '5 min  •  Synchronie respiratoire',
    },
    {
      'icon': Icons.electric_bolt,
      'routineKey': 'mirror_aura',
      'routineTitle': 'Mirror Aura',
      'sublabel': '2 min  •  Don d\'énergie',
    },
    {
      'icon': Icons.water,
      'routineKey': 'silent_presence',
      'routineTitle': 'Silent Presence',
      'sublabel': '5 min  •  Silence partagé',
    },
    {
      'icon': Icons.flash_on,
      'routineKey': 'pulse_match',
      'routineTitle': 'Pulse Match',
      'sublabel': '1 min 30  •  Contact à distance',
    },
    {
      'icon': Icons.wb_sunny_outlined,
      'routineKey': 'duo_morning',
      'routineTitle': 'Duo Morning',
      'sublabel': '5 min  •  Rituel du matin ensemble',
    },
    {
      'icon': Icons.chat_bubble_outline,
      'routineKey': 'debrief_duo',
      'routineTitle': 'Debrief Duo',
      'sublabel': '5 min  •  Partage de la journée',
    },
    {
      'icon': Icons.nightlight_round,
      'routineKey': 'night_tandem',
      'routineTitle': 'Night Tandem',
      'sublabel': '3 min  •  Endormissement synchronisé',
    },
    {
      'icon': Icons.spa_outlined,
      'routineKey': 'savoring_duo',
      'routineTitle': 'Savoring Duo',
      'sublabel': '3 min  •  Savourer un moment',
    },
    {
      'icon': Icons.waves,
      'routineKey': 'bio_ambient_duo',
      'routineTitle': 'Bio Ambient Duo',
      'sublabel': '8 min  •  Cohérence cardiaque guidée',
    },
    {
      'icon': Icons.favorite,
      'routineKey': 'twin_coherence',
      'routineTitle': 'Twin Cohérence',
      'sublabel': '3 min  •  Fusion des souffles',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final inviteId = invite['id'] as String;
    final twinUid  = twin['uid'] as String;
    final twinName = twin['prenom'] as String? ?? 'Twin';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        _TwinCard(twin: twin),
        const SizedBox(height: 20),
        _IncomingSessionBanner(
          twinUid: twinUid,
          inviteId: inviteId,
          twinName: twinName,
          myName: myName,
        ),
        Text('LANCER UNE ROUTINE',
            style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ..._routines.map((r) => _RoutineTile(
              icon: r['icon'] as IconData,
              routineKey: r['routineKey'] as String,
              routineTitle: r['routineTitle'] as String,
              sublabel: r['sublabel'] as String,
              twinUid: twinUid,
              inviteId: inviteId,
              twinName: twinName,
              myName: myName,
            )),
      ],
    );
  }
}

class _TwinCard extends StatelessWidget {
  final Map<String, dynamic> twin;
  const _TwinCard({required this.twin});

  @override
  Widget build(BuildContext context) {
    final name = twin['prenom'] as String? ?? '?';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_gold.withValues(alpha: 0.15), _gold.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: _gold.withValues(alpha: 0.2),
          child: Text(name[0].toUpperCase(),
              style: GoogleFonts.poppins(
                  color: _gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 16),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: _gold)),
              const SizedBox(width: 6),
              Text('Ton twin',
                  style: GoogleFonts.poppins(color: _gold, fontSize: 13)),
            ]),
          ],
        )),
        const Icon(Icons.favorite, color: _gold, size: 22),
      ]),
    );
  }
}

// ── Bannière sessions entrantes ───────────────────────────────────────────────

class _IncomingSessionBanner extends StatelessWidget {
  final String twinUid;
  final String inviteId;
  final String twinName;
  final String myName;

  const _IncomingSessionBanner({
    required this.twinUid,
    required this.inviteId,
    required this.twinName,
    required this.myName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: TwinService.incomingRoutineSessionsStream(),
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
              return _IncomingCard(
                sessionId: doc.id,
                routineKey: rKey,
                routineTitle: rTitle,
                initiatorName: from,
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

class _IncomingCard extends StatelessWidget {
  final String sessionId;
  final String routineKey;
  final String routineTitle;
  final String initiatorName;
  final String myName;

  const _IncomingCard({
    required this.sessionId,
    required this.routineKey,
    required this.routineTitle,
    required this.initiatorName,
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
                routineType: 'twin',
                myName: myName,
                existingSessionId: sessionId,
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

// ── Tuile routine ─────────────────────────────────────────────────────────────

class _RoutineTile extends StatelessWidget {
  final IconData icon;
  final String routineKey;
  final String routineTitle;
  final String sublabel;
  final String twinUid;
  final String inviteId;
  final String twinName;
  final String myName;

  const _RoutineTile({
    required this.icon,
    required this.routineKey,
    required this.routineTitle,
    required this.sublabel,
    required this.twinUid,
    required this.inviteId,
    required this.twinName,
    required this.myName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoutineLobby(
                routineKey: routineKey,
                routineTitle: routineTitle,
                routineType: 'twin',
                myName: myName,
                twinUid: twinUid,
                twinInviteId: inviteId,
                partnerName: twinName,
              ),
            ),
          ),
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
                    color: _gold.withValues(alpha: 0.15)),
                child: Icon(icon, color: _gold, size: 22),
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
                  color: _gold.withValues(alpha: 0.6), size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Tuile utilisateur générique ───────────────────────────────────────────────

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
          backgroundColor: _gold.withValues(alpha: 0.15),
          child: Text(name[0].toUpperCase(),
              style: GoogleFonts.poppins(
                  color: _gold,
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
