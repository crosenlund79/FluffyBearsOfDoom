# 🧸💣 Fluffy Bears of Doom

A Godot 4.3 arcade game. Four teddy bears play classic fixed-grid bomb tactics with pastel
fabric toy bombs. The bombs burst into **confetti** that **stuns** instead of kills. Hold
**Steal** next to a stunned bear to pull out its stuffing (**fluff**). Fluff counts as your
score and also shapes your body: the more you have, the rounder and wobblier you get, the
slower you start moving, and the harder you are to stop.

Open the folder in Godot 4.3 and press **Play**.

## Controls
| | Player 1 | Player 2 |
|---|---|---|
| Move | WASD | Arrow keys |
| Place bomb | Space | Enter |
| Steal fluff (hold) | Left Shift | Right Ctrl |
| Special (Line Bomb) | E | Right Shift |

A lone player can use either layout. Gamepads: stick/d-pad, A bomb, X/B/RT steal, Y/LB special.
Esc/P pauses, N skips to the next music track.

## Power-ups
Extra Bomb · Bigger Blast · Springy Stitching (speed) · Bomb Kick (walk into bombs) ·
Line Bomb (special key: lays all free bombs in a line) · Rubber Bombs (kicked bombs bounce; includes kick) ·
Immortality (20 s, can't be stunned or robbed) · Biome Shuffle (reshuffles floor terrain after a warning) ·
**curses:** Reverse Controls (12 s, contagious on contact) · Bomb Diarrhea (10 s, bombs drop by themselves).

## Music & sound
- **Music:** put `.mp3`, `.ogg` or `.wav` files in `assets/audio/music/`. Tracks are found
  automatically, play in sequence, and loop, with optional shuffle. This also works in
  exported builds. To add music after exporting, put `.mp3`/`.ogg` files in a `music/` folder
  next to the game executable, or in `user://music/`.
- **Sound effects:** put a file named after the sound in `assets/audio/sfx/` (ogg/wav/mp3) to
  replace the generated placeholder. The names are `place fuse confetti concussion steal pickup
  curse squeak bump kick boing pop menu tick go shuffle immortal victory`.
- Volumes, mute and shuffle are set from Menu → Audio (also available from the pause menu) and
  saved to `user://settings.cfg`.

## Replacing the art
Every placeholder is named `template_<name>.png`. To replace one, put `<name>.png` in the **same
folder**. The game uses your file when it exists and falls back to the template otherwise. The
generator (`tools/generate_placeholders.py`) only ever writes `template_` files. Sheets are a
single row, and the cell size is `image width / cell count`, so you can use any resolution.
Draw each part centred in its cell.

| File | Template size | Layout |
|---|---|---|
| `bears/template_bear.png` | 1280×128 | 10 cells: body, belly, head, ear, arm, leg, face normal, face smug, face indignant, face stunned. Draw the body parts light grey/white because they are tinted per bear. Faces are drawn untinted on a transparent background. |
| `tiles/template_tiles.png` | 576×64 | 9 cells: rug, rug alt, ice, honey, bouncy, conveyor (pointing right), pillar, cushion block, border |
| `objects/template_bomb.png` | 64×64 | Draw the fabric bomb pale, because it is tinted pastel per bear. Rubber bombs get stripes drawn on top. The fuse tip sits near the top right. |
| `objects/template_fluff.png` | 32×32 | a tuft of stuffing |
| `powerups/template_powerups.png` | 640×64 | 10 cells: bomb, blast, speed, shuffle, kick, line, rubber, immortality, reverse, diarrhea |
| `effects/template_effects.png` | 448×64 | 7 cells: confetti centre, confetti arm (horizontal), confetti end (pointing right), star, dust, sparkle, cartoon bird (facing right) |

## Tuning
All gameplay numbers are in `scripts/tuning.gd`: the fluff→mass curve, braking, bombs,
curses and so on. Terrain physics are in `scripts/terrain.gd` and arena layouts are in
`scripts/arena_maps.gd`.

Smoke test (all-AI match, prints standings): `godot --headless --path . -- --autotest [--arena=1]`
