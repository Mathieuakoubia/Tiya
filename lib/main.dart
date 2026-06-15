import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'auth_screen.dart';
import 'biometric_test_screen.dart';
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
import 'squad_screen.dart';
import 'twin_screen.dart';
import 'morning_ritual.dart';
import 'widgets/aura_widget.dart';
import 'notification_service.dart';
import 'auth_service.dart';
// Nouvelles routines Phase 1-3
import 'reset_flash.dart';
import 'bio_ambient.dart';
import 'tap_sync.dart';
import 'infini_draw.dart';
import 'morning_ancrage.dart';
import 'end_of_day_release.dart';
import 'gratitude_flash.dart';
import 'decris_express.dart';
import 'oled_therapy.dart';
import 'audio_binaurale.dart';
import 'plexus_weight.dart';
import 'vagus_ear.dart';
import 'oculo_cardiaque.dart';
import 'readiness_check.dart';
import 'savoring_moment.dart';
import 'micro_celebration.dart';
import 'pensee_observee.dart';
import 'preparation_sommeil.dart';
import 'cocon_premenstruel.dart';
import 'vague_regles.dart';
import 'energie_ovulation.dart';
import 'between_two_worlds.dart';
import 'reveil_doux.dart';
import 'repos_yeux.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialise les notifs push dès que l'utilisateur est authentifié
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) NotificationService.init();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/Fonds-02.png'), context);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiyia MVP',
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      routes: {
        '/home':              (_) => const HomePage(),
        '/collective-shield': (_) => const CollectiveShield(),
        '/squad-pulse':       (_) => const SquadPulse(),
        '/morning-ritual':    (_) => const MorningRitual(),
        '/audio-capsule':     (_) => const AudioCapsule(),
        '/twin-coherence':    (_) => const TwinCoherence(),
        '/mirror-aura':       (_) => const MirrorAura(),
        '/silent-presence':   (_) => const SilentPresence(),
        '/pulse-match':       (_) => const PulseMatch(),
        // Nouvelles routines
        '/reset-flash':       (_) => const ResetFlash(),
        '/bio-ambient':       (_) => BioAmbient(audioUrl: ''),
        '/tap-sync':          (_) => const TapSync(),
        '/infini-draw':       (_) => const InfiniDraw(),
        '/morning-ancrage':   (_) => const MorningAncrage(),
        '/end-of-day':        (_) => const EndOfDayRelease(),
        '/gratitude-flash':   (_) => const GratitudeFlash(),
        '/decris-express':    (_) => const DecrisExpress(),
        '/oled-therapy':      (_) => const OledTherapy(),
        '/audio-binaurale':   (_) => AudioBinaurale(audioAlphaUrl: '', audioThetaUrl: ''),
        '/plexus-weight':     (_) => const PlexusWeight(),
        '/vagus-ear':         (_) => const VagusEar(),
        '/oculo-cardiaque':   (_) => const OculoCardiaque(),
        '/readiness-check':   (_) => const ReadinessCheck(),
        '/savoring-moment':   (_) => const SavoringMoment(),
        '/micro-celebration': (_) => const MicroCelebration(),
        '/pensee-observee':   (_) => const PenseeObservee(),
        '/prep-sommeil':      (_) => const PreparationSommeil(),
        '/cocon-premenstruel':(_) => const CoconPremenstruel(),
        '/vague-regles':      (_) => const VagueRegles(),
        '/energie-ovulation': (_) => const EnergieOvulation(),
        '/between-worlds':    (_) => const BetweenTwoWorlds(),
        '/reveil-doux':       (_) => const ReveilDoux(),
        '/repos-yeux':        (_) => const ReposYeux(),
        '/biometric-test':    (_) => const BiometricTestScreen(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Pousse la route en attente si l'app a été ouverte via une notification
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => NotificationService.flushPendingRoute());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tiyia — Prototypes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text('Se déconnecter ?',
                      style: TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Déconnexion',
                          style: TextStyle(color: Color(0xFF0DAABA))),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const AuthGate(),
                      transitionDuration: Duration.zero,
                    ),
                    (_) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: "DIAGNOSTIC", color: const Color(0xFF0DAABA)),
            const SizedBox(height: 14),
            _RoutineButton(
              icon: Icons.face,
              label: "Test Biométrie",
              sublabel: "6s caméra + 3s voix  •  Score Aura en direct",
              color: const Color(0xFF0DAABA),
              onTap: () => _push(context, const BiometricTestScreen()),
            ),
            const SizedBox(height: 28),
            _SectionHeader(label: "SEULE", color: const Color(0xFFD9CCE8)),
            const SizedBox(height: 14),
            _RoutineButton(
              icon: Icons.remove_red_eye,
              label: "Saccadic Reset",
              sublabel: "1 min 30  •  Nettoyage oculaire EMDR",
              color: const Color(0xFF0DAABA),
              onTap: () => _push(
                  context, const EyeMovementEMDR(baseSpeedDuration: 2000)),
            ),
            _RoutineButton(
              icon: Icons.fingerprint,
              label: "Le Pouce Apaisant",
              sublabel: "2 min  •  Résonance corporelle",
              color: const Color(0xFF0DAABA),
              onTap: () => _push(context, const SoothingThumb()),
            ),
            _RoutineButton(
              icon: Icons.delete_sweep_outlined,
              label: "Vide-Poubelle Mental",
              sublabel: "1 min 30  •  Décharge cognitive",
              color: const Color(0xFF065963),
              onTap: () => _push(context, const CognitiveSorting()),
            ),
            _RoutineButton(
              icon: Icons.auto_awesome,
              label: "Aura Cleaning",
              sublabel: "1 min  •  Reset visuel",
              color: const Color(0xFFD9CCE8),
              onTap: () => _push(context, const AuraCleaning()),
            ),
            const SizedBox(height: 28),
            _SectionHeader(label: "TWIN", color: const Color(0xFFE8B86E)),
            const SizedBox(height: 14),
            _RoutineButton(
              icon: Icons.favorite,
              label: "Mon Twin",
              sublabel: "10 routines  •  Invitations • Lobby",
              color: const Color(0xFFE8B86E),
              onTap: () => _push(context, const TwinScreen()),
            ),
            const SizedBox(height: 28),
            _SectionHeader(label: "SQUAD", color: const Color(0xFF065963)),
            const SizedBox(height: 14),
            _RoutineButton(
              icon: Icons.group,
              label: "Mon Squad",
              sublabel: "7 routines  •  Invitations • Lobby",
              color: const Color(0xFF065963),
              onTap: () => _push(context, const SquadScreen()),
            ),
            _RoutineButton(
              icon: Icons.headphones,
              label: "Audio Capsule",
              sublabel: "30 sec  •  Murmure de sécurité",
              color: const Color(0xFFE8B86E),
              onTap: () => _push(context, const AudioCapsule()),
            ),
            _RoutineButton(
              icon: Icons.wb_sunny,
              label: "Morning Ritual",
              sublabel: "2 min  •  Alignement du groupe",
              color: const Color(0xFFD9CCE8),
              onTap: () => _push(context, const MorningRitual()),
            ),
            const SizedBox(height: 28),
            _SectionHeader(label: "NOUVELLES SOLO P1", color: Color(0xFF0DAABA)),
            const SizedBox(height: 14),
            _RoutineButton(icon: Icons.sunny, label: "Reset Flash",
              sublabel: "3 min  •  Cohérence cardiaque", color: const Color(0xFF0DAABA),
              onTap: () => _push(context, const ResetFlash())),
            _RoutineButton(icon: Icons.music_note, label: "Bio-Ambient",
              sublabel: "3 min  •  Immersion sonore", color: const Color(0xFF0DAABA),
              onTap: () => _push(context, BioAmbient(audioUrl: ''))),
            _RoutineButton(icon: Icons.touch_app, label: "Tap Sync",
              sublabel: "1 min  •  Anti-rumination", color: const Color(0xFF065963),
              onTap: () => _push(context, const TapSync())),
            _RoutineButton(icon: Icons.all_inclusive, label: "Dessin Infini",
              sublabel: "2 min  •  Régulation sensorimotrice", color: const Color(0xFF065963),
              onTap: () => _push(context, const InfiniDraw())),
            _RoutineButton(icon: Icons.wb_sunny_outlined, label: "Morning Ancrage",
              sublabel: "90s  •  Intention du jour", color: const Color(0xFF0DAABA),
              onTap: () => _push(context, const MorningAncrage())),
            _RoutineButton(icon: Icons.nights_stay, label: "End of Day",
              sublabel: "3 min  •  Clôture de journée", color: const Color(0xFF065963),
              onTap: () => _push(context, const EndOfDayRelease())),
            _RoutineButton(icon: Icons.eco, label: "Gratitude Flash",
              sublabel: "90s  •  3 galets de gratitude", color: const Color(0xFF0DAABA),
              onTap: () => _push(context, const GratitudeFlash())),
            _RoutineButton(icon: Icons.local_fire_department, label: "Décrispation Express",
              sublabel: "90s  •  PMR 4 zones", color: const Color(0xFF065963),
              onTap: () => _push(context, const DecrisExpress())),
            const SizedBox(height: 28),
            _SectionHeader(label: "NOUVELLES SOLO P2", color: Color(0xFFE8B86E)),
            const SizedBox(height: 14),
            _RoutineButton(icon: Icons.lightbulb_outline, label: "OLED Therapy",
              sublabel: "2 min  •  Lumière 0.1Hz", color: const Color(0xFFE8B86E),
              onTap: () => _push(context, const OledTherapy())),
            _RoutineButton(icon: Icons.hearing, label: "Vagus Ear",
              sublabel: "90s  •  Stimulation nerf vague", color: const Color(0xFFE8B86E),
              onTap: () => _push(context, const VagusEar())),
            _RoutineButton(icon: Icons.remove_red_eye, label: "Oculo-Cardiaque",
              sublabel: "1 min  •  Réflexe oculo-cardiaque", color: const Color(0xFFE8B86E),
              onTap: () => _push(context, const OculoCardiaque())),
            _RoutineButton(icon: Icons.spa, label: "Plexus Weight",
              sublabel: "3 min  •  Pression profonde", color: const Color(0xFFE8B86E),
              onTap: () => _push(context, const PlexusWeight())),
            _RoutineButton(icon: Icons.calendar_today, label: "Readiness Check",
              sublabel: "2 min  •  Préparation mentale", color: const Color(0xFF065963),
              onTap: () => _push(context, const ReadinessCheck())),
            _RoutineButton(icon: Icons.star_border, label: "Savoring Moment",
              sublabel: "2 min  •  Capsule positive", color: const Color(0xFF065963),
              onTap: () => _push(context, const SavoringMoment())),
            _RoutineButton(icon: Icons.celebration, label: "Micro-Célébration",
              sublabel: "30s  •  Célébrer un succès", color: const Color(0xFFE8B86E),
              onTap: () => _push(context, const MicroCelebration())),
            _RoutineButton(icon: Icons.psychology, label: "Pensée Observée",
              sublabel: "2 min  •  Défusion cognitive ACT", color: const Color(0xFF065963),
              onTap: () => _push(context, const PenseeObservee())),
            _RoutineButton(icon: Icons.bedtime, label: "Préparation Sommeil",
              sublabel: "8 min  •  Rituel du soir", color: const Color(0xFF065963),
              onTap: () => _push(context, const PreparationSommeil())),
            const SizedBox(height: 28),
            _SectionHeader(label: "NOUVELLES SOLO P3", color: Color(0xFFD9CCE8)),
            const SizedBox(height: 14),
            _RoutineButton(icon: Icons.favorite_border, label: "Cocon Prémenstruel",
              sublabel: "3 min  •  Phase lutéale", color: const Color(0xFFD9CCE8),
              onTap: () => _push(context, const CoconPremenstruel())),
            _RoutineButton(icon: Icons.waves, label: "Vague de Règles",
              sublabel: "2 min  •  Deep pressure", color: const Color(0xFFD9CCE8),
              onTap: () => _push(context, const VagueRegles())),
            _RoutineButton(icon: Icons.bolt, label: "Énergie d'Ovulation",
              sublabel: "90s  •  Activation", color: const Color(0xFFF2631D),
              onTap: () => _push(context, const EnergieOvulation())),
            _RoutineButton(icon: Icons.swap_horiz, label: "Between Two Worlds",
              sublabel: "60s  •  Transition de contexte", color: const Color(0xFFD9CCE8),
              onTap: () => _push(context, const BetweenTwoWorlds())),
            _RoutineButton(icon: Icons.wb_twilight, label: "Réveil Doux",
              sublabel: "60s  •  Lever progressif", color: const Color(0xFFD9CCE8),
              onTap: () => _push(context, const ReveilDoux())),
            _RoutineButton(icon: Icons.visibility_off, label: "Repos Yeux",
              sublabel: "60s  •  Fatigue oculaire", color: const Color(0xFFD9CCE8),
              onTap: () => _push(context, const ReposYeux())),
            const SizedBox(height: 28),
            _SectionHeader(label: "DESIGN", color: Color(0xFFE8B86E)),
            const SizedBox(height: 14),
            _RoutineButton(
              icon: Icons.bubble_chart,
              label: "Aura Widget",
              sublabel: "Preview — bulle irisée animée",
              color: Color(0xFFE8B86E),
              onTap: () => _push(context, const _AuraPreviewPage()),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext ctx, Widget w) => Navigator.push(
        ctx,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => w,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
}

class _AuraPreviewPage extends StatelessWidget {
  const _AuraPreviewPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F3F2),
        foregroundColor: const Color(0xFF232323),
        elevation: 0,
        title: const Text("Aura"),
      ),
      body: const Center(
        child: AuraWidget(size: 320),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 4,
          height: 20,
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
                width: 44,
                height: 44,
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
