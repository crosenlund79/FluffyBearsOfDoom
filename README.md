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
| Special (remote detonate / Line Bomb) | E | R (Right Shift also works) |

A lone player can use either layout. Gamepads: stick/d-pad, A bomb, X/B/RT steal, Y/LB special.
Esc/P pauses, N skips to the next music track. **Every key can be remapped** in Menu → Controls
(or Settings → Controls, also from the pause menu): click a key, press the new one. If that key was
already used by another action, the two swap, so nothing is ever left unbound. Bindings are saved
with the settings, and "Reset to defaults" restores the table above. There is no on-screen key
overview during a match any more.

## The match screen
The arena sits in the middle, uncovered. On **both** sides of it is the same ranked stack of four
small playing-card panels, 1st at the top and 4th at the bottom: rank (gold, silver and bronze;
the leader has a crown; tied players share a rank), name, portrait, fluff score (it blinks while
someone is stealing that player's stuffing) and a small fluff bar running to the instant-win line.
The human player's cards have a thick frame in their colour and a **YOU** (or P1/P2) tab, which
travels with the card through every animation. Both stacks show one shared ranking and always
move together.

When places change, the cards physically **slide** to their new slots, wobbling on the way. Cards
moving up get a brief **gold glow** (▲) and pass on an outer lane. Cards moving down get a
**splatter of blood** (▼) and pass on an inner lane, so every card stays visible. The effects fade
as the cards settle, and the splatter never covers the score. The ranking updates as soon as a
whole-number score changes; equal scores keep their current order, so ties never flicker.

A bear whose bomb stuns someone **growls**: an angry face, a head shake and a "GRRR!" in the arena,
and the same snarl on its two cards. An eliminated bear's cards are greyed and stamped DEFLATED.

**Time of Doom** counts down above the arena. Which power-ups a bear has picked up is not shown:
**Power-ups** in the main menu lists every badge with its name and effect. The layout is designed
for 1280x720 and stays centred on any window shape; ultrawide and 4:3 screens get more wallpaper.

## Winning, knockback and elimination
**Bomb knockback:** a bear stunned by a bomb is blown along the blast direction, sliding down the
corridor until the next tile is a wall, a cushion block, a closed Time of Doom tile or a bomb. It
picks up every power-up it slides over, curses included, and always ends centred on an open tile.

**Zero fluff:** a bear that loses all its stuffing collapses into a flat, limp, faded plush and is
out for the rest of the round. It can't move, bomb, steal or be targeted, and its cards are greyed
and stamped DEFLATED.

The round ends when the timer runs out (most fluff wins), or **instantly** when a bear's fluff
reaches the instant-win threshold (default 300; Settings → *Instant win at*, or `INSTANT_WIN_FLUFF`
in `scripts/tuning.gd`; *Off* plays to the timer).

## Time of Doom: the closing arena
From 60% of the round the arena closes in **one tile at a time**, walking clockwise around the
outermost playable ring, then the next ring in: four rings (128 tiles), the last one shut at 97% of
the round. Each tile flashes before it shuts (faster as its moment comes, with an inward arrow and
ticking), so the closing edge is always visible. A shut tile is permanently solid. Bombs there
vanish (their owners get them back), power-ups and cushion blocks are cleared, loose stuffing hops
inward, and a bear caught on a closing tile is shoved to the nearest open cell and stunned, never
eliminated. The middle 5x3 tiles always stay open. The AI treats flashing tiles as danger. Timing is
`DOOM_*` in `scripts/tuning.gd`.

## Horror: the jack-in-the-box
Horror only. Every so often a wooden pillar rattles and flashes red, faster and faster. Then a clown
bursts out of a box on top of it, cackling, locks on to the **nearest bear wherever it is** (crosshair
and a dashed line), lunges across the arena on its spring neck and hammers it (stunned). It never
changes the grid, so it can't trap anyone. Replace its art with `objects/horror/clown.png`
(3 cells: head, mallet, box). Timing is `CLOWN_*` in `scripts/tuning.gd`.

## Power-ups
Every bear can **kick** bombs (walk into one): it slides along the corridor until something blocks it.
A ring in the owner's colour on the floor shows whose bomb it is.

Extra Bomb · Bigger Blast · Springy Stitching (speed) ·
**Remote Detonator** (your bombs wait, with an antenna in your colour, until you press the special key; a backup fuse sets them off after 10 s) ·
Line Bomb (special key when you have no remote bombs out: lays all free bombs in a line) · Rubber Bombs (kicked bombs bounce) ·
Immortality (20 s, can't be stunned or robbed) · Biome Shuffle (after a warning the **whole floor**
becomes one biome, ice, honey, bouncy or a one-way conveyor, with its physics; after
`SHUFFLE_DURATION` seconds it goes back exactly as it was; walls, blocks, bombs and power-ups stay) ·
**curses:** Reverse Controls (12 s, contagious on contact) · Bomb Diarrhea (10 s, bombs drop by themselves).
Power-ups lying in a blast are destroyed; ones uncovered by that same blast survive.

## Princess Hunt (a one-time trap)
Some rounds (45%) hide one **Princess Hunt** badge (a crown) under a cushion block, never more than
one. Whoever picks it up springs the trap: her crown peeks over the outer wall with a warning, then
the princess leaps in laughing and hunts the **nearest active bear** along the corridors,
switching to another bear when it gets clearly closer (by 2+ tiles, so she never dithers between
two). If no corridor leads to her target, or a chase drags on past 10 s, she simply leaps over. When she reaches it she laughs, takes aim (a red laser line) and fires one shotgun blast:
a long stun, a quarter of the victim's stuffing blown out and a shove away. Against an immortal or
just-recovered bear it's a harmless **blank**. Then she leaps back out over the wall. A bomb blast
on her tile drives her off early. She uses the princess character sheet, so Horror and Custom art
apply to her, and she is always gone within 30 s. Timing is `PRINCESS_*` in `scripts/tuning.gd`.

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

## Normal, Horror & Custom mode
Choose the mode at the top of the menu. The change applies immediately and is saved.
Gameplay is identical in all modes; only the presentation changes.
- **Normal:** cute plush bears, playful taunts, stuffing puffs and confetti, cheerful sounds.
- **Horror:** grimy stitched bears with mismatched, glowing eyes, creepy taunts, blood splatters,
  a darker, flickering nursery with a vignette, twitchy idle animations, crows and skulls
  circling stunned bears, and darker sounds.
- **Custom:** your own art. For every sprite the game first looks for
  `assets/sprites/<folder>/custom/<name>.png` (same file names as the templates, e.g.
  `bears/custom/bunny.png`, `tiles/custom/tiles.png`, `powerups/custom/powerups.png`). Anything
  you haven't supplied is shown exactly as in Normal. Custom files are never read in Normal or
  Horror, and the placeholder generator never writes into `custom/`. Custom mode plays, sounds
  and looks (menus, music, taunts) like Normal; only the sprites change.

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
- **Supplied recordings** (from the audio handover, original file names kept) live in folders
  under `assets/audio/sfx/`; a folder holds several takes and one is picked at random each time:

  | Folder | Used for |
  |---|---|
  | `explosion/` (5) | every bomb, and the duck parade burst (the confetti crackle plays on top) |
  | `impact/` (10 punches) | knockback slamming into a wall, the clown's hammer, the princess's shot |
  | `kick/` | shoving a bomb |
  | `eliminated/` | a bear running out of stuffing |
  | `defeat/` (4) | the results screen when a human player didn't win (otherwise the victory jingle) |
  | `princess_laugh/`, `shotgun/`, `shotgun_hit/`, `shell_drop/` | the Princess Hunt |
  | `footsteps/<material>/` | footsteps by floor: Normal and Custom use rug = wood, ice = ice, honey = mud, bouncy = snow, conveyor = concrete; Horror uses gravel, glass, mud, snow and stone |

  Add or swap takes by dropping files into those folders (or a `sfx/horror/<name>/` folder for
  Horror only). The original handover note is kept as `assets/audio/sfx/HANDOVER_original.txt`.
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

Custom mode reads only `<folder>/custom/<name>.png` and otherwise uses the Normal lookup above
(see *Normal, Horror & Custom mode*). Horror placeholders exist for `bears` (all four characters), `tiles`, `effects`,
`powerups` and `objects/chair`. Everything else is shared and
tinted darker in code. The
generator (`tools/generate_placeholders.py`) only ever writes `template_` files. Sheets are a
single row, and the cell size is `image width / cell count`, so you can use any resolution.
Draw each part centred in its cell. The rig draws arms and legs at about 70% of their sprite
length and ears 15–35% larger (per character, in `scripts/species.gd`). This is done in code, so the
sheets keep their layout and your replacement art (Normal, Horror or Custom) is never altered.

**Resolution:** the built-in templates are drawn at **4×** the layout sizes below (a bear cell is
512 px, a tile 256 px) and scaled down in game to the same on-screen size as before, using
mipmapped filtering so they stay crisp. Replacements can be any multiple (1×, 2×, 4×, ...): sizes
and positions on screen don't change, only the detail.

| File | Layout size (templates are 4× this) | Layout |
|---|---|---|
| `bears/template_bear.png` | 1280×128 | 10 cells: body, belly, head, ear, arm, leg, face normal, face smug, face indignant, face stunned. Draw the body parts light grey/white because they are tinted per bear. Faces are drawn untinted on a transparent background. |
| `bears/template_bunny.png`, `template_dino.png`, `template_princess.png` | 1536×128 | 12 cells: the same 10 as the bear sheet (bunny ears / dino horn nubs go in the ear cell), then cell 10 = tail (bunny puff, dino tail; the princess uses it for her skirt) and cell 11 = topper (bunny bow, dino back crest, princess crown). Missing character sheets fall back to the bear sheet. |
| `tiles/template_tiles.png` | 576×64 | 9 cells: rug, rug alt, ice, honey, bouncy, conveyor (pointing right), pillar, cushion block, border |
| `objects/template_bomb.png` | 64×64 | Draw the fabric bomb pale, because it is tinted pastel per bear. Rubber bombs get stripes drawn on top. The fuse tip sits near the top right. |
| `objects/template_fluff.png` | 32×32 | a tuft of stuffing |
| `objects/template_chair.png` | 96×96 | the crane-delivered armchair, untinted; tufts of stuffing are drawn on top in code |
| `objects/template_duck.png` | 128×64 | 2 cells: wind-up pull-along duck facing right (shared by mother and ducklings at different scales), wind-up key |
| `powerups/template_powerups.png` | 640×64 | 10 cells: bomb, blast, speed, shuffle, kick, line, rubber, immortality, reverse, diarrhea. The glow halo, outline, sparkles and pickup burst are drawn in code, so a replacement only needs the badge. Horror has its own sheet: dark badges with a blood-red rim (eyeball bomb, blood drops, a spine, a staring eye, a crossed-out heart; the curses in sickly green). |
| `objects/horror/template_clown.png` | 192×64 | Horror only, 3 cells: jack-in-the-box clown head (facing you), mallet (head up), the striped box (front; the lid is drawn in code) |
| `effects/template_effects.png` | 512×64 | 8 cells: blast centre, blast arm (horizontal), blast end (pointing right), star, dust, sparkle, cartoon bird (facing right), floor splat decal. In Horror: blood bursts, a skull, a crow and a blood splatter. |

## Tests
- `godot --headless -- --feature-test` checks the supplied recordings load, bomb knockback (slide
  distance, power-up pickup, ending centred), the bomber's growl, the whole-floor Biome Shuffle and
  its exact restore, zero-fluff elimination, the princess (blank vs immortal, real shot, once per
  round, bomb defeat, leaving), Time of Doom tile order and timing, and key rebinding with swaps.
- `godot --headless -- --autotest [--mode=horror|custom] [--arena=N] [--crane] [--clown] [--duck] [--princess] [--win=N]`
  plays an all-AI match and prints standings (`--shots=DIR` with a display saves screenshots).
- `godot --headless -- --rank-test` drives the HUD ranking through ties, a single overtake, a full
  simultaneous reversal, rapid consecutive changes and gradual stealing, and checks that both card
  stacks show the right order with every card settled in its slot.

## Tuning
All gameplay numbers are in `scripts/tuning.gd`: the fluff→mass curve, braking, bombs,
curses and so on. Terrain physics are in `scripts/terrain.gd` and arena layouts are in
`scripts/arena_maps.gd`.

Smoke test (all-AI match, prints standings): `godot --headless --path . -- --autotest [--arena=1]`
