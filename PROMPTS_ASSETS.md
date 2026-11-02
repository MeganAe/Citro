# Assets à faire générer par une IA

Le jeu fonctionne déjà sans ces fichiers (titre en texte, fond = le cimetière en 3D). Chaque fichier ci-dessous, une fois déposé au bon endroit avec le bon nom, est utilisé automatiquement, sans toucher au code.

## Règles communes (à coller au début de chaque demande)

> Direction artistique : jeu de survie 3D low-poly, cimetière d'Halloween la nuit. Lumière de lune bleutée, ombres profondes, quelques points de lumière chaude orange (citrouilles, lanternes). Palette : bleu nuit #070a14 et #121830, ambre #e9a23b, blanc crème #ece8dd. Ambiance sérieuse et sobre, pas de dessin animé, pas de couleurs saturées, pas de néon. **Aucun texte, aucune lettre, aucun logo, aucun filigrane dans l'image.** Pas de gore.

Les générateurs d'images écrivent mal les lettres : le nom du jeu est donc toujours écrit par le jeu lui-même (police Cinzel). Ne demande jamais de texte à l'IA.

---

## 1. Image de fond du menu — `assets/ui/key_art.jpg`

Format 1920 × 1080 (16:9), JPG, moins de 600 Ko.

```
Wide cinematic scene of a lone survivor in a sci-fi blue suit standing in an abandoned
cemetery at night, seen from behind and slightly from the side, low-poly 3D game style
with soft painterly lighting. Full moon behind thin clouds, blue moonlight, thick low fog.
Crooked gravestones, dead trees, a rusty fence, glowing carved pumpkins on the ground
casting warm orange light. Distant silhouettes of skulls and pumpkins creeping out of the
mist. Composition: all the action on the RIGHT half of the image. The LEFT 40% of the image
is dark and nearly empty (fog and shadow), because menu buttons are placed over it.
Moody, restrained, high contrast, no text, no letters, no watermark.
```

À vérifier : la partie gauche est sombre et calme, le personnage est à droite, rien ne ressemble à des lettres.

## 2. Logo (optionnel) — `assets/ui/logo.png`

Si tu ne le fournis pas, le jeu écrit « LA NUIT DES CITROUILLES » avec la police Cinzel, ce qui est déjà propre. Fais ce logo seulement si tu veux un emblème à la place.

Format PNG transparent, 1120 × 460. Demande **un emblème sans texte** (le texte se règle dans le code si besoin) :

```
Minimal emblem for a horror survival game: a single carved pumpkin with a thin crescent moon
cut into it, drawn as a clean flat vector mark, amber orange #e9a23b on transparent
background, thin line details, symmetrical, no text, no letters, no gradient background.
```

## 3. Icône de l'application — `assets/ui/app_icon.png`

Format 1024 × 1024, PNG, sans transparence pour l'icône pleine. L'icône Android adaptative demande aussi deux calques de 432 × 432 : un fond uni `#0d1226` et le motif seul sur fond transparent (le motif reste dans les 66 % centraux).

```
App icon: a glowing carved jack-o'-lantern pumpkin seen from the front, warm orange #f07a14
light from inside, small pale moon at the top right, deep navy #0d1226 background, flat clean
vector style, strong silhouette readable at 48 pixels, centered, generous margin around the
subject, no text, no letters.
```

Ensuite, dans Godot : Projet → Paramètres du projet → Application → Config → Icône.

## 4. Visuel de présentation Play Store / itch.io — `store/feature_graphic.png`

Format 1024 × 500 (Play Store) ; refais-le en 630 × 500 pour la couverture itch.io. Même demande que l'image du menu, avec en plus :

```
Same scene as the menu key art but composed for a banner of 1024x500: character and glowing
pumpkins in the centre, symmetrical fog on both sides, enough empty dark space at the top
and bottom edges for a store to crop. No text.
```

## 5. Captures d'écran des boutiques

Pas besoin d'IA : prends de vraies captures du jeu sur téléphone (jeu en cours, au moins une avec beaucoup de monstres et une avec le menu). Les boutiques demandent de vraies captures.

---

## Texture manquante des décors (important)

Le fichier `halloweenbits_texture.png` n'est pas dans le pack Halloween Bits que tu m'as donné. Une IA ne peut pas le recréer : il est dessiné pour les modèles 3D. Récupère-le dans le téléchargement d'origine du pack (dossier des textures) et copie-le dans `assets/halloween/`. Les couleurs de secours disparaissent alors toutes seules.

---

## Sons et musiques (si tu veux remplacer ceux générés)

Tous les fichiers sont dans `assets/audio/`. Garde les mêmes noms, format WAV 16 bits mono ou stéréo, 44,1 kHz.

| Fichier | Demande à l'agent audio |
|---|---|
| `music_night.wav` | Boucle de 60 à 90 s, sans coupure audible. Ambiance sombre : nappe grave, cordes lointaines, un glas discret. Pas de mélodie qui accroche, tempo lent. |
| `music_dawn.wav` | Même durée, même tonalité, mais plus claire : cordes qui montent, lumière, un espoir mesuré. Elle se mélange avec la précédente à l'approche de l'aube. |
| `heartbeat.wav` | Battement de cœur grave, 70 battements/minute, boucle de 2 à 4 s. |
| `shoot.wav` | Coup de pistolet sec de science-fiction, 0,2 s, léger écho. |
| `reload.wav`, `empty.wav` | Rechargement mécanique de 1,2 s ; déclic à vide de 0,1 s. |
| `enemy_hit.wav`, `enemy_die.wav` | Impact sourd sur une citrouille ; éclatement et os qui roulent, 0,5 s. |
| `hurt.wav` | Souffle court de douleur du personnage, 0,4 s, sans parole. |
| `pickup.wav`, `freeze.wav` | Petite note chaude montante ; cloche de glace cristalline, 1 s. |
| `roll.wav`, `bell.wav` | Frottement de tissu rapide ; cloche grave unique, queue de 3 s. |
| `win.wav`, `lose.wav` | Accord ouvert de lever de soleil, 3 s ; accord sombre qui s'éteint, 3 s. |

Demande toujours des sons **libres de droits ou générés pour toi**, et garde la preuve de la licence si tu publies sur une boutique.
