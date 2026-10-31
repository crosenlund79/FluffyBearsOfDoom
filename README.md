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

## Doom Duck Parade
Every now and then a portal opens in a wooden pillar. A wind-up mother duck marches out with
three ducklings and wanders the corridors for about 12 seconds, ticking faster as she goes.
In the last 3 seconds she flashes and the cells she will hit are outlined. Then she bursts,
and the confetti **flows around corners** for up to 4 grid steps, stunning any bear it reaches.
Spawn timing, countdown, speed and reach are the `DUCK_*` values in `scripts/tuning.gd`.

## Music & sound
- **Menu music:** `assets/audio/music/menu/`. **Gameplay music:** `assets/audio/music/gameplay/`.
  Put `.mp3`, `.ogg` or `.wav` files there; they are found automatically. Tracks play in
  sequence or shuffled and loop. Music fades out when you switch between the menu and a match,
  and an empty folder just means silence. Godot imports these files, so they are packed into
  exported Windows builds (the `Windows Desktop` preset in `export_presets.cfg`).
- **After exporting**, you can also add `.mp3`/`.ogg` files without re-exporting by placing them in
  `music/menu/` or `music/gameplay/` next to the `.exe`, or in `user://music/<menu|gameplay>/`.
- **Sound effects:** put a file named after the sound in `assets/audio/sfx/` (ogg/wav/mp3) to
  replace the generated placeholder. The names are `place fuse confetti concussion steal pickup
  curse squeak bump kick boing pop menu tick go shuffle immortal victory`. Duck parade sounds:
  `portal clock_tick quack duckling_quack duck_warning duck_confetti`.
- Volumes, mute and shuffle are set from Menu → Audio (also in the pause menu) and saved to
  `user://settings.cfg`. One music volume covers both playlists. N skips to the next track.

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
| `objects/template_duck.png` | 128×64 | 2 cells: wind-up pull-along duck facing right (shared by mother and ducklings at different scales), wind-up key |
| `powerups/template_powerups.png` | 640×64 | 10 cells: bomb, blast, speed, shuffle, kick, line, rubber, immortality, reverse, diarrhea |
| `effects/template_effects.png` | 448×64 | 7 cells: confetti centre, confetti arm (horizontal), confetti end (pointing right), star, dust, sparkle, cartoon bird (facing right) |

## Tuning
All gameplay numbers are in `scripts/tuning.gd`: the fluff→mass curve, braking, bombs,
curses and so on. Terrain physics are in `scripts/terrain.gd` and arena layouts are in
`scripts/arena_maps.gd`.

Smoke test (all-AI match, prints standings): `godot --headless --path . -- --autotest [--arena=1]`
