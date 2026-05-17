const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();

const db        = admin.firestore();
const messaging = admin.messaging();

const ROUTINE_LABELS = {
  collective_shield: 'Collective Shield',
  squad_pulse:       'Squad Pulse',
  morning_ritual:    'Morning Ritual',
  audio_capsule:     'Audio Capsule',
  twin_coherence:    'Twin-Cohérence',
  mirror_aura:       'Mirror-Aura',
  silent_presence:   'Silent-Presence',
  pulse_match:       'Pulse-Match',
};

// ─────────────────────────────────────────────────────────────────────────────
// SQUAD : nouvelle session → notifier tous les membres du squad (sauf lanceur)
// Déclenché par la création d'un doc dans squad_sessions/
// ─────────────────────────────────────────────────────────────────────────────
exports.onSquadSessionCreated = functions.firestore
  .document('squad_sessions/{sessionId}')
  .onCreate(async (snap, context) => {
    const { squadId, routineName, launchedBy } = snap.data();

    // Récupère le squad pour avoir la liste des UIDs membres
    const squadDoc = await db.collection('squads').doc(squadId).get();
    if (!squadDoc.exists) return null;
    const members = squadDoc.data().users || [];

    // Collecte les tokens FCM de chaque membre (sauf le lanceur)
    const tokens = [];
    for (const uid of members) {
      if (uid === launchedBy) continue;
      const userDoc = await db.collection('users').doc(uid).get();
      const token = userDoc.data()?.fcmToken;
      if (token) tokens.push(token);
    }
    if (tokens.length === 0) return null;

    // Nom du lanceur
    const launcherDoc = await db.collection('users').doc(launchedBy).get();
    const launcherName = launcherDoc.data()?.prenom || 'Une amie';
    const label = ROUTINE_LABELS[routineName] || routineName;

    return messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: '✨ Tiyia — Invitation Squad',
        body:  `${launcherName} t'invite à faire ${label}`,
      },
      data: {
        routineName,
        sessionId: context.params.sessionId,
        type: 'squad_session',
      },
      android: { priority: 'high' },
      apns:    { payload: { aps: { sound: 'default', badge: 1 } } },
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// TWIN : nouvelle session → notifier le twin (sauf lanceur)
// Déclenché par la création d'un doc dans twin_sessions/
// ─────────────────────────────────────────────────────────────────────────────
exports.onTwinSessionCreated = functions.firestore
  .document('twin_sessions/{sessionId}')
  .onCreate(async (snap, context) => {
    const { users, routineName, launchedBy } = snap.data();

    const twinUid = (users || []).find(uid => uid !== launchedBy);
    if (!twinUid) return null;

    const twinDoc = await db.collection('users').doc(twinUid).get();
    const token   = twinDoc.data()?.fcmToken;
    if (!token) return null;

    const launcherDoc = await db.collection('users').doc(launchedBy).get();
    const launcherName = launcherDoc.data()?.prenom || 'Ton Twin';
    const label = ROUTINE_LABELS[routineName] || routineName;

    return messaging.send({
      token,
      notification: {
        title: '💜 Tiyia — Ton Twin t\'appelle',
        body:  `${launcherName} veut faire ${label} avec toi`,
      },
      data: {
        routineName,
        sessionId: context.params.sessionId,
        type: 'twin_session',
      },
      android: { priority: 'high' },
      apns:    { payload: { aps: { sound: 'default', badge: 1 } } },
    });
  });
