## Every gameplay number lives here, so the game is easy to tune.
extends RefCounted

# --- Arena -------------------------------------------------------------------
const TILE := 48.0
const COLS := 15
const ROWS := 13
const BLOCK_DENSITY := 0.72
const POWERUP_CHANCE := 0.34

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
const SHUFFLE_DURATION := 22.0
const SHUFFLE_REGIONS := 4

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
const REMOTE_BACKUP_FUSE := 10.0         # a remote bomb still goes off on its own after this long
const REMOTE_THREAT_TIME := 1.5          # how soon other AIs assume someone else's remote bomb may blow

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
