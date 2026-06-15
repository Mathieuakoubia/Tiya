# REGLES DE DEVELOPPEMENT TIYIA MVP

## SECURITE — REGLES ABSOLUES

- Jamais de cle API, secret, token, ou credential dans le code source
- Jamais de `google-services.json` ni `firebase_options.dart` commites (deja dans `.gitignore`)
- Toujours valider les entrees a la frontiere du systeme (formulaires, API externes)
- Limiter la longueur des champs texte utilisateur (max 500 chars par defaut)
- Requetes Firestore : toujours utiliser des parametres, jamais de concatenation de chaines
- Cibles : Android + iOS uniquement (pas de web)
- il faut catch les erreur quand tu cree une fonctionnalité 

## SECURITE FIRESTORE — REGLES METIER

- Validation d'appartenance Squad croisee obligatoire : tout document qui reference un `squadId` doit verifier que l'auteur est membre de ce squad via `isSquadMember(squadId)`
- Un utilisateur ne peut ecrire que des documents dont il est l'auteur (`fromUid`, `authorUid`, `userUid` == `request.auth.uid`)
- Les lectures Squad sont restreintes aux membres du squad concerne (jamais `allow read: if isAuth()` seul pour des donnees Squad)
- Champs modifiables restreints : toujours utiliser `affectedKeys().hasOnly([...])` pour limiter les updates

## RGPD — DONNEES BIOMETRIQUES

- Aucune image ou audio sauvegarde sur disque
- Traitement biometrique (visage, voix) en RAM uniquement
- Seul le resultat texte de l'analyse Aura est sauvegarde en Firestore
- Si la camera est indisponible : fallback propre (pas de crash)

## CYCLE DE VIE / BATTERIE

- Liberer `AVCaptureSession` apres 6 secondes maximum
- Appeler `record.dispose()` apres 3 secondes maximum
- Stopper tous les streams dans `dispose()`

## STYLE DE CODE

- Aucun emoji dans le code, les strings, ou les commentaires
- Constantes nommees pour toutes les valeurs magiques
- Commentaires uniquement quand le POURQUOI n'est pas evident
- Pas de blocs de commentaires multi-lignes ni de docstrings

## CHARTE GRAPHIQUE — PALETTE OFFICIELLE

| Role | Hex |
|---|---|
| Background principal | #121212 |
| Turquoise (accent primaire) | #0DAABA |
| Bleu petrole (accent secondaire) | #065963 |
| Lila (doux/feminin) | #D9CCE8 |
| Ivoire (clarte) | #F8F1E9 |
| Gold (energie) | #E8B86E |

Aucune couleur hors palette autorisee sans justification explicite dans le spec de la routine.

## TYPOGRAPHIE

- Titres / phrases Aria : Gelica
- Corps de texte : Poppins
- Texte secondaire italique : Playfair

## AUTRE 

- Ce n'est pas un MVP que l'on developpe mais la solution finale
