# Vérification des 53 routines — SOZIA

## Charte graphique de référence

**Couleurs autorisées :**
| Nom | Hex | Usage |
|-----|-----|-------|
| Turquoise | `#0DAABA` | Couleur principale, accents |
| Bleu pétrole | `#065963` | Boutons, fond secondaire |
| Lila | `#D9CCE8` | Routines douces, phases féminines |
| Ivoire | `#F8F1E9` | Texte sur fond clair |
| Gold | `#E8B86E` | Timers, récompenses, succès |
| Fond | `#121212` | Background de toutes les routines |

**Typographie :**
| Usage | Police | Style |
|-------|--------|-------|
| Titre principal | Gelica | SemiBold — MAJUSCULES |
| Titre secondaire | Poppins | SemiBold |
| Sous-titre | Gelica | Regular |
| Corps de texte | Poppins | Medium — minuscule |
| Texte secondaire | Playfair | Medium Italic — minuscule |

**Règle générale :** fond `#121212` pour toutes les routines. Boutons avec `backgroundColor: #065963`, `foregroundColor: white`, `borderRadius: 30`, `elevation: 0`.

---

## Checklist design commune (à vérifier sur TOUTE routine)
- [ ] Fond `#121212`
- [ ] Couleurs d'accent dans la palette officielle
- [ ] Texte principal en Gelica (italic/light pour phrases Aria)
- [ ] Timer en gold `#E8B86E` taille 14
- [ ] Bouton "Continuer" fond `#065963`
- [ ] Pas de couleurs hors palette (pas de orange pur, rouge, brun)

---

## Routines classées de la plus complexe à la moins complexe

---

### TIER 1 — TRÈS COMPLEXE ★★★★★
*Multi-capteurs + multi-devices + IA/sync temps réel*

---

#### R21 — Squad-Resonance `lib/squad_resonance.dart`
**Type :** Squad | **Durée :** 2 min | **Phase launch :** Phase 2 (jan 2027)

**Spec attendue :** 5 appareils synchronisés. La personne en crise reçoit des micro-vibrations de chacune des 4 autres. Aura en rouge sombre visible par le groupe. Tapotement lent synchronisé par WebSocket.

**À tester :**
- [ ] 5 appareils se connectent à la même session
- [ ] Vibrations haptiques reçues simultanément sur l'appareil en crise
- [ ] Aura rouge visible chez les 4 accompagnantes
- [ ] Désync WebSocket > 200ms : alerte ou rattrapage
- [ ] Fond `#121212`, couleurs dans palette

**Risques :** Latence WebSocket, Android bloque parfois les vibrations simultanées

---

#### R20 — Co-Gaze Alpha `lib/co_gaze_alpha.dart`
**Type :** Twin | **Durée :** 3 min | **Phase launch :** Phase 2 (jan 2027)

**Spec attendue :** Point central qui pulse à la moyenne des 2 FC (rPPG). Eye-tracking vérifie que les deux regardent le point. WebSocket partage les données cardiaques.

**À tester :**
- [ ] rPPG détecte une FC plausible (50–100 bpm) via caméra arrière
- [ ] La fréquence du point = moyenne des 2 FC reçues
- [ ] Eye-tracking pause si regard dévié
- [ ] WebSocket sync < 100ms
- [ ] Fond `#121212`, point turquoise `#0DAABA`

**Risques :** rPPG peu fiable sur Android non-Pixel. Prévoir fallback bpm fixe (6/min).

---

#### R1 — Reset Flash `lib/reset_flash.dart`
**Type :** Solo | **Durée :** 3 min | **Phase launch :** Phase 1 (sept 2026) ⚡ PRIORITÉ ABSOLUE

**Spec attendue :** Selfie Flash avant → respiration guidée (barres verticales 4-5s inspiration / 5-6s expiration) → vibrations 7-10 Hz continu → Aura bleuit progressivement → Selfie Flash après.

**À tester :**
- [ ] Caméra s'ouvre et capture bien au démarrage
- [ ] Barres animées montent/descendent au bon rythme
- [ ] Vibration continue 7-10 Hz (pas de coupure)
- [ ] Aura change de couleur progressivement vers turquoise
- [ ] Deuxième selfie flash à la fin
- [ ] Fond `#121212`, accents `#0DAABA`

**Charte :** ⚠️ Vérifier que l'icône SelfieFlash affiche bien (pas de caractère asiatique)

---

#### R7 — Twin-Coherence `lib/twin_coherence_rt.dart`
**Type :** Twin | **Durée :** 3 min | **Phase launch :** Phase 1 (sept 2026)

**Spec attendue :** 2 cercles qui gonflent. Caméra capte le rythme respiratoire de chaque Twin. Si synchronisation → sphère dorée. WebSocket partage les phases.

**À tester :**
- [ ] Deux appareils se connectent à la même session Twin
- [ ] Caméra détecte mouvement respiratoire (pas juste idle)
- [ ] Sphère dorée apparaît si < 0.5s de décalage de phase
- [ ] Sphère disparaît si désynchronisation
- [ ] Fond `#121212`, sphère gold `#E8B86E`

---

#### R13 — Audio-Capsule `lib/audio_capsule.dart` + `lib/audio_capsule_send.dart`
**Type :** Squad | **Durée :** 1 min | **Phase launch :** Phase 2 (jan 2027)

**Spec attendue :** Enregistrement 10s côté émettrice (filtrage vocal : refus si ton stressé). Déverrouillage conditionnel côté destinataire (pic de tension détecté). Bulle lumineuse palpite.

**À tester :**
- [ ] Enregistrement 10s fonctionne et se coupe bien
- [ ] Analyse ton vocal : un enregistrement calme passe, un stressé est refusé (ou placeholder)
- [ ] Déclenchement côté destinataire quand Aura tendue
- [ ] Bulle palpite correctement
- [ ] Fond `#121212`

---

#### R22 — Breath-Drawing `lib/breath_drawing.dart`
**Type :** Twin | **Durée :** 2 min | **Phase launch :** Phase 2 (jan 2027)

**Spec attendue :** Twin A respire → caméra capte → ligne lumineuse sur écran de B → B suit avec le doigt.

**À tester :**
- [ ] Ligne montante/descendante cohérente avec respiration A
- [ ] Toucher de B détecté et comparé à la ligne
- [ ] Feedback si B suit bien (ex. couleur)
- [ ] WebSocket latence acceptable
- [ ] Fond `#121212`, ligne turquoise `#0DAABA`

---

### TIER 2 — COMPLEXE ★★★★
*Multi-devices ou capteurs spécialisés*

---

#### R3 — Saccadic Reset `lib/emdr_widget.dart`
**Type :** Solo | **Durée :** 1 min 30 | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Bille lumineuse G→D. Eye-tracking : si yeux quittent la bille, elle s'arrête. Vitesse augmente si bon suivi.

**À tester :**
- [ ] Bille se déplace bien gauche-droite
- [ ] Pause si regard dévié (eye-tracking)
- [ ] Vitesse progressive
- [ ] Traînée lumineuse apaisante
- [ ] Fond `#121212`, bille turquoise

---

#### R25 — Mirror-Breath `lib/mirror_breath.dart`
**Type :** Twin | **Durée :** 2 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Onde lumineuse G→D reflétant rythme respiratoire de A. B regarde passivement.

**À tester :**
- [ ] Onde fluide et réactive à la respiration A
- [ ] B voit l'onde en temps réel (WebSocket)
- [ ] Fond `#121212`, onde turquoise ou lila

---

#### R27 — Vocal-Humming Sync `lib/vocal_humming_sync.dart`
**Type :** Twin | **Durée :** 2 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Deux Twins fredonnent. Micro détecte. Vibrations haptiques synchronisées chez les deux.

**À tester :**
- [ ] Micro détecte le bourdonnement (pas juste le bruit ambiant)
- [ ] Vibrations déclenchées simultanément
- [ ] Visuel vibration partagée
- [ ] Fond `#121212`

---

#### R10 — Bio-Ambient Duo `lib/bio_ambient_duo.dart`
**Type :** Twin | **Durée :** 3-5 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Fond généré IA (mer calme/agitée). Micro détecte si quelqu'un parle → vagues agitées. WebSocket.

**À tester :**
- [ ] Audio génératif joue bien
- [ ] Micro détecte parole et anime les vagues
- [ ] Silence → mer calme
- [ ] Fond `#121212`, vagues turquoise

---

#### R8 — The High-Five `lib/high_five.dart`
**Type :** Twin | **Durée :** 2 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Compte à rebours 3-2-1. Les 2 Twins touchent en même temps. Si < 200ms d'écart → animation explosion lumière + vibration identique.

**À tester :**
- [ ] Compte à rebours bien synchronisé (WebSocket)
- [ ] Précision milliseconde détectée
- [ ] Animation explosion si synchrone
- [ ] Fond `#121212`, animation gold

---

#### R9 — Aura-Exchange `lib/aura_exchange.dart`
**Type :** Twin | **Durée :** 5 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Glisser le doigt vers le haut pour envoyer l'énergie. Bloqué si émettrice tendue. Aura destinataire change instantanément.

**À tester :**
- [ ] Geste "glisser vers le haut" reconnu
- [ ] Vérification état Aura émettrice (blocage si tendue)
- [ ] Changement couleur Aura destinataire via WebSocket
- [ ] Traînée lumineuse animée
- [ ] Fond `#121212`

---

#### R19 — Lullaby Haptique `lib/lullaby_haptique.dart`
**Type :** Twin | **Durée :** 2 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Twin A incline le téléphone (gyroscope). B reçoit vibrations calquées sur le balancement.

**À tester :**
- [ ] Gyroscope capte l'inclinaison G/D
- [ ] Vibrations B reproduisent le mouvement A
- [ ] Visuel berceau/sable qui bascule
- [ ] Fond `#121212`, teintes lila `#D9CCE8`

---

#### R28 — Thermal-Touch `lib/thermal_touch.dart`
**Type :** Twin | **Durée :** 2 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** A caresse l'écran. B reçoit haptique haute fréquence/basse amplitude (illusion chaleur). iPhone seulement activé, Android désactivé.

**À tester :**
- [ ] Caresse A détectée (position et vélocité)
- [ ] Haptique B déclenché (sur Android : vérifier que la routine ne crash pas)
- [ ] Message "fonctionnalité optimisée pour iPhone" sur Android
- [ ] Fond `#121212`

---

#### R11 — Squad-Pulse `lib/squad_pulse.dart`
**Type :** Squad | **Durée :** 2 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** 5 pulsations lumineuses. Rouge rapide = tension. Bleu lent = calme. Temps réel WebSocket.

**À tester :**
- [ ] 5 pulsations distinctes affichées
- [ ] Couleur/vitesse reflète l'Aura réelle de chaque membre
- [ ] Mise à jour < 1s
- [ ] Fond `#121212`, turquoise/rouge selon état

---

#### R12 — Intention Wheel `lib/intention_wheel.dart`
**Type :** Squad | **Durée :** 2 min | **Phase launch :** Phase 1 (sept 2026) ⚡ DÉJÀ TESTÉ

**Spec :** Roue 5 sections. Chaque membre choisit un mot. Mots visibles sur la roue. Logo central s'illumine quand tous ont choisi.

**À tester :**
- [ ] Roue affiche bien les 5 sections colorées
- [ ] Icône centrale (étoile `Icons.stars`) visible (plus de caractère asiatique)
- [ ] Mots apparaissent sur la roue au fur et à mesure
- [ ] Logo s'illumine en gold quand 5/5 membres
- [ ] Fond `#121212`

---

#### R14 — Collective Shield `lib/collective_shield.dart`
**Type :** Squad | **Durée :** 2 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Dôme qui se solidifie. Si moyenne Aura Squad > seuil, Aria lance le bouclier. Badge "Squad Invincible" quand complet.

**À tester :**
- [ ] Dôme s'anime et se solidifie progressivement
- [ ] Badge débloqué quand 5/5 ont fait Reset Flash
- [ ] Fond `#121212`, dôme turquoise

---

#### R50 — Squad-Morning-Pulse `lib/squad_morning_pulse.dart`
**Type :** Squad | **Durée :** 60s | **Phase launch :** Phase 1 (sept 2026)

**Spec :** 5 Auras dans un cercle. Non connectées = veilleuse. Signal Aura sur appui long.

**À tester :**
- [ ] Auras des membres connectés affichées avec couleur réelle
- [ ] Membres hors-ligne = veilleuse (gris)
- [ ] Appui long = envoi Signal Aura
- [ ] Fond `#121212`

---

### TIER 3 — MODÉRÉ ★★★
*Solo avec capteurs ou Twin simples*

---

#### R4 — Vagal-Haptic `lib/soothing_thumb.dart`
**Type :** Solo | **Durée :** 2 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Pouce sur cercle. Vibrations 7-10 Hz. 6 cycles/min. Pause si pouce quitte l'écran.

**À tester :**
- [ ] Zone tactile détecte contact/retrait du pouce
- [ ] Vibration 7-10 Hz en continu (pas de micro-coupures)
- [ ] Message "contact rompu" si pouce retire
- [ ] Fond `#121212`, cercle turquoise

---

#### R2 — Aura-Cleaning `lib/aura_cleaning.dart`
**Type :** Solo | **Durée :** 3 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Visage entouré d'une brume colorée. Frotter l'écran nettoie la brume via caméra.

**À tester :**
- [ ] Caméra affiche le visage en temps réel
- [ ] Brume colorée rendu autour du visage
- [ ] Geste de frottement détecté (zone nettoyée)
- [ ] Aura s'éclaircit progressivement
- [ ] Fond `#121212`

---

#### R24 — Oculo-Cardiaque `lib/oculo_cardiaque.dart`
**Type :** Solo | **Durée :** 1 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Point descend lentement. Suivre du regard en louchant légèrement + expiration. Eye-tracking vérifie convergence.

**À tester :**
- [ ] Point descend lentement au centre
- [ ] Eye-tracking détecte convergence oculaire
- [ ] Fond `#121212`, point turquoise

---

#### R23 — Vagus-Ear `lib/vagus_ear.dart`
**Type :** Solo | **Durée :** 1 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Schéma placement contre le tragus. Haptique 40-60 Hz. Capteur proximité → écran noir. Durée max 90s. Délai 15 min avant relance.

**À tester :**
- [ ] Schéma instruction clair
- [ ] Capteur de proximité détecte le téléphone contre l'oreille → écran noir
- [ ] Vibration 40-60 Hz active
- [ ] Bouton désactivé si < 15 min depuis dernière utilisation
- [ ] Fond `#121212`

---

#### R29 — Morning Ancrage `lib/morning_ancrage.dart`
**Type :** Solo | **Durée :** 90s | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Arrière-plan teinte aube. Cercle d'intention vide. 6 mots proposés. 4 cycles respiration activante. Intention chargée dans l'Aura.

**À tester :**
- [ ] 6 mots proposés (Clarté, Douceur, Présence, Force, Légèreté, Patience)
- [ ] Saisie libre en option
- [ ] 4 cycles respiration (haptique légère)
- [ ] Fond clair ivoire `#F8F1E9` ou dark avec accent doux
- [ ] Timer 90s correct

**Charte :** ⚠️ Background doit être différent du soir — envisager fond `#F8F1E9` (ivoire) le matin

---

#### R30 — Readiness Check `lib/readiness_check.dart`
**Type :** Solo | **Durée :** 2 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** 3 étapes — identification somatique sur silhouette, respiration 30s, projection mentale "fin de l'événement".

**À tester :**
- [ ] Silhouette humaine interactive (zones corporelles touchables)
- [ ] Respiration 30s guidée haptiquement
- [ ] Texte projection mentale affiché
- [ ] Fond `#121212`

---

#### R40 — Préparation Sommeil `lib/preparation_sommeil.dart`
**Type :** Solo | **Durée :** 8 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** 4 étapes — body scan 3 min → respiration 3 cycles/min → narration optionnelle 2 min → silence haptique 1 min. Luminosité diminue progressivement. Programme DND.

**À tester :**
- [ ] Enchaînement des 4 étapes sans accroc
- [ ] Respiration 3 cycles/min (20s cycle)
- [ ] Luminosité écran diminue progressivement
- [ ] Permission DND demandée
- [ ] Fond `#121212` vers noir complet

---

#### R16 — OLED-Therapy `lib/oled_therapy.dart`
**Type :** Solo | **Durée :** 2 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Écran entier pulse à 0.1 Hz. Aucune interaction. Introduction J45. Warning sensibilité lumineuse.

**À tester :**
- [ ] Écran entier devient source lumineuse
- [ ] Pulsation exactement 0.1 Hz (1 cycle = 10s)
- [ ] Message warning photosensibilité affiché
- [ ] Fond noir entre pulses

---

#### R17 — Audio-Binaurale `lib/audio_binaurale.dart`
**Type :** Solo | **Durée :** 3 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Casque obligatoire (détection auto). Deux fréquences distinctes (une par oreille). Onde sonore stylisée.

**À tester :**
- [ ] Détection casque branché (route audio en stéréo)
- [ ] Message "casque requis" si non branché
- [ ] Son bien stéréo (fréquences distinctes gauche/droite)
- [ ] Onde sonore animée réactive au volume
- [ ] Fond `#121212`

---

#### R26 — Plexus-Weight `lib/plexus_weight.dart`
**Type :** Solo | **Durée :** 3 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Interface très sombre. Vibrations Deep Pressure : lourdes, lentes. Timer 5 min max. Introduction J30.

**À tester :**
- [ ] Vibrations perçues comme "lourdes" (pattern lent longue durée)
- [ ] Timer coupe automatiquement à 5 min max
- [ ] Interface quasi-noire, impulsion centrale lente
- [ ] Fond `#0D0D0D` ou `#121212`

---

#### R44 — Duo-Morning `lib/duo_morning.dart`
**Type :** Twin | **Durée :** 90s | **Phase launch :** Phase 1 (sept 2026)

**Spec :** 2 cercles d'intention côte à côte. Chaque Twin choisit son intention. Intentions visibles l'une pour l'autre. Respiration 4 cycles vivifiants.

**À tester :**
- [ ] Intentions visibles en temps réel chez les deux
- [ ] 4 cycles respiration haptique
- [ ] Fond `#121212` ou ivoire clair

---

#### R45 — Debrief-Duo `lib/debrief_duo.dart`
**Type :** Twin | **Durée :** 3 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** 2 boîtes symboliques. Chaque Twin dépose ses événements (privé). Boîtes ferment en synchronie. Option mot 15 caractères partagé.

**À tester :**
- [ ] Boîtes ferment en synchronie (WebSocket)
- [ ] Contenu des boîtes visible UNIQUEMENT par la propriétaire
- [ ] Option mot partagé fonctionne
- [ ] Fond `#121212`, boîtes lila `#D9CCE8`

---

#### R46 — Gratitude-Mirror `lib/gratitude_mirror.dart`
**Type :** Twin | **Durée :** 2 min | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Pont lumineux entre 2 Auras. Chaque Twin saisit une phrase courte (30 car). Les phrases se croisent sur le pont. Vibration haptique à réception.

**À tester :**
- [ ] Limite 30 caractères respectée
- [ ] Animation pont lumineux
- [ ] Vibration à réception du message
- [ ] Fond `#121212`, pont gold `#E8B86E`

---

#### R47 — Savoring-Duo `lib/savoring_duo.dart`
**Type :** Twin | **Durée :** 2 min | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Bulle dorée commune. "Qu'est-ce que vous voulez retenir ?" Capsule partagée créée et archivée.

**À tester :**
- [ ] Bulle partagée visible chez les deux en temps réel
- [ ] Capsule sauvegardée et accessible plus tard
- [ ] Fond `#121212`, bulle gold

---

#### R48 — Cycle-Companion `lib/cycle_companion.dart`
**Type :** Twin | **Durée :** 2 min | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Aura corail visible par l'accompagnante. Consentement explicite préalable. Respiration lente sync 4 cycles/min.

**À tester :**
- [ ] Consentement demandé avant activation
- [ ] Aura corail visible chez l'accompagnante
- [ ] Respiration sync 4 cycles/min haptique doux
- [ ] Fond `#121212`, accent lila `#D9CCE8`

---

#### R49 — Night-Tandem `lib/night_tandem.dart`
**Type :** Twin | **Durée :** 4 min | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Deux lunes côte à côte. Respiration 3 cycles/min. Body scan 2 min. Silence 1 min. Option "Bonne nuit".

**À tester :**
- [ ] Lunes s'atténuent progressivement
- [ ] Respiration sync 3 cycles/min
- [ ] Option "Bonne nuit" envoyée
- [ ] Fond `#121212`, lunes lila ou gold doux

---

### TIER 4 — SIMPLE ★★
*Solo interaction basique ou Twin sans capteurs*

---

#### R5 — Cognitive Sorting `lib/cognitive_sorting.dart`
**Type :** Solo | **Durée :** 2 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Pluie d'icônes. Corbeille en bas. Glisser vers la corbeille. Aura s'éclaircit de 5% par icône jetée. Étincelle à chaque suppression.

**À tester :**
- [ ] Icônes tombent et sont draggables
- [ ] Corbeille reconnaît le dépôt
- [ ] Étincelle visuelle à chaque icône jetée
- [ ] Aura change visuellement
- [ ] Fond `#121212`, icônes turquoise/lila

---

#### R15 — Tap-Sync `lib/tap_sync.dart`
**Type :** Solo | **Durée :** 1 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Points néon apparaissent. Tapoter chaque point pour le faire disparaître. Vitesse s'accélère. Pop animation.

**À tester :**
- [ ] Points apparaissent à positions aléatoires
- [ ] Tap précis détecté (rayon tolérance < 20dp)
- [ ] Vitesse augmente progressivement
- [ ] Animation pop satisfaisante
- [ ] Fond `#121212`, points turquoise néon

---

#### R18 — Écriture/Dessin Infini `lib/infini_draw.dart`
**Type :** Solo | **Durée :** 2 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Tracé infini (∞) en transparence. Résistance haptique si mouvement trop rapide/brusque.

**À tester :**
- [ ] Tracé ∞ guide visible en transparence
- [ ] Tracé lumineux suit le doigt
- [ ] Vibration de friction si mouvement trop rapide
- [ ] Fond `#121212`, tracé turquoise

---

#### R6 — Bio-Ambient `lib/bio_ambient.dart`
**Type :** Solo | **Durée :** 3 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Fond immersif. Musique générée selon score tension. Fréquences alpha, bruit brun. Casque recommandé.

**À tester :**
- [ ] Audio joue correctement
- [ ] Fond évolue visuellement
- [ ] Suggestion casque affichée
- [ ] Fond `#121212`

---

#### R31 — End-of-Day Release `lib/end_of_day_release.dart`
**Type :** Solo | **Durée :** 3 min | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Objets lumineux représentant les événements du jour. Glisser dans la boîte. Boîte se ferme. Fond vire en mode soirée.

**À tester :**
- [ ] Objets lumineux draggables
- [ ] Boîte se ferme avec animation
- [ ] Fond passe en mode soirée (plus sombre/chaud)
- [ ] Fond `#121212`, objets gold ou lila

---

#### R35 — Micro-Célébration `lib/micro_celebration.dart`
**Type :** Solo/Squad | **Durée :** 30s | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Saisie max 15 caractères. Feu d'artifice doux. Aura vire or. Option partage Squad.

**À tester :**
- [ ] Compteur 15 caractères max
- [ ] Animation feu d'artifice
- [ ] Aura prend la teinte gold
- [ ] Option partage Squad déclenche Squad-Celebration-Wave
- [ ] Fond `#121212`

---

#### R36 — Pensée Observée `lib/pensee_observee.dart`
**Type :** Solo | **Durée :** 2 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Aria reformule : "Vous avez la pensée que [texte]." Pause 10s. "Cette pensée est un événement mental, pas une vérité." Choix : laisser passer / noter / contester.

**À tester :**
- [ ] Saisie texte libre fonctionne
- [ ] Reformulation Aria s'affiche correctement
- [ ] Pause 10 secondes respectée
- [ ] 3 boutons de choix fonctionnels
- [ ] Fond `#121212`, interface minimaliste sans couleurs vives

---

#### R37 — Cocon Prémenstruel `lib/cocon_premenstruel.dart`
**Type :** Solo | **Durée :** 3 min | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Tonalités enveloppantes. 4 cycles/min (15s cycle). Validation émotions fluctuantes.

**À tester :**
- [ ] Respiration 4 cycles/min (15s/cycle) — plus lent que Reset Flash (6/min)
- [ ] Vibrations douces haptiques
- [ ] Message "pas de performer" affiché
- [ ] Fond `#121212` (**PAS** `#120A0A`)
- [ ] Accent lila `#D9CCE8` ou gold — **PAS** orange/brun hors palette

**Charte :** ⚠️ Corriger `_bg = Color(0xFF120A0A)` → `Color(0xFF121212)` et `_warm = Color(0xFFD9753A)` → `Color(0xFFD9CCE8)` (lila)

---

#### R38 — Vague de Règles `lib/vague_regles.dart`
**Type :** Solo | **Durée :** 2 min | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Vagues rouges profondes. Deep Pressure haptique (vibrations lentes/lourdes). Audio optionnel.

**À tester :**
- [ ] Vagues animées fluides et lentes
- [ ] Vibrations longues et profondes (Deep Pressure)
- [ ] Audio optionnel joue si URL fournie
- [ ] Fond `#121212` (**PAS** `#0E0508`)
- [ ] Couleur vague dans palette — le rouge foncé `#8B1A2A` est acceptable si sobre

**Charte :** ⚠️ Corriger `_bg = Color(0xFF0E0508)` → `Color(0xFF121212)`

---

#### R39 — Énergie d'Ovulation `lib/energie_ovulation.dart`
**Type :** Solo | **Durée :** 90s | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Aura dorée éclatante. Animations rapides/vives. Respiration activante (inspire rapide 3s + expire 3s).

**À tester :**
- [ ] Respiration 6 cycles/min activant (3s inspiration, 3s expiration)
- [ ] Animation s'accélère (contrairement aux autres routines)
- [ ] Vibration à chaque transition inspire/expire
- [ ] Fond `#121212`
- [ ] Couleur principale **gold** `#E8B86E` — **PAS** orange `#F2631D` (hors palette)

**Charte :** ⚠️ Corriger `_fire = Color(0xFFF2631D)` → `Color(0xFFE8B86E)` (gold)

---

#### R42 — Décrispation Express `lib/decris_express.dart`
**Type :** Solo | **Durée :** 90s | **Phase launch :** Phase 1 (sept 2026)

**Spec :** Silhouette avec 4 zones en tension. Guidage : mâchoire → épaules → cou → mains. Contracter-relâcher.

**À tester :**
- [ ] 4 zones s'illuminent successivement sur la silhouette
- [ ] Timer par zone (5s contraction + relâché)
- [ ] Haptique accompagne chaque phase
- [ ] Fond `#121212`, silhouette turquoise/lila

---

#### R51 — Squad-Gratitude-Garden `lib/squad_gratitude_garden.dart`
**Type :** Squad | **Durée :** 2 min | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Jardin partagé. Chaque membre ajoute un galet avec un mot. Filtre "galets reçus".

**À tester :**
- [ ] Jardin affiche les galets de tous les membres
- [ ] Ajout d'un galet avec mot court
- [ ] Filtre "galets reçus pour moi" fonctionnel
- [ ] Fond `#121212`

---

#### R52 — Squad-Celebration-Wave `lib/squad_celebration_wave.dart`
**Type :** Squad | **Durée :** 90s | **Phase launch :** Phase 2 (jan 2027)

**Spec :** Déclenchée automatiquement depuis Micro-Célébration. Notification Signal Aura aux 4 autres. Vibration en vague chez la célébrante.

**À tester :**
- [ ] Déclenchement automatique depuis Micro-Célébration
- [ ] Notification aux 4 autres
- [ ] Vibration "en vague" reçue (pattern séquentiel)
- [ ] Fond `#121212`, animation gold

---

#### R53 — Squad-Night-Watch `lib/squad_night_watch.dart`
**Type :** Squad | **Durée :** 3 min | **Phase launch :** Phase 3 (mars 2027)

**Spec :** 5 Auras en cercle protecteur. Respiration 3 cycles/min partagée. Silence haptique. Notification aux absentes le lendemain.

**À tester :**
- [ ] 5 Auras affichées en cercle
- [ ] Respiration sync 3 cycles/min
- [ ] Silence haptique final 1 min
- [ ] Notification "les filles ont pensé à toi" envoyée le lendemain

---

### TIER 5 — MINIMAL ★
*Affichage / saisie simple*

---

#### R32 — Between-Two-Worlds `lib/between_two_worlds.dart`
**Type :** Solo | **Durée :** 60s | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Dégradé visuel d'une teinte à l'autre. Haptique rythme la respiration. Aura reprend avec variation signifiant "autre contexte".

**À tester :**
- [ ] Dégradé visuel progressif
- [ ] Haptique 4 cycles en 60s
- [ ] Fond `#121212` → changement subtil

---

#### R33 — Gratitude Flash `lib/gratitude_flash.dart`
**Type :** Solo | **Durée :** 90s | **Phase launch :** Phase 1 (sept 2026)

**Spec :** 3 éléments positifs. Jardin intérieur qui se remplit. Galets colorés ajoutés.

**À tester :**
- [ ] 3 champs de saisie ou 3 prompts vocaux
- [ ] Galet ajouté au jardin pour chaque élément
- [ ] Jardin persistant (données sauvegardées)
- [ ] Fond `#121212`

---

#### R34 — Savoring Moment `lib/savoring_moment.dart`
**Type :** Solo | **Durée :** 2 min | **Phase launch :** Phase 2 (jan 2027)

**Spec :** 3 questions : sensation corps / ce qu'on retient / à qui on le doit. Capsule mémoire créée.

**À tester :**
- [ ] 3 questions s'enchaînent
- [ ] Option audio 10s fonctionne
- [ ] Capsule sauvegardée et accessible
- [ ] Fond `#121212`, bulle gold

---

#### R41 — Réveil Doux `lib/reveil_doux.dart`
**Type :** Solo | **Durée :** 60s | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Lumière monte progressivement (lever de soleil). Aria voix calme. 4 cycles respiration. Option enchaîner Morning Ancrage.

**À tester :**
- [ ] Fond passe de noir à lumière progressive (teinte dorée/chaude)
- [ ] 4 cycles haptique doux
- [ ] Bouton "enchaîner Morning Ancrage" fonctionne
- [ ] PAS de selfie flash au démarrage

---

#### R43 — Repos Yeux `lib/repos_yeux.dart`
**Type :** Solo | **Durée :** 60s | **Phase launch :** Phase 3 (mars 2027)

**Spec :** Cibles pour proche/lointain/gauche/droite. Fermer les yeux 15s. Guidage vocal.

**À tester :**
- [ ] 4 cibles s'affichent successivement
- [ ] Timer 15s pour les yeux fermés
- [ ] Guidage vocal (ou texte en mode silence)
- [ ] Fond `#121212`, cibles turquoise

---

## Problèmes connus à corriger avant tests

| Fichier | Problème | Correction à faire |
|---------|----------|--------------------|
| `cocon_premenstruel.dart` | `_bg = #120A0A` | → `#121212` |
| `cocon_premenstruel.dart` | `_warm = #D9753A` (hors palette) | → `#D9CCE8` (lila) |
| `vague_regles.dart` | `_bg = #0E0508` | → `#121212` |
| `energie_ovulation.dart` | `_fire = #F2631D` (hors palette) | → `#E8B86E` (gold) |
| Tous les fichiers | `withValues(alpha:)` → **CORRIGÉ** ✅ | |
| Tous les fichiers | Icônes icomoon (caractères asiatiques) → **CORRIGÉ** ✅ | |

---

## Ordre de test recommandé (Phase 1 prioritaire)

1. **R1** Reset Flash — routine pilier, toujours proposée
2. **R12** Intention Wheel — Squad, déjà vu sur l'app
3. **R15** Tap-Sync — Solo simple, bon pour valider le build
4. **R5** Cognitive Sorting — Solo simple
5. **R18** Écriture Infini — Solo, valide l'haptique
6. **R6** Bio-Ambient — Solo, valide l'audio
7. **R29** Morning Ancrage — Solo matin
8. **R33** Gratitude Flash — Solo soir
9. **R42** Décrispation Express — Solo corps
10. **R31** End-of-Day Release — Solo transition
11. **R7** Twin-Coherence — Twin, premier test multi-devices
12. **R8** High-Five — Twin, timing précis
13. **R9** Aura-Exchange — Twin
14. **R25** Mirror-Breath — Twin
15. **R10** Bio-Ambient Duo — Twin audio
16. **R11** Squad-Pulse — Squad
17. **R14** Collective Shield — Squad
18. **R50** Squad-Morning-Pulse — Squad
19. **R44** Duo-Morning — Twin matin
