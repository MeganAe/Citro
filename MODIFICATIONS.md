# Modifications apportées — assets générés intégrés

Projet d'origine téléchargé depuis le lien fourni, avec les assets générés intégrés
(images en réalisme 3D photoréaliste + nouveaux sons). Aucun script n'a été modifié.

## Images ajoutées (style rendu 3D réaliste)
- `assets/ui/key_art.jpg` — 1920×1080, fond du menu (le code de `menus.gd` le charge
  automatiquement). Action à droite, gauche sombre pour les boutons.
- `assets/ui/logo.png` — 1120×460 transparent, citrouille 3D avec croissant de lune.
  Affiché à la place du titre texte dès qu'il est présent (prévu dans `menus.gd`).
- `assets/ui/app_icon.png` — 1024×1024, icône de l'application.
- `assets/ui/app_icon_background.png` — 432×432, fond uni #0d1226 (icône adaptative Android).
- `assets/ui/app_icon_foreground.png` — 432×432 transparent, motif dans les 66 % centraux.
- `store/feature_graphic.png` — 1024×500 (Play Store).
- `store/itch_cover_630x500.png` — 630×500 (couverture itch.io).

## Modification de configuration
- `project.godot` → `config/icon` pointe maintenant sur `res://assets/ui/app_icon.png`
  (au lieu de `icon.svg`, qui est conservé mais n'est plus utilisé).
  Pour Android : dans le préréglage d'export, renseigner aussi l'icône adaptative
  avec `app_icon_foreground.png` + `app_icon_background.png`.

## Sons remplacés (mêmes noms de fichiers, donc aucun code à changer)
Les 15 fichiers de `assets/audio/` : `music_night.wav` et `music_dawn.wav`
(60 s bouclables, mono 22 050 Hz), `heartbeat.wav`, `shoot.wav`, `reload.wav`,
`empty.wav`, `enemy_hit.wav`, `enemy_die.wav`, `hurt.wav`, `pickup.wav`,
`freeze.wav`, `roll.wav`, `bell.wav`, `win.wav`, `lose.wav` (effets en 44,1 kHz mono).

Note : les musiques et le heartbeat sont bien en mono 16 bits, format attendu par
`_make_loop_player()` dans `game.gd` (calcul de `loop_end`).

## Fichiers d'import Godot
Les `.import` des nouvelles images ont été générés avec Godot 4.3
(`--headless --import`) et le projet a été testé : il se lance et tous les
assets se chargent (vérifié par script de chargement). Le dossier `.godot/`
(cache d'import) n'est pas inclus dans le ZIP : Godot le régénère à l'ouverture.

## Toujours manquant (inchangé, cf. PROMPTS_ASSETS.md)
- `assets/halloween/halloweenbits_texture.png` : à récupérer dans le pack
  Halloween Bits d'origine (non générable par IA).
- Captures d'écran boutiques : à faire en jeu réel sur téléphone.

## Mise a jour : titre du menu, filets et musiques personnelles

- Nouveau titre du menu en image (`assets/ui/title.webp`, 1200 px, fond
  transparent) : lettrage 3D pierre/metal "LA NUIT DES CITROUILLES" avec la
  citrouille au croissant de lune. Il remplace l'ancien texte en Cinzel
  ecrit par le code (et l'ancien `logo.png`, supprime).
- Tous les filets de separation (`UI.rule`) ont ete retires des menus :
  filet ambre sous le titre, filets sous les en-tetes (Commandes, Options,
  sections), filet vertical entre les colonnes de Commandes, filets des
  ecrans Pause et Fin de partie. Remplaces par de simples espacements.
- Musiques personnelles : le dossier `AJOUTEZ_VOS_MUSIQUES_ICI/` a la racine
  du projet recoit vos chansons (MP3/OGG/WAV, lues par ordre alphabetique,
  en boucle). S'il contient au moins une chanson, `game.gd` la joue a la
  place des musiques d'ambiance ; dossier vide = musiques d'origine.
  Mode d'emploi detaille dans `AJOUTEZ_VOS_MUSIQUES_ICI/LISEZ-MOI.txt`.
  Teste dans Godot : chanson detectee et jouee, retour aux musiques
  d'origine des que le dossier est vide.

## Mise a jour : collisions strictes (on ne traverse plus rien)

Diagnostic (mesures faites dans Godot) : les tombes, la crypte, les bancs
avaient deja des collisions, mais :
- les murs invisibles etaient a ARENA + 0,6 alors que la cloture visuelle est
  a ARENA - 0,3 (epaisse de 0,39 m) : on entrait d'environ 60 cm DANS la
  cloture et les murs avant d'etre arrete ;
- les citrouilles decoratives (26), les bougies et les morceaux de cloture
  brisee etaient en collide = "none" : on les traversait ;
- les piliers du portail d'entree n'avaient aucune collision ;
- les boites des props faisaient 85 % de la taille du modele et les troncs
  d'arbres 0,25 m de rayon : on s'enfoncait visuellement dans les objets.

Corrections dans scripts/world.gd :
- murs invisibles alignes sur la face interieure de la cloture
  (half = ARENA + 0,0) : le joueur est arrete par la cloture elle-meme ;
- nouveau mode de collision "cylinder" pour les props ronds (citrouilles
  decoratives, bougies) ; morceaux de cloture brisee passes en "box" ;
- piliers du portail rendus solides (boites invisibles de 0,55 x 3,4 x 0,7 m
  a x = -1,45 / +1,45), le passage central reste libre ;
- boites des props a 97 % de la taille reelle du modele, troncs d'arbres
  a 0,32-0,60 m de rayon ;
- restent volontairement sans collision : les plaques de terre des tombes
  et les os plats au sol (on marche dessus), et la foret derriere la
  cloture (hors de portee).
Dans scripts/player.gd : accroche au sol (0,30 m), angle de mur et marge
de securite physique ajustes (0,06 m).

Tests physiques automatises dans Godot (personnage-test, capsule du joueur,
8 m/s) : cloture sud/nord/est -> arret a 33,12 m (le bord de la capsule
touche la cloture sans y entrer) ; tombe/sanctuaire -> arret a 0,81 m du
centre ; citrouille decorative -> arret a 0,67 m (rayon du cylindre +
rayon du joueur). Le jeu complet se lance sans erreur.

## Mise a jour : visee realiste, solide et fluide

Constat sur l'ancien systeme : l'aide a la visee ne fonctionnait qu'au
tactile ; le personnage tirait avant d'etre tourne vers sa cible (la balle
partait de sa poitrine dans l'axe de la camera, meme de dos) ; le reticule
ne disait jamais si on touchait ; aucun recul.

Dans scripts/player.gd :
- Aide a la visee douce pour TOUTES les commandes (souris comprise), si
  elle est activee dans les Options : cone de 13 degres a la souris,
  20 degres au tactile, portee = portee du tir, et controle de ligne de
  vue (jamais de verrouillage a travers un mur ou une tombe). La cible
  gardee beneficie d'une hysteresis de 2,5 degres pour ne pas sauter
  d'un monstre a l'autre. Point vise = centre de masse du monstre
  (nouveau Enemy.aim_point() dans enemy.gd : poitrine au sol, centre
  pour les volants).
- Des qu'on vise/tire, le personnage fait face a la camera AVANT que la
  balle parte (rotation rapide dediee), il se deplace a 62 % de sa
  vitesse pendant la visee (tir stable), et le traceur part de la bouche
  du canon (epaule droite) au lieu du centre de la poitrine.
- Recul camera : petit coup (0,02 rad) qui s'estompe en ~0,2 s a chaque tir.
Dans scripts/hud.gd : reticule dynamique - blanc au repos, ambre et
legerement dilate quand un monstre est sous le viseur ou verrouille,
rouge 0,12 s quand une balle touche (signaux aim_changed / hit_confirmed
du joueur, branches dans bind_player()).
Dans scripts/menus.gd : l'option "Aide a la visee" est maintenant visible
pour tous les schemas de commande (plus seulement le tactile), et les
ecrans Commandes l'expliquent.

Tests automatises (scenes de test lancees dans Godot 4.3) :
- monstre en face du viseur -> verrouille ; a 30 degres -> ignore ;
  derriere un mur -> ignore (ligne de vue).
- tir reel avec viseur decale de 8 degres : le monstre perd 2 PV en
  2 balles tirees (12 -> 10 munitions), et le modele du personnage se
  tourne a -172 degres, face a la visee. Jeu complet lance sans erreur.

## Mise a jour : graphismes et ambiance

Decouverte : la texture du pack Halloween Bits n'etait pas perdue. Chaque
FBX contient la meme atlas 1024x1024 (les fichiers *_0.png, tous identiques),
mais props.gd ne l'appliquait que sous le nom halloweenbits_texture.png.
-> assets/halloween/halloweenbits_texture.png restauree (copie d'un *_0.png) :
tous les modeles ont maintenant leurs vraies couleurs/textures du pack au
lieu des couleurs unies de secours. Verifie dans Godot : le materiau de la
pierre tombale reference bien la texture.

Dans scripts/game.gd (environnement) :
- lune visible dans le ciel : disque pale a crateres + halo, genere par le
  code, place dans la direction de la lumiere de lune, exempt de brouillard ;
- contre-jour froid faible (0,18, sans ombres) oppose a la lune : les
  silhouettes se detachent du fond ;
- etalonnage : exposition 1,06, contraste 1,08, saturation 1,12 ;
- brouillard retravaille : densite 0,014 + brume basse pres du sol
  (hauteur 7 m), ciel peu affecte (0,35) ;
- ombres de lune en 4 paliers (qualite haute), biais normal 0,5 contre
  l'effet granuleux sur les modeles low-poly ;
- par qualite : occlusion ambiante SSAO des la Moyenne (les props posent
  au sol), et en Haute : brouillard volumetrique (halos des lanternes dans
  la brume, energie volumetrique 1,6 sur les lanternes) + SDFGI.
Dans scripts/world.gd : le sol n'est plus un aplat uni - texture de terre
procedurale (bruit fractal sans couture, tuile ~4,5 m), aucun fichier requis.

Le jeu complet se lance sans erreur apres ces changements. Sur telephone
(qualite Basse par defaut), SSAO/volumetrique/SDFGI sont coupes : seule la
texture restauree et l'etalonnage s'appliquent, sans cout de performance.

## Mise a jour : jouable par tout le monde

Difficultes (Options -> JEU, sauvegardees) : Histoire / Normal / Cauchemar.
Elles agissent sur le nombre max de monstres (x0,65 / 1 / 1,35 en fin de
nuit : 22 / 34 / 46), le rythme d'apparition (x1,35 / 1 / 0,8), la vitesse
(x0,85 / 1 / 1,15), les degats (x0,6 / 1 / 1,4) et les PV (x0,75 / 1 / 1,3)
des monstres (scripts/game.gd, fonction _diff).

Manette complete (scripts/inputs.gd, _add_gamepad) : stick gauche pour
bouger, stick droit pour la camera (branche dans player.gd, meme
sensibilite que la souris), RT ou RB pour tirer, B roulade, X recharger,
LB/L3 courir, Start pause, A valider, Y recommencer. Les menus se pilotent
a la manette via les actions d'interface natives de Godot et le focus deja
en place. Verifie : les 10 actions ont bien leurs evenements manette.

Tutoriel interactif (premiere partie uniquement) : 5 gestes appris en
jouant - se deplacer, tourner la camera, tirer, roulade, recharger - avec
un texte adapte au schema de commande (tactile / clavier / manette),
monstres retardes de 30 s, Entree ou A pour passer. La completion est
sauvegardee (tutorial_seen), il ne se rejoue pas. Teste de bout en bout
dans une vraie partie : les 5 etapes s'enchainent et se terminent.

Accessibilite (Options -> ACCESSIBILITE) :
- Taille du texte 85 %-130 % (appliquee a tous les labels via
  UI.scaled_size dans ui_theme.gd ; effet au relancement du jeu) ;
- Reduire les flashs : vignette de degats a 0,25 et flash de tir a 0,8 ;
- Tir automatique sur cible verrouillee (avec l'aide a la visee) :
  le tir part tout seul quand le reticule est sur un monstre.

## 11. Contenu, progression et game feel (v7)

### Nouveaux monstres
- **Citrouille explosive jaune** (dès 01:45) : rapide, fonce sur le joueur et
  explose à bout portant (22 dégâts dans 2,7 m) ; sa barre de vie remplacée par
  rien — 1 PV suffit, tire dessus de loin !
- **Fantôme tireur** (dès 02:45) : crâne volant qui garde ses distances (~9 m)
  et lance des projectiles lumineux toutes les ~2,4 s.
- **boss : le Roi Citrouille** (à 05:24, f = 0,88 de la nuit) : citrouille géante
  de 2,6 m, 30 PV, 25 dégâts ; message d'alerte, cloche, secousse caméra.
  En le tuant : ralentissement bref (hitstop), secousse, et 2 cadeaux tombent.

### Pouvoirs à ramasser (toutes les ~30 s, en plus des soins et du gel)
- **Bouclier spectral** (citrouille jaune) : +50 d'armure pendant 25 s,
  affiché dans le HUD, absorbe les dégâts avant les PV.
- **Rage** (bougie rouge) : dégâts doublés pendant 12 s.
- **Rapidité** (bougie verte) : +25 % de vitesse pendant 15 s.

### Progression
- Chaque monstre rapporte de l'**XP** (citrouille 10 … boss 150) ; barre bleue
  et niveau affichés dans le HUD.
- À chaque **montée de niveau** : le jeu se met en pause et propose **3
  améliorations au choix** (dégâts, chargeur, cadence, recharge, vie, vitesse,
  endurance) — clic ou manette (bouton A).
- **Succès sauvegardés** : Premier sang, Chasseur de monstres (50 éliminations),
  Le Roi Citrouille est tombé, Niveau 5, Survivant de la nuit. Les statistiques
  (éliminations cumulées) persistent entre les parties.
- **Mode infini** : après la victoire, le bouton MODE INFINI de l'écran de fin
  relance la nuit sans limite ; les monstres deviennent plus rapides avec le
  temps et l'horloge affiche « 06:00 +mm:ss ».

### Game feel
- **Barre de vie** au-dessus de chaque monstre blessé (verte → jaune → rouge,
  plus grande pour le boss).
- **Chiffres de dégâts** flottants ; les coups critiques (12 % de chances,
  dégâts ×2) s'affichent en orange et plus gros.
- **Secousse caméra** quand on reçoit un coup (forte), au tir (légère),
  à l'explosion du boss ; réduite si « Réduire les flashs » est coché.

## Mise a jour : corrections d'interface et mobile (v12)

- Aide des touches (HUD) : texte corrige (Maj = courir, ZQSD = bouger), place en bas a
  gauche sur plusieurs lignes, ne touche plus le compteur de munitions et de grenades.
- Sol : texture de terre fine, sans raccord visible et peu contrastee (a la place des grandes
  taches floues violettes) ; filtrage anisotrope.
- Tutoriel : messages sur deux a trois lignes ; la mention "Entree pour passer" n'apparait
  plus au tactile (pas de touche Entree).
- Tactile : le bandeau arme/munitions/grenades ne chevauche plus l'horloge (detail de l'arme
  masque, textes plus petits).
- Qualite Basse : 20 % de monstres en moins en simultane (_max_enemies).

## Mise a jour : grenade devastatrice (v13)

- Degats : 30 au centre (avant : 6), rayon 6,5 m (avant : 3,4 m), decroissance douce jusqu'a 30 %
  au bord. Tue en un coup tout sauf le Roi Citrouille, qui encaisse 30 PV d'un coup.
- Les monstres qui survivent sont projetes en arriere (2 a 7 m) et etourdis 0,7 s.
- Effets (tous en code, aucun fichier d'image) : flash blanc + halo orange qui gonflent, onde de
  choc lumineuse au sol, flammes, eclats incandescents, fumee, trace de brulure qui s'efface,
  lumiere orange vive, forte secousse de camera, tres bref ralenti.
  "Reduire les flashs" supprime le flash blanc et le ralenti et adoucit la lumiere.
  Qualite Basse : 45 % des particules, Moyenne : 75 %.
- Nouveau son `assets/audio/explode_big.wav` (grosse explosion : sous-basse, souffle, debris),
  declare dans SFX_NAMES de game.gd. L'ancien `explode.wav` est conserve.
- Correction : les messages courts du HUD ("Niveau 3 !", "Vague de citrouilles...") s'affichaient
  en colonne verticale depuis la v12 ; ils s'affichent de nouveau sur une ligne.
