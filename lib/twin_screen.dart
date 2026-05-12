import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'twin_service.dart';
import 'twin_coherence.dart';
import 'mirror_aura.dart';
import 'silent_presence.dart';
import 'pulse_match.dart';

const _gold = Color(0xFFD4A853);
const _bg = Color(0xFF121212);
const _bordeaux = Color(0xFF0DAABA);

Widget _routineWidget(String name) {
  switch (name) {
    case 'Twin-Coherence':  return const TwinCoherence();
    case 'Mirror-Aura':     return const MirrorAura();
    case 'Silent-Presence': return const SilentPresence();
    case 'Pulse Match':     return const PulseMatch();
    default:                return const TwinCoherence();
  }
}

class TwinScreen extends StatefulWidget {
  const TwinScreen({super.key});

  @override
  State<TwinScreen> createState() => _TwinScreenState();
}

class _TwinScreenState extends State<TwinScreen> {
  Map<String, dynamic>? _twinProfile;
  Map<String, dynamic>? _matchedInvite;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final invite = await TwinService.getMyMatchedTwin();
    final profile = invite != null ? await TwinService.getMyTwinProfile() : null;
    if (mounted) {
      setState(() {
        _matchedInvite = invite;
        _twinProfile = profile;
        _loading = false;
      });
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
        title: Text('Mon Twin', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _twinProfile == null
              ? _NoTwinView(onMatched: _load)
              : _HasTwinView(
                  twin: _twinProfile!,
                  invite: _matchedInvite!,
                ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAS ENCORE DE TWIN — Invitations reçues + recherche
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
      setState(() => _results = r);
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
      setState(() { _results = []; _searchCtrl.clear(); });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _bordeaux));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        // Invitations de matching reçues
        _PendingMatchRequests(onAccepted: widget.onMatched),
        const SizedBox(height: 28),

        // Trouver un twin
        Text('Trouver un twin', style: GoogleFonts.poppins(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Cherche par email ou prénom et invite quelqu\'un à devenir ton twin.',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14, height: 1.5)),
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
                  borderSide: const BorderSide(color: _gold, width: 1.5)),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _gold))
                : const Icon(Icons.search, color: _gold),
          ),
        ]),

        if (_results.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._results.map((u) {
            final name = u['prenom'] as String? ?? u['email'] ?? '?';
            return _UserTile(
              user: u,
              action: TextButton(
                onPressed: () => _invite(u['uid'], name),
                child: Text('Inviter', style: GoogleFonts.poppins(
                  color: _gold, fontWeight: FontWeight.w600)),
              ),
            );
          }),
        ] else if (!_searching && _searchCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Aucun résultat.',
            style: GoogleFonts.poppins(color: Colors.white38)),
        ],
      ],
    );
  }
}

// Invitations de matching reçues (quelqu'un veut être ton twin)
class _PendingMatchRequests extends StatelessWidget {
  final VoidCallback onAccepted;
  const _PendingMatchRequests({required this.onAccepted});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: TwinService.myPendingTwinRequestsStream(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        // Filtre : uniquement les invitations reçues (pas envoyées par moi)
        final incoming = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['fromUid'] != TwinService.currentUid;
        }).toList();

        if (incoming.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demandes reçues', style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...incoming.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final fromUid = data['fromUid'] as String? ?? '';
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users').doc(fromUid).get(),
                builder: (_, userSnap) {
                  final userName = userSnap.hasData && userSnap.data!.exists
                      ? (userSnap.data!.data()
                          as Map<String, dynamic>)['prenom'] as String? ?? '?'
                      : '...';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: _gold.withValues(alpha: 0.2),
                        child: Text(userName[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: _gold, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName, style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                          Text('veut être ton twin',
                            style: GoogleFonts.poppins(
                              color: Colors.white54, fontSize: 12)),
                        ],
                      )),
                      TextButton(
                        onPressed: () async {
                          await TwinService.declineTwinRequest(doc.id);
                        },
                        child: Text('Refuser', style: GoogleFonts.poppins(
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
                                SnackBar(content: Text(e.toString()),
                                  backgroundColor: _bordeaux));
                            }
                          }
                        },
                        child: Text('Accepter', style: GoogleFonts.poppins(
                          color: _gold, fontWeight: FontWeight.w600,
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

// ══════════════════════════════════════════════════════════════════════════════
// TWIN MATCHÉ — Profil + sessions en attente + routines à lancer
// ══════════════════════════════════════════════════════════════════════════════

class _HasTwinView extends StatelessWidget {
  final Map<String, dynamic> twin;
  final Map<String, dynamic> invite;
  const _HasTwinView({required this.twin, required this.invite});

  static const _routines = [
    {'icon': Icons.favorite,      'name': 'Twin-Coherence',
     'sublabel': '3 min  •  Fusion des souffles'},
    {'icon': Icons.electric_bolt, 'name': 'Mirror-Aura',
     'sublabel': '2 min  •  Don d\'énergie'},
    {'icon': Icons.water,         'name': 'Silent-Presence',
     'sublabel': '5 min  •  Silence partagé'},
    {'icon': Icons.flash_on,      'name': 'Pulse Match',
     'sublabel': '1 min 30  •  Contact à distance'},
  ];

  @override
  Widget build(BuildContext context) {
    final inviteId = invite['id'] as String;
    final twinUid = twin['uid'] as String;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        _TwinCard(twin: twin),
        const SizedBox(height: 28),

        // Sessions de routine en attente (lancées par le twin)
        _IncomingSessionBanner(inviteId: inviteId),

        Text('LANCER UNE ROUTINE', style: GoogleFonts.poppins(
          color: Colors.white54, fontSize: 12,
          fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ..._routines.map((r) => _RoutineTile(
          icon: r['icon'] as IconData,
          name: r['name'] as String,
          sublabel: r['sublabel'] as String,
          twinUid: twinUid,
          inviteId: inviteId,
        )),
      ],
    );
  }
}

// ── Carte twin matché ─────────────────────────────────────────────────────────

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
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: _gold.withValues(alpha: 0.2),
          child: Text(name[0].toUpperCase(), style: GoogleFonts.poppins(
            color: _gold, fontSize: 24, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              Container(width: 8, height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: _gold)),
              const SizedBox(width: 6),
              Text('Ton twin', style: GoogleFonts.poppins(
                color: _gold, fontSize: 13)),
            ]),
          ],
        )),
        const Icon(Icons.favorite, color: _gold, size: 22),
      ]),
    );
  }
}

// ── Sessions de routine reçues (bannière) ─────────────────────────────────────

class _IncomingSessionBanner extends StatelessWidget {
  final String inviteId;
  const _IncomingSessionBanner({required this.inviteId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: TwinService.pendingTwinSessionsStream(inviteId),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final incoming = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['launchedBy'] != TwinService.currentUid;
        }).toList();

        if (incoming.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('INVITATION REÇUE', style: GoogleFonts.poppins(
              color: Colors.white54, fontSize: 12,
              fontWeight: FontWeight.w600, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            ...incoming.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _IncomingSessionCard(sessionId: doc.id, data: data);
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _IncomingSessionCard extends StatelessWidget {
  final String sessionId;
  final Map<String, dynamic> data;
  const _IncomingSessionCard({required this.sessionId, required this.data});

  @override
  Widget build(BuildContext context) {
    final routineName = data['routineName'] as String? ?? 'Routine';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.notifications_active, color: _gold, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invitation à $routineName', style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            Text('Ton twin t\'invite à cette routine maintenant',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
          ],
        )),
        const SizedBox(width: 8),
        Column(children: [
          TextButton(
            onPressed: () async {
              try {
                await TwinService.acceptTwinSession(sessionId);
                if (!context.mounted) return;
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _routineWidget(routineName)));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: _bordeaux));
              }
            },
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            child: Text('Rejoindre', style: GoogleFonts.poppins(
              color: _gold, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => TwinService.declineTwinSession(sessionId),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            child: Text('Refuser', style: GoogleFonts.poppins(
              color: Colors.white38, fontSize: 12)),
          ),
        ]),
      ]),
    );
  }
}

// ── Tuile routine à lancer ────────────────────────────────────────────────────

class _RoutineTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String sublabel;
  final String twinUid;
  final String inviteId;
  const _RoutineTile({
    required this.icon, required this.name, required this.sublabel,
    required this.twinUid, required this.inviteId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _launch(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.15)),
                child: Icon(icon, color: _gold, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sublabel, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                ],
              )),
              Icon(Icons.send, color: _gold.withValues(alpha: 0.6), size: 18),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _launch(BuildContext context) async {
    try {
      final sessionId =
          await TwinService.startTwinSession(twinUid, inviteId, name);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _WaitingDialog(sessionId: sessionId, routineName: name),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _bordeaux));
    }
  }
}

// ── Dialog d'attente côté lanceur ─────────────────────────────────────────────

class _WaitingDialog extends StatefulWidget {
  final String sessionId;
  final String routineName;
  const _WaitingDialog({required this.sessionId, required this.routineName});

  @override
  State<_WaitingDialog> createState() => _WaitingDialogState();
}

class _WaitingDialogState extends State<_WaitingDialog> {
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: TwinService.sessionStream(widget.sessionId),
      builder: (_, snap) {
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String?;

          if (status == 'active' && !_navigated) {
            _navigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _routineWidget(widget.routineName)));
              }
            });
          }

          if (status == 'declined') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).pop();
            });
            return _shell(child: Text('Ton twin a refusé.',
              style: GoogleFonts.poppins(
                color: Colors.redAccent, fontSize: 16,
                fontWeight: FontWeight.w600)));
          }
        }

        return _shell(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: _gold, strokeWidth: 2),
          const SizedBox(height: 20),
          Text('En attente de ton twin...', style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Invitation envoyée pour ${widget.routineName}',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
        ]));
      },
    );
  }

  Widget _shell({required Widget child}) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          child,
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler', style: GoogleFonts.poppins(
              color: Colors.white38, fontSize: 13)),
          ),
        ]),
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
    final name = user['prenom'] as String? ?? '?';
    final email = user['email'] as String? ?? '';
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
          child: Text(name[0].toUpperCase(), style: GoogleFonts.poppins(
            color: _gold, fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600)),
            Text(email, style: GoogleFonts.poppins(
              color: Colors.white38, fontSize: 12),
              overflow: TextOverflow.ellipsis),
          ],
        )),
        action,
      ]),
    );
  }
}
