# Guide d'Implémentation Biométrique Interne — Projet SOZIA
Dernière mise à jour : 29 Mai 2026

Ce document valide et structure la transition de la solution cloud Hume AI (sunset le 14 juin 2026) vers la nouvelle architecture de traitement 100% locale (On-Device).

---

## 1. Viabilité Technique & Sécurité des Sources

### A. Évaluation de la Solution On-Device
* **Viabilité :** La solution est excellente et hautement viable. Exécuter les modèles directement sur le smartphone élimine les temps de latence réseau, supprime les coûts d'infrastructure Cloud et garantit une conformité RGPD native (aucune donnée biométrique ou vocale ne quitte l'appareil).
* **Fiabilité du Dépôt (Savchenko) :** Tu peux accorder une confiance totale aux travaux du chercheur Andrey Savchenko. Ses modèles d'architecture *EfficientNet-B2* sont des références académiques et industrielles pour la reconnaissance d'émotions légères et optimisées sur architectures ARM mobiles.
* **Format TFLite :** Le fichier `enet_b2_8.tflite` fourni est déjà compilé pour TensorFlow Lite, ce qui permet une exécution directe par les puces neuronales et graphiques des smartphones (NPU/GPU).

### B. Choix Technologiques : Langage & Base de Données
* **Langage unique :** Tout le traitement s'effectue localement en **Dart** (langage natif de Flutter/FlutterFlow) via les liaisons binaires des packages (`tflite_flutter`, `google_mlkit_face_detection`, `record`). Aucun langage backend ou serveur externe n'est requis[cite: 5].
* **Gestion des Données (Modèles IA) :** Le fichier `.tflite` ne s'intègre pas dans une base de données[cite: 5]. Il doit être téléchargé et placé directement dans le répertoire local `assets/models/` de l'application et déclaré dans le fichier `pubspec.yaml`[cite: 5].
* **Gestion des Résultats (Firestore) :** Les flux vidéos et les fichiers audio de 3 secondes sont uniquement traités en mémoire vive (RAM) et immédiatement détruits après l'analyse[cite: 5]. **Seul le résultat mathématique final** (le score de Valence/Arousal ou le code couleur hexadécimal de l'Aura généré, ex: `#9DD9D2`) est sauvegardé dans ta base de données Firestore[cite: 4, 5].

---

## 2. Architecture de Synchronisation (FlutterFlow ➔ Code Custom)

Pour garantir une expérience fluide, l'ensemble du processus biométrique doit être encapsulé dans une **Custom Action FlutterFlow** asynchrone développée sur VS Code[cite: 1, 5].




## flutter pub outdated
Showing outdated packages.
[*] indicates versions that are not the latest available.

Package Name                           Current              Upgradable           Resolvable           Latest              

direct dependencies:                  
audio_session                          *0.1.25              *0.1.25              0.2.3                0.2.3               
audioplayers                           *5.2.1               *5.2.1               *6.6.0               6.7.0               
camera                                 *0.10.6              *0.10.6              *0.11.2              0.12.0+1            
cloud_firestore                        *5.6.12              *5.6.12              6.5.0                6.5.0               
cupertino_icons                        *1.0.8               *1.0.8               *1.0.8               1.0.9               
firebase_auth                          *5.7.0               *5.7.0               6.5.2                6.5.2               
firebase_core                          *3.15.2              *3.15.2              4.10.0               4.10.0              
firebase_database                      *11.3.10             *11.3.10             12.4.2               12.4.2              
firebase_messaging                     *15.2.10             *15.2.10             16.3.0               16.3.0              
firebase_storage                       *12.4.10             *12.4.10             13.4.2               13.4.2              
google_fonts                           *6.3.0               *6.3.0               *6.3.0               8.1.0               
google_mlkit_face_detection            *0.9.0               *0.9.0               *0.13.1              0.13.2              
image                                  *4.8.0               *4.8.0               *4.8.0               4.9.1               
just_audio                             *0.9.46              *0.9.46              0.10.5               0.10.5              
noise_meter                            *5.0.2               *5.0.2               *5.0.2               5.1.0               
permission_handler                     *11.4.0              *11.4.0              *11.4.0              12.0.3              
record                                 *5.2.1               *5.2.1               *6.2.1               7.0.0               
sensors_plus                           *5.0.1               *5.0.1               7.0.0                7.0.0               
tflite_flutter                         *0.10.4              *0.10.4              0.12.1               0.12.1              
vibration                              *1.9.0               *1.9.0               3.1.8                3.1.8               

dev_dependencies:                     
flutter_lints                          *5.0.0               *5.0.0               *5.0.0               6.0.0               

transitive dependencies:              
_flutterfire_internals                 *1.3.59              *1.3.59              1.3.72               1.3.72              
async                                  *2.11.0              *2.11.0              *2.11.0              2.13.1              
audio_streamer                         *4.2.2               *4.2.2               *4.2.2               4.3.0               
audioplayers_android                   *4.0.3               *4.0.3               5.2.1                5.2.1               
audioplayers_darwin                    *5.0.2               *5.0.2               6.4.0                6.4.0               
audioplayers_linux                     *3.1.0               *3.1.0               4.2.1                4.2.1               
audioplayers_platform_interface        *6.1.0               *6.1.0               7.1.1                7.1.1               
audioplayers_web                       *4.1.0               *4.1.0               *5.2.0               5.2.1               
audioplayers_windows                   *3.1.0               *3.1.0               *4.3.0               4.3.1               
boolean_selector                       *2.1.1               *2.1.1               *2.1.1               2.1.2               
camera_android                         *0.10.10+5           *0.10.10+5           -                    0.10.10+18          
camera_android_camerax                 -                    -                    *0.6.17              0.7.2+1             
camera_avfoundation                    *0.9.21+1            *0.9.21+1            *0.9.21+1            0.10.1              
camera_platform_interface              *2.10.0              *2.10.0              *2.10.0              2.13.0              
camera_web                             *0.3.5               *0.3.5               *0.3.5               0.3.5+3             
characters                             *1.3.0               *1.3.0               *1.3.0               1.4.1               
clock                                  *1.1.1               *1.1.1               *1.1.1               1.1.2               
cloud_firestore_platform_interface     *6.6.12              *6.6.12              8.0.2                8.0.2               
cloud_firestore_web                    *4.4.12              *4.4.12              5.5.0                5.5.0               
collection                             *1.19.0              *1.19.0              *1.19.0              1.19.1              
cross_file                             *0.3.4+2             *0.3.4+2             *0.3.4+2             0.3.5+2             
device_info_plus                       *11.3.0              *11.3.0              *11.3.0              13.1.0              
device_info_plus_platform_interface    *7.0.2               *7.0.2               *7.0.2               8.1.0               
fake_async                             *1.3.1               *1.3.1               *1.3.1               1.3.3               
ffi                                    *2.1.3               *2.1.3               *2.1.3               2.2.0               
firebase_auth_platform_interface       *7.7.3               *7.7.3               9.0.2                9.0.2               
firebase_auth_web                      *5.15.3              *5.15.3              6.2.2                6.2.2               
firebase_core_platform_interface       *6.0.3               *6.0.3               7.0.1                7.0.1               
firebase_core_web                      *2.24.1              *2.24.1              3.8.0                3.8.0               
firebase_database_platform_interface   *0.2.6+10            *0.2.6+10            0.4.0+2              0.4.0+2             
firebase_database_web                  *0.2.6+16            *0.2.6+16            0.2.7+9              0.2.7+9             
firebase_messaging_platform_interface  *4.6.10              *4.6.10              4.8.0                4.8.0               
firebase_messaging_web                 *3.10.10             *3.10.10             4.2.0                4.2.0               
firebase_storage_platform_interface    *5.2.10              *5.2.10              6.0.2                6.0.2               
firebase_storage_web                   *3.10.17             *3.10.17             3.11.8               3.11.8              
flutter_plugin_android_lifecycle       *2.0.29              *2.0.29              *2.0.29              2.0.35              
google_mlkit_commons                   *0.6.1               *0.6.1               *0.11.0              0.11.1              
js                                     *0.6.7               *0.6.7               -                    0.7.2               (discontinued)  
leak_tracker                           *10.0.7              *10.0.7              *10.0.7              11.0.2              
leak_tracker_flutter_testing           *3.0.8               *3.0.8               *3.0.8               3.0.10              
leak_tracker_testing                   *3.0.1               *3.0.1               *3.0.1               3.0.2               
matcher                                *0.12.16+1           *0.12.16+1           *0.12.16+1           0.12.20             
material_color_utilities               *0.11.1              *0.11.1              *0.11.1              0.13.0              
meta                                   *1.15.0              *1.15.0              *1.15.0              1.18.2              
mime                                   -                    -                    2.0.0                2.0.0               
path                                   *1.9.0               *1.9.0               *1.9.0               1.9.1               
path_provider_android                  *2.2.17              *2.2.17              *2.2.17              2.3.1               
path_provider_foundation               *2.4.1               *2.4.1               *2.4.1               2.6.0               
permission_handler_android             *12.1.0              *12.1.0              *12.1.0              13.0.1              
permission_handler_apple               *9.4.7               9.4.9                9.4.9                9.4.9               
petitparser                            *6.0.2               *6.0.2               *6.0.2               7.0.2               
record_android                         *1.5.2               *1.5.2               *1.5.2               2.0.1               
record_ios                             -                    -                    *1.2.1               2.0.0               
record_macos                           -                    -                    *1.2.2               2.0.0               
record_platform_interface              *1.5.0 (overridden)  *1.5.0 (overridden)  *1.5.0 (overridden)  2.0.0 (overridden)  
record_web                             *1.3.0               *1.3.0               *1.3.0               2.0.0               
record_windows                         *1.0.7               *1.0.7               *1.0.7               2.0.0               
sensors_plus_platform_interface        *1.2.0               *1.2.0               2.0.1                2.0.1               
source_span                            *1.10.0              *1.10.0              *1.10.0              1.10.2              
stack_trace                            *1.12.0              *1.12.0              *1.12.0              1.12.1              
stream_channel                         *2.1.2               *2.1.2               *2.1.2               2.1.4               
string_scanner                         *1.3.0               *1.3.0               *1.3.0               1.4.1               
synchronized                           *3.3.0+3             *3.3.0+3             *3.3.0+3             3.4.1               
term_glyph                             *1.2.1               *1.2.1               *1.2.1               1.2.2               
test_api                               *0.7.3               *0.7.3               *0.7.3               0.7.12              
uuid                                   *4.5.2               4.5.3                4.5.3                4.5.3               
vector_math                            *2.1.4               *2.1.4               *2.1.4               2.3.0               
vibration_platform_interface           *0.0.3               *0.0.3               0.1.2                0.1.2               
vm_service                             *14.3.0              *14.3.0              *14.3.0              15.2.0              
win32                                  *5.10.1              *5.10.1              *5.10.1              6.3.0               
win32_registry                         *1.1.5               *1.1.5               *1.1.5               3.0.3               
xml                                    *6.5.0               *6.5.0               *6.5.0               7.0.1               

transitive dev_dependencies:          
lints                                  *5.1.1               *5.1.1               *5.1.1               6.1.0               

2 upgradable dependencies are locked (in pubspec.lock) to older versions.
To update these dependencies, use `flutter pub upgrade`.

37  dependencies are constrained to versions that are older than a resolvable version.
To update these dependencies, edit pubspec.yaml, or run `flutter pub upgrade --major-versions`.

js
    Package js has been discontinued. See https://dart.dev/go/package-discontinue