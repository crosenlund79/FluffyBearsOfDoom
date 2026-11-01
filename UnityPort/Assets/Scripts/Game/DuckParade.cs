// The Doom Duck Parade (port of duck_parade.gd): a portal opens in a permanent
// wall, a wind-up mother duck and three ducklings march the corridors, the
// clockwork speeds up, and the mother bursts into confetti that flows around corners.
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public class DuckParade
    {
        static readonly Vector2Int[] DIRS = { new Vector2Int(1, 0), new Vector2Int(-1, 0), new Vector2Int(0, 1), new Vector2Int(0, -1) };
        const float OPEN_TIME = 0.9f, PORTAL_LINGER = 4f;
        const int DUCKLINGS = 3;

        Game game;
        Arena arena;
        Vector2Int wall;
        float t;
        bool marching;
        public float countdown = Tuning.DUCK_TIME;
        Vector2 motherPos;
        Vector2Int curCell;
        public Vector2Int nextCell;
        Vector2Int heading = new Vector2Int(0, 1);
        readonly List<Vector2> trail = new List<Vector2>();
        float phase, tickT, quackT = 1f, warnT;
        readonly List<float[]> pendingT = new List<float[]>();   // [time, pitch]
        readonly Rng rng = new Rng();
        public bool done;

        public void Setup(Game g, Vector2Int wallCell)
        {
            game = g; arena = g.arena; wall = wallCell;
            motherPos = PortalPos();
            trail.Add(motherPos);
            curCell = wall;
            nextCell = wall + new Vector2Int(0, 1);
            Sfx.Play("portal");
        }

        /// The visible (front) face of the wall block.
        Vector2 PortalPos() => arena.CellCenter(wall) + new Vector2(0, arena.T * 0.3f);
        /// True once the ducks are out and the countdown is running.
        public bool Armed => marching;
        float Urgency => Gd.Clamp(1f - countdown / Tuning.DUCK_TIME, 0f, 1f);
        public Vector2Int MotherCell => arena.WorldToCell(motherPos);

        public void PhysicsUpdate(float delta)
        {
            if (done) return;
            t += delta;
            if (!marching)
            {
                if (t >= OPEN_TIME) marching = true;
                return;
            }
            countdown -= delta;
            float u = Urgency;
            March(delta, u);
            Sounds(delta, u);
            if (countdown <= 0f)
            {
                done = true;
                game.DuckExplode(this);
            }
        }

        void March(float delta, float u)
        {
            float speed = Tuning.DUCK_SPEED * (1f + 0.35f * u);
            phase += delta * (9f + 10f * u);
            Vector2 target = arena.CellCenter(nextCell);
            Vector2 to = target - motherPos;
            float step = speed * delta;
            if (to.magnitude <= step) { motherPos = target; curCell = nextCell; ChooseNext(); }
            else motherPos += to.normalized * step;
            if (trail.Count == 0 || Vector2.Distance(motherPos, trail[trail.Count - 1]) > 1.5f)
            {
                trail.Add(motherPos);
                int maxLen = (int)(Tuning.DUCKLING_SPACING * (DUCKLINGS + 2) / 1.5f) + 10;
                if (trail.Count > maxLen) trail.RemoveAt(0);
            }
        }

        void ChooseNext()
        {
            var options = new List<Vector2Int>();
            foreach (var d in DIRS)
            {
                if (d == -heading) continue;
                Vector2Int n = curCell + d;
                if (!arena.IsSolid(n) && !arena.bombs.ContainsKey(n)) options.Add(d);
            }
            if (options.Count == 0)
            {
                Vector2Int back = curCell - heading;
                if (!arena.IsSolid(back) && !arena.bombs.ContainsKey(back)) options.Add(-heading);
            }
            if (options.Count == 0) { nextCell = curCell; return; } // boxed in: march on the spot
            Vector2Int dd = options[rng.Int(options.Count)];
            if (options.Contains(heading) && rng.F() < 0.45f) dd = heading;
            heading = dd;
            nextCell = curCell + dd;
        }

        void Sounds(float delta, float u)
        {
            tickT -= delta;
            if (tickT <= 0f)
            {
                tickT = Gd.Lerp(0.42f, 0.07f, Mathf.Pow(u, 1.3f));
                Sfx.Play("clock_tick", 1f + u * 0.4f + rng.Range(-0.05f, 0.05f), -9f);
            }
            quackT -= delta;
            if (quackT <= 0f)
            {
                quackT = Gd.Lerp(1.9f, 0.38f, u);
                Sfx.Play("quack", rng.Range(0.92f, 1.05f) + u * 0.25f, -2f);
                for (int i = 0; i < DUCKLINGS; i++) // the little ones answer
                    pendingT.Add(new[] { 0.16f + i * 0.11f, rng.Range(1f, 1.2f) + u * 0.3f });
            }
            if (countdown < Tuning.DUCK_WARNING)
            {
                warnT -= delta;
                if (warnT <= 0f)
                {
                    warnT = Gd.Lerp(0.4f, 0.12f, 1f - countdown / Tuning.DUCK_WARNING);
                    Sfx.Play("duck_warning", 1f + (1f - countdown / Tuning.DUCK_WARNING) * 0.5f, -6f);
                }
            }
            for (int i = pendingT.Count - 1; i >= 0; i--)
            {
                pendingT[i][0] -= delta;
                if (pendingT[i][0] <= 0f) { Sfx.Play("duckling_quack", pendingT[i][1], -5f); pendingT.RemoveAt(i); }
            }
        }

        /// Position and travel direction `dist` px back along the mother's path.
        bool BackAlong(float dist, out Vector2 pos, out Vector2 dir)
        {
            float remaining = dist;
            Vector2 pp = motherPos;
            for (int i = trail.Count - 1; i >= 0; i--)
            {
                Vector2 q = trail[i];
                float seg = Vector2.Distance(pp, q);
                if (seg >= remaining && seg > 0f)
                {
                    pos = Vector2.LerpUnclamped(pp, q, remaining / seg);
                    dir = (pp - q).normalized;
                    return true;
                }
                remaining -= seg;
                pp = q;
            }
            pos = pp; dir = new Vector2(0, 1);
            return false; // still inside the portal
        }

        // ---- drawing ----
        public void Draw(Painter p)
        {
            Tex fx = Assets.Get("effects/effects");
            float T = arena.T;
            float u = Urgency;
            p.SetBase(Xf.Translate(arena.Position));
            p.ResetTransform();
            // portal swirl on the wall's front face
            float open = Gd.Clamp(t / 0.5f, 0f, 1f) * (1f - Gd.Clamp((t - OPEN_TIME - PORTAL_LINGER) / 0.6f, 0f, 1f));
            if (open > 0f)
            {
                Vector2 pc = PortalPos() + new Vector2(0, -2);
                Color[] cols = { Gd.Hex("c9b2e3"), Gd.Hex("f2a7b5"), Gd.Hex("a8dcc0"), Gd.Hex("a7c8e8") };
                p.SetTransform(pc, 0f, new Vector2(1f, 0.7f) * open);
                p.Circle(Vector2.zero, T * 0.42f, new Color(0.35f, 0.25f, 0.45f, 0.85f));
                for (int k = 0; k < 4; k++)
                {
                    float r = T * (0.38f - k * 0.08f);
                    float a0 = t * (3f + k) * (k % 2 == 0 ? 1 : -1);
                    p.Arc(Vector2.zero, r, a0, a0 + Gd.TAU * 0.7f, 18, cols[k], 3f);
                }
                p.ResetTransform();
                Tex sp = fx.Region(Assets.EFFECT_CELLS, 5);
                for (int k = 0; k < 3; k++)
                {
                    float a = t * 2f + k * Gd.TAU / 3f;
                    Vector2 pp = pc + new Vector2(Mathf.Cos(a) * T * 0.5f, Mathf.Sin(a) * T * 0.3f);
                    p.TextureRect(sp, new Rect(pp - new Vector2(5, 5), new Vector2(10, 10)), new Color(1, 1, 1, open));
                }
            }
            if (!marching) return;
            // imminent detonation: show exactly where the confetti will flow
            bool warn = countdown < Tuning.DUCK_WARNING;
            if (warn)
            {
                float pulse = 0.5f + 0.5f * Mathf.Sin(t * (10f + 14f * u));
                foreach (var c in game.DuckBlastCells(MotherCell, Tuning.DUCK_BLAST_RANGE))
                {
                    Rect r = Arena.Grow(new Rect(new Vector2(c.x, c.y) * T, new Vector2(T, T)), -3);
                    p.Rect(r, new Color(0.95f, 0.55f, 0.62f, 0.12f + 0.18f * pulse));
                    UiStyle.StitchRect(p, Arena.Grow(r, -2), new Color(0.75f, 0.3f, 0.4f, 0.4f + 0.5f * pulse), 1.6f, 4f);
                }
            }
            // ducklings from the back, then the mother on top
            for (int i = DUCKLINGS; i >= 1; i--)
                if (BackAlong(i * Tuning.DUCKLING_SPACING, out Vector2 dpos, out Vector2 ddir))
                    DrawDuck(p, dpos, ddir, 0.62f, phase - i * 1.3f, u, false);
            DrawDuck(p, motherPos, new Vector2(heading.x, heading.y), 1f, phase, u, warn);
        }

        void DrawDuck(Painter p, Vector2 pos, Vector2 dir, float sc, float ph, float u, bool warn)
        {
            Tex tex = Assets.Get("objects/duck");
            float T = arena.T;
            float size = T * 1.15f * sc;
            if (warn) size *= 1f + 0.08f * Mathf.Abs(Mathf.Sin(t * 18f));
            float flip = dir.x < -0.1f ? -1f : 1f;
            float bob = Mathf.Abs(Mathf.Sin(ph)) * 3f * sc;
            float wobble = Mathf.Sin(ph * 0.5f) * (0.08f + 0.25f * u * u) + (warn ? Mathf.Sin(t * 47f + sc) * 0.12f * u : 0f);
            p.SetTransform(pos + new Vector2(0, T * 0.3f), 0f, new Vector2(1f, 0.3f));
            p.Circle(Vector2.zero, size * 0.4f, new Color(0.3f, 0.2f, 0.15f, 0.2f));
            Vector2 bse = pos + new Vector2(0, T * 0.32f - bob);
            // spinning wind-up key on the back
            float keySpin = Mathf.Cos(t * (6f + 22f * u));
            p.SetTransform(bse + Gd.Rotated(new Vector2(-size * 0.28f * flip, -size * 0.62f), wobble * flip), wobble * flip, new Vector2(flip * 0.55f * keySpin, 0.55f));
            p.TextureRect(tex.Region(2, 1), new Rect(-size * 0.5f, -size * 0.5f, size, size));
            p.SetTransform(bse, wobble * flip, new Vector2(flip, 1f));
            Color col = Settings.mode == "horror" ? new Color(0.78f, 0.7f, 0.68f) : Color.white;
            if (warn && (t * (4f + 10f * u)) % 1f < 0.5f) col = new Color(1f, 0.68f, 0.7f);
            p.TextureRect(tex.Region(2, 0), new Rect(-size * 0.5f, -size, size, size), col);
            p.ResetTransform();
            if (warn)
            {
                Vector2 b = pos + new Vector2(0, -size * 0.95f - 6f);
                p.Circle(b, 9f, Gd.Hex("fbf5e8"));
                p.Arc(b, 9f, 0f, Gd.TAU, 16, new Color(0.75f, 0.3f, 0.4f), 2f);
                p.String(b + new Vector2(-8, 6), "!", HAlign.Center, 16, 16, new Color(0.75f, 0.3f, 0.4f));
            }
        }
    }
}
