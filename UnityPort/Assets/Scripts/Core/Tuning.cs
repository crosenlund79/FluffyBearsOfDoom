// Every gameplay number lives here, so the game is easy to tune.
// (Port of scripts/tuning.gd - values identical.)
namespace FBD
{
    public static class Tuning
    {
        // --- Arena ---
        public const float TILE = 48f;
        public const int COLS = 15;
        public const int ROWS = 13;
        public const float BLOCK_DENSITY = 0.72f;
        public const float POWERUP_CHANCE = 0.34f;

        // --- Fluff ---
        public const float START_FLUFF = 100f;
        public static readonly float[] ROUND_TIMES = { 90f, 150f, 240f };

        // --- Movement (for a bear holding START_FLUFF on a normal rug) ---
        public const float BASE_SPEED = 165f;
        public const float BASE_ACCEL = 1500f;
        public const float BASE_BRAKE = 1900f;
        public const float MASS_MIN = 0.45f;
        public const float MASS_PER_RATIO = 0.55f;
        public const float SPEED_MASS_FALLOFF = 0.25f;
        public const float ACCEL_EXP = 1.9f;
        public const float BRAKE_EXP = 2.3f;
        public const float ALIGN_ACCEL = 1.7f;
        public const float LANE_PULL = 14f;
        public const float HITBOX_HALF = 17f;
        public const float BUMP_MIN_SPEED = 70f;
        public const float SPEED_UP_SPEED = 16f;
        public const float SPEED_UP_ACCEL = 0.15f;
        public const int MAX_SPEED_LEVEL = 4;

        // --- Bombs ---
        public const float BOMB_FUSE = 2.6f;
        public const float FLAME_TIME = 0.55f;
        public const int START_BOMBS = 1;
        public const int START_RANGE = 2;
        public const int MAX_BOMBS = 8;
        public const int MAX_RANGE = 8;

        // --- Stun & stealing ---
        public const float STUN_TIME = 3.6f;
        public const float STUN_IMMUNE = 1.3f;
        public const float STEAL_RANGE = 1.3f;
        public const float STEAL_RATE = 24f;
        public const float STUN_SPILL = 6f;
        public const float ROBBED_GRUMPY = 2.2f;

        // --- Biome Shuffle ---
        public const float SHUFFLE_WARN = 1.8f;
        public const float SHUFFLE_DURATION = 22f;
        public const int SHUFFLE_REGIONS = 4;

        // --- Bomb abilities ---
        public const float KICK_SPEED = 330f;
        public const int RUBBER_MAX_BOUNCES = 8;

        // --- Power-ups & curses ---
        public const float IMMORTAL_TIME = 20f;
        public const float REVERSE_TIME = 12f;
        public const float REVERSE_REINFECT_IMMUNE = 3f;
        public const float INFECT_DIST = 0.85f;
        public const float INFECT_DELAY = 1f;
        public const float DIARRHEA_TIME = 10f;
        public const float DIARRHEA_INTERVAL = 0.3f;

        // --- Doom Duck Parade ---
        public const bool DUCK_ENABLED = true;
        public static readonly float[] DUCK_FIRST_DELAY = { 20f, 35f };
        public static readonly float[] DUCK_INTERVAL = { 35f, 55f };
        public const float DUCK_TIME = 12f;
        public const float DUCK_SPEED = 62f;
        public const int DUCK_BLAST_RANGE = 4;
        public const float DUCK_WARNING = 3f;
        public const float DUCKLING_SPACING = 22f;
    }
}
