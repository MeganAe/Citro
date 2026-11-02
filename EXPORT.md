# Publier le jeu sur téléphone et sur le web

Le jeu détecte tout seul un téléphone ou une tablette et affiche alors les commandes tactiles, en paysage. Sur ordinateur, tu peux les tester dans le jeu : Options → Schéma de commandes → Tactile (le clic de souris remplace le doigt avec une tablette graphique ou un écran tactile ; sans écran tactile, utilise plutôt l'export web sur ton téléphone).

Je n'ai pas pu essayer le jeu sur un vrai téléphone depuis mon environnement : fais le test de la liste en bas avant de publier.

## Option A — Web (le plus rapide à partager)

1. Godot 4.3 → Éditeur → Gérer les modèles d'exportation → télécharger.
2. Projet → Exporter → Ajouter… → **Web**.
3. Laisse « Prise en charge des threads » **désactivée** (le jeu marche partout, y compris sur iPhone). Exporte vers un dossier `build/` en nommant le fichier `index.html`.
4. Mets le dossier en ligne en HTTPS : itch.io (type « HTML », « Cette page s'affiche en plein écran sur mobile »), GitHub Pages ou Netlify.
5. Sur le web, Godot utilise le moteur graphique « Compatibilité » : le rendu est un peu plus simple (pas de halo lumineux). Rien à régler.

Un navigateur de téléphone ne passe pas en plein écran tout seul : demande aux joueurs d'ajouter la page à l'écran d'accueil, ou héberge sur itch.io qui propose le plein écran.

## Option B — Android (APK / AAB)

À faire sur ordinateur (Windows, macOS ou Linux), une seule fois :

1. Installe **JDK 17** et **Android Studio** (ou seulement les outils en ligne de commande). Dans le SDK Manager, ajoute : Platform-Tools, Build-Tools 34, Platform 34, Command-line Tools, CMake 3.10.2 et NDK 23.2.8568313.
2. Dans Godot : Éditeur → Paramètres de l'éditeur → Exporter → Android : renseigne le chemin du SDK Android et du JDK.
3. Éditeur → Gérer les modèles d'exportation → télécharger les modèles 4.3.
4. Crée une clé de signature (garde le fichier et le mot de passe en lieu sûr, la perdre empêche toute mise à jour) :
   `keytool -genkey -v -keystore nuit-des-citrouilles.keystore -alias nuit -keyalg RSA -keysize 2048 -validity 10000`

Pour chaque version :

1. Projet → Exporter → Ajouter… → **Android**.
2. Dans la section **Options** : renseigne la clé (Release), le nom de paquet unique (par exemple `com.tonnom.nuitdescitrouilles`), la version.
   Architectures : coche seulement **arm64-v8a**. Permissions : coche **Vibrate**.
3. Pour tester sur ton téléphone : active le mode développeur, branche-le en USB, puis le bouton Android « Déploiement en un clic » en haut de Godot.
4. Pour le Play Store : coche « Utiliser une compilation Gradle » (installe le modèle Android depuis le menu Projet) puis exporte en **AAB**. Le Play Store exige un AAB. Le premier compte développeur coûte 25 $ une fois.

L'icône vient de Projet → Paramètres du projet → Application → Config → Icône ; pour Android, ajoute aussi l'icône adaptative dans le préréglage (voir `PROMPTS_ASSETS.md`).

## Si le jeu est lent sur un téléphone

- Options → Qualité graphique → **Basse** (c'est le réglage par défaut sur mobile : pas d'ombres, pas de halo, image un peu moins nette).
- `scripts/game.gd` : dans `_max_enemies`, réduis `26.0` (nombre maximum de monstres à l'écran).
- `scripts/world.gd` : réduis le nombre de tombes, d'arbres et de lanternes.

## Liste de test sur téléphone

- [ ] Le jeu démarre en paysage, rien n'est caché par l'encoche ou les coins arrondis.
- [ ] Joystick : marcher doucement, courir en poussant à fond.
- [ ] Caméra : glisser à droite tourne ; garder le doigt sur le bouton de tir et glisser tourne aussi.
- [ ] Tir, rechargement, roulade répondent du premier coup, deux doigts en même temps.
- [ ] Le bouton pause marche ; recevoir un appel ou changer d'appli met le jeu en pause.
- [ ] Options : curseurs et boutons faciles à toucher ; les réglages sont gardés après avoir fermé le jeu.
- [ ] Le jeu reste fluide à la fin de la nuit (le plus de monstres). Sinon, qualité Basse ou moins de monstres.
