# 🧸💣 Fluffy Horror Bears

(Formerly *Fluffy Bears of Doom*. Saved settings and key bindings carry over.)

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
| Special (proximity bomb / Line Bomb) | E | R (Right Shift also works) |

A lone player can use either layout. Gamepads: stick/d-pad, A bomb, X/B/RT steal, Y/LB special.
Esc/P pauses, N skips to the next music track. **Every key can be remapped** in Menu → Controls
(or Settings → Controls, also from the pause menu): click a key, press the new one. If that key was
already used by another action, the two swap, so nothing is ever left unbound. Bindings are saved
with the settings, and "Reset to defaults" restores the table above. There is no on-screen key
overview during a match any more.

## The match screen
The arena sits in the middle, a step **below** the raised, bevelled rim around it (the rim casts a
shadow into the pit). The grid is 17x15 tiles, one ring larger than before, drawn slightly zoomed
out so it fills the same space. Above it: the round timer and, quietly on the left, the song that's
playing.

On **both** sides is the same ranked stack of four small playing cards, 1st at the top. They lie a
little crooked and overlapping, like a dealt pile. Each card shows a rank skull, name, portrait,
fluff score (it blinks while someone is stealing that player's stuffing) and a small fluff bar. The
skulls get nastier with rank: a small cracked one for 4th, a meaner one for 3rd, a fanged skull with
a heavy brow for 2nd, and a huge, muscular, red-eyed brute for 1st. The human player's cards have a
thick frame and a **YOU** (or P1/P2) tab. Both stacks show one shared ranking and move together.
When places change, the cards slide to their new slots, wobbling on the way. Promoted cards glow
**gold** and demoted ones get a **blood splatter**, as before.

A big **spider** with glowing red eyes crawls around the card stacks (and along the top of the
screen to the other side). Now and then it shoots a strand between cards and leaves a cobweb that
fades. It never goes over the arena and has no effect on play.

A bear whose bomb stuns someone **growls** in the arena and on its cards; an eliminated bear's cards
are greyed and stamped DEFLATED. **Power-ups** in the main menu lists every badge with its effect.

## Starting a round
Every round starts paused. The music plays and all the bears **dance** to it, while the timer,
bombs and AI wait. "Press SPACE or ENTER to start" (or a pad's A / Start) starts the round for
everyone at once; that key press never drops a bomb.

## Options
- **Players:** One Human, Two Humans, or **Pure AI (watch)**, where all four bears are AI-controlled.
- **Settings → Diseases:** turn off Reverse Controls and Bomb Diarrhea entirely (they never drop and
  nothing spreads).

## Winning, knockback and elimination
**Bomb knockback:** a bear stunned by a bomb is blown along the blast direction, sliding down the
corridor until the next tile is a wall, a cushion block, a closed Time of Doom tile or a bomb. It
picks up every power-up it slides over, curses included, and always ends centred on an open tile.

**Zero fluff:** a bear that loses all its stuffing collapses into a flat, limp, faded plush and is
out for the rest of the round. It can't move, bomb, steal or be targeted, and its cards are greyed
and stamped DEFLATED.

**Bomb damage** happens only at the instant of detonation: a blast stuns every bear standing in it
at that moment, once (a chain of bombs never hits the same bear twice). The lingering flames are
just for show.

The round ends when the timer runs out (most fluff wins), when only one bear (or none) still has
stuffing (the survivor wins; among equals, whoever lasted longer ranks higher), or **instantly** when a bear's fluff
reaches the instant-win threshold (default 300; Settings → *Instant win at*, or `INSTANT_WIN_FLUFF`
in `scripts/tuning.gd`; *Off* plays to the timer).

## Tournament of Doom
**Menu → Tournament.** Ten rounds of you against three of the ten named AI bears. Each opponent
turns up in exactly three rounds, and the line-ups get nastier (by combination, not by stats):

| Round | Opponents | Round | Opponents |
|---|---|---|---|
| 1 | Oswald, Theodor, Pip | 6 | Knuckles, Grimble, Brunhilde |
| 2 | Theodor, Pip, Brunhilde | 7 | Harald, Vesper, Mabel |
| 3 | Oswald, Mabel, Pip | 8 | Knuckles, Balthazar, Grimble |
| 4 | Theodor, Grimble, Brunhilde | 9 | Harald, Vesper, Balthazar |
| 5 | Oswald, Harald, Mabel | 10 | Knuckles, Balthazar, Vesper |

- **Rules:** 90-second rounds on a fixed arena rotation, instant win at 300 fluff, diseases on,
  whatever the menu says (so runs stay comparable). You pick the opponents' skill (Easy / Normal / Hard).
- **Winning a round** uses the normal victory rule: most stuffing at the whistle, the instant-win
  threshold, or the last bear with stuffing. Win to advance. A tie for first ("It's a fluffy
  tie!") is not a win.
- **Lives:** you have three. A lost round costs one and is replayed with a fresh layout; losing
  with no lives left ends the run (with a Retry button). Leaving a round, or the game closing
  during one, counts as losing it.
- **Between rounds:** round result (winner, rankings, everyone's stuffing gained/lost, duration),
  your lives and running totals, standings (4/2/1/0 points per round), the next opponents and a
  ten-round progression board.
- **Autosave** after every round (`user://tournament.cfg`): *Continue* on the Tournament screen.
- **Finishing** shows the champion screen: total time, stuffing collected and lost, personal bests
  and any new leaderboard places.

### The ten opponents
They reuse the four bear rigs with their own colour, and all share one tactical AI (bombs, blast
lines, escapes, stuns, stealing, power-ups, kicked and proximity bombs, sticky/slippery floors and
every hazard). Personality is a set of weights in `scripts/personalities.gd`, never extra speed or
hidden information:

| Bear | Plays like |
|---|---|
| Oswald | balanced and a little cautious; takes the chances he's given |
| Harald | pressure bomber: bombs whenever a rival is close, takes risks, blunders now and then |
| Theodor | defensive: big safety margins, holds his fire |
| Mabel | thief: goes for every stunned bear and every chair |
| Grimble | trapper: choke-point and proximity traps, bombs bears stuck on honey or ice |
| Balthazar | strategist: reads chain reactions, predicts where rivals run, traps them |
| Pip | power-up magpie with sudden whims; careless |
| Brunhilde | territorial: stays in her quarter and attacks intruders |
| Knuckles | kicker: hunts the Kick power-up, kicks bombs at rivals and into other bombs (chains) |
| Vesper | patient hunter: waits, then strikes at weakened, cursed or stunned bears |

### Leaderboards
**Menu → Leaderboards** (or from the Tournament screen). Two boards per difficulty, top 10 each,
stored in `user://leaderboards.cfg`:

- **Fastest Tournament:** total *active* gameplay time over every round you played (lost rounds
  included); pre-round dances, pauses, results and menus don't count. Shown as m:ss.cc.
- **Least Stuffing Lost:** every bit of stuffing taken from you (stolen, blown out, spilled) over
  every round you played. Each loss is counted once, when it happens; stuffing you win back later
  doesn't erase it. Ties go to the faster time.

Each entry has your name (editable on the Tournament screen), date, time, stuffing lost and
collected, result, difficulty, theme and rules version. Only complete tournament wins at normal
speed qualify: any sped-up clock or developer/test switch (`--seed`, `--win`, the test modes)
marks the run invalid. Difficulties and rule versions never share a board.

## Watch AI (spectator mode)
**Menu → Watch AI.** Pick four opponents (or Random) and their skill; the match starts by itself.
Rank cards show names, places and stuffing; an event feed (bottom right) logs the big moments;
speed 1× / 2× / 4× with the buttons or the keys 1, 2, 4. The standings appear at the end with
*Watch another* / *Change line-up*. Spectator matches never touch tournaments or leaderboards.

## Commentary, bomb placement and lighting
- **Commentary** (tournament and Watch AI; Settings → Commentary): short reactive lines in a panel
  under the left card stack, about chain reactions, close escapes, theft, big losses, kicks,
  power-up hoards, self-stuns, lead changes, comebacks, eliminations, the last bear standing, the
  hazards and the winner, plus a word on each bear's style in quiet moments. Big moments come
  first; minor ones wait for cooldowns and lines aren't repeated.
- **Placing a bomb** is now visible: the bear dips, leans and puts its paws down for 0.14 s while
  the bomb drops from its paws onto the tile (0.12 s). Purely visual: no delay, fuse unchanged.
- **Lighting** (Settings → Lighting: High / Low / Off): a soft ambient tone, a glow on every bomb
  (pulsing faster as its fuse runs out, red on an armed proximity bomb), a brief flash from each
  explosion, and in High warm lamps (the arena corners in Normal, flickering pumpkins with the odd
  brown-out in Horror). Custom keeps the light neutral so custom art keeps its colours.

## Time of Doom: the closing arena
From 60% of the round the arena closes in **one tile at a time**, walking clockwise around the
outermost playable ring, then the next ring in: five rings (180 tiles), the last one shut at 97% of
the round. Each tile flashes before it shuts (faster as its moment comes, with an inward arrow and
ticking), so the closing edge is always visible. A shut tile is permanently solid. Bombs there
vanish (their owners get them back), power-ups and cushion blocks are cleared, loose stuffing hops
inward, and a bear caught on a closing tile is shoved to the nearest open cell and stunned, never
eliminated. The middle 5x3 tiles always stay open. The AI treats flashing tiles as danger. Timing is
`DOOM_*` in `scripts/tuning.gd`.

## Horror: the jack-in-the-box
Horror only. One wooden pillar carries a striped box with a **hatch** from the start of the round,
so you know where the trouble lives. Every so often it rattles and flashes, the hatch creaks open,
there's a pause (eyes glint in the dark), the clown rises out, another pause, then it cackles
frantically, locks on to the nearest bear wherever it is, and lunges at it on its spring neck. It
looms bigger as it arcs toward the camera and shrinks as it comes down with the hammer. If the Time
of Doom shuts its pillar, the box moves to another one. While it aims, a crosshair and a dashed line
mark the victim, and the hammer stuns. It never changes the grid, so it can't trap anyone. Replace its art with `objects/horror/clown.png`
(3 cells: head, mallet, box). Timing is `CLOWN_*` in `scripts/tuning.gd`.

## Power-ups
Ordinary bombs always burn a timed fuse. A ring in the owner's colour on the floor shows whose
bomb it is.

**Bomb Kick** is a power-up (every round starts without it): walk into a bomb to kick it along the
corridor until something blocks it.

**Proximity Bombs** give 3 charges (up to 6) for the special key. A proximity bomb counts down
**3 → 2 → 1** on its shell while it arms, then shows a red detection ring: the first rival to step
next to it sets it off (after a short beep). Its owner can never trip it, and an untripped one goes
off by itself after 30 s. It uses one of your bomb slots, keeps your blast range, chains like any
bomb and can be kicked. The AI lays them in corridors near rivals and steers around rivals' traps
(Easy only respects them once they're armed). Tuning: `PROX_*` in `scripts/tuning.gd`.

Extra Bomb · Bigger Blast · Springy Stitching (speed) ·
Line Bomb (special key when you have no proximity bombs: lays all free bombs in a line) · Rubber Bombs (kicked bombs bounce) ·
Immortality (20 s, can't be stunned or robbed) · Biome Shuffle (after a warning the **whole floor**
becomes ice, honey or bouncy with its physics, or **Conveyor Chaos** lays a few belts along the
corridors; after `SHUFFLE_DURATION` seconds it goes back exactly as it was; walls, blocks, bombs and power-ups stay) ·
**curses:** Reverse Controls (12 s, contagious on contact) · Bomb Diarrhea (10 s, bombs drop by themselves).
Power-ups lying in a blast are destroyed; ones uncovered by that same blast survive.

**Distribution** (`scripts/powerup_plan.gd`, numbers in `scripts/tuning.gd` under `PU_*`): every
round has a fixed budget of 24 items: **10 core** (Extra Bomb, Bigger Blast), **6 mobility** (Bomb
Kick, Springy Stitching, Rubber Bombs), **4 tactical** (Proximity Bombs, Line Bomb, Immortality),
**3 chaos** (Biome Shuffle, the curses) and **at most 1 special** (Princess Hunt, in 45% of rounds).
Category weights and per-kind caps are configurable. Kinds that are switched off (Settings →
Diseases) are redistributed to the other categories. Most items hide under cushion blocks; 4 are
held back and drop onto open floor between 30% and 70% of the round. Each spawn corner gets the same
early set (a Bomb, a Fire and a Speed-or-Kick in its nearest blocks), and rare items hide far from
every spawn. The layout follows the round's seed.

**Conveyors:** an arena never has more than 2 horizontal and 2 vertical belts (`MAX_H_BELTS`,
`MAX_V_BELTS`); maps are trimmed to that, and Conveyor Chaos lays belts of 5–9 tiles along
corridors instead of covering the floor.

## Princess Hunt (a one-time trap)
Some rounds (45%, the special category's chance) hide one **Princess Hunt** badge (a crown) under a cushion block, never more than
one. Whoever picks it up springs the trap: her crown peeks over the outer wall with a warning, then
the princess leaps in laughing and hunts the **nearest active bear** along the corridors,
switching to another bear when it gets clearly closer (by 2+ tiles, so she never dithers between
two). If no corridor leads to her target, or a chase drags on past 10 s, she simply leaps over. When she reaches it she laughs, takes aim (a red laser line) and fires one shotgun blast:
a long stun, a quarter of the victim's stuffing blown out and a shove away. Against an immortal or
just-recovered bear it's a harmless **blank**. Then she leaps back out over the wall. A bomb blast
on her tile drives her off early. She is drawn bigger than the bears, biggest up on the raised rim and in mid-leap, and a little
smaller once she's down in the pit, to match the arena's perspective. She uses the princess character sheet, so Horror and Custom art
apply to her, and she is always gone within 30 s. Timing is `PRINCESS_*` in `scripts/tuning.gd`.

## The claw and the chair
A carnival **claw** hangs from a rail along the top edge of the arena, parked in the top-left corner
with a stuffed chair in its prongs, all round. Rarely (first after 40–65 s, then every 60–90 s after
the last chair is gone) the warning bulbs along the rail light up and race toward the drop point.
The claw rides along the rail, lowers over its target (a pulsing marker on the floor), opens its
prongs and drops the chair, then rides back for a fresh one. The chair holds 60 fluff: stand next to
it and hold **Steal** to loot it. A blast bursts it open into pickups, and the AI goes for it too.
Timing and amount are the `CRANE_*` / `CHAIR_FLUFF` values in `scripts/tuning.gd`.

## Doom Duck Parade
Every now and then a portal opens in a wooden pillar. A wind-up mother duck marches out with
three ducklings and wanders the corridors for about 12 seconds, ticking faster as she goes.
In the last 3 seconds she flashes and the cells she will hit are outlined. Then she bursts,
and the confetti **flows around corners** for up to 4 grid steps, stunning any bear it reaches.
Spawn timing, countdown, speed and reach are the `DUCK_*` values in `scripts/tuning.gd`.

## Horror's cast and dressing
In Horror the bears become creatures: Player is an **Elk Bear** (antlers, a long dark snout), Oswald
a much nastier **Bunny** (shredded ears, glowing eyes, a mouth full of needle teeth), Harald a
**Zombie Bear** (rotting patches, a dangling eye, bone spikes), and Theodor a **Skeleton Bear**
(ribcage, bones, a grinning skull, a rag tutu and a rusty crown). Normal art is unchanged; Custom
mode uses these Horror sheets for anything you haven't replaced.
The outer wall is dressed with jack-o'-lanterns, skulls, spiders, bats and corner cobwebs, and
faint webs hang in some corridor corners. The floor drops its checkerboard for a calmer grid.
Cartoon remains (headless bodies, severed heads, bones, blood) lie on the rim outside the
playfield. All of it is decoration only.

Gameplay feel: a bomb-stunned bear is launched after a short beat (0.18 s), honey is a little less
sticky, and stealing stuffing is more violent: the victim jerks and shakes, tufts and (in Horror)
red spray fly, fabric rips and the screen jolts. How stealing works is unchanged.

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
  you haven't supplied is shown exactly as in **Horror** (Horror art is Custom's template), so
  `custom/` holds the same file names and layouts as the Horror sheets. Custom files are never read
  in Normal or Horror, and the placeholder generator never writes into `custom/`. Custom also
  takes Horror's music, arena dressing (decorations, remains) and the jack-in-the-box clown; menus,
  taunts and sounds stay as in Normal. `assets/sprites/CUSTOM_ART.txt` lists every file name you can supply.

### Custom characters: the clown and the princess
Both can be fully re-skinned in Custom mode (and in Horror, from the `horror/` folders), including
their entrances, attacks and exits. Every file is optional and is looked up Custom → Horror; when
none exists the built-in animation plays, so Normal and Horror look exactly as before.

- **Base art:** `objects/custom/clown.png` (3 cells: head, mallet, box; same as the Horror template).
- **Animation strips:** one row of square frames (frame size = image height, any number of frames,
  any resolution), in `assets/sprites/objects/custom/`:

| File | Plays during | Replaces |
|---|---|---|
| `clown_enter.png` | bursting out of the box and staring | head + mallet |
| `clown_attack.png` | cackling (first half), lunging (third quarter), hammering (last quarter) | head + mallet |
| `clown_exit.png` | sinking back into the box | head + mallet |
| `clown_hit.png` | the hammer's impact, on the victim | the red shock ring |
| `princess_enter.png` | peeking over the wall (first half), leaping in (second half) | crown peek, rig |
| `princess_walk.png` | hunting (loops about once a second) | rig |
| `princess_attack.png` | aiming (first half), firing (second half) | rig and toy gun |
| `princess_exit.png` | leaping out over the wall | rig |
| `princess_idle.png` | any princess phase without its own strip (loops) | rig |
| `princess_shot.png` | the muzzle blast when she fires, pointed at her victim | flash and pellets |

Frames face right; they are mirrored to face the victim. The princess keeps her perspective scaling
(bigger on the rim and mid-leap), her shadow, the laser sight and all gameplay timing. The clown
keeps its spring neck, box, hatch and crosshair. The princess's own strips never touch Theodor
(`bears/custom/princess.png` is still Theodor's sheet).

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

Custom mode reads only `<folder>/custom/<name>.png` and otherwise uses the Horror lookup above
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

## Windows build and installer
The version is `application/config/version` in `project.godot` (currently **1.0.0**); the build
script, the installer and the uninstall entry all use it.

```bash
tools/build_windows.sh /path/to/godot-4.3
```

It needs Godot 4.3 with its export templates, plus Inno Setup 6 for the installer (`ISCC` on
Windows, or `ISCC="wine C:\\path\\ISCC.exe"` elsewhere). It writes to `dist/`, which Git ignores:

| File | What |
|---|---|
| `dist/FluffyHorrorBears.exe` | the game: one standalone 64-bit EXE with every asset embedded |
| `dist/FluffyHorrorBears-<version>-win64.zip` | portable copy of the EXE |
| `dist/FluffyHorrorBears-<version>-setup.exe` | installer: Start Menu shortcut, optional desktop shortcut (unchecked by default), uninstaller (also in Apps & features) |

The installer script is `installer/FluffyHorrorBears.iss` (installs per user by default; an
administrator can choose all users). The EXE keeps Godot's file icon unless you configure `rcedit`
in Godot's editor settings and set `application/modify_resources=true` in `export_presets.cfg`;
the in-game window icon is the game's own either way. Settings and saves go to
`%APPDATA%\godot\app_userdata\Fluffy Bears of Doom` (kept on uninstall).

## Tests
- `godot --headless -- --feature-test` checks the supplied recordings load, bomb knockback (slide
  distance, power-up pickup, ending centred), the bomber's growl, the whole-floor Biome Shuffle and
  its exact restore, zero-fluff elimination, the princess (blank vs immortal, real shot, once per
  round, bomb defeat, leaving), Time of Doom tile order and timing, and key rebinding with swaps.
- `godot --headless -- --autotest [--mode=horror|custom] [--arena=N] [--crane] [--clown] [--duck] [--princess] [--win=N]`
  plays an all-AI match and prints standings (`--shots=DIR` with a display saves screenshots).
- The feature test also covers proximity bombs (countdown, owner-proof, rival trigger, AI trap
  zones), instant-only blast damage and single hits in chains, Kick as a power-up, conveyor limits,
  the power-up distribution over 200 seeds (categories, caps, fair corners, rare placement, diseases
  off, reproducibility) and simultaneous eliminations.
- `godot --headless -- --balance --levels=hard,easy,easy,easy --matches=50 [--first=N] --seed=1000 --out=FILE.jsonl`
  plays headless AI matches back to back (match *i*: seed + *i*, spawn rotation *i* % 4, arena
  (*i* / 4) % 3) and writes one JSON line per match with every bear's rank, fluff, stolen fluff,
  stuns, bombs, hits, self-hits, pickups and elimination time. Shard with `--first` to use every core.
- `godot -- --perf [--stress] [--seconds=60] [--mode=horror]` samples frame, process and physics
  times, draw calls, memory, objects and nodes during an all-Hard match (`--stress`: every hazard and
  ability at once).
- `--seed=N` reproduces an arena's blocks and power-ups; `--rotate=N` rotates the spawn corners.
- `godot --headless -- --tournament-test` plays whole Tournaments of Doom at 8× through the real
  screens (an AI stands in for you), simulating an application restart after every round, and
  checks: rounds progress, four bears per match, all ten opponents appear, lives/failure/retry,
  forfeits, the bomb-placement pose, commentary, both leaderboards (order, tie-break, top 10,
  separate difficulties, personal bests), that accelerated or developer runs never qualify, and an
  AI spectator match that runs on its own. Your own saves are backed up and restored.
- `godot -- --shots-demo=DIR [--mode=horror]` screenshots the new screens, a 1× tournament round
  and a spectator match (needs a display).
- `godot --headless -- --balance --names=all --levels=normal,normal,normal,normal --matches=N`
  pits the ten personalities against each other, four per match.
- `godot --headless -- --rank-test` drives the HUD ranking through ties, a single overtake, a full
  simultaneous reversal, rapid consecutive changes and gradual stealing, and checks that both card
  stacks show the right order with every card settled in its slot.

## Tuning
All gameplay numbers are in `scripts/tuning.gd`: the fluff→mass curve, braking, bombs,
curses, power-up distribution and the AI's decision-making (`AI_*`, one value per difficulty). Terrain physics are in `scripts/terrain.gd` and arena layouts are in
`scripts/arena_maps.gd`.

Smoke test (all-AI match, prints standings): `godot --headless --path . -- --autotest [--arena=1]`

## AI difficulty and balance
All three levels play by the same rules with the same inputs (no peeking at hidden power-ups, no
superhuman reactions); they differ only in how they decide:

| | Easy | Normal | Hard |
|---|---|---|---|
| Decides every | 0.4 s | 0.34 s | 0.24 s |
| Notices it's in a blast line | 85% | 88% | 95% |
| Safety margin before a blast | 0.35 s | 0.5 s | 0.6 s (+ chain reactions) |
| Robs a stunned bear | 85%, for 2.6–3.8 s | 85% | always, whole stun |
| Extras | careless bombs (5%), no kick / line | kicks, line bombs | predicts movement, traps rivals, avoids ice when heavy, counter-steers |

Measured with `--balance` (150 s rounds, rotating spawns and all three arenas, fresh seeds):

| Matchup | Matches | Result |
|---|---|---|
| 1 Hard vs 3 Easy (before tuning) | 120 | Hard wins 89.2% (95% CI 82–94%) |
| **1 Hard vs 3 Easy (final)** | 200 | **Hard wins 53.0% (46–60%)** |
| 1 Normal vs 3 Easy | 96 | Normal wins 43.8% (34–54%) |
| 1 Hard vs 3 Normal | 48 | Hard wins 47.9% (35–62%); an even share is 25% |
| 4 Hard (seat fairness) | 48 | seats win 19–29% |
| 1 Hard vs 3 Easy, after the personalities were added (Oswald, Harald, Theodor) | 100 | Hard wins 55.0% (45–64%) |

The ten personalities, four per match at Normal, 80 matches (`--balance --names=all`); per match:

| Bear | Win % | Stolen | Bombs | Hits/bomb | Self-stuns | Power-ups | Kicks |
|---|---|---|---|---|---|---|---|
| Oswald | 37.5 | 87.9 | 46.3 | 0.048 | 1.12 | 4.7 | 1.0 |
| Harald | 30.0 | 67.3 | 45.2 | 0.053 | 1.03 | 3.4 | 1.9 |
| Knuckles | 26.5 | 68.6 | 41.5 | 0.059 | 1.47 | 4.5 | **3.6** |
| Mabel | 25.7 | 71.5 | 43.4 | 0.055 | 0.86 | 4.2 | 1.7 |
| Brunhilde | 25.0 | 60.8 | 42.1 | 0.053 | 1.22 | 3.9 | 1.1 |
| Pip | 24.2 | 57.2 | 37.1 | 0.069 | 1.09 | **6.2** | 1.8 |
| Vesper | 23.5 | 65.6 | 38.6 | 0.047 | 1.09 | 4.0 | 1.3 |
| Grimble | 23.1 | 82.4 | **49.3** | 0.049 | 1.04 | 3.7 | 2.5 |
| Theodor | 20.7 | 67.4 | **35.9** | 0.045 | 0.90 | 5.1 | 2.6 |
| Balthazar | 12.9 | 53.5 | 46.6 | 0.044 | 1.35 | 4.2 | 1.8 |

With ~30 matches each, win rates differ by less than their noise (except Oswald, the strongest);
the styles show in kicks, power-ups and bombing. In the tournament itself an AI stand-in for the
player (Hard, Easy opponents) lost its three lives after 5–8 rounds in three runs: winning ten
rounds on three lives is a real challenge (`LIVES` in `scripts/tournament.gd`).

