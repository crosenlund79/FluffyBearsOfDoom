// The crane-delivered chair (port of chair.gd) and the crane event that drops it
// (port of crane_event.gd).
using UnityEngine;

namespace FBD
{
    /// A chair stuffed full of fluff. Bears loot it like a stunned bear: stand next
    /// to it and hold Steal. It isn't solid, and a blast bursts it open, scattering
    /// the rest of its stuffing as pickups.
    public class Chair : Lootable
    {
        public Game game;
        public Vector2Int cell;
        float t, squash, squashV, lastFluff;

        public void Setup(Game g, Vector2Int c)
        {
            game = g; cell = c;
            position = g.arena.CellCenter(c);
            fluff = Tuning.CHAIR_FLUFF; lastFluff = fluff;
            stunT = 999f;   // never "wakes up" (lets the AI treat it like a victim)
            squashV = 9f;
        }

        public float Fill => Gd.Clamp(fluff / Tuning.CHAIR_FLUFF, 0f, 1f);

        public void Process(float delta)
        {
            t += delta;
            robbedT = Mathf.Max(0f, robbedT - delta);
            if (fluff < lastFluff - 0.01f) squashV += (lastFluff - fluff) * 0.9f;   // each tug makes it puff and sag
            lastFluff = fluff;
            // fixed substeps keep the stiff spring stable on long frames
            int steps = Mathf.Max(1, Mathf.CeilToInt(delta / 0.008f));
            float dt = delta / steps;
            for (int i = 0; i < steps; i++)
            {
                squashV += (-260f * squash - 2f * Mathf.Sqrt(260f) * 0.18f * squashV) * dt;
                squash += squashV * dt;
            }
            squash = Gd.Clamp(squash, -0.6f, 0.6f);
        }

        public void Draw(Painter p, Vector2 origin)
        {
            float T = game.arena.T;
            float f = Fill;
            float w = T * 1.02f;
            float h = w * (0.78f + 0.22f * f) * (1f - squash * 0.25f);
            Vector2 shake = robbedT > 0f ? new Vector2(Mathf.Sin(t * 47f), Mathf.Cos(t * 39f)) * 1.6f : Vector2.zero;
            p.SetBase(Xf.Translate(origin + position));
            p.SetTransform(new Vector2(0, T * 0.34f), 0f, new Vector2(1f, 0.32f));
            p.Circle(Vector2.zero, w * 0.48f, new Color(0.15f, 0.1f, 0.08f, 0.32f));
            p.SetTransform(shake, 0f, new Vector2(1f + squash * 0.25f, 1f));
            p.TextureRect(Assets.Get("objects/chair"), new Rect(-w * 0.5f, T * 0.4f - h, w, h));
            // stuffing still poking out of the top, more when fuller
            Tex tuft = Assets.Get("objects/fluff");
            int n = Mathf.CeilToInt(f * 5f);
            for (int i = 0; i < n; i++)
            {
                float x = (i - (n - 1) * 0.5f) * 8f;
                float bob = Mathf.Sin(t * 3f + i * 1.3f) * 1.5f;
                float s = 10f + 4f * f;
                p.TextureRect(tuft, new Rect(x - s * 0.5f, T * 0.4f - h - s * 0.45f + bob, s, s), ModeTheme.StuffingColor);
            }
            p.SetBase(Xf.Identity);
            p.ResetTransform();
        }
    }

    /// Rare event: a crane hook swings in from off-screen carrying an overstuffed
    /// chair, dangles over a cell (with a target marker as warning), drops it and leaves.
    public class CraneEvent
    {
        public const int ENTER = 0, LOWER = 1, HOVER = 2, DROP = 3, LEAVE = 4;

        Game game;
        Arena arena;
        public Vector2Int target;
        public int phase = ENTER;
        float t, age;              // time in the current phase / overall
        Vector2 hook;              // arena-local
        float side = 1f, chairY, chairV, swing, swingV, creak;
        public bool done;
        bool carrying = true;
        readonly Rng rng = new Rng();

        public void Setup(Game g, Vector2Int cell)
        {
            game = g; arena = g.arena; target = cell;
            side = rng.F() < 0.5f ? 1f : -1f;
            Vector2 tc = arena.CellCenter(cell);
            hook = new Vector2(tc.x - side * 900f, TravelY());
            swingV = side * 1.5f;
            Sfx.Play("crane");
        }

        float TravelY() => Mathf.Max(arena.CellCenter(target).y - 150f, -20f);
        /// Top edge of the chair once it stands on its cell (matches Chair.Draw).
        float LandTop() => arena.CellCenter(target).y + arena.T * 0.4f - arena.T * 1.02f;
        /// Hook height that leaves the chair dangling about a tile above its cell.
        float HangY() => LandTop() - 28f - arena.T;

        void Next(int p) { phase = p; t = 0f; }

        public void PhysicsUpdate(float delta)
        {
            if (done) return;
            age += delta;
            t += delta;
            // pendulum swing of the load
            swingV += (-18f * swing - 1.6f * swingV) * delta;
            swing += swingV * delta;
            creak -= delta;
            if (creak <= 0f && phase != LEAVE) { creak = 1.6f; Sfx.Play("crane", rng.Range(0.9f, 1.1f), -6f); }
            Vector2 tc = arena.CellCenter(target);
            switch (phase)
            {
                case ENTER:
                {
                    float step = Tuning.CRANE_SPEED * delta;
                    if (Mathf.Abs(tc.x - hook.x) <= step)
                    {
                        hook.x = tc.x;
                        swingV -= side * 2.5f;   // sudden stop sets the chair swinging
                        Next(LOWER);
                    }
                    else hook.x += Gd.Sign(tc.x - hook.x) * step;
                    break;
                }
                case LOWER:
                    hook.y = Gd.Lerp(TravelY(), HangY(), Gd.SmoothStep(0f, 1f, t / 0.9f));
                    if (t >= 0.9f) Next(HOVER);
                    break;
                case HOVER:
                    hook.y = HangY() + Mathf.Sin(t * 9f) * 1.5f;
                    if (t >= Tuning.CRANE_HOVER)
                    {
                        Next(DROP);
                        chairV = 60f;
                        Sfx.Play("pop", 0.6f, -4f);   // clunk of the release
                    }
                    break;
                case DROP:
                    chairV += 1400f * delta;
                    chairY += chairV * delta;
                    hook.y -= 120f * delta;
                    if (hook.y + 28f + chairY >= LandTop())
                    {
                        carrying = false;
                        game.LandChair(target);
                        Next(LEAVE);
                    }
                    break;
                case LEAVE:
                    hook.y -= 260f * delta;
                    hook.x += side * 120f * delta;
                    if (hook.y < -420f) { done = true; }
                    break;
            }
        }

        public void Draw(Painter p)
        {
            float T = arena.T;
            bool horror = ModeTheme.Horror;
            Color metal = horror ? new Color(0.32f, 0.27f, 0.27f) : new Color(0.48f, 0.44f, 0.47f);
            Color dark = horror ? new Color(0.12f, 0.08f, 0.08f) : new Color(0.25f, 0.2f, 0.2f);
            p.SetBase(Xf.Translate(arena.Position));
            p.ResetTransform();
            // target marker on the floor while it dangles (the drop warning)
            if (phase == LOWER || phase == HOVER || (phase == DROP && carrying))
            {
                Vector2 c = arena.CellCenter(target);
                float pulse = 0.5f + 0.5f * Mathf.Sin(age * 10f);
                Color col = horror ? new Color(0.75f, 0.1f, 0.12f) : UiStyle.ROSE_DARK;
                p.SetTransform(c + new Vector2(0, 8), 0f, new Vector2(1f, 0.45f));
                p.Circle(Vector2.zero, T * 0.44f, new Color(col.r, col.g, col.b, 0.14f + 0.12f * pulse));
                p.Arc(Vector2.zero, T * 0.44f, 0f, Gd.TAU, 28, new Color(col.r, col.g, col.b, 0.6f + 0.4f * pulse), 2.4f);
                p.Arc(Vector2.zero, T * 0.24f, 0f, Gd.TAU, 20, new Color(col.r, col.g, col.b, 0.5f + 0.4f * pulse), 1.6f);
                p.ResetTransform();
            }
            // cable from the top of the screen
            Vector2 top = new Vector2(hook.x, -80f);
            p.Line(top, hook + new Vector2(0, -8), dark, 3f);
            if (horror)
                for (int k = 0; k < 3; k++)
                {
                    float y = Gd.Lerp(top.y, hook.y, 0.3f + k * 0.25f);
                    p.Circle(new Vector2(hook.x + 2, y + (age * 30f + k * 20f) % 14f), 1.6f, new Color(0.5f, 0.03f, 0.07f, 0.8f));
                }
            // hook block + claw
            p.Rect(new Rect(hook + new Vector2(-8, -14), new Vector2(16, 12)), metal);
            p.Rect(new Rect(hook + new Vector2(-8, -14), new Vector2(16, 12)), dark, false, 1.5f);
            Vector2 claw = hook + new Vector2(0, -2);
            p.Arc(claw + new Vector2(0, 10), 9f, -Gd.PI * 0.1f, Gd.PI * 1.15f, 14, metal, 3.5f);
            // the chair hanging from (or falling off) the hook
            if (carrying)
            {
                float w = T * 1.02f;
                Vector2 anchor = hook + new Vector2(0, 14 + chairY);
                p.SetTransform(anchor, swing * 0.35f, Vector2.one);
                if (phase != DROP)
                {
                    p.Line(Vector2.zero, new Vector2(-w * 0.3f, 18), dark, 1.6f);   // straps
                    p.Line(Vector2.zero, new Vector2(w * 0.3f, 18), dark, 1.6f);
                }
                p.TextureRect(Assets.Get("objects/chair"), new Rect(-w * 0.5f, 14, w, w));
                p.ResetTransform();
            }
            p.SetBase(Xf.Identity);
        }
    }
}
