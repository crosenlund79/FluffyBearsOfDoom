# Fluffy Bears of Doom: Unity port

A standalone Unity/C# port of the Godot 4.3 game. Gameplay, physics, AI, maps, power-ups,
curses, the Doom Duck Parade, taunts, Normal/Horror modes, menus, HUD, settings, music and
sound effects are all reimplemented natively in C#. The project needs nothing from the
original Godot project.

## Requirements
- **Unity 2022.3 LTS** (made for 2022.3.50f1; any 2022.3.x should work). It uses the Built-in
  Render Pipeline and only Unity's built-in modules, so no package downloads are needed.
- Target: Windows / macOS / Linux standalone.

## Open & play
1. Unity Hub → **Add** → select this folder (the one containing `Assets`, `Packages`, `ProjectSettings`).
2. Open `Assets/Scenes/Main.unity` and press **Play**.
   Everything is created at runtime by `App.cs` (`[RuntimeInitializeOnLoadMethod]`), so the
   scene only holds a camera.
3. To build: **File → Build Settings → Build** (the scene list is already set).

## Controls
| | Player 1 | Player 2 |
|---|---|---|
| Move | WASD | Arrow keys |
| Place bomb | Space | Enter |
| Steal fluff (hold) | Left Shift | Right Ctrl |
| Line Bomb (special) | E | Right Shift |

A lone player can use either layout. Gamepad (XInput axis layout on Windows): left stick or d-pad,
A bomb, X/B/RT steal, Y/LB special, Start pause. In two-player mode pad 1 drives Player 1 and pad
2 drives Player 2. Esc/P pauses, N skips to the next music track. Menus work with the mouse,
arrows/WASD + Enter/Space, or the d-pad + A.

## Replacing art and audio (works in built games too)
All art and audio live in `Assets/StreamingAssets` and are loaded at runtime.

**Sprites** (`StreamingAssets/Sprites/<folder>/`): each sprite uses the first file that exists:
1. `<folder>/<mode>/<name>.png`: your mode-specific art (`mode` = `normal` or `horror`)
2. `<folder>/<name>.png`: your shared art
3. `<folder>/<mode>/template_<name>.png`: the built-in mode placeholder
4. `<folder>/template_<name>.png`: the built-in placeholder

Your files always win and placeholders never overwrite anything. Sheets are a single row and the
cell size is `image width / cell count`.

| File | Cells |
|---|---|
| `bears/template_bear.png` | 10: body, belly, head, ear, arm, leg, face normal/smug/indignant/stunned |
| `tiles/template_tiles.png` | 9: rug, rug alt, ice, honey, bouncy, conveyor (→), pillar, cushion block, border |
| `objects/template_bomb.png` | 1 (tinted per bear) |
| `objects/template_fluff.png` | 1 |
| `objects/template_duck.png` | 2: wind-up duck (→), wind-up key |
| `powerups/template_powerups.png` | 10: bomb, blast, speed, shuffle, kick, line, rubber, immortality, reverse, diarrhea |
| `effects/template_effects.png` | 8: blast centre, arm, end (→), star, dust, sparkle, bird (→), floor splat |

Horror placeholders exist for `bears`, `tiles` and `effects`.

**Music** (`StreamingAssets/Audio/music/<menu|gameplay>/<normal|horror>/`): `.mp3`, `.ogg` and `.wav`
files are found automatically. Loose files in `menu/` or `gameplay/` are shared by both modes. If
a Horror folder is empty, the Normal tracks play slowed. In a built game you can also add tracks
to `music/<menu|gameplay>/<normal|horror>/` next to the executable, or under
`Application.persistentDataPath/music/`.

**Sound effects** (`StreamingAssets/Audio/sfx/`, Horror-only overrides in `sfx/horror/`): name a file
after the sound (`place fuse confetti concussion steal pickup curse squeak bump kick boing pop menu
tick go shuffle immortal victory taunt mode portal clock_tick quack duckling_quack duck_warning
duck_confetti`) to replace the built-in procedural placeholder.

Settings (volumes, mute, shuffle, mode, players, AI levels, arena, round length) are saved to
`Application.persistentDataPath/settings.json`.

## Code map (`Assets/Scripts`)
- `Core/`: `Tuning` (every gameplay number), `Terrain`, `ArenaMaps`, `Settings`, `ModeTheme` (+ `Taunts`), `Assets` (sprite loader), `Controls` (input), `Gd` (math helpers).
- `Game/`: `Game` (match logic), `Arena`, `Bear` (physics, theft, curses, taunts), `BearVisual` (procedural plush rig), `AiController`, `HumanController`, `Bomb`, `DuckParade`, `Effects` (blasts, particles, pickups, power-ups, decals).
- `Render/`: `Painter` (batched 2D drawing in 1280×720 canvas space), `Xf` (2D transforms).
- `UI/`: `Menu`, `Hud`, `AudioPanel`, `Gui` (widgets), `UiStyle` (palettes).
- `Audio/`: `Sfx` (procedural placeholders + replacements), `Music` (playlists, fades), `AudioHub`.
- `App.cs`: bootstrap, camera, scene flow.

## Implementation notes
- **Drawing:** the game draws everything procedurally each frame, as the original did with
  Godot `_draw()`. Gameplay objects are plain C# classes updated by `App`, so there are no
  prefabs. Physics runs in `FixedUpdate` at 60 Hz, the same tick rate as Godot.
- **Text:** text uses an OS serif font (Georgia, Palatino, DejaVu Serif, …) through Unity's
  dynamic fonts, falling back to Unity's built-in font.
- **Audio volumes:** Master, Music and SFX are applied as gains, because Godot's audio buses have
  no Unity equivalent without a mixer asset.
- **Gamepad axis numbers:** these follow the Windows XInput layout. macOS and Linux drivers
  number axes and buttons differently, so d-pad and trigger mappings may need adjusting in
  `ProjectSettings/InputManager.asset` there.
- **Known quirk kept from the original:** when a second Biome Shuffle starts while an earlier one
  is still active, the earlier shuffle's cells show warning outlines again until they revert.
