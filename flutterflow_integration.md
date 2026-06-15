# Intégration du système de routines d'équipe dans FlutterFlow

## Principe général

FlutterFlow ne peut pas gérer nativement la logique de session temps réel
(invitations, acceptation, countdown, navigation conditionnelle vers des
widgets custom). Il faut donc diviser le travail en deux :

| Ce que FlutterFlow gère | Ce qui reste en code custom |
|---|---|
| UI des pages Twin et Squad (listes, cartes, boutons) | `TwinService` et `SquadService` (Custom Actions) |
| Requêtes Firestore simples (membres, invitations) | `RoutineLobby` (Custom Widget complet) |
| Navigation entre pages FF | Toutes les routines elles-mêmes (déjà custom) |
| App State / Page State | Stream d'écoute de session |

---

## 1. Fichiers custom à importer dans FlutterFlow

Dans FlutterFlow > **Custom Code > Custom Files**, importer (ou coller) :

```
lib/twin_service.dart
lib/squad_service.dart
lib/routine_lobby.dart
lib/rtdb_session.dart
```

Ainsi que tous les fichiers de routines déjà existants
(`twin_coherence_rt.dart`, `duo_morning.dart`, etc.).

Ces fichiers apparaissent ensuite comme des imports disponibles dans
les Custom Actions et Custom Widgets.

---

## 2. Variables App State à créer

Dans FlutterFlow > **App State**, créer ces variables persistantes
(elles survivent à la navigation entre pages) :

| Nom | Type | Description |
|---|---|---|
| `myName` | String | Prénom de l'utilisateur courant |
| `twinUid` | String | UID du twin matché |
| `twinInviteId` | String | ID du document twinInvitation |
| `twinName` | String | Prénom du twin |
| `squadId` | String | ID du squad courant |
| `squadMemberUids` | List\<String\> | UIDs des membres du squad |
| `squadMemberNames` | List\<String\> | Prénoms des membres du squad |

Charger ces valeurs au démarrage de l'app via une Custom Action
`initAppState()` (voir section 3).

---

## 3. Custom Actions

Chaque méthode de service devient une Custom Action dans
FlutterFlow > **Custom Code > Custom Actions**.

### 3.1 initAppState

Charge le profil utilisateur, le twin et le squad au démarrage.
Appelée dans l'action **On App Load** de la page principale.

```dart
import 'package:tiyia_mvp/custom_code/actions/index.dart';
import 'package:tiyia_mvp/flutter_flow/flutter_flow_util.dart';
import '/custom_code/twin_service.dart';
import '/custom_code/squad_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future initAppState() async {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return;

  // Prénom
  final myDoc = await FirebaseFirestore.instance
      .collection('users').doc(uid).get();
  FFAppState().myName =
      myDoc.data()?['prenom'] as String? ?? '';

  // Twin
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

  // Squad
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

Appelée quand l'utilisateur appuie sur une tuile de routine twin.
Retourne le widget `RoutineLobby` via `Navigator.push`.

**Paramètres d'entrée (à définir dans FF) :**
- `routineKey` (String)
- `routineTitle` (String)

```dart
import '/custom_code/routine_lobby.dart';
import 'package:flutter/material.dart';

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

Même principe pour les routines squad.

**Paramètres d'entrée :**
- `routineKey` (String)
- `routineTitle` (String)

```dart
import '/custom_code/routine_lobby.dart';
import 'package:flutter/material.dart';

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
Future sendTwinRequest(String toUid) async {
  await TwinService.sendTwinRequest(toUid);
}

// acceptTwinRequest — paramètre : inviteId (String)
Future acceptTwinRequest(String inviteId) async {
  await TwinService.acceptTwinRequest(inviteId);
  await initAppState(); // recharge l'App State
}

// declineTwinRequest — paramètre : inviteId (String)
Future declineTwinRequest(String inviteId) async {
  await TwinService.declineTwinRequest(inviteId);
}
```

### 3.6 sendSquadInvite / acceptSquadInvite / declineSquadInvite / leaveSquad

```dart
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

Retourne une liste JSON pour alimenter une ListView dans FF.

**Paramètre :** `query` (String)
**Retour :** `List<dynamic>` (chaque item : `{uid, prenom, email}`)

```dart
Future<List<dynamic>> searchUsers(String query) async {
  return await TwinService.searchUsers(query);
}
```

---

## 4. Structure des pages FlutterFlow

### Page TwinScreen

Conditions d'affichage à gérer via **Conditional Visibility** dans FF :

```
Si AppState.twinUid est vide
  → Afficher le bloc "Pas de twin" (recherche + invitations reçues)
Sinon
  → Afficher le bloc "Twin matché" (carte twin + routines)
```

**Bloc "Pas de twin" :**
- TextField de recherche → action `searchUsers(query)` → ListView de résultats
- Chaque résultat : bouton "Inviter" → action `sendTwinRequest(uid)`
- StreamBuilder sur `twinInvitation` (collection FF) filtré par
  `users arrayContains currentUserUid AND status == 'pending'`
  → cards Accepter/Refuser → actions `acceptTwinRequest` / `declineTwinRequest`

**Bloc "Twin matché" :**
- Carte profil du twin (texte depuis AppState.twinName)
- **Bannière sessions entrantes** (voir section 5)
- Liste des 10 routines twin (voir tableau ci-dessous)
  → chaque tuile appelle `launchTwinRoutine(context, routineKey, routineTitle)`

**Tableau des routines twin à créer comme items de liste :**

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

### Page SquadScreen

Même logique de conditional visibility :

```
Si AppState.squadId est vide
  → Bloc "Pas de squad" (créer / rejoindre)
Sinon
  → Bloc "Squad matché" (membres + routines)
```

**Bloc "Squad matché" :**
- Header avec nom du squad
- **Bannière sessions entrantes** (voir section 5)
- StreamBuilder sur `squads/{squadId}` → liste des membres
- Liste des 7 routines squad → action `launchSquadRoutine`
- Recherche pour inviter → action `sendSquadInvite`
- Bouton quitter → action `leaveSquad`

**Tableau des routines squad :**

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

C'est le composant qui affiche "Quelqu'un t'invite à une routine".

Dans FlutterFlow, créer un **Component** réutilisable `IncomingSessionBanner`.

**Query Firestore à configurer dans le composant :**

Pour twin :
```
Collection : twin_sessions
Filtre 1 : users arrayContains [currentUserUid]
Filtre 2 : status in ['waiting', 'accepted']
```

Pour squad :
```
Collection : squad_sessions
Filtre 1 : squadId == AppState.squadId
Filtre 2 : status in ['waiting', 'accepted']
```

**Filtrage côté Flutter** (dans le builder) — afficher uniquement les documents
où `launchedBy != currentUserUid` ET `acceptedBy` ne contient pas `currentUserUid`.

Ce filtre n'est pas possible nativement dans FF (FF ne supporte pas les filtres
`!=` sur des arrays). Il faut donc une Custom Function :

```dart
// Custom Function : isIncomingSession
// Paramètres : launchedBy (String), acceptedBy (List<String>)
// Retour : bool

bool isIncomingSession(String launchedBy, List<String> acceptedBy) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  return launchedBy != uid && !acceptedBy.contains(uid);
}
```

Appliquer cette fonction dans la **Conditional Visibility** de chaque card.

Chaque card affiche :
- `routineTitle` (champ du document)
- `initiatorName` (champ du document)
- Bouton "Rejoindre" → action `joinRoutineSession(context, sessionId, routineKey, routineTitle, routineType)`

---

## 6. Navigation : schéma complet

```
FlutterFlow Page (TwinScreen / SquadScreen)
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
  └── Bannière "Rejoindre"
        └── Custom Action joinRoutineSession
              └── Navigator.push → RoutineLobby (mode destinataire)
                    └── (même flux que ci-dessus)
```

`RoutineLobby` utilise `Navigator.pushReplacement` pour naviguer vers
la routine : quand l'utilisateur appuie sur Back depuis la routine,
il revient directement à la page FF (pas au lobby).

---

## 7. Dépendances pubspec à vérifier dans FF

Dans FlutterFlow > **Settings > Pubspec Dependencies**, s'assurer que ces
packages sont présents (ils le sont déjà dans le projet code) :

```yaml
cloud_firestore: ^5.x.x
firebase_auth: ^5.x.x
firebase_database: ^11.x.x   # pour RTDB (routines RT)
```

---

## 8. Checklist de mise en place dans FlutterFlow

- [ ] Importer les fichiers custom (twin_service, squad_service, routine_lobby, rtdb_session + tous les fichiers routines)
- [ ] Créer les 6 variables App State (myName, twinUid, twinInviteId, twinName, squadId, squadMemberUids, squadMemberNames)
- [ ] Créer la Custom Action `initAppState` et l'appeler dans **On App Load**
- [ ] Créer les Custom Actions : `launchTwinRoutine`, `launchSquadRoutine`, `joinRoutineSession`
- [ ] Créer les Custom Actions de gestion : `sendTwinRequest`, `acceptTwinRequest`, `declineTwinRequest`, `sendSquadInvite`, `acceptSquadInvite`, `declineSquadInvite`, `leaveSquad`, `searchUsers`
- [ ] Créer la Custom Function `isIncomingSession`
- [ ] Construire la page TwinScreen avec conditional visibility twin/pas-de-twin
- [ ] Construire la page SquadScreen avec conditional visibility squad/pas-de-squad
- [ ] Créer le composant `IncomingSessionBanner` (twin + squad) avec la query Firestore et la Custom Function de filtre
- [ ] Brancher chaque tuile de routine sur `launchTwinRoutine` / `launchSquadRoutine`
- [ ] Brancher le bouton "Rejoindre" sur `joinRoutineSession`
- [ ] Tester le flux complet : initiateur lance → destinataire reçoit la bannière → accepte → initiateur voit "Prêt" → clique Commencer → countdown → routine

---

## 9. Ce que RoutineLobby gère automatiquement

Une fois lancé via les Custom Actions, `RoutineLobby` gère de façon
autonome tout le flux temps réel. FlutterFlow n'a pas à intervenir :

- Création du document de session dans Firestore
- Écoute temps réel du document (stream)
- Acceptation et mise à jour du statut
- Affichage de la liste des membres avec état accepté/en attente
- Activation du bouton "Commencer" quand au moins 1 autre membre a accepté
- Déclenchement du countdown 3-2-1 quand `status == 'started'`
- Navigation vers la bonne routine selon `routineKey`
- Cas `squad_celebration_wave` : saisie du mot de célébration avant envoi
- Annulation et nettoyage du document si l'initiateur quitte
