import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'squad_service.dart';

const _bordeaux = Color(0xFF0DAABA);
const _bg = Color(0xFF121212);

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  Map<String, dynamic>? _squad;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSquad();
  }

  Future<void> _loadSquad() async {
    final squad = await SquadService.getMySquad();
    if (mounted) setState(() { _squad = squad; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Mon Squad', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _bordeaux))
          : _squad == null
              ? _NoSquadView(onSquadCreated: _loadSquad)
              : _HasSquadView(squad: _squad!, onLeft: _loadSquad),
    );
  }
}

// ── Pas encore de squad ───────────────────────────────────────────────────────

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
      setState(() => _results = r);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _bordeaux),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        // Invitations reçues
        _PendingInvites(onAccepted: widget.onSquadCreated),
        const SizedBox(height: 28),

        // Créer un squad
        Text('Créer un Squad', style: GoogleFonts.poppins(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Lance ton Squad et invite tes amies (2 à 5 membres).',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _createSquad,
            style: ElevatedButton.styleFrom(
              backgroundColor: _bordeaux,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: Text('Créer mon Squad', style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 36),
        const Divider(color: Colors.white12),
        const SizedBox(height: 24),

        // Chercher une amie
        Text('Rejoindre via une amie', style: GoogleFonts.poppins(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Cherche une amie par email ou prénom pour qu\'elle t\'invite.',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
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
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _bordeaux, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _bordeaux))
                : const Icon(Icons.search, color: _bordeaux),
          ),
        ]),

        if (_results.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._results.map((u) => _UserTile(
            user: u,
            action: const Text('Profil trouvé', style: TextStyle(color: Colors.white38, fontSize: 12)),
          )),
        ] else if (!_searching && _searchCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Aucun résultat.', style: GoogleFonts.poppins(color: Colors.white38)),
        ],
      ],
    );
  }
}

// ── A déjà un squad ───────────────────────────────────────────────────────────

class _HasSquadView extends StatefulWidget {
  final Map<String, dynamic> squad;
  final VoidCallback onLeft;
  const _HasSquadView({required this.squad, required this.onLeft});

  @override
  State<_HasSquadView> createState() => _HasSquadViewState();
}

class _HasSquadViewState extends State<_HasSquadView> {
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
      setState(() => _results = r);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _invite(String toUid, String name) async {
    try {
      await SquadService.sendInvite(toUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation envoyée à $name !'),
          backgroundColor: Colors.green.shade700),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _bordeaux),
      );
    }
  }

  Future<void> _leaveSquad() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Quitter le Squad ?',
          style: GoogleFonts.poppins(color: Colors.white)),
        content: Text('Tu devras être réinvité pour rejoindre un nouveau Squad.',
          style: GoogleFonts.poppins(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter', style: TextStyle(color: _bordeaux))),
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
    final isFull = members.length >= 5;
    final squadId = widget.squad['id'] as String;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        // Nom du squad + badge membres
        Row(children: [
          Expanded(child: Text(widget.squad['name'] ?? 'Mon Squad',
            style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _bordeaux.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _bordeaux.withValues(alpha: 0.4)),
            ),
            child: Text('${members.length}/5',
              style: GoogleFonts.poppins(color: _bordeaux,
                fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 24),

        // Membres en temps réel
        Text('Membres', style: GoogleFonts.poppins(
          color: Colors.white54, fontSize: 12,
          fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: SquadService.mySquadMembersStream(squadId),
          builder: (_, snap) {
            if (!snap.hasData) return const LinearProgressIndicator(color: _bordeaux);
            final list = snap.data!;
            return Column(children: list.map((m) => _UserTile(
              user: m,
              action: m['uid'] == SquadService.currentUid
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _bordeaux.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Vous', style: GoogleFonts.poppins(
                        color: _bordeaux, fontSize: 11, fontWeight: FontWeight.w600)),
                    )
                  : const SizedBox.shrink(),
            )).toList());
          },
        ),

        const SizedBox(height: 28),

        // Inviter quelqu'un (si pas plein)
        if (!isFull) ...[
          Text('Inviter une amie', style: GoogleFonts.poppins(
            color: Colors.white54, fontSize: 12,
            fontWeight: FontWeight.w600, letterSpacing: 1.5)),
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
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _bordeaux, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: _searching ? null : _search,
              icon: _searching
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _bordeaux))
                  : const Icon(Icons.search, color: _bordeaux),
            ),
          ]),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._results.map((u) => _UserTile(
              user: u,
              action: TextButton(
                onPressed: () => _invite(u['uid'], u['prenom'] ?? u['email'] ?? '?'),
                child: Text('Inviter', style: GoogleFonts.poppins(
                  color: _bordeaux, fontWeight: FontWeight.w600)),
              ),
            )),
          ],
          const SizedBox(height: 28),
        ],

        // Quitter le squad
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _leaveSquad,
          icon: const Icon(Icons.exit_to_app, color: Colors.white38, size: 18),
          label: Text('Quitter le Squad',
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 14)),
        ),
      ],
    );
  }
}

// ── Invitations reçues ────────────────────────────────────────────────────────

class _PendingInvites extends StatelessWidget {
  final VoidCallback onAccepted;
  const _PendingInvites({required this.onAccepted});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SquadService.myPendingInvitesStream(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
        final invites = snap.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invitations reçues', style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...invites.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _bordeaux.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _bordeaux.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['squadName'] ?? 'Un Squad',
                        style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                      Text('de ${data['fromName'] ?? '?'}',
                        style: GoogleFonts.poppins(
                          color: Colors.white54, fontSize: 13)),
                    ],
                  )),
                  TextButton(
                    onPressed: () async {
                      await SquadService.declineInvite(doc.id);
                    },
                    child: Text('Refuser', style: GoogleFonts.poppins(
                      color: Colors.white38, fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await SquadService.acceptInvite(doc.id, data['squadId']);
                        onAccepted();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()),
                              backgroundColor: _bordeaux),
                          );
                        }
                      }
                    },
                    child: Text('Rejoindre', style: GoogleFonts.poppins(
                      color: _bordeaux, fontWeight: FontWeight.w600, fontSize: 13)),
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
          backgroundColor: _bordeaux.withValues(alpha: 0.2),
          child: Text(name[0].toUpperCase(),
            style: GoogleFonts.poppins(
              color: _bordeaux, fontWeight: FontWeight.w700, fontSize: 16)),
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

// ── Dialog nom du squad ───────────────────────────────────────────────────────

Future<String?> _showNameDialog(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text('Nom de ton Squad',
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Ex: Les Guerrières ⚡',
          hintStyle: TextStyle(color: Colors.white38),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _bordeaux)),
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
              color: _bordeaux, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
