# 🧸💣 Fluffy Bears of Doom

A Godot 4.3 arcade game. Four teddy bears play classic fixed-grid bomb tactics,
but bombs only **stun**. Hold **Steal** next to a stunned bear to pull out its
stuffing (**fluff**). Fluff counts as your score and also sets your body: more fluff
makes you rounder and wobblier, slower to get going and much harder to stop.

Open the folder in Godot 4.3 and press **Play**.

## Controls
| | Solo player | Gamepad |
|---|---|---|
| Move | WASD / Arrows | Left stick / D-pad |
| Bomb | Space / Enter | A |
| Steal (hold) | E / Shift | X, B or RT |
| Pause | Esc / P | Start |

For local multiplayer, set more slots to *Human* in the menu.
P1 WASD Space E · P2 Arrows Enter RShift · P3 IJKL O U · P4 Numpad 8456 0 . · each pad drives its own player.

## Project layout
- `scripts/tuning.gd`: every gameplay number (movement, mass curve, bombs, stun, theft).
- `scripts/terrain.gd`: terrain physics (rug, ice, honey, bouncy, conveyors). This is kept separate from the art.
- `scripts/arena_maps.gd`: the arenas (Traditional Nursery, Frozen Nursery, Playroom Mayhem).
- `scripts/bear.gd`: movement physics shared by humans and AI. `bear_visual.gd` is the procedural plush rig.
- `scripts/ai_controller.gd`: the Easy / Normal / Hard AI.
- `tools/generate_placeholders.py`: regenerates the `template_*.png` placeholders (needs Pillow).

Smoke test (all-AI match, prints standings): `godot --headless --path . -- --autotest [--arena=1]`

## Replacing the art
Every placeholder is named `template_<name>.png`. To replace one, put `<name>.png` in the
**same folder**. The game uses your file when it exists and falls back to the template otherwise.
The generator only ever writes `template_` files. Sheets are a single row, and the cell size is
`image width / cell count`, so you can use any resolution. Draw each part centred in its cell.

| File | Size (template) | Layout |
|---|---|---|
| `bears/template_bear.png` | 1280×128 | 10 cells: body, belly, head, ear, arm, leg, face normal, face smug, face indignant, face stunned. Draw the body parts light grey/white, because they are tinted per bear. Faces are drawn untinted on a transparent background. |
| `tiles/template_tiles.png` | 576×64 | 9 cells: rug, rug alt, ice, honey, bouncy, conveyor (pointing right), pillar, cushion block, border |
| `objects/template_bomb.png` | 64×64 | the bomb. The fuse tip sits near the top right. |
| `objects/template_fluff.png` | 32×32 | a tuft of stuffing |
| `powerups/template_powerups.png` | 256×64 | 4 cells: extra bomb, bigger blast, springy stitching (speed), biome shuffle |
| `effects/template_effects.png` | 384×64 | 6 cells: blast centre, blast arm (horizontal), blast end (pointing right), star, dust, sparkle |

Sounds are generated placeholders. To replace one, drop `squeak`, `bump`, `boom`, `pop`, `stun`, `steal`,
`pickup`, `tick`, `go`, `shuffle`, `boing` or `fanfare` as `.ogg`/`.wav` into `assets/audio/`.
