// A teddy bear (port of bear.gd): grid-corridor movement with fluff-dependent
// inertia, bombs, stuns, stuffing theft, curses and taunts. Humans and AI drive
// it through the same inputs (InputDir, WantBomb, WantSteal, WantSpecial), so
// both get identical physics - and identical curses.
using UnityEngine;

namespace FBD
{
    public interface IController { void Update(float delta); }

    public class Bear : IBearSource
    {
        public int slot;
        public string bearName = "";
        public Color color = Color.white;
        public bool isHuman;
        public string ctrlLabel = "";
        public Game game;
        public Arena arena;
        public IController controller;

        public float fluff = Tuning.START_FLUFF;
        public Vector2 position, velocity, facing = new Vector2(0, 1);

        // Controller inputs
        public Vector2 inputDir;
        public bool wantBomb, wantSteal, wantSpecial;

        // Power-ups
        public int bombsMax = Tuning.START_BOMBS, bombRange = Tuning.START_RANGE, speedLevel, activeBombs;
        public bool canKick, hasLine, hasRubber;

        // State
        public float stunT, immuneT, robbedT;
        public bool stealing;
        public Bear stealTarget;
        public bool onBouncy;
        public int terrainId;

        // Timed effects
        public float immortalT, reverseT, diarrheaT, infectCd, reinfectImmune;
        float diarrheaCd;

        // Taunts (purely cosmetic)
        public Bear lastHitBy;
        public bool lastHitBySet;
        public string bubbleText = "";
        public float bubbleT, tauntCd;
        public int tauntCount;
        public float fluffAtStun;
        readonly Rng rng = new Rng();

        // Stats for the results screen
        public float stolenTotal;
        public int timesStunned;

        public BearVisual visual;
        float stealSfxT;

        // ---- IBearSource ----
        public Vector2 Velocity => velocity;
        public float Fluff => fluff;
        public Vector2 Facing => facing;
        public bool IsStunned => stunT > 0f;
        public bool Stealing => stealing;
        public Vector2 StealDir => stealTarget != null ? (stealTarget.position - (position + visual.rigPos)).normalized : Vector2.zero;
        public float RobbedT => robbedT;
        public float ImmuneT => immuneT;
        public bool OnBouncy => onBouncy;
        public bool Smug => false;

        public void Setup(Game g, int s, string n, Color col, Vector2Int spawn)
        {
            game = g; arena = g.arena; slot = s; bearName = n; color = col;
            position = arena.CellCenter(spawn);
            visual = new BearVisual(this, col, s * 1.7f);
        }

        // ---- fluff-dependent physical properties ----
        public float FluffRatio => fluff / Tuning.START_FLUFF;
        public float Mass => Tuning.MASS_MIN + Tuning.MASS_PER_RATIO * FluffRatio;
        public float MaxSpeed => Tuning.BASE_SPEED * Gd.Clamp(1f + Tuning.SPEED_MASS_FALLOFF * (1f - Mass), 0.55f, 1.18f) + speedLevel * Tuning.SPEED_UP_SPEED;
        public float Accel => Mathf.Min(Tuning.BASE_ACCEL / Mathf.Pow(Mass, Tuning.ACCEL_EXP) * (1f + speedLevel * Tuning.SPEED_UP_ACCEL), 4500f);
        public float Brake => Mathf.Min(Tuning.BASE_BRAKE / Mathf.Pow(Mass, Tuning.BRAKE_EXP), 6000f);
        public Vector2Int Cell => arena.WorldToCell(position);
        public bool CanAct => !IsStunned && game.ControlsEnabled;
        public bool CanPlaceBomb => activeBombs < bombsMax && !arena.bombs.ContainsKey(Cell);

        public bool OverlapsCell(Vector2Int c)
        {
            float h = Tuning.HITBOX_HALF;
            var r = new Rect(position - new Vector2(h, h), new Vector2(h, h) * 2f);
            var cr = new Rect(new Vector2(c.x, c.y) * arena.T, new Vector2(arena.T, arena.T));
            return r.Overlaps(cr);
        }

        // ---- per physics frame ----
        public void PhysicsUpdate(float delta)
        {
            if (controller != null && CanAct) controller.Update(delta);
            else { inputDir = Vector2.zero; wantBomb = false; wantSteal = false; wantSpecial = false; }
            if (stunT > 0f)
            {
                stunT -= delta;
                if (stunT <= 0f) Recover();
            }
            immuneT = Mathf.Max(0f, immuneT - delta);
            robbedT = Mathf.Max(0f, robbedT - delta);
            immortalT = Mathf.Max(0f, immortalT - delta);
            bubbleT = Mathf.Max(0f, bubbleT - delta);
            tauntCd = Mathf.Max(0f, tauntCd - delta);
            infectCd = Mathf.Max(0f, infectCd - delta);
            reinfectImmune = Mathf.Max(0f, reinfectImmune - delta);
            if (reverseT > 0f)
            {
                reverseT -= delta;
                if (reverseT <= 0f) { reverseT = 0f; reinfectImmune = Tuning.REVERSE_REINFECT_IMMUNE; }
            }
            diarrheaT = Mathf.Max(0f, diarrheaT - delta);
            diarrheaCd -= delta;
            if (diarrheaT > 0f && game.ControlsEnabled && !IsStunned && diarrheaCd <= 0f && CanPlaceBomb)
            {
                diarrheaCd = Tuning.DIARRHEA_INTERVAL;
                wantBomb = true; // out it comes, whether you like it or not
            }
            if (wantSpecial)
            {
                wantSpecial = false;
                if (hasLine && game.ControlsEnabled && !IsStunned) game.PlaceLine(this);
            }
            if (wantBomb) { wantBomb = false; game.TryPlaceBomb(this); }
            UpdateSteal(delta);
            Move(delta);
        }

        void UpdateSteal(float delta)
        {
            if (wantSteal && CanAct && inputDir == Vector2.zero)
            {
                Bear target = game.FindStealTarget(this);
                if (target != null)
                {
                    if (!stealing) { Sfx.Play("squeak", 1.4f, -4f); game.OnStealStarted(this, target); }
                    stealing = true;
                    stealTarget = target;
                    float amount = Mathf.Min(Tuning.STEAL_RATE * delta, target.fluff);
                    target.fluff -= amount;
                    fluff += amount;
                    stolenTotal += amount;
                    target.robbedT = Tuning.ROBBED_GRUMPY;
                    Vector2 d = target.position - position;
                    facing = Mathf.Abs(d.x) > Mathf.Abs(d.y) ? new Vector2(Gd.Sign(d.x), 0) : new Vector2(0, Gd.Sign(d.y));
                    stealSfxT -= delta;
                    if (stealSfxT <= 0f)
                    {
                        stealSfxT = 0.12f;
                        Sfx.Play("steal", rng.Range(0.9f, 1.4f) / Mathf.Sqrt(Mathf.Max(FluffRatio, 0.3f)), -8f);
                    }
                    return;
                }
            }
            stealing = false;
            stealTarget = null;
        }

        void Move(float delta)
        {
            terrainId = arena.TerrainAt(Cell);
            var tp = Terrain.Props(terrainId);
            onBouncy = terrainId == Terrain.BOUNCY;
            float ms = MaxSpeed * tp.speed, ac = Accel * tp.accel, br = Brake * tp.brake;
            Vector2 dir = (CanAct && !stealing) ? inputDir : Vector2.zero;
            if (reverseT > 0f) dir = -dir; // the curse: left is right, up is down
            if (dir == Vector2.zero)
            {
                velocity.x = Gd.MoveToward(velocity.x, 0f, br * delta);
                velocity.y = Gd.MoveToward(velocity.y, 0f, br * delta);
            }
            else
            {
                facing = dir;
                float lane = LaneOffset(dir);
                float laneV = Gd.Clamp(lane * Tuning.LANE_PULL, -ms, ms);
                if (dir.x != 0f)
                {
                    velocity.x = Drive(velocity.x, dir.x * ms, ac, br, delta);
                    velocity.y = Align(velocity.y, laneV, ac * Tuning.ALIGN_ACCEL, br * Tuning.ALIGN_ACCEL, delta);
                }
                else
                {
                    velocity.y = Drive(velocity.y, dir.y * ms, ac, br, delta);
                    velocity.x = Align(velocity.x, laneV, ac * Tuning.ALIGN_ACCEL, br * Tuning.ALIGN_ACCEL, delta);
                }
            }
            Vector2 motion = (velocity + tp.push) * delta;
            float restitution = tp.bounce + 0.06f * Mathf.Min(FluffRatio, 4f);
            if (Sweep(0, motion.x)) OnWall(0, restitution);
            if (Sweep(1, motion.y)) OnWall(1, restitution);
        }

        /// Accelerate along the pressed axis; reversing uses brake + accel.
        static float Drive(float v, float target, float ac, float br, float dt)
        {
            if (v != 0f && Gd.Sign(v) != Gd.Sign(target)) return Gd.MoveToward(v, target, (ac + br) * dt);
            if (Mathf.Abs(v) > Mathf.Abs(target)) return Gd.MoveToward(v, target, br * dt);
            return Gd.MoveToward(v, target, ac * dt);
        }

        /// The perpendicular axis: steer into the lane, but momentum only bleeds off
        /// through braking - this is what makes heavy bears overshoot intersections.
        static float Align(float v, float target, float ac, float br, float dt)
        {
            if (Mathf.Abs(v) > Mathf.Abs(target) || (v != 0f && Gd.Sign(v) != Gd.Sign(target))) return Gd.MoveToward(v, target, br * dt);
            return Gd.MoveToward(v, target, ac * dt);
        }

        /// Offset (along the perpendicular axis) to the lane centre that leads in `dir`.
        float LaneOffset(Vector2 dir)
        {
            Vector2Int c = Cell;
            Vector2 ctr = arena.CellCenter(c);
            if (dir.x != 0f)
            {
                float off = position.y - ctr.y;
                int n = Mathf.Abs(off) > 2f ? 2 : 1;
                for (int k = 0; k < n; k++)
                {
                    int r = k == 0 ? c.y : c.y + (off > 0f ? 1 : -1);
                    if (!arena.BlocksBear(new Vector2Int(c.x, r), this) && !arena.BlocksBear(new Vector2Int(c.x + (int)dir.x, r), this))
                        return arena.CellCenter(new Vector2Int(c.x, r)).y - position.y;
                }
                return ctr.y - position.y;
            }
            float offx = position.x - ctr.x;
            int nx = Mathf.Abs(offx) > 2f ? 2 : 1;
            for (int k = 0; k < nx; k++)
            {
                int q = k == 0 ? c.x : c.x + (offx > 0f ? 1 : -1);
                if (!arena.BlocksBear(new Vector2Int(q, c.y), this) && !arena.BlocksBear(new Vector2Int(q, c.y + (int)dir.y), this))
                    return arena.CellCenter(new Vector2Int(q, c.y)).x - position.x;
            }
            return ctr.x - position.x;
        }

        /// Moves along one axis; clamps against solid cells. Returns true on contact.
        bool Sweep(int axis, float amount)
        {
            if (amount == 0f) return false;
            float h = Tuning.HITBOX_HALF, T = arena.T;
            Vector2 pos = position;
            pos[axis] += amount;
            Vector2Int minc = arena.WorldToCell(pos - new Vector2(h, h));
            Vector2Int maxc = arena.WorldToCell(pos + new Vector2(h, h) - new Vector2(0.001f, 0.001f));
            bool hit = false;
            Bomb kicked = null;
            for (int cx = minc.x; cx <= maxc.x; cx++)
                for (int cy = minc.y; cy <= maxc.y; cy++)
                {
                    var c = new Vector2Int(cx, cy);
                    if (!arena.BlocksBear(c, this)) continue;
                    hit = true;
                    if (canKick && arena.bombs.TryGetValue(c, out Bomb bb)) kicked = bb;
                    if (axis == 0)
                    {
                        if (amount > 0f) pos.x = Mathf.Min(pos.x, cx * T - h - 0.001f);
                        else pos.x = Mathf.Max(pos.x, (cx + 1) * T + h + 0.001f);
                    }
                    else
                    {
                        if (amount > 0f) pos.y = Mathf.Min(pos.y, cy * T - h - 0.001f);
                        else pos.y = Mathf.Max(pos.y, (cy + 1) * T + h + 0.001f);
                    }
                }
            position = pos;
            if (kicked != null && !(IsStunned || stealing))
            {
                // only kick a bomb we're roughly lined up with
                int perp = 1 - axis;
                if (Mathf.Abs(position[perp] - kicked.position[perp]) < 14f)
                {
                    var d = Vector2Int.zero;
                    d[axis] = amount > 0f ? 1 : -1;
                    kicked.Kick(d);
                }
            }
            return hit;
        }

        void OnWall(int axis, float restitution)
        {
            float impact = Mathf.Abs(velocity[axis]);
            float dir = Gd.Sign(velocity[axis]);
            velocity[axis] = -velocity[axis] * restitution;
            if (impact > Tuning.BUMP_MIN_SPEED)
            {
                visual.Bump(axis, impact, dir);
                float pitch = 1.25f / Mathf.Sqrt(Mathf.Max(FluffRatio, 0.35f));
                if (onBouncy) Sfx.Play("boing", pitch * rng.Range(0.9f, 1.1f), -6f);
                else Sfx.Play(impact > 140f ? "squeak" : "bump", pitch * rng.Range(0.9f, 1.1f), 20f * Mathf.Log10(Gd.Clamp(impact / 220f, 0.2f, 1f)) - 6f);
                if (impact > 150f)
                    game.SpawnDust(position + new Vector2(axis == 0 ? dir * Tuning.HITBOX_HALF : 0f, axis == 1 ? dir * Tuning.HITBOX_HALF : 0f), 2);
            }
        }

        // ---- events ----
        public void Stun(Vector2 fromPos)
        {
            if (IsStunned || immuneT > 0f || immortalT > 0f) return;
            stunT = Tuning.STUN_TIME;
            timesStunned++;
            fluffAtStun = fluff;
            stealing = false;
            stealTarget = null;
            Vector2 away = position - fromPos;
            if (away.magnitude > 1f) velocity += away.normalized * 90f;
            visual.OnStunned(Mathf.Abs(away.x) > 1f ? Gd.Sign(away.x) : 0f);
            Sfx.Play("concussion", rng.Range(0.95f, 1.08f) / Mathf.Pow(Mathf.Max(FluffRatio, 0.35f), 0.25f));
            game.OnBearStunned(this);
        }

        void Recover()
        {
            stunT = 0f;
            immuneT = Tuning.STUN_IMMUNE;
            visual.OnRecover();
            if (fluffAtStun - fluff > 10f) Taunt("robbed", true); // wakes up noticeably lighter
            Sfx.Play("pop", 1.3f);
        }

        /// A cheeky (or creepy) line with a reaction animation and voice.
        /// Cosmetic only: never affects movement. Rate-limited so it can't clutter.
        public void Taunt(string kind, bool force = false)
        {
            if (!game.ControlsEnabled && kind != "robbed") return;
            if (!force && (tauntCd > 0f || game.BubbleCount() >= 2)) return;
            bubbleText = Taunts.Line(kind, bearName, rng);
            bubbleT = 1.7f;
            tauntCd = 4f;
            tauntCount++;
            visual.PlayTaunt(Taunts.Anim(rng));
            float voice = Taunts.VOICE.TryGetValue(bearName, out float v) ? v : 1f;
            float pitch = voice * rng.Range(0.93f, 1.07f) / Mathf.Pow(Mathf.Max(FluffRatio, 0.4f), 0.2f);
            Sfx.Play("taunt", pitch, -3f);
        }

        public void AddFluff(float amount) { fluff += amount; visual.Kick(0.12f); }

        // ---- drawing ----
        public Xf WorldXf => Xf.Translate(arena.Position + position);

        public void Draw(Painter p)
        {
            Xf bx = WorldXf;
            // Soft plush shadow, independent of the rig's flopping and hopping.
            float w = visual.shadowW * (1f - visual.hop * 0.02f);
            p.SetBase(bx);
            p.SetTransform(new Vector2(0, 15), 0f, new Vector2(1f, 0.38f));
            p.Circle(Vector2.zero, w, new Color(0.3f, 0.2f, 0.15f, 0.2f));
            p.Circle(Vector2.zero, w * 0.7f, new Color(0.3f, 0.2f, 0.15f, 0.1f));
            p.ResetTransform();
            visual.Draw(p, bx);
            DrawOverlay(p, bx);
        }

        const float BUBBLE = 1.7f;

        /// Cartoon birds and stars, curse icons, immortality halo, player marker, bubble.
        void DrawOverlay(Painter p, Xf bx)
        {
            Tex fx = Assets.Get("effects/effects");
            Tex icons = Assets.Get("powerups/powerups");
            p.SetBase(bx);
            p.ResetTransform();
            Vector2 head = visual.HeadLocal();
            Vector2 above = head + new Vector2(0, -visual.headR - 10f);
            float t = visual.t;
            if (bubbleT > 0f) DrawBubble(p, above + new Vector2(0, IsStunned ? -30f : -24f));
            if (immortalT > 0f)
            {
                float a = 0.25f + 0.15f * Mathf.Sin(t * 6f);
                if (immortalT < 3f && (t * 6f) % 1f < 0.5f) a *= 0.3f;
                p.SetTransform(new Vector2(0, -visual.headR), 0f, new Vector2(1f, 1.15f));
                p.Circle(Vector2.zero, visual.shadowW + 14f, new Color(1f, 0.9f, 0.55f, a));
                p.SetTransform(above + new Vector2(0, 4), 0f, new Vector2(1f, 0.3f));
                p.Arc(Vector2.zero, 12f, 0f, Gd.TAU, 20, new Color(0.95f, 0.78f, 0.35f, 0.95f), 3f);
                p.ResetTransform();
            }
            if (IsStunned)
            {
                // old-cartoon concussion: birds and stars circling above the head
                Tex star = fx.Region(Assets.EFFECT_CELLS, 3), bird = fx.Region(Assets.EFFECT_CELLS, 6);
                float rx = 16f + visual.headR * 0.4f;
                for (int i = 0; i < 4; i++)
                {
                    float a = t * 3.5f + i * Gd.TAU / 4f;
                    Vector2 pp = above + new Vector2(Mathf.Cos(a) * rx, Mathf.Sin(a) * 6f);
                    bool front = Mathf.Sin(a) > 0f;
                    float sz = front ? 15f : 12f;
                    if (i % 2 == 0)
                    {
                        float flap = 0.75f + 0.25f * Mathf.Sin(t * 30f + i);
                        float d = Mathf.Sin(a) > 0f ? -1f : 1f; // flies the way it orbits
                        p.SetTransform(pp, 0f, new Vector2(d, flap));
                        p.TextureRect(bird, new Rect(-new Vector2(sz, sz) * 0.6f, new Vector2(sz, sz) * 1.2f));
                    }
                    else
                    {
                        p.SetTransform(pp, t * 4f, Vector2.one);
                        p.TextureRect(star, new Rect(-new Vector2(sz, sz) * 0.5f, new Vector2(sz, sz)));
                    }
                }
                p.ResetTransform();
                return;
            }
            float x = (reverseT > 0f && diarrheaT > 0f) ? -10f : 0f;
            float[] curseT = { reverseT, diarrheaT };
            int[] curseCell = { 8, 9 };
            for (int k = 0; k < 2; k++)
            {
                if (curseT[k] <= 0f) continue;
                Vector2 pp = above + new Vector2(x, -8f + Mathf.Sin(t * 5f + x) * 2f);
                p.SetTransform(pp, Mathf.Sin(t * 7f + x) * 0.25f, Vector2.one);
                p.TextureRect(icons.Region(Assets.POWERUP_CELLS, curseCell[k]), new Rect(-10, -10, 20, 20));
                x += 20f;
            }
            p.ResetTransform();
            if (isHuman && bubbleT <= 0f)
            {
                float y = above.y - (x != 0f ? 22f : 2f);
                Color c = Gd.WithAlpha(Gd.Darkened(color, 0.3f), 0.95f);
                p.Polygon(new[] { new Vector2(above.x - 6, y - 8), new Vector2(above.x + 6, y - 8), new Vector2(above.x, y) }, c);
                if (bearName.StartsWith("Player "))
                    p.String(new Vector2(above.x - 20, y - 11), "P" + bearName.Substring(7), HAlign.Center, 40, 13, c);
            }
        }

        /// A small, short-lived speech bubble that never blocks much of the arena.
        void DrawBubble(Painter p, Vector2 anchor)
        {
            float life = bubbleT;
            float pop = Gd.Clamp((BUBBLE - life) / 0.15f, 0f, 1f);
            float fade = Gd.Clamp(life / 0.3f, 0f, 1f);
            Color[] cols = ModeTheme.BubbleColors;
            const int fs = 12;
            float w = p.TextWidth(bubbleText, fs) + 12f;
            const float h = 18f;
            float sc = 0.6f + 0.4f * pop;
            Vector2 jitter = ModeTheme.Horror ? new Vector2(rng.Range(-0.6f, 0.6f), rng.Range(-0.6f, 0.6f)) : Vector2.zero;
            p.SetTransform(anchor + jitter, 0f, new Vector2(sc, sc));
            var r = new Rect(-w * 0.5f, -h, w, h);
            Color bg = cols[0], fg = cols[1], ol = cols[2];
            p.Rect(r, new Color(bg.r, bg.g, bg.b, bg.a * fade));
            p.Rect(r, new Color(ol.r, ol.g, ol.b, fade), false, 1.2f);
            p.Polygon(new[] { new Vector2(-4, 0), new Vector2(4, 0), new Vector2(0, 6) }, new Color(ol.r, ol.g, ol.b, fade));
            p.String(new Vector2(-w * 0.5f + 6, -5), bubbleText, HAlign.Left, -1, fs, new Color(fg.r, fg.g, fg.b, fade));
            p.ResetTransform();
        }
    }
}
