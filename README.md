# 🧸💣 Fluffy Bears of Doom

A Godot 4.3 arcade game. Four plush toys (a teddy bear, a teddy bunny, a small dino and a
teddy bear princess) play classic fixed-grid bomb tactics with pastel
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
| Special (remote detonate / Line Bomb) | E | Right Shift |

A lone player can use either layout. Gamepads: stick/d-pad, A bomb, X/B/RT steal, Y/LB special.
Esc/P pauses, N skips to the next music track.

## Power-ups
Every bear can **kick** bombs (walk into one): it slides along the corridor until something blocks it.
A ring in the owner's colour on the floor shows whose bomb it is.

Extra Bomb · Bigger Blast · Springy Stitching (speed) ·
**Remote Detonator** (your bombs wait, with an antenna in your colour, until you press the special key; a backup fuse sets them off after 10 s) ·
Line Bomb (special key when you have no remote bombs out: lays all free bombs in a line) · Rubber Bombs (kicked bombs bounce) ·
Immortality (20 s, can't be stunned or robbed) · Biome Shuffle (reshuffles floor terrain after a warning) ·
**curses:** Reverse Controls (12 s, contagious on contact) · Bomb Diarrhea (10 s, bombs drop by themselves).
Power-ups lying in a blast are destroyed; ones uncovered by that same blast survive.

## Crane chair delivery
Rarely (first after 40–65 s, then every 60–90 s) a crane hook swings in from the top of the
screen carrying an armchair. It hovers over a free cell with a pulsing drop marker, then lets
go. The chair is stuffed with 60 fluff: stand next to it and hold **Steal** to loot it, just
like a stunned bear. A blast bursts it open and scatters what is left as pickups. The AI goes
for it too. Timing and amount are the `CRANE_*` / `CHAIR_FLUFF` values in `scripts/tuning.gd`.

## Doom Duck Parade
Every now and then a portal opens in a wooden pillar. A wind-up mother duck marches out with
three ducklings and wanders the corridors for about 12 seconds, ticking faster as she goes.
In the last 3 seconds she flashes and the cells she will hit are outlined. Then she bursts,
and the confetti **flows around corners** for up to 4 grid steps, stunning any bear it reaches.
Spawn timing, countdown, speed and reach are the `DUCK_*` values in `scripts/tuning.gd`.

## Normal & Horror mode
Choose the mode at the top of the menu. The change applies immediately and is saved.
Gameplay is identical in both modes; only the presentation changes.
- **Normal:** cute plush bears, playful taunts, stuffing puffs and confetti, cheerful sounds.
- **Horror:** grimy stitched bears with mismatched, glowing eyes, creepy taunts, blood splatters,
  a darker, flickering nursery with a vignette, twitchy idle animations, crows and skulls
  circling stunned bears, and darker sounds.

**Taunts:** a bear gloats when its bomb stuns someone, mocks bombers who stun themselves,
crows when it starts stealing, and complains when it wakes up robbed. Each taunt is a short
bubble with a reaction animation and a voice. The animations are purely visual and never
block movement, and taunts are rate-limited (at most 2 bubbles on screen at once). Edit the
lines and per-bear quips in `scripts/taunts.gd`. Mode palettes and tints are in
`scripts/mode_theme.gd`.

## Music & sound
- **Music folders** (`.mp3` / `.ogg` / `.wav`, found automatically):

  | | Normal | Horror |
  |---|---|---|
  | Menu | `assets/audio/music/menu/normal/` | `assets/audio/music/menu/horror/` |
  | Gameplay | `assets/audio/music/gameplay/normal/` | `assets/audio/music/gameplay/horror/` |

  Files placed loose in `menu/` or `gameplay/` are shared by both modes. If a Horror folder is
  empty, the Normal tracks play slowed and detuned instead. An empty Normal folder just means
  silence. Switching between screens fades the music out first.
- **Exported builds:** these tracks are imported and packed automatically (see the
  `Windows Desktop` preset in `export_presets.cfg`). You can also add `.mp3`/`.ogg` files later
  under `music/<menu|gameplay>/<normal|horror>/` next to the `.exe`.
- **Sound effects:** put a file named after the sound in `assets/audio/sfx/` to replace it in both
  modes, or in `assets/audio/sfx/horror/` to replace it in Horror only. In Horror the order is
  `sfx/horror/<name>` → `sfx/<name>` → built-in horror sound → built-in normal sound (played
  slower). The names are `place fuse confetti concussion steal pickup curse squeak bump kick boing
  pop menu tick go shuffle immortal victory taunt mode`, plus the duck parade sounds `portal
  clock_tick quack duckling_quack duck_warning duck_confetti`.
- Volumes, mute, shuffle and **Bear outlines** (a dark outline for visibility) are set from
  Menu → Settings (also in the pause menu) and saved to `user://settings.cfg`. N skips to the
  next track. A small "Now playing" note appears briefly whenever a track starts.

## Replacing the art
Every placeholder is named `template_<name>.png`. To replace one, put `<name>.png` in the **same
folder** (both modes), or in that folder's `horror/` sub-folder (Horror only). For each sprite
the game uses the first file that exists:
1. `<folder>/<mode>/<name>.png`: your mode-specific art
2. `<folder>/<name>.png`: your shared art
3. `<folder>/<mode>/template_<name>.png`: the built-in mode placeholder
4. `<folder>/template_<name>.png`: the built-in placeholder

Horror placeholders exist for `bears` (all four characters), `tiles`, `effects`,
`powerups` and `objects/chair`. Everything else is shared and
tinted darker in code. The
generator (`tools/generate_placeholders.py`) only ever writes `template_` files. Sheets are a
single row, and the cell size is `image width / cell count`, so you can use any resolution.
Draw each part centred in its cell.

| File | Template size | Layout |
|---|---|---|
| `bears/template_bear.png` | 1280×128 | 10 cells: body, belly, head, ear, arm, leg, face normal, face smug, face indignant, face stunned. Draw the body parts light grey/white because they are tinted per bear. Faces are drawn untinted on a transparent background. |
| `bears/template_bunny.png`, `template_dino.png`, `template_princess.png` | 1536×128 | 12 cells: the same 10 as the bear sheet (bunny ears / dino horn nubs go in the ear cell), then cell 10 = tail (bunny puff, dino tail; the princess uses it for her skirt) and cell 11 = topper (bunny bow, dino back crest, princess crown). Missing character sheets fall back to the bear sheet. |
| `tiles/template_tiles.png` | 576×64 | 9 cells: rug, rug alt, ice, honey, bouncy, conveyor (pointing right), pillar, cushion block, border |
| `objects/template_bomb.png` | 64×64 | Draw the fabric bomb pale, because it is tinted pastel per bear. Rubber bombs get stripes drawn on top. The fuse tip sits near the top right. |
| `objects/template_fluff.png` | 32×32 | a tuft of stuffing |
| `objects/template_chair.png` | 96×96 | the crane-delivered armchair, untinted; tufts of stuffing are drawn on top in code |
| `objects/template_duck.png` | 128×64 | 2 cells: wind-up pull-along duck facing right (shared by mother and ducklings at different scales), wind-up key |
| `powerups/template_powerups.png` | 640×64 | 10 cells: bomb, blast, speed, shuffle, kick, line, rubber, immortality, reverse, diarrhea. The glow halo, outline, sparkles and pickup burst are drawn in code, so a replacement only needs the badge. Horror has its own sheet: dark badges with a blood-red rim (eyeball bomb, blood drops, a spine, a staring eye, a crossed-out heart; the curses in sickly green). |
| `effects/template_effects.png` | 512×64 | 8 cells: blast centre, blast arm (horizontal), blast end (pointing right), star, dust, sparkle, cartoon bird (facing right), floor splat decal. In Horror: blood bursts, a skull, a crow and a blood splatter. |

## Tuning
All gameplay numbers are in `scripts/tuning.gd`: the fluff→mass curve, braking, bombs,
curses and so on. Terrain physics are in `scripts/terrain.gd` and arena layouts are in
`scripts/arena_maps.gd`.

Smoke test (all-AI match, prints standings): `godot --headless --path . -- --autotest [--arena=1]`
