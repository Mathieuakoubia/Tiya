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