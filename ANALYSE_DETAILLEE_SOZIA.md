# ANALYSE DÉTAILLÉE - APPLICATION SOZIA

## 1. RÉSUMÉ EXÉCUTIF

**Sozia** est un assistant IA mobile qui synchronise l'énergie intérieure avec la vie extérieure. C'est une application Flutter cross-platform complexe (iOS, Android, Web) avec backend Firebase et fonctionnalités AI.

- **Version actuelle**: 0.0.1+35
- **Nombre de fichiers Dart**: ~235 fichiers
- **Architecture**: MVVM + State Management (Provider)
- **Backend**: Firebase Firestore + Cloud Functions (Node.js)

---

## 2. STACK TECHNOLOGIQUE

### 2.1 Framework Principal
```
Framework: Flutter (SDK >=3.0.0 <4.0.0)
Plateformes: iOS (version 11+), Android, Web
Navigation: GoRouter 12.1.3
State Management: Provider 6.1.5
```

### 2.2 Services Firebase (Backend)
- **Firebase Core** 3.14.0
- **Firebase Auth** 5.6.0 (authentification utilisateur)
- **Cloud Firestore** 5.6.9 (base de données NoSQL)
- **Firebase Storage** 12.4.7 (stockage fichiers)
- **Firebase Performance** 0.10.1+7 (monitoring)

### 2.3 Dépendances Majeures
| Catégorie | Packages |
|-----------|----------|
| **IA/ML** | google_mlkit_face_detection 0.13.2 |
| **Auth** | Google Sign-In 6.3.0, Sign-in with Apple 7.0.1 |
| **Média** | camera 0.10.5, image_picker 1.1.2, video_player 2.10.0 |
| **Audio** | flutter_tts 3.8.5, record 6.0.0 |
| **Animations** | flutter_animate 4.5.0, Lottie 3.1.2 |
| **UI** | google_fonts 6.3.3, flutter_svg 2.1.0 |
| **Storage Local** | shared_preferences 2.5.3, sqflite 2.3.3 |
| **Contacts** | flutter_contacts 1.1.9+2 |
| **Calendrier** | Intégration Google Calendar & Microsoft Graph (tokens) |
| **Permissions** | permission_handler 12.0.0+1 |

### 2.4 Cloud Functions (Backend Node.js)
```
Location: firebase/functions/
- api_manager.js: Gestion des appels API
- index.js: Point d'entrée Cloud Functions
- package.json: Dépendances Node.js
```

---

## 3. ARCHITECTURE APPLICATION

### 3.1 Structure des Répertoires

```
lib/
├── main.dart                 # Point d'entrée app
├── app_state.dart           # État global (FFAppState - Provider)
├── index.dart               # Exports des pages principales
│
├── auth/                    # Authentification
│   ├── auth_manager.dart
│   ├── firebase_auth/
│   └── base_auth_user_provider.dart
│
├── backend/                 # Couche données & API
│   ├── backend.dart         # Exports des collections Firestore
│   ├── api_requests/        # Appels API externes
│   ├── firebase/            # Configuration & utilitaires Firebase
│   ├── firebase_storage/    # Gestion Storage
│   └── schema/              # Modèles Firestore (Records)
│
├── flutter_flow/            # Framework de base (FlutterFlow)
│   ├── flutter_flow_theme.dart
│   ├── flutter_flow_model.dart
│   ├── flutter_flow_util.dart
│   ├── custom_functions.dart
│   ├── custom_icons.dart
│   ├── flutter_flow_animations.dart
│   ├── nav/                 # Routage GoRouter
│   └── internationalization.dart
│
├── components/              # Composants réutilisables
│   ├── btn_primaire_widget.dart
│   ├── btn_secondaire_background_widget.dart
│   ├── navbar_widget.dart
│   ├── text_field_*.dart    # Champs de saisie
│   └── empty_widget.dart
│
├── custom_code/             # Code personnalisé
│   ├── widgets/             # Widgets custom complexes
│   │   ├── animated_aura.dart
│   │   ├── aura_cleaning.dart
│   │   ├── cognitive_sorting.dart
│   │   ├── eye_movement_e_m_d_r.dart
│   │   ├── light_transfer_animation.dart
│   │   ├── sozia_loading_dots.dart
│   │   ├── soothing_thumb.dart
│   │   └── send_*.dart (twin/presence/force/repos)
│   │
│   ├── actions/             # Fonctions métier personnalisées
│   │   ├── connect_google_calendar.dart
│   │   ├── save_calendar_events.dart
│   │   ├── save_guardian_suggestions.dart
│   │   ├── fetch_today_events.dart
│   │   ├── reschedule_event.dart
│   │   └── create_lunch_break_block.dart
│   │
│   ├── services/
│   │   ├── twin_service.dart
│   │   ├── squad_service.dart
│   │   └── rtdb_session.dart
│   └── routine_lobby.dart
│
└── Pages (Screens)
    ├── connexion/           # Authentification & Onboarding
    │   ├── a_initial_page/
    │   ├── l_connexion/
    │   ├── mdp_oublie/
    │   ├── g_inscription/
    │   ├── b_permission/
    │   ├── c_onboarding/
    │   └── i_invitation_twin_onboarding/
    │
    ├── dashboard/           # Écran principal
    │   ├── a_dashboard/
    │   ├── z_welcome/
    │   ├── b_loading_selfie/
    │   ├── d_results_analys_sozia/
    │   ├── new_*_received/  # Notifications
    │   └── loading_error/
    │
    ├── cercle/              # Mode "Cercle" (Squad/Groupe)
    │   ├── a_cercle_dashboard/
    │   ├── b_s_signs_cercle/
    │   ├── c_lumiere_cercle/
    │   ├── d_presence_cercle/
    │   ├── e_force_cercle/
    │   ├── f_repos_cercle/
    │   ├── invitation_code_cercle/
    │   └── invite_squad/
    │
    ├── twin/                # Mode "Twin" (Jumeaux/Partenaires)
    │   ├── a_twin_dashboard/
    │   ├── b_s_signs_twin/
    │   ├── c_lumiere/
    │   ├── d_presence/
    │   ├── e_force/
    │   ├── f_repos/
    │   ├── invitation_twin/
    │   ├── invitation_code_binome/
    │   └── twin_actions/
    │
    ├── guardian/            # Mode Tuteur
    │   ├── guardian_mode/
    │   ├── connect_calendars/
    │   └── tiyia_recup/
    │
    ├── profil/              # Profil utilisateur
    │   └── parametres/
    │
    ├── notification/        # Gestion notifications
    │
    ├── routines_exercices/  # Exercices & routines
    │
    ├── test_auras/          # Tests visuels auras
    │
    └── test_exo_mathieu/    # Tests spécifiques dev
```

### 3.2 Base de Données Firestore (Collections)

**Schema Records** (Modèles Firestore):
1. **users_record.dart** - Profils utilisateurs
2. **selfie_record.dart** - Selfies/Photos utilisateur
3. **guardian_actions_record.dart** - Actions du tuteur
4. **twin_signals_record.dart** - Signaux échangés entre twins (binômes)
5. **squad_record.dart** - Groupes/Cercles
6. **notification_record.dart** - Notifications
7. **calendar_connections_record.dart** - Connexions calendrier (Google/Microsoft)
8. **calendar_events_record.dart** - Événements calendrier
9. **guardian_suggestions_record.dart** - Suggestions du tuteur IA
10. **twin_invitation_record.dart** - Invitations entre twins
11. **routine_record.dart** - Routines d'exercices
12. **etat_analyze_record.dart** - Analyses d'état

---

## 4. MODULES FONCTIONNELS PRINCIPAUX

### 4.1 Authentification (`auth/`)
- **Provider**: Firebase Auth
- **Méthodes**: Email/Password, Google Sign-In, Apple Sign-In
- **État**: `BaseAuthUser` + stream d'authentification
- **Fichier clé**: `firebase_user_provider.dart`

### 4.2 Modes d'Utilisation

#### **Mode Connexion** (`connexion/`)
- Onboarding complet
- Permissions demandées
- Codes d'invitation pour twins/cercles
- Récupération mot de passe

#### **Mode Cercle** (`cercle/`)
- Dashboard groupe
- 5 types d'énergie: Lumière, Présence, Force, Repos, Signes
- Invitations pour rejoindre cercle
- Actions de groupe confirmées

#### **Mode Twin** (`twin/`)
- Dashboard binôme (partenaire unique)
- Mêmes 5 types d'énergie
- Actions d'échange confirmées
- Codes d'invitation binôme
- Matching success page

#### **Mode Guardian** (`guardian/`)
- Interface tuteur/soignant
- Connexion calendriers (Google Calendar, Microsoft Graph)
- Suggestions IA pour l'utilisateur
- Récupération données utilisateur

### 4.3 Dashboard Principal (`dashboard/`)
- Analyse selfie (détection IA visuelle)
- Résultats d'analyse Sozia
- Réception notifications (nouvelle lumière, présence, force, repos)
- État de chargement & gestion erreurs
- Page de bienvenue

### 4.4 Notifications & Routines (`notification/`, `routines_exercices/`)
- Système de notifications
- Exercices de respiration (Breath.json)
- Flash reset
- Animations "soothing thumb"

### 4.5 Profil & Paramètres (`profil/`)
- Gestion profil utilisateur
- Paramètres

---

## 5. COUCHE MÉTIER - CUSTOM CODE

### 5.1 Services Personnalisés (`custom_code/`)

#### **twin_service.dart**
- Logique métier mode Twin
- Communication bidirectionnelle twins
- Synchronisation signaux

#### **squad_service.dart**
- Gestion groupes/cercles
- Actions groupe
- Gestion membres

#### **rtdb_session.dart**
- Real-time Database sessions
- Gestion sessions utilisateur
- Synchronisation en temps réel

#### **routine_lobby.dart**
- Gestion lobby routines
- Orchestration exercices

### 5.2 Actions Personnalisées (`custom_code/actions/`)

| Action | Description |
|--------|-------------|
| `connect_google_calendar.dart` | Authentification OAuth Google Calendar |
| `save_calendar_events.dart` | Sauvegarde événements Firestore |
| `fetch_today_events.dart` | Récupère événements du jour depuis API Google |
| `reschedule_event.dart` | Modifie horaire événement |
| `save_guardian_suggestions.dart` | Sauvegarde suggestions IA tuteur |
| `create_lunch_break_block.dart` | Crée bloc pause déjeuner calendrier |

### 5.3 Widgets Personnalisés (`custom_code/widgets/`)

| Widget | Utilité |
|--------|---------|
| `animated_aura.dart` | Aura animée (chakra/énergie) |
| `aura_cleaning.dart` | Animation nettoyage aura |
| `cognitive_sorting.dart` | Tri cognitif visuel |
| `eye_movement_e_m_d_r.dart` | Exercice EMDR (mouvements oculaires) |
| `light_transfer_animation.dart` | Animation transfert de lumière |
| `sozia_loading_dots.dart` | Indicateur chargement custom |
| `soothing_thumb.dart` | Interaction apaisante (pouce) |
| `send_repos_twin.dart` | Envoyer repos à twin |
| `send_presence_twin.dart` | Envoyer présence |
| `send_force_twin.dart` | Envoyer force |

---

## 6. ÉTAT GLOBAL & PERSISTENCE (`app_state.dart`)

**FFAppState** (Singleton Provider):
```dart
- guardianModeActive: bool          # Mode tuteur activé
- googleCalendarToken: String       # Token OAuth Google
- microsoftGraphToken: String       # Token OAuth Microsoft
- pendingActions: List<DocumentRef> # Actions en attente
- [autres flags de sessions]
```

Gestion: **Provider 6.1.5** + **ChangeNotifier**

---

## 7. CONFIGURATION FIREBASE

### 7.1 Fichiers de Configuration
- `firebase.json` - Configuration Firebase project
- `firestore.rules` - Règles de sécurité Firestore
- `firestore.indexes.json` - Index optimisés
- `storage.rules` - Règles accès Storage

### 7.2 Points d'Entrée
- **iOS**: `ios/Runner/GoogleService-Info.plist`
- **Android**: `android/app/google-services.json`

---

## 8. ASSETS & RESSOURCES

```
assets/
├── audios/              # Fichiers audio
├── fonts/               # Polices personnalisées
├── images/              # Images (icons, backgrounds)
├── jsons/
│   └── Breath.json      # Données exercices respiration
├── pdfs/                # Documents PDF
├── rive_animations/     # Animations Rive
└── videos/              # Vidéos tutoriels/contenu
```

---

## 9. PLATEFORMES NATIVES

### 9.1 iOS (`ios/`)
- **Minimum**: iOS 11+
- **Notification**: Extension `ImageNotification/` pour notifications enrichies
- **Bridging Header**: Interopérabilité Swift/Dart
- **Entitlements**: Configuration capabilities (camera, contacts, calendrier)
- **Privacy**: `PrivacyInfo.xcprivacy`

### 9.2 Android (`android/`)
- **Build**: Gradle (versions configurées)
- **Proguard**: Obfuscation code
- **Lifecycle**: Plugin flutter_plugin_android_lifecycle

---

## 10. PATTERNS & CONVENTIONS OBSERVÉES

### 10.1 Architecture MVVM-like
```
Page/Screen
├── *_widget.dart        # UI (StatefulWidget)
├── *_model.dart         # Logic (extends FlutterFlowModel)
└── (Data via Backend)
```

### 10.2 Nomenclature Prefix Fichiers Pages
- `a_*` → Page primaire/principale d'une section
- `b_*` → Deuxième page
- `z_*` → Page finale (ex: welcome)
- `l_*` → Login/Connexion
- `c_*` → Configuration/Connexion
- `d_*` → Dashboard/Details
- `f_*` → Final/Fin
- `g_*` → Registration/Guichet
- `i_*` → Invitation
- `k_*` → Success/Confirmation

### 10.3 Thématique Énergies (5 Piliers)
- **Lumière**: Énergie positive, clarté
- **Présence**: Connexion, pleine conscience
- **Force**: Énergie vitale
- **Repos**: Récupération, sommeil
- **Signes/Émotions**: Lecture d'émotions (Selfie AI)

### 10.4 FlutterFlow Framework
L'app utilise **FlutterFlow** (builder visuel Flutter):
- Widgets standardisés (`flutter_flow_widgets.dart`)
- Thème centralisé (`flutter_flow_theme.dart`)
- Utilitaires helpers (`flutter_flow_util.dart`)
- Routage déclaratif (`nav/`)

---

## 11. PERFORMANCE & MONITORING

### 11.1 Analytics
- **Firebase Performance**: `firebase_performance` 0.10.1+7
- Monitoring temps réponse, crashes

### 11.2 Cache & Optimisation
- **Image Cache**: `cached_network_image` 3.4.1
- **Cache Manager**: `flutter_cache_manager` 3.4.1
- **Local Storage**: `shared_preferences` 2.5.3

---

## 12. INTÉGRATIONS TIERCES

| Intégration | Objectif |
|-------------|----------|
| **Google Calendar API** | Sync calendrier gardien/tuteur |
| **Microsoft Graph** | Connexion Outlook/Microsoft |
| **Google ML Kit Face** | Détection visage + émotions (selfies) |
| **Google Fonts** | Typographie |
| **Localization** | i18n multi-langue |

---

## 13. POINTS DE COMPLEXITÉ IDENTIFIÉS

### Domaines à Optimiser:
1. **Gestion État**: Dépendance heavy Provider + FFAppState
2. **Widgets Custom**: Animations complexes + state management local
3. **Syncro Temps Réel**: Twin/Cercle action confirmation
4. **IA/Selfie**: Détection faciale + analyse émotions
5. **Calendar Sync**: Logique complexe Google/Microsoft reconciliation
6. **Permissions**: Multiples (camera, contacts, calendrier, storage)
7. **Erreur Handling**: Patterns cohérents à améliorer

---

## 14. FICHIERS CLÉS POUR DÉMARRAGE

| Fichier | Priorité | Raison |
|---------|----------|--------|
| `lib/main.dart` | CRITIQUE | Point d'entrée |
| `lib/app_state.dart` | HAUTE | État global |
| `lib/backend/backend.dart` | HAUTE | Accès données |
| `lib/flutter_flow/nav/nav.dart` | HAUTE | Routage app |
| `lib/connexion/l_connexion/` | MOYENNE | Onboarding |
| `firebase/functions/` | MOYENNE | Backend Node.js |

---

## 15. RECOMMANDATIONS POUR AMÉLIORATION

### Quick Wins:
1. ✅ Audit permissions (demander uniquement les nécessaires)
2. ✅ Lazy loading images & données
3. ✅ Centraliser erreurs (ErrorHandler pattern)
4. ✅ Tests unitaires custom_code/

### Moyen Terme:
1. 🔄 Refactor state management (Riverpod/Redux alternative)
2. 🔄 Modulariser custom_code/ en features
3. 🔄 Documentation API Cloud Functions
4. 🔄 Augmenter couverture tests

### Long Terme:
1. 📊 Migration architecture à micro-app strategy
2. 📊 Offline-first sync strategy
3. 📊 WebSocket vs HTTP polling Twin/Cercle

---

## 16. COMMANDES DE BUILD ESSENTIELLES

```bash
# Lancer application
flutter run

# Build release iOS
flutter build ios --release

# Build release Android
flutter build apk --release

# Build web
flutter build web --release

# Tests
flutter test

# Analyser code
flutter analyze

# Format code
dart format lib/
```

---

## 17. VERSION & ROADMAP

- **Actuelle**: 0.0.1+35 (Early Beta)
- **État**: Développement actif
- **Cible**: MVP complet puis production
- **Cadence**: Itérationen rapides

---

**Document généré le**: 2026-06-29
**Pour envoi IA**: ✅ Format structuré, prêt pour analyse
