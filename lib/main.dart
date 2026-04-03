import 'package:flutter/material.dart';
import 'emdr_widget.dart';
import 'soothing_thumb.dart';
import 'cognitive_sorting.dart';
import 'aura_cleaning.dart';
import 'twin_coherence.dart';
import 'mirror_aura.dart';
import 'silent_presence.dart';
import 'pulse_match.dart';
import 'collective_shield.dart';
import 'audio_capsule.dart';
import 'squad_pulse.dart';
import 'morning_ritual.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiyia MVP',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tiyia — Prototypes")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: "SEULE", color: const Color(0xFF82667F)),
            const SizedBox(height: 14),
            _RoutineButton(
              icon: Icons.remove_red_eye,
              label: "Saccadic Reset",
              sublabel: "1 min 30  •  Nettoyage oculaire EMDR",
              color: Colors.blueAccent,
              onTap: () => _push(context,
                  const EyeMovementEMDR(baseSpeedDuration: 2000)),
            ),
            _RoutineButton(
              icon: Icons.fingerprint,
              label: "Le Pouce Apaisant",
              sublabel: "2 min  •  Résonance corporelle",
              color: Colors.teal,
              onTap: () => _push(context, const SoothingThumb()),
            ),
            _RoutineButton(
              icon: Icons.delete_sweep_outlined,
              label: "Vide-Poubelle Mental",
              sublabel: "1 min 30  •  Décharge cognitive",
              color: const Color(0xFF735983),
              onTap: () => _push(context, const CognitiveSorting()),
            ),
            _RoutineButton(
              icon: Icons.auto_awesome,
              label: "Aura Cleaning",
              sublabel: "1 min  •  Reset visuel",
              color: const Color(0xFF82667F),
              onTap: () => _push(context, const AuraCleaning()),
            ),

            const SizedBox(height: 28),

            _SectionHeader(label: "TWIN", color: const Color(0xFFD4A853)),
            const SizedBox(height: 14),
            _RoutineButton(
              icon: Icons.favorite,
              label: "Twin-Coherence",
              sublabel: "3 min  •  Fusion des souffles",
              color: const Color(0xFFD4A853),
              onTap: () => _push(context, const TwinCoherence()),
            ),
            _RoutineButton(
              icon: Icons.electric_bolt,
              label: "Mirror-Aura",
              sublabel: "2 min  •  Don d'énergie",
              color: const Color(0xFFE91E8C),
              onTap: () => _push(context, const MirrorAura()),
            ),
            _RoutineButton(
              icon: Icons.water,
              label: "Silent-Presence",
              sublabel: "5 min  •  Silence partagé",
              color: const Color(0xFF00BCD4),
              onTap: () => _push(context, const SilentPresence()),
            ),
            _RoutineButton(
              icon: Icons.flash_on,
              label: "Pulse Match",
              sublabel: "1 min 30  •  Contact à distance",
              color: const Color(0xFFFF5722),
              onTap: () => _push(context, const PulseMatch()),
            ),

            const SizedBox(height: 28),

            _SectionHeader(label: "SQUAD", color: const Color(0xFF3F51B5)),
            const SizedBox(height: 14),
            _RoutineButton(
              icon: Icons.shield,
              label: "Collective Shield",
              sublabel: "2 min  •  Protection groupée",
              color: const Color(0xFF3F51B5),
              onTap: () => _push(context, const CollectiveShield()),
            ),
            _RoutineButton(
              icon: Icons.headphones,
              label: "Audio Capsule",
              sublabel: "30 sec  •  Murmure de sécurité",
              color: const Color(0xFFFF8F00),
              onTap: () => _push(context, const AudioCapsule()),
            ),
            _RoutineButton(
              icon: Icons.people,
              label: "Squad Pulse",
              sublabel: "1 min  •  Partage d'énergie",
              color: const Color(0xFF4CAF50),
              onTap: () => _push(context, const SquadPulse()),
            ),
            _RoutineButton(
              icon: Icons.wb_sunny,
              label: "Morning Ritual",
              sublabel: "2 min  •  Alignement du groupe",
              color: const Color(0xFF9C27B0),
              onTap: () => _push(context, const MorningRitual()),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext ctx, Widget w) =>
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => w));
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4, height: 20,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.5)),
    ]);
  }
}

class _RoutineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  const _RoutineButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
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
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.25), size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}
