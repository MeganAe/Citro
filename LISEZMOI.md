# La Nuit des Citrouilles — version 3

Jeu de survie 3D (Godot 4.3 ou plus récent). Tu es enfermé dans un cimetière la nuit d'Halloween : tiens jusqu'à l'aube (5 minutes, de minuit à 6 h). Joue au clavier et à la souris, ou au doigt sur téléphone et tablette.

## Lancer le jeu

1. Installe **Godot 4.3 ou plus récent** (godotengine.org).
2. Importer → choisis `project.godot` → attends l'import des modèles (première fois seulement).
3. **F5** pour jouer.

## Ce qui a changé dans cette version

- **Menus refaits** : écran titre, commandes, options, pause, fin de partie avec statistiques. Police Cinzel (titres) et Barlow Semi Condensed (texte), icônes Lucide, une seule couleur d'accent. Fonctionne à la souris, au clavier (Tab, Entrée, Échap) et au doigt.
- **Options** : volumes (général, musique, effets), sensibilité de la caméra, schéma de commandes (Auto, Tactile, Clavier), aide à la visée et vibrations (tactile), qualité graphique (Basse, Moyenne, Haute), plein écran, compteur d'images par seconde. Tout est sauvegardé.
- **Mobile** : joystick flottant à gauche, caméra au doigt à droite, boutons de tir, roulade, rechargement et pause. Le tir se cale sur le monstre proche du viseur (désactivable). Pause automatique si l'appli perd le focus. Marges de sécurité pour les encoches.
- **HUD refait** : vie et endurance avec icônes, horloge, munitions, compteur de monstres, message d'événement, indicateur de gel.

## Commandes clavier

| Action | Touche |
|---|---|
| Bouger | ZQSD ou WASD, flèches |
| Courir | Maj |
| Roulade | Espace |
| Viser / tirer | Souris / clic gauche (maintenu = tir continu) |
| Recharger | R |
| Pause | Échap ou P |

## Fichiers à connaître

- `scripts/ui_theme.gd` : palette, polices, thème de tous les menus. Pour changer la couleur d'accent : `ACCENT`.
- `scripts/menus.gd` : écrans titre, commandes, options, pause, fin de partie.
- `scripts/hud.gd` : interface en jeu.
- `scripts/touch_controls.gd` : commandes tactiles (tailles et positions dans `_layout`).
- `scripts/settings.gd` : réglages sauvegardés, détection du mobile.
- `scripts/game.gd`, `player.gd`, `enemy.gd`, `world.gd` : le jeu lui-même (durée de la nuit, ennemis, arme, cimetière).
- `assets/ui/key_art.jpg` et `assets/ui/logo.png` : images facultatives du menu (voir `PROMPTS_ASSETS.md`).

## À faire de ton côté

1. **Texture des décors** : copie `halloweenbits_texture.png` (pack Halloween Bits d'origine) dans `assets/halloween/`. Sans elle, les décors ont des couleurs de secours.
2. **Images** : fais générer `key_art.jpg`, l'icône et le visuel de boutique avec `PROMPTS_ASSETS.md`.
3. **Publier** : suis `EXPORT.md` (web ou Android) et passe la liste de test sur un vrai téléphone.

## Licences

- Polices Cinzel et Barlow Semi Condensed : SIL Open Font License (fichiers de licence dans `assets/fonts/`).
- Icônes Lucide : licence ISC (`assets/ui/icons/LICENSE-lucide.txt`).
- Personnage et décors : packs Quaternius / KayKit, selon leurs licences d'origine.
