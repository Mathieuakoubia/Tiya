# Integration du widget InfiniDraw dans FlutterFlow

## Prerequis

- Projet FlutterFlow existant
- Acces a l'editeur de Custom Widgets

---

## Etape 1 : Creer le Custom Widget

1. Dans FlutterFlow, ouvrir le panneau lateral gauche
2. Cliquer sur **Custom Code** (icone `</>`)
3. Cliquer sur **+ Add** puis **Widget**
4. Nommer le widget : `InfiniDraw`
5. Ajouter un parametre :
   - Nom : `onComplete`
   - Type : `Action` (nullable)

---

## Etape 2 : Coller le code

1. Supprimer tout le code genere par defaut dans l'editeur
2. Ouvrir le fichier `lib/infini_draw.dart` du projet
3. Copier **tout** le contenu du fichier
4. Coller dans l'editeur FlutterFlow

### Modification requise pour FlutterFlow

FlutterFlow genere ses widgets avec un prefixe. Renommer la classe publique :

```dart
// La ligne :
class InfiniDraw extends StatefulWidget {

// Doit correspondre au nom que vous avez donne dans FlutterFlow.
// Si FlutterFlow attend "InfiniDraw", ne changez rien.
```

Les classes privees (`_InfiniDrawState`, `_Ico`, `_Phase`, `_InfiniGuidePainter`, `_PathPainter`) restent telles quelles car elles sont internes au widget.

---

## Etape 3 : Polices personnalisees

Le widget utilise la police **Gelica**. Dans FlutterFlow :

1. Aller dans **Settings & Integrations** > **Design System** > **Typography**
2. Verifier que la police Gelica est ajoutee en tant que custom font
3. Si elle n'est pas disponible, ajouter les fichiers `.ttf` / `.otf` via **Custom Fonts**

Si Gelica n'est pas disponible, le widget utilisera la police par defaut sans crash.

---

## Etape 4 : Asset image

Le widget reference une image dans l'ecran de completion :

```
assets/images/Fonds-02.png
```

Dans FlutterFlow :
1. Aller dans **Settings & Integrations** > **Assets**
2. Uploader `Fonds-02.png`
3. Verifier que le chemin correspond a `assets/images/Fonds-02.png`

---

## Etape 5 : Police d'icones icomoon

Le widget utilise une icone custom via la police `icomoon` (code `0xe901`).

1. Aller dans **Custom Code** > **Custom Files**
2. Ajouter le fichier `icomoon.ttf` dans les assets du projet
3. Declarer la police dans `pubspec.yaml` via FlutterFlow :

```yaml
fonts:
  - family: icomoon
    fonts:
      - asset: assets/fonts/icomoon.ttf
```

Si la police icomoon n'est pas presente, l'icone de l'ecran de completion ne s'affichera pas (pas de crash).

---

## Etape 6 : Placer le widget dans une page

1. Creer une nouvelle page ou ouvrir la page cible
2. Dans l'arbre de widgets, ajouter un **Custom Widget**
3. Selectionner `InfiniDraw`
4. Configurer le parametre `onComplete` :
   - Lier a une action FlutterFlow (ex: naviguer vers la page suivante)
   - Ou laisser vide si la navigation se fait via le bouton "Continuer" interne

### Taille du widget

Le widget est concu pour occuper **tout l'ecran** (il contient son propre `Scaffold`).
Configurez le container parent avec :
- Width : `double.infinity` ou `MediaQuery.of(context).size.width`
- Height : `double.infinity` ou `MediaQuery.of(context).size.height`

---

## Etape 7 : Tester

1. Lancer le mode **Test** dans FlutterFlow ou compiler via Xcode/Android Studio
2. Verifier les points suivants :

| Point de controle                                      | Attendu                                      |
|--------------------------------------------------------|----------------------------------------------|
| Compte a rebours 3-2-1                                 | Affiche sur fond turquoise                   |
| Message "Posez votre doigt pour commencer"             | Visible en bas de l'ecran                    |
| Trace du doigt                                         | Trainee gold vers lila, s'efface rapidement  |
| Lever le doigt                                         | Chrono en pause, message de reprise          |
| Reposer le doigt                                       | Chrono reprend                               |
| Mouvement rapide du doigt                              | Vibration haptique progressive               |
| Timer atteint 0:00                                     | Ecran de completion avec image de fond       |
| Bouton "Continuer"                                     | Ferme l'ecran (pop)                          |

---

## Dependances

Le widget utilise uniquement des packages Flutter natifs (`flutter/material.dart`, `flutter/services.dart`).
Aucune dependance externe supplementaire n'est requise pour FlutterFlow.

---

## Depannage

**Le trace ne s'affiche pas :**
Verifier que le widget a bien la taille plein ecran. Un container trop petit empeche le `GestureDetector` de capter les evenements tactiles.

**La vibration ne fonctionne pas :**
`HapticFeedback` necessite un appareil physique. Le simulateur iOS ne reproduit pas les retours haptiques.

**L'image de completion ne s'affiche pas :**
Verifier le chemin `assets/images/Fonds-02.png` dans les assets FlutterFlow.

**La police Gelica ne s'applique pas :**
Verifier que les fichiers de police sont correctement declares dans les custom fonts FlutterFlow.
