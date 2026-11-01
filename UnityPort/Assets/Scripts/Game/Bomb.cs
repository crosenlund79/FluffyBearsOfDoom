// A stitched fabric toy bomb on a grid cell (port of bomb.gd). Every bomb can
// be kicked; rubber bombs bounce off obstacles; remote bombs wait for their
// owner's detonator. A ring in the owner's colour shows whose bomb it is.
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public class Bomb
    {
        public Game game;
        public Arena arena;
        public Bear owner;
        public Vector2Int cell;
        public int blastRange = 2;
        public float fuse = Tuning.BOMB_FUSE;
        public bool exploded, rubber, remote;
        public readonly List<Bear> passThrough = new List<Bear>();
        public Vector2Int moveDir;
        public Vector2 position;
        int bounces;
        Color tint = Color.white;
        float t, squash, squashV;
        int lastTick = 3;
        readonly Rng rng = new Rng();

        public void Setup(Game g, Bear bear, Vector2Int c, int r)
        {
            game = g; arena = g.arena; owner = bear; cell = c; blastRange = r;
            rubber = bear.hasRubber;
            remote = bear.hasRemote;
            if (remote) fuse = Tuning.REMOTE_BACKUP_FUSE;
            position = arena.CellCenter(c);
            tint = ModeTheme.BombTint(bear.color, rubber); // pastel version of the owner's colour
        }

        public bool IsMoving => moveDir != Vector2Int.zero;

        public void Kick(Vector2Int dir)
        {
            if (IsMoving || exploded) return;
            if (!Free(cell + dir)) return;
            moveDir = dir;
            bounces = 0;
            squashV -= 8f;
            Sfx.Play("kick", rng.Range(0.9f, 1.1f));
        }

        public void PhysicsUpdate(float delta)
        {
            t += delta;
            fuse -= delta;
            float sq = 2f * Mathf.Sqrt(300f) * 0.18f;
            squashV += (-300f * squash - sq * squashV) * delta;
            squash += squashV * delta;
            if (IsMoving) Slide(delta);
            for (int i = passThrough.Count - 1; i >= 0; i--)
                if (!passThrough[i].OverlapsCell(cell)) passThrough.RemoveAt(i);
            int tick = Mathf.CeilToInt(fuse / 0.33f);
            if (fuse < 1f && tick != lastTick)
            {
                lastTick = tick;
                Sfx.Play("fuse", 1f + (1f - fuse) * 0.5f, -10f);
            }
            if (fuse <= 0f && !exploded) game.Explode(this);
        }

        bool Free(Vector2Int c)
        {
            if (arena.IsSolid(c) || arena.bombs.ContainsKey(c)) return false;
            foreach (var b in game.bears)
                if (b.Cell == c && !passThrough.Contains(b)) return false;
            return true;
        }

        void Slide(float delta)
        {
            float step = Tuning.KICK_SPEED * delta;
            Vector2 dirv = new Vector2(moveDir.x, moveDir.y);
            Vector2 center = arena.CellCenter(cell);
            float ahead = Vector2.Dot(center - position, dirv);
            if (ahead > step) { position += dirv * step; return; }
            // at the centre of a cell: carry on, bounce or stop
            if (Free(cell + moveDir))
            {
                position += dirv * step;
                Vector2Int nc = arena.WorldToCell(position);
                if (nc != cell)
                {
                    arena.bombs.Remove(cell);
                    cell = nc;
                    arena.bombs[cell] = this;
                    foreach (var b in game.bears)
                        if (b.OverlapsCell(cell) && !passThrough.Contains(b)) passThrough.Add(b);
                }
                return;
            }
            position = center;
            if (rubber && bounces < Tuning.RUBBER_MAX_BOUNCES && Free(cell - moveDir))
            {
                moveDir = -moveDir;
                bounces++;
                squashV += 14f;
                Sfx.Play("boing", rng.Range(1.1f, 1.4f), -6f);
            }
            else
            {
                moveDir = Vector2Int.zero;
                squashV += 6f;
            }
        }

        public void Draw(Painter p)
        {
            Tex tex = Assets.Get("objects/bomb");
            Tex fx = Assets.Get("effects/effects");
            float T = arena.T;
            p.SetBase(Xf.Translate(arena.Position + position));
            float urgency = Gd.Clamp(1f - fuse / Tuning.BOMB_FUSE, 0f, 1f);
            // ticking: a pulse and little hops that get faster
            float rate = 6f + urgency * urgency * 26f;
            float pulse = Mathf.Sin(t * rate) * (0.04f + 0.07f * urgency);
            float hop = Mathf.Max(0f, Mathf.Sin(t * rate * 0.5f)) * (1f + 4f * urgency);
            float pop = 1f + 0.35f * Mathf.Exp(-t * 9f) * Mathf.Sin(t * 30f);
            float fin = fuse < 0.35f ? (0.35f - fuse) / 0.35f : 0f; // last-moment swell
            float s = T * 0.92f * pop * (1f + fin * 0.25f);
            float sx = 1f + pulse + squash * 0.5f, sy = 1f - pulse - squash * 0.5f;
            if (IsMoving)
            {
                bool horiz = moveDir.x != 0;
                sx *= horiz ? 1.12f : 0.9f;
                sy *= horiz ? 0.9f : 1.12f;
            }
            p.SetTransform(new Vector2(0, T * 0.32f), 0f, new Vector2(1f, 0.35f));
            p.Circle(Vector2.zero, s * 0.4f, new Color(0.15f, 0.1f, 0.08f, 0.38f));
            // owner ring on the floor
            Color own = owner.color;
            p.Arc(Vector2.zero, s * 0.5f, 0f, Gd.TAU, 28, new Color(own.r, own.g, own.b, 0.95f), 4f);
            p.Arc(Vector2.zero, s * 0.5f, 0f, Gd.TAU, 28, Gd.WithAlpha(Gd.Darkened(own, 0.5f), 0.6f), 1.5f);
            float twitch = Mathf.Sin(t * 47f) * 0.08f * fin;
            p.SetTransform(new Vector2(0, T * 0.3f - hop), twitch + (IsMoving ? Mathf.Sin(t * 12f) * 0.1f : 0f), new Vector2(sx, sy));
            Color col = tint;
            if (fuse < 0.8f && (t * 10f) % 1f < 0.5f) col = Gd.Lerp(tint, new Color(1f, 0.82f, 0.82f), 0.6f);
            var rect = new Rect(-s * 0.5f, -s - 2f, s, s);
            p.TextureRect(tex, rect, col);
            if (rubber)
            {
                // candy stripes mark a rubber bomb
                Vector2 c = rect.center + new Vector2(-s * 0.02f, s * 0.075f);
                foreach (float k in new[] { -0.18f, 0f, 0.18f })
                {
                    float y = c.y + k * s;
                    float hw = Mathf.Sqrt(Mathf.Max(0f, 0.09f - k * k)) * s;
                    p.Line(new Vector2(c.x - hw, y), new Vector2(c.x + hw, y), new Color(1, 1, 1, 0.75f), s * 0.05f);
                }
            }
            if (remote)
            {
                // radio antenna in the owner's colour instead of a burning fuse
                Powerup.DrawRemoteAntenna(p, new Vector2(s * 0.24f, -s * 0.98f), s / 40f, t, Gd.Lightened(owner.color, 0.2f));
                if (fuse > Tuning.BOMB_FUSE) { p.ResetTransform(); return; }
            }
            // brightening stitched fuse spark
            Vector2 spark = new Vector2(s * 0.26f, -s * 1.02f);
            float ss = 8f + urgency * 8f + Mathf.Sin(t * 40f) * 3f;
            Color sparkCol = Gd.Lerp(new Color(1f, 0.95f, 0.8f), new Color(1f, 0.6f, 0.55f), urgency);
            p.TextureRect(fx.Region(Assets.EFFECT_CELLS, 5), new Rect(spark - new Vector2(ss, ss) * 0.5f, new Vector2(ss, ss)), sparkCol);
            p.ResetTransform();
        }
    }
}
