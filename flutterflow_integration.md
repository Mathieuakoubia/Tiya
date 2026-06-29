# Intégration du système de routines d'équipe dans FlutterFlow (Sozia)

## Contexte projet

L'application FlutterFlow s'appelle **Sozia** (package `sozia`, version 0.0.1+35).
Les pages Twin et Cercle existent déjà. L'objectif est d'intégrer les routines
dans ces pages existantes — pas de créer de nouvelles pages.

| Terminologie code custom | Terminologie FlutterFlow/Sozia |
|---|---|
| Squad | Cercle |
| SquadScreen | `cercle/a_cercle_dashboard` |
| TwinScreen | `twin/a_twin_dashboard` |

---

## Principe général

FlutterFlow ne peut pas gérer nativement la logique de session temps réel
(invitations, acceptation, countdown, navigation conditionnelle vers des
widgets custom). Il faut donc diviser le travail en deux :

| Ce que FlutterFlow gère | Ce qui reste en code custom |
|---|---|
| UI des pages Twin et Cercle (listes, cartes, boutons) | `TwinService` et `SquadService` (Custom Actions) |
| Requêtes Firestore simples (membres, invitations) | `RoutineLobby` (Custom Widget complet) |
| Navigation entre pages FF | Toutes les routines elles-mêmes (déjà custom) |
| App State / Page State | Stream d'écoute de session |

---

## 1. Fichiers custom dans FlutterFlow

### 1.1 Fichiers déjà en place

Ces fichiers sont déjà présents dans le code téléchargé depuis FlutterFlow :

```
custom_code/services/twin_service.dart     ← déjà là
custom_code/services/squad_service.dart    ← déjà là
custom_code/services/rtdb_session.dart     ← déjà là
custom_code/routine_lobby.dart             ← déjà là
```

### 1.2 Fichiers de routines à ajouter

Dans FlutterFlow > **Custom Code > Custom Files**, ajouter chaque fichier de
routine dans `custom_code/widgets/` :

```
custom_code/widgets/twin_coherence.dart
custom_code/widgets/twin_coherence_rt.dart
custom_code/widgets/mirror_aura.dart
custom_code/widgets/silent_presence.dart
custom_code/widgets/pulse_match.dart
custom_code/widgets/duo_morning.dart
custom_code/widgets/debrief_duo.dart
custom_code/widgets/night_tandem.dart
custom_code/widgets/savoring_duo.dart
custom_code/widgets/bio_ambient_duo.dart
custom_code/widgets/collective_shield.dart
custom_code/widgets/squad_pulse.dart
custom_code/widgets/squad_morning_pulse.dart
custom_code/widgets/squad_gratitude_garden.dart
custom_code/widgets/squad_celebration_wave.dart
custom_code/widgets/squad_resonance.dart
custom_code/widgets/squad_night_watch.dart
```

### 1.3 Correction des imports dans routine_lobby.dart

Dans `routine_lobby.dart`, les imports relatifs doivent pointer vers les bons chemins :

```dart
// Services
import '/custom_code/services/twin_service.dart';
import '/custom_code/services/squad_service.dart';

// Routines twin
import '/custom_code/widgets/twin_coherence.dart';
import '/custom_code/widgets/twin_coherence_rt.dart';
import '/custom_code/widgets/mirror_aura.dart';
import '/custom_code/widgets/silent_presence.dart';
import '/custom_code/widgets/pulse_match.dart';
import '/custom_code/widgets/duo_morning.dart';
import '/custom_code/widgets/debrief_duo.dart';
import '/custom_code/widgets/night_tandem.dart';
import '/custom_code/widgets/savoring_duo.dart';
import '/custom_code/widgets/bio_ambient_duo.dart';

// Routines squad/cercle
import '/custom_code/widgets/collective_shield.dart';
import '/custom_code/widgets/squad_pulse.dart';
import '/custom_code/widgets/squad_morning_pulse.dart';
import '/custom_code/widgets/squad_gratitude_garden.dart';
import '/custom_code/widgets/squad_celebration_wave.dart';
import '/custom_code/widgets/squad_resonance.dart';
import '/custom_code/widgets/squad_night_watch.dart';
```

---

## 2. Variables App State à ajouter

`FFAppState` existe déjà dans le projet Sozia avec les champs :
`guardianModeActive`, `googleCalendarToken`, `microsoftGraphToken`, `pendingActions`.

Dans FlutterFlow > **App State**, **ajouter** ces 7 nouvelles variables
(ne pas toucher aux variables existantes) :

| Nom | Type | Description |
|---|---|---|
| `myName` | String | Prénom de l'utilisateur courant |
| `twinUid` | String | UID du twin matché |
| `twinInviteId` | String | ID du document twinInvitation |
| `twinName` | String | Prénom du twin |
| `squadId` | String | ID du cercle courant |
| `squadMemberUids` | List\<String\> | UIDs des membres du cercle |
| `squadMemberNames` | List\<String\> | Prénoms des membres du cercle |

Charger ces valeurs au démarrage via la Custom Action `initAppState()`
appelée dans **On App Load** de la page principale.

---

## 3. Custom Actions

Chaque méthode de service devient une Custom Action dans
FlutterFlow > **Custom Code > Custom Actions**.

### 3.1 initAppState

Appelée dans l'action **On App Load** de la page principale.

```dart
import 'package:sozia/flutter_flow/flutter_flow_util.dart';
import '/custom_code/services/twin_service.dart';
import '/custom_code/services/squad_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future initAppState() async {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return;

  final myDoc = await FirebaseFirestore.instance
      .collection('users').doc(uid).get();
  FFAppState().myName =
      myDoc.data()?['prenom'] as String? ?? '';

  final invite = await TwinService.getMyMatchedTwin();
  if (invite != null) {
    final users = List<String>.from(invite['users'] ?? []);
    FFAppState().twinInviteId = invite['id'] as String? ?? '';
    FFAppState().twinUid =
        users.firstWhere((u) => u != uid, orElse: () => '');
    final twinDoc = await FirebaseFirestore.instance
        .collection('users').doc(FFAppState().twinUid).get();
    FFAppState().twinName =
        twinDoc.data()?['prenom'] as String? ?? '';
  }

  final squad = await SquadService.getMySquad();
  if (squad != null) {
    FFAppState().squadId = squad['id'] as String? ?? '';
    final memberUids = List<String>.from(squad['users'] ?? []);
    FFAppState().squadMemberUids = memberUids;
    final memberDocs = await Future.wait(
      memberUids.map((u) => FirebaseFirestore.instance
          .collection('users').doc(u).get()),
    );
    FFAppState().squadMemberNames = memberDocs
        .map((d) => d.data()?['prenom'] as String? ?? '?')
        .toList();
  }
}
```

### 3.2 launchTwinRoutine

Appelée quand l'utilisateur appuie sur une tuile de routine twin dans
`twin/a_twin_dashboard`.

**Paramètres d'entrée :**
- `routineKey` (String)
- `routineTitle` (String)

```dart
import '/custom_code/routine_lobby.dart';
import 'package:flutter/material.dart';
import 'package:sozia/flutter_flow/flutter_flow_util.dart';

Future launchTwinRoutine(
  BuildContext context,
  String routineKey,
  String routineTitle,
) async {
  if (FFAppState().twinUid.isEmpty) return;
  await Navigator.push(context, MaterialPageRoute(
    builder: (_) => RoutineLobby(
      routineKey: routineKey,
      routineTitle: routineTitle,
      routineType: 'twin',
      myName: FFAppState().myName,
      twinUid: FFAppState().twinUid,
      twinInviteId: FFAppState().twinInviteId,
      partnerName: FFAppState().twinName,
    ),
  ));
}
```

### 3.3 launchSquadRoutine

Appelée depuis `cercle/a_cercle_dashboard`.

**Paramètres d'entrée :**
- `routineKey` (String)
- `routineTitle` (String)

```dart
import '/custom_code/routine_lobby.dart';
import 'package:flutter/material.dart';
import 'package:sozia/flutter_flow/flutter_flow_util.dart';

Future launchSquadRoutine(
  BuildContext context,
  String routineKey,
  String routineTitle,
) async {
  if (FFAppState().squadId.isEmpty) return;
  await Navigator.push(context, MaterialPageRoute(
    builder: (_) => RoutineLobby(
      routineKey: routineKey,
      routineTitle: routineTitle,
      routineType: 'squad',
      myName: FFAppState().myName,
      squadId: FFAppState().squadId,
      memberUids: FFAppState().squadMemberUids,
      memberNames: FFAppState().squadMemberNames,
    ),
  ));
}
```

### 3.4 joinRoutineSession

Appelée quand le destinataire appuie sur "Rejoindre" dans la bannière
de session entrante.

**Paramètres d'entrée :**
- `sessionId` (String)
- `routineKey` (String)
- `routineTitle` (String)
- `routineType` (String) — `'twin'` ou `'squad'`

```dart
import '/custom_code/routine_lobby.dart';
import 'package:flutter/material.dart';
import 'package:sozia/flutter_flow/flutter_flow_util.dart';

Future joinRoutineSession(
  BuildContext context,
  String sessionId,
  String routineKey,
  String routineTitle,
  String routineType,
) async {
  await Navigator.push(context, MaterialPageRoute(
    builder: (_) => RoutineLobby(
      routineKey: routineKey,
      routineTitle: routineTitle,
      routineType: routineType,
      myName: FFAppState().myName,
      existingSessionId: sessionId,
      squadId: routineType == 'squad' ? FFAppState().squadId : null,
    ),
  ));
}
```

### 3.5 sendTwinRequest / acceptTwinRequest / declineTwinRequest

```dart
// sendTwinRequest — paramètre : toUid (String)
import '/custom_code/services/twin_service.dart';

Future sendTwinRequest(String toUid) async {
  await TwinService.sendTwinRequest(toUid);
}

// acceptTwinRequest — paramètre : inviteId (String)
Future acceptTwinRequest(String inviteId) async {
  await TwinService.acceptTwinRequest(inviteId);
  await initAppState();
}

// declineTwinRequest — paramètre : inviteId (String)
Future declineTwinRequest(String inviteId) async {
  await TwinService.declineTwinRequest(inviteId);
}
```

### 3.6 sendSquadInvite / acceptSquadInvite / declineSquadInvite / leaveSquad

```dart
import '/custom_code/services/squad_service.dart';
import 'package:sozia/flutter_flow/flutter_flow_util.dart';

// sendSquadInvite — paramètre : toUid (String)
Future sendSquadInvite(String toUid) async {
  await SquadService.sendInvite(toUid);
}

// acceptSquadInvite — paramètres : inviteId, squadId (String)
Future acceptSquadInvite(String inviteId, String squadId) async {
  await SquadService.acceptInvite(inviteId, squadId);
  await initAppState();
}

// declineSquadInvite — paramètre : inviteId (String)
Future declineSquadInvite(String inviteId) async {
  await SquadService.declineInvite(inviteId);
}

// leaveSquad
Future leaveSquad() async {
  await SquadService.leaveSquad();
  FFAppState().squadId = '';
  FFAppState().squadMemberUids = [];
  FFAppState().squadMemberNames = [];
}
```

### 3.7 searchUsers

**Paramètre :** `query` (String)
**Retour :** `List<dynamic>` (chaque item : `{uid, prenom, email}`)

```dart
import '/custom_code/services/twin_service.dart';

Future<List<dynamic>> searchUsers(String query) async {
  return await TwinService.searchUsers(query);
}
```

---

## 4. Intégration dans les pages existantes

Les pages Twin et Cercle **existent déjà** dans Sozia. On les enrichit.

### Page `twin/a_twin_dashboard`

Ajouter un bloc conditionnel **dans la page existante** :

```
Si AppState.twinUid n'est pas vide
  → Afficher la section routines twin (liste + bannière sessions)
Sinon
  → (La page gère déjà l'état "pas de twin" via les pages invitation_twin)
```

**Section routines twin à ajouter :**
- **Bannière sessions entrantes** (voir section 5)
- Liste des 10 routines twin → action `launchTwinRoutine(context, routineKey, routineTitle)`

**Tableau des routines twin :**

| Icône | routineKey | routineTitle |
|---|---|---|
| air | twin_coherence_rt | Cohérence Twin |
| electric_bolt | mirror_aura | Mirror Aura |
| water | silent_presence | Silent Presence |
| flash_on | pulse_match | Pulse Match |
| wb_sunny_outlined | duo_morning | Duo Morning |
| chat_bubble_outline | debrief_duo | Debrief Duo |
| nightlight_round | night_tandem | Night Tandem |
| spa_outlined | savoring_duo | Savoring Duo |
| waves | bio_ambient_duo | Bio Ambient Duo |
| favorite | twin_coherence | Twin Cohérence |

### Page `cercle/a_cercle_dashboard`

Même principe dans la page Cercle existante :

```
Si AppState.squadId n'est pas vide
  → Afficher la section routines cercle (liste + bannière sessions)
```

**Tableau des routines cercle :**

| Icône | routineKey | routineTitle |
|---|---|---|
| wb_sunny_outlined | squad_morning_pulse | Morning Pulse |
| favorite_border | squad_gratitude_garden | Gratitude Garden |
| shield_outlined | collective_shield | Collective Shield |
| electric_bolt | squad_pulse | Squad Pulse |
| celebration_outlined | squad_celebration_wave | Celebration Wave |
| support_outlined | squad_resonance | Squad Resonance |
| nightlight_round | squad_night_watch | Night Watch |

---

## 5. Bannière de sessions entrantes

Créer un **Component** réutilisable `IncomingSessionBanner`.

**Query Firestore pour twin :**
```
Collection : twin_sessions
Filtre 1 : users arrayContains [currentUserUid]
Filtre 2 : status in ['waiting', 'accepted']
```

**Query Firestore pour cercle :**
```
Collection : squad_sessions
Filtre 1 : squadId == AppState.squadId
Filtre 2 : status in ['waiting', 'accepted']
```

Le filtre `launchedBy != currentUid` n'est pas possible nativement dans FF.
Créer une **Custom Function** :

```dart
// Custom Function : isIncomingSession
// Paramètres : launchedBy (String), acceptedBy (List<String>)
// Retour : bool
import 'package:firebase_auth/firebase_auth.dart';

bool isIncomingSession(String launchedBy, List<String> acceptedBy) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  return launchedBy != uid && !acceptedBy.contains(uid);
}
```

Appliquer dans la **Conditional Visibility** de chaque card.

Chaque card affiche `routineTitle`, `initiatorName` et un bouton "Rejoindre"
→ action `joinRoutineSession(context, sessionId, routineKey, routineTitle, routineType)`

---

## 6. Navigation : schéma complet

```
FlutterFlow Page (a_twin_dashboard / a_cercle_dashboard)
  │
  ├── Tuile routine tapée
  │     └── Custom Action launchTwinRoutine / launchSquadRoutine
  │           └── Navigator.push → RoutineLobby (Custom Widget)
  │                 │
  │                 ├── Phase "waiting" (initiateur)
  │                 ├── Phase "invite" (destinataire)
  │                 ├── Initiateur clique "Commencer"
  │                 │     └── Firestore status → 'started'
  │                 ├── Phase "countdown" 3-2-1
  │                 └── Navigator.pushReplacement → Routine Widget
  │
  └── Bannière "Rejoindre" (IncomingSessionBanner)
        └── Custom Action joinRoutineSession
              └── Navigator.push → RoutineLobby (mode destinataire)
                    └── (même flux)
```

`RoutineLobby` utilise `Navigator.pushReplacement` : depuis la routine,
Back revient à la page FF (pas au lobby).

---

## 7. Dépendances pubspec à vérifier

Dans FlutterFlow > **Settings > Pubspec Dependencies**, vérifier la présence de :

```yaml
cloud_firestore: ^5.x.x     # déjà présent (5.6.9)
firebase_auth: ^5.x.x       # déjà présent (5.6.0)
firebase_database: ^11.x.x  # A AJOUTER — utilisé par rtdb_session.dart
                             # pour les routines temps réel (twin_coherence_rt, etc.)
```

**Important :** `firebase_database` n'est pas dans le projet Sozia actuel.
Il faut l'ajouter manuellement dans pubspec avant de tester les routines RT.

---

## 8. Checklist de mise en place dans FlutterFlow

- [ ] Corriger les imports dans `routine_lobby.dart` (chemins `/custom_code/services/` et `/custom_code/widgets/`)
- [ ] Ajouter les 17 fichiers de routines dans `custom_code/widgets/`
- [ ] Ajouter `firebase_database: ^11.x.x` dans pubspec
- [ ] Ajouter les 7 variables App State (myName, twinUid, twinInviteId, twinName, squadId, squadMemberUids, squadMemberNames)
- [ ] Créer la Custom Action `initAppState` et l'appeler dans **On App Load**
- [ ] Créer les Custom Actions : `launchTwinRoutine`, `launchSquadRoutine`, `joinRoutineSession`
- [ ] Créer les Custom Actions de gestion : `sendTwinRequest`, `acceptTwinRequest`, `declineTwinRequest`, `sendSquadInvite`, `acceptSquadInvite`, `declineSquadInvite`, `leaveSquad`, `searchUsers`
- [ ] Créer la Custom Function `isIncomingSession`
- [ ] Intégrer la section routines dans la page `twin/a_twin_dashboard` existante
- [ ] Intégrer la section routines dans la page `cercle/a_cercle_dashboard` existante
- [ ] Créer le composant `IncomingSessionBanner` (twin + cercle) avec la Custom Function de filtre
- [ ] Brancher chaque tuile sur `launchTwinRoutine` / `launchSquadRoutine`
- [ ] Brancher "Rejoindre" sur `joinRoutineSession`
- [ ] Tester le flux complet : initiateur lance → destinataire reçoit bannière → accepte → initiateur voit "Prêt" → Commencer → countdown → routine

---

## 9. Ce que RoutineLobby gère automatiquement

Une fois lancé via les Custom Actions, `RoutineLobby` gère tout le flux temps réel.
FlutterFlow n'intervient pas :

- Création du document de session dans Firestore
- Écoute temps réel du document (stream)
- Acceptation et mise à jour du statut
- Affichage des membres avec état accepté/en attente
- Activation du bouton "Commencer" quand au moins 1 autre membre a accepté
- Déclenchement du countdown 3-2-1 quand `status == 'started'`
- Navigation vers la bonne routine selon `routineKey`
- Cas `squad_celebration_wave` : saisie du mot de célébration avant envoi
- Annulation et nettoyage du document si l'initiateur quitte
