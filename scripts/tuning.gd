## Every gameplay number lives here, so the game is easy to tune.
extends RefCounted

# --- Arena -------------------------------------------------------------------
const TILE := 48.0
const COLS := 17          # one extra outer ring (zoomed out: see ARENA_SCALE)
const ROWS := 15
const ARENA_SCALE := 0.8667   # the 17x15 grid drawn at this scale fills the same screen area as the old 15x13
const BLOCK_DENSITY := 0.72

# --- Power-up distribution (scripts/powerup_plan.gd) ----------------------------
# Kinds: 0 Bomb, 1 Fire, 2 Speed, 3 Shuffle, 4 Kick, 5 Line, 6 Rubber, 7 Immortal,
#        8 Reverse, 9 Diarrhea, 10 Proximity, 11 Princess
# Each category draws `count` items by weight; "chance" < 1 makes it a maximum
# rather than a guarantee; "refill": false keeps it out of redistribution.
const PU_TOTAL := 24
const PU_CATEGORIES := [
	{"name": "core", "count": 10, "kinds": {0: 1.0, 1: 1.0}},
	{"name": "mobility", "count": 6, "kinds": {4: 1.0, 2: 1.4, 6: 0.6}},
	{"name": "tactical", "count": 4, "kinds": {10: 1.2, 5: 0.8, 7: 0.8}},
	{"name": "chaos", "count": 3, "kinds": {3: 1.2, 8: 0.9, 9: 0.9}, "refill": false},
	{"name": "special", "count": 1, "kinds": {11: 1.0}, "chance": 0.45, "refill": false},
]
# most of one kind per round (per-bear stacking caps live in bear.gd: 8 bombs, range 8)
const PU_CAPS := {0: 6, 1: 6, 2: 4, 3: 2, 4: 2, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 2, 11: 1}
const PU_RESERVE := 4              # items held back to drop onto the floor later
const PU_RESERVE_WINDOW := [0.3, 0.7]   # share of the round over which the reserve drops
const PU_EARLY_RADIUS := 5         # blocks this close to a spawn count as its region
const PU_EARLY_SET := [[0], [1], [2, 4]]   # near every corner: a Bomb, a Fire and a Speed-or-Kick
const PU_EARLY_PER_SPAWN := 3
const PU_RARE := [3, 5, 7, 8, 9, 10, 11]   # placed far from every spawn
const PU_RARE_MIN_DIST := 5
const PU_VALUE := {0: 1.0, 1: 1.0, 2: 0.8, 4: 0.8, 6: 0.6}

# --- Fluff --------------------------------------------------------------------
const START_FLUFF := 100.0
const ROUND_TIMES := [90.0, 150.0, 240.0]

# --- Movement (for a bear holding START_FLUFF on a normal rug) ----------------
const BASE_SPEED := 165.0        # px/s top speed
const BASE_ACCEL := 1500.0       # px/s^2
const BASE_BRAKE := 1900.0       # px/s^2 friction when not pushing
const MASS_MIN := 0.45           # mass of a completely empty bear
const MASS_PER_RATIO := 0.55     # extra mass per START_FLUFF of stuffing
const SPEED_MASS_FALLOFF := 0.25 # top speed lost per unit of extra mass
const ACCEL_EXP := 1.9           # accel = BASE_ACCEL / mass^ACCEL_EXP
const BRAKE_EXP := 2.3           # brake = BASE_BRAKE / mass^BRAKE_EXP (heavy bears can't stop)
const ALIGN_ACCEL := 1.7         # how hard bears steer back into corridor lanes
const LANE_PULL := 14.0          # lane alignment speed per px of offset
const HITBOX_HALF := 17.0        # collision box half size; never changes with size
const BUMP_MIN_SPEED := 70.0     # wall impact speed that makes a squeak
const SPEED_UP_SPEED := 16.0     # top speed per Springy Stitching power-up
const SPEED_UP_ACCEL := 0.15     # extra acceleration per Springy Stitching
const MAX_SPEED_LEVEL := 4

# --- Bombs ---------------------------------------------------------------------
const BOMB_FUSE := 2.6
const FLAME_TIME := 0.55
const START_BOMBS := 1
const START_RANGE := 2
const MAX_BOMBS := 8
const MAX_RANGE := 8

# --- Stun & stealing ----------------------------------------------------------
const STUN_TIME := 3.6
const STUN_IMMUNE := 1.3         # invulnerability after waking up
const STEAL_RANGE := 1.3         # in tiles, centre to centre
const STEAL_RATE := 24.0         # fluff per second
const STUN_SPILL := 6.0          # fluff that pops out when stunned
const ROBBED_GRUMPY := 2.2       # seconds a robbed bear looks indignant

# --- Biome Shuffle --------------------------------------------------------------
const SHUFFLE_WARN := 1.8
const MAX_H_BELTS := 2                   # conveyor belts per arena (maps and Biome Shuffle alike)
const MAX_V_BELTS := 2
const SHUFFLE_BELT_LEN := Vector2i(5, 9)  # Conveyor Chaos belt length range (tiles)
const SHUFFLE_DURATION := 15.0          # seconds the whole floor stays the shuffled biome before it reverts


# --- Bomb abilities -------------------------------------------------------------
const KICK_SPEED := 330.0        # px/s of a kicked bomb
const RUBBER_MAX_BOUNCES := 8

# --- Power-ups & curses -----------------------------------------------------------
const IMMORTAL_TIME := 20.0
const REVERSE_TIME := 12.0
const REVERSE_REINFECT_IMMUNE := 3.0  # after being cured
const INFECT_DIST := 0.85            # tiles, centre to centre
const INFECT_DELAY := 1.0            # a freshly infected bear can't pass it on at once
const DIARRHEA_TIME := 10.0
const DIARRHEA_INTERVAL := 0.3

# --- Doom Duck Parade --------------------------------------------------------------
const DUCK_ENABLED := true
const DUCK_FIRST_DELAY := [20.0, 35.0]   # seconds into a match before the first parade (min, max)
const DUCK_INTERVAL := [35.0, 55.0]      # pause between parades (min, max)
const DUCK_TIME := 12.0                  # countdown from emerging to detonation
const DUCK_SPEED := 62.0                 # px/s waddling speed
const DUCK_BLAST_RANGE := 4              # flood-fill reach in grid steps (turns corners)
const DUCK_WARNING := 3.0                # last seconds: danger zone shown, frantic wobble
const DUCKLING_SPACING := 22.0           # px between ducks in the procession

# --- Corridor assistance ----------------------------------------------------------
const CENTER_ASSIST_SPEED := 90.0        # px/s a bear is nudged toward an open corridor it is steering into
const TURN_LOOKAHEAD := 1.15             # tiles ahead along the motion to look for the corridor you pressed toward

# --- Remote Detonator -------------------------------------------------------------
# Proximity bombs (the special key, from the Proximity Bombs power-up)
const PROX_CHARGES := 3                  # proximity bombs per power-up
const PROX_MAX_CHARGES := 6
const PROX_ARM_TIME := 3.0               # seconds before it is live (3 -> 2 -> 1 shown on the bomb)
const PROX_RANGE := 1.05                 # tiles: an opponent this close to an armed one sets it off
const PROX_TRIGGER_DELAY := 0.12         # alarm beep between being tripped and going off
const PROX_LIFETIME := 30.0              # an untripped proximity bomb goes off on its own after this long

# --- Horror footprints ------------------------------------------------------------
const FOOTPRINT_STRIDE := 13.0           # px between footprints
const FOOTPRINT_LIFE := 7.0              # seconds a footprint takes to fade
const FOOTPRINT_MAX := 220               # oldest prints are recycled beyond this
const BLOOD_PER_PRINT := 0.045           # how quickly a bear's feet run dry

# --- Crane chair drop (rare event) -------------------------------------------------
const CRANE_ENABLED := true
const CRANE_FIRST_DELAY := [40.0, 65.0]  # seconds into a match before the first drop (min, max)
const CRANE_INTERVAL := [60.0, 90.0]     # after a chair is gone, wait this long for the next
const CRANE_SPEED := 260.0               # px/s the hook travels across
const CRANE_HOVER := 1.1                 # seconds it dangles over the target (drop warning)
const CHAIR_FLUFF := 60.0                # stuffing inside a delivered chair

# Instant win: a bear whose fluff reaches this ends the round on the spot.
const INSTANT_WIN_FLUFF := 300.0           # default threshold (0 = off); players pick in Settings
const INSTANT_WIN_CHOICES := [0.0, 200.0, 250.0, 300.0, 350.0]

# Time of Doom: the arena closes in ring by ring near the end of the round.
const DOOM_ENABLED := true
const DOOM_START := 0.60                   # fraction of the round when the first ring starts warning
const DOOM_END := 0.97                     # fraction by which the last tile has shut (tiles close one by one in between)
const DOOM_RINGS := 5                      # rings closed, outermost playable ring first
const DOOM_WARN := 3.0                     # max seconds each tile flashes before it shuts (3% of the round, at least 1.8 s)
const DOOM_STUN := 1.6                     # stun for a bear shoved inward by a closing ring

# Horror jack-in-the-box: a pillar rattles, a clown bursts out and hammers the nearest bear.
const CLOWN_ENABLED := true
const CLOWN_FIRST_DELAY := [25.0, 40.0]
const CLOWN_INTERVAL := [28.0, 45.0]
const CLOWN_WARN := 3.0                    # seconds of accelerating flashing before it bursts out
const CLOWN_STUN := 2.2

# Princess Hunt (a rare trap power-up; at most one princess per round)
const PRINCESS_SPEED := 175.0          # px/s along the corridors (a touch faster than a bear)
const PRINCESS_STUN := 4.0             # her shotgun blast: a long stun...
const PRINCESS_SPILL := 0.25           # ...and this share of the victim's stuffing blown out
const PRINCESS_WARN := 2.0             # seconds her crown peeks over the wall before she leaps in
const PRINCESS_MAX_TIME := 30.0        # she always leaves after this long, attack or not

# --- AI decision-making (per level: [Easy, Normal, Hard]) ---------------------
# Same rules and inputs for everyone; levels differ only in how they decide.
const AI_THINK_TIME := [0.5, 0.28, 0.24]      # seconds between decisions (Hard ~ a quick human)
const AI_NOTICE_DANGER := [0.85, 0.93, 0.95]    # chance a decision notices it stands in a blast line
const AI_CARELESS_BOMB := [0.05, 0.0, 0.0]    # chance to drop a bomb with no way out
const AI_STEAL_SKIP := [0.15, 0.0, 0.0]        # chance to ignore a robbable stunned bear
const AI_STEAL_BUDGET_EASY := [2.0, 3.6]      # Easy steals for this many seconds, then wanders off
const AI_DANGER_MARGIN := [0.35, 0.5, 0.6]    # seconds of slack kept before a blast when choosing a path
const AI_EASY_ROB_CHANCE := 0.75            # Easy goes after a stunned bear this often
const AI_ROB_GREED := [0.0, 0.0, 0.0]         # extra goal score per fluff of a stunned bear (Hard)
