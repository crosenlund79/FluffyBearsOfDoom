// Small visual entities: blasts, particles, fluff tufts, power-ups, decals
// (ports of explosion.gd, particle.gd, fluff_pickup.gd, powerup.gd, decal.gd).
using UnityEngine;

namespace FBD
{
    public abstract class Entity
    {
        public Vector2 position;
        public float rotation;
        public bool dead;
        public virtual void Process(float delta) { }
        public abstract void Draw(Painter p, Vector2 origin);
        protected void Base(Painter p, Vector2 origin)
        {
            p.SetBase(Xf.TRS(origin + position, rotation, Vector2.one));
            p.ResetTransform();
        }
    }

    public struct Segment { public Vector2 pos; public int kind; public float rot; }

    /// A blast of confetti (or blood in Horror): hazard tint, burst sprite and paper pieces.
    public class Explosion : Entity
    {
        public Segment[] segments;
        float age;
        const float T = Tuning.TILE;

        public override void Process(float delta)
        {
            age += delta;
            if (age > Tuning.FLAME_TIME + 0.3f) dead = true;
        }

        public override void Draw(Painter p, Vector2 origin)
        {
            Base(p, origin);
            Tex tex = Assets.Get("effects/effects");
            Color[] CONFETTI = ModeTheme.Confetti;
            float k = age / Tuning.FLAME_TIME;
            float grow = Gd.Clamp(k * 6f, 0f, 1f);
            float fade = 1f - Gd.Clamp((k - 0.8f) / 0.5f, 0f, 1f);
            for (int si = 0; si < segments.Length; si++)
            {
                var seg = segments[si];
                Vector2 pp = seg.pos;
                Color hz = CONFETTI[si % CONFETTI.Length];
                p.ResetTransform();
                p.Rect(Arena.Grow(new Rect(pp - new Vector2(T, T) * 0.5f, new Vector2(T, T)), -2), new Color(hz.r, hz.g, hz.b, 0.4f * fade));
                float wob = 1f + 0.08f * Mathf.Sin(age * 30f + pp.x * 0.1f + pp.y * 0.07f);
                float sc = grow * wob;
                p.SetTransform(pp, seg.rot, seg.kind != 0 ? new Vector2(1f, sc) : new Vector2(sc, sc));
                float size = T * (seg.kind == 0 ? 1.3f : 1.1f);
                p.TextureRect(tex.Region(Assets.EFFECT_CELLS, seg.kind), new Rect(-size * 0.5f, -size * 0.5f, size, size), new Color(1, 1, 1, fade));
                // fluttering paper pieces
                for (int i = 0; i < 6; i++)
                {
                    float h = ((si * 7 + i * 13) % 17) / 17f;
                    float h2 = ((si * 11 + i * 5) % 13) / 13f;
                    Vector2 start = new Vector2((h - 0.5f) * T * 0.8f, (h2 - 0.5f) * T * 0.6f);
                    Vector2 off = start + new Vector2(Mathf.Sin(age * 9f + i) * 4f, age * 40f * (0.5f + h));
                    Color c = CONFETTI[(si + i) % CONFETTI.Length];
                    p.SetTransform(pp + off, age * (6f + i * 2f) + h * 6f, new Vector2(1f, 0.5f + 0.5f * Mathf.Abs(Mathf.Sin(age * 12f + i))));
                    p.Rect(new Rect(-3, -2, 6, 4), new Color(c.r, c.g, c.b, fade));
                }
            }
            p.ResetTransform();
        }
    }

    /// A tiny sprite particle: stars, dust, stuffing; hasTex=false = a confetti paper piece.
    /// If `target` is set it flies in an arc toward that bear (stolen fluff).
    public class Particle : Entity
    {
        public bool hasTex = true;
        public string sheet = "effects/effects";
        public int cells = 1, cell;
        public Vector2 vel;
        public float gravity, drag, life = 0.6f, age, spin, size = 16f, grow, arc = 26f;
        public Color color = Color.white;
        public Bear target;
        public Vector2 start;

        public override void Process(float delta)
        {
            age += delta;
            if (age >= life) { dead = true; return; }
            if (target != null)
            {
                float k = age / life;
                float e = k * k * (3f - 2f * k);
                position = Vector2.LerpUnclamped(start, target.position + new Vector2(0, -22), e) + new Vector2(0, -Mathf.Sin(k * Gd.PI) * arc);
                size = Gd.Lerp(size, 8f, delta * 2f);
            }
            else
            {
                vel *= Mathf.Max(0f, 1f - drag * delta);
                vel.y += gravity * delta;
                position += vel * delta;
            }
            rotation += spin * delta;
            size += grow * delta;
        }

        public override void Draw(Painter p, Vector2 origin)
        {
            Base(p, origin);
            float a = 1f - Gd.Clamp((age / life - 0.6f) / 0.4f, 0f, 1f);
            var col = new Color(color.r, color.g, color.b, color.a * a);
            if (!hasTex)
            {
                float flip = 0.35f + 0.65f * Mathf.Abs(Mathf.Sin(age * 14f + spin));
                p.SetTransform(Vector2.zero, 0f, new Vector2(1f, flip));
                p.Rect(new Rect(-size * 0.5f, -size * 0.3f, size, size * 0.6f), col);
                p.ResetTransform();
                return;
            }
            Tex t = Assets.Get(sheet);
            if (cells > 1) t = t.Region(cells, cell);
            p.TextureRect(t, new Rect(-size * 0.5f, -size * 0.5f, size, size), col);
        }
    }

    /// A loose tuft of stuffing that popped out of a stunned bear.
    public class FluffPickup : Entity
    {
        public float amount = 5f;
        public Vector2 from, to;
        public Vector2Int cell;
        float t;
        const float FLIGHT = 0.5f;
        public bool landed;

        public void Init() { position = from; }

        public override void Process(float delta)
        {
            t += delta;
            if (!landed)
            {
                float k = Mathf.Min(t / FLIGHT, 1f);
                position = Vector2.LerpUnclamped(from, to, k);
                if (k >= 1f) landed = true;
            }
        }

        public override void Draw(Painter p, Vector2 origin)
        {
            Base(p, origin);
            float hop = !landed ? Mathf.Sin(Mathf.Min(t / FLIGHT, 1f) * Gd.PI) * 34f : 3f + Mathf.Sin(t * 3f) * 2f;
            float s = 16f + amount * 1.2f;
            p.SetTransform(new Vector2(0, 8), 0f, new Vector2(1f, 0.4f));
            p.Circle(Vector2.zero, s * 0.4f, new Color(0.3f, 0.2f, 0.15f, 0.18f));
            p.SetTransform(new Vector2(0, -hop), Mathf.Sin(t * 2f) * 0.2f, Vector2.one);
            p.TextureRect(Assets.Get("objects/fluff"), new Rect(-s * 0.5f, -s * 0.5f, s, s), ModeTheme.StuffingColor);
            p.ResetTransform();
        }
    }

    /// A collectible power-up badge on a grid cell.
    public class Powerup : Entity
    {
        public const int BOMB = 0, FIRE = 1, SPEED = 2, SHUFFLE = 3, KICK = 4, LINE = 5, RUBBER = 6, IMMORTAL = 7, REVERSE = 8, DIARRHEA = 9, REMOTE = 10;
        public static readonly string[] NAMES = { "Extra Bomb", "Bigger Blast", "Springy Stitching", "Biome Shuffle", "Bomb Kick",
            "Line Bomb", "Rubber Bombs", "Immortality", "Reverse Controls!", "Bomb Diarrhea!", "Remote Detonator" };
        // Every bear can kick now, so Bomb Kick no longer drops (its sheet cell is kept for compatibility).
        public static readonly float[] WEIGHTS = { 22f, 20f, 9f, 6f, 0f, 7f, 5f, 4f, 9f, 7f, 7f };
        /// Sheet cell per kind. The Remote Detonator reuses the bomb badge plus a drawn
        /// antenna, so existing 10-cell replacement sheets keep working.
        public static readonly int[] CELL = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 };
        public static bool IsBad(int kind) => kind == REVERSE || kind == DIARRHEA;

        public int kind;
        public Vector2Int cell;
        float t;

        public override void Process(float delta) { t += delta; }

        public override void Draw(Painter p, Vector2 origin)
        {
            Base(p, origin);
            float appear = Gd.Clamp(t * 4f, 0f, 1f);
            float s = 38f * (appear + 0.2f * Mathf.Sin(appear * Gd.PI));
            float bob = Mathf.Sin(t * 3f) * 2.5f;
            p.SetTransform(new Vector2(0, 14), 0f, new Vector2(1f, 0.35f));
            p.Circle(Vector2.zero, s * 0.38f, new Color(0.3f, 0.2f, 0.15f, 0.2f));
            float wob = IsBad(kind) ? Mathf.Sin(t * 9f) * 0.12f : Mathf.Sin(t * 2f) * 0.08f; // curses twitch suspiciously
            p.SetTransform(new Vector2(0, -2 + bob), wob, Vector2.one);
            p.TextureRect(Assets.Get("powerups/powerups").Region(Assets.POWERUP_CELLS, CELL[kind]), new Rect(-s * 0.5f, -s * 0.5f, s, s));
            if (kind == REMOTE) DrawRemoteAntenna(p, new Vector2(s * 0.18f, -s * 0.2f), s / 38f, t, new Color(0.9f, 0.2f, 0.25f));
            p.ResetTransform();
        }

        /// A little radio antenna with a blinking tip and signal arcs (remote bombs and their badge).
        /// Draws in the painter's current local space.
        public static void DrawRemoteAntenna(Painter p, Vector2 bse, float sc, float t, Color tip)
        {
            Vector2 top = bse + new Vector2(4, -12) * sc;
            p.Line(bse, top, new Color(0.25f, 0.18f, 0.15f), 2f * sc);
            bool on = (t * 2.5f) % 1f < 0.55f;
            p.Circle(top, 2.8f * sc, on ? tip : Gd.Darkened(tip, 0.5f));
            if (on)
                for (int k = 0; k < 2; k++)
                    p.Arc(top, (5f + k * 3.5f) * sc, -Gd.PI * 0.85f, -Gd.PI * 0.15f, 6, new Color(tip.r, tip.g, tip.b, 0.75f - k * 0.3f), 1.4f * sc);
        }
    }

    /// Floor mark where a bear was knocked out (stuffing / blood splatter).
    public class Decal : Entity
    {
        public Color color = Color.white;
        public float size = 40f, life = 25f, age;

        public Decal(Rng rng) { rotation = rng.F() * Gd.TAU; }

        public override void Process(float delta)
        {
            age += delta;
            if (age >= life) dead = true;
        }

        public override void Draw(Painter p, Vector2 origin)
        {
            Base(p, origin);
            float grow = Gd.Clamp(age / 0.15f, 0f, 1f);
            float a = color.a * Gd.Clamp((life - age) / 3f, 0f, 1f);
            float s = size * (0.6f + 0.4f * grow);
            p.TextureRect(Assets.Get("effects/effects").Region(Assets.EFFECT_CELLS, 7), new Rect(-s * 0.5f, -s * 0.5f, s, s), new Color(color.r, color.g, color.b, a));
        }
    }
}
