// The procedural teddy bear rig (port of bear_visual.gd).
//
// Built from one shared sprite sheet (body, belly, head, ear, arm, leg and four
// faces), tinted per bear. Walking, waddling, belly jiggle, growth, deflation,
// stun flops, squash/stretch and taunts are all springs and sine waves that
// scale continuously with fluff - identical constants to the Godot version.
// The Godot Sprite2D hierarchy is reproduced as explicit transforms:
//   rig -> legs, body(-> belly, wrinkles), arms, head(-> ears behind, face)
using UnityEngine;

namespace FBD
{
    /// What the rig needs to know about its bear (a real Bear or a menu Puppet).
    public interface IBearSource
    {
        Vector2 Velocity { get; }
        float Fluff { get; }
        Vector2 Facing { get; }
        bool IsStunned { get; }
        bool Stealing { get; }
        Vector2 StealDir { get; }   // zero when not stealing
        float RobbedT { get; }
        float ImmuneT { get; }
        bool OnBouncy { get; }
        bool Smug { get; }
    }

    /// Stand-in data source for menus and the results screen.
    public class Puppet : IBearSource
    {
        public Vector2 velocity; public float fluff = 100f; public Vector2 facing = Vector2.up * -1f;
        public float stunT; public bool smug;
        public Puppet() { facing = new Vector2(0, 1); }
        public Vector2 Velocity => velocity;
        public float Fluff => fluff;
        public Vector2 Facing => facing;
        public bool IsStunned => stunT > 0f;
        public bool Stealing => false;
        public Vector2 StealDir => Vector2.zero;
        public float RobbedT => 0f;
        public float ImmuneT => 0f;
        public bool OnBouncy => false;
        public bool Smug => smug;
    }

    public class BearVisual
    {
        const int FACE_NORMAL = 0, FACE_SMUG = 1, FACE_INDIGNANT = 2, FACE_STUNNED = 3;
        public const float PART_SCALE = 0.36f;
        const float BASE_CELL = 128f;
        const float TAUNT_TIME = 1.1f;

        struct Part { public Vector2 pos; public float rot; public Vector2 scale; public Vector2 offset; public Color col; }

        public IBearSource source;
        public Color tint = Color.white;
        public float seedOffset;
        readonly Rng rng = new Rng();

        float cw = 128f, unit = PART_SCALE;
        Part body, belly, head, face;
        readonly Part[] legs = new Part[2], arms = new Part[2], ears = new Part[2];
        bool faceVisible = true;
        float wrinkles;

        // springs
        Vector2 bodyOff, bodyV, bellyOff, bellyV;
        float squash, squashV, lean, leanV, flop, flopV, flopDir = 1f, earWob, earWobV;

        public float g = 1f, phase, t, hop;
        Vector2 lastVel;
        int faceIdx = FACE_NORMAL;
        public float shadowW = 20f, headTop = -50f, headR = 18f;
        public Vector2 rigPos;     // rig position relative to the bear
        public float rigRot;
        public float alpha = 1f;
        // taunts / horror twitch
        string tauntKind = "";
        float tauntT, twitchT = 3f, twitch;
        bool horror;

        public BearVisual(IBearSource src, Color col, float seed)
        {
            source = src; tint = col; seedOffset = seed;
            horror = Settings.mode == "horror";
            // the cell width only scales parts; textures may be any resolution
            cw = BASE_CELL;
            unit = PART_SCALE * BASE_CELL / cw;
            g = TargetG();
            for (int i = 0; i < 2; i++)
            {
                legs[i] = new Part { offset = new Vector2(0, -0.12f * cw), col = tint, scale = Vector2.one * unit };
                arms[i] = new Part { offset = new Vector2(0, 0.2f * cw), col = tint, scale = Vector2.one * unit };
                ears[i] = new Part { offset = new Vector2(0, -0.06f * cw), col = tint, scale = Vector2.one };
            }
            body = new Part { col = tint, scale = Vector2.one * unit };
            belly = new Part { col = Gd.Lerp(tint, Color.white, 0.72f), scale = Vector2.one };
            head = new Part { col = tint, scale = Vector2.one * unit };
            face = new Part { col = Color.white, scale = Vector2.one };
        }

        float TargetG() => source == null ? 1f : Gd.Clamp(source.Fluff / Tuning.START_FLUFF, 0f, 6f);

        // ---- reactions ----
        /// Wall bump. axis 0 = horizontal impact, 1 = vertical.
        public void Bump(int axis, float impact, float dir)
        {
            float k = Gd.Clamp(impact / 220f, 0.2f, 1.6f);
            if (axis == 0) { squashV -= 7f * k; bodyV.x += dir * impact * 0.35f; bellyV.x += dir * impact * 0.6f; }
            else { squashV += 7f * k; bodyV.y += dir * impact * 0.3f; bellyV.y += dir * impact * 0.5f; }
            earWobV += dir * 12f * k;
        }
        public void Kick(float amount) { squashV += amount * 10f; bellyV.y += amount * 120f; }
        public void OnStunned(float fromDir)
        {
            flopDir = fromDir != 0f ? fromDir : (rng.F() < 0.5f ? 1f : -1f);
            flopV += flopDir * 6f;
            squashV += 9f;
            earWobV += 20f * flopDir;
        }
        public void PlayTaunt(string kind) { tauntKind = kind; tauntT = TAUNT_TIME; squashV += 4f; }
        public void OnRecover() { squashV -= 8f; flopV -= flopDir * 3f; }

        static Vector2 Spring(float x, float v, float target, float k, float zeta, float dt)
        {
            float c = 2f * Mathf.Sqrt(k) * zeta;
            v += (k * (target - x) - c * v) * dt;
            x += v * dt;
            return new Vector2(x, v);
        }

        public void Update(float delta)
        {
            if (source == null) return;
            delta = Mathf.Min(delta, 0.05f);
            t += delta;
            Vector2 vel = source.Velocity;
            g = Gd.Lerp(g, TargetG(), 1f - Mathf.Exp(-delta * 5f));
            Vector2 acc = Gd.LimitLength((vel - lastVel) / Mathf.Max(delta, 0.001f), 5000f);
            lastVel = vel;
            float speed = vel.magnitude;
            float soft = 0.6f + 0.4f * g;
            float sag = Gd.Clamp((0.6f - g) / 0.6f, 0f, 1f);
            bool stunned = source.IsStunned;

            // Body lags behind acceleration (delayed mass), less damping when stuffed.
            float kb = 160f / soft;
            float zb = Gd.Clamp(0.55f / (0.6f + 0.35f * g), 0.12f, 0.8f);
            float cb = 2f * Mathf.Sqrt(kb) * zb;
            bodyV += (-kb * bodyOff - cb * bodyV - acc * 0.010f * soft) * delta;
            bodyOff += bodyV * delta;
            bodyOff = Gd.LimitLength(bodyOff, 8f + 4f * g);

            // Belly: a softer secondary spring riding on the body.
            float kl = 110f / soft;
            float zl = Gd.Clamp(0.32f / (0.6f + 0.4f * g), 0.07f, 0.6f);
            float cl = 2f * Mathf.Sqrt(kl) * zl;
            bellyV += (-kl * bellyOff - cl * bellyV - acc * 0.008f * soft - bodyV * 0.5f) * delta;
            bellyOff += bellyV * delta;
            bellyOff = Gd.LimitLength(bellyOff, 6f + 5f * g);

            var sq = Spring(squash, squashV, 0f, 260f / soft, Gd.Clamp(0.3f / (0.6f + 0.4f * g), 0.07f, 0.5f), delta);
            squash = Gd.Clamp(sq.x, -0.4f, 0.4f);
            squashV = sq.y;

            // Delayed leaning into motion and away from braking.
            float leanTarget = Gd.Clamp(vel.x / 300f, -1f, 1f) * (0.1f + 0.04f * g) - Gd.Clamp(acc.x / 3000f, -1f, 1f) * 0.14f * soft;
            if (stunned) leanTarget = 0f;
            var ln = Spring(lean, leanV, leanTarget, 70f / soft, Gd.Clamp(0.45f / (0.6f + 0.4f * g), 0.1f, 0.7f), delta);
            lean = ln.x; leanV = ln.y;

            var ew = Spring(earWob, earWobV, -bodyV.x * 0.01f, 120f, 0.18f, delta);
            earWob = Gd.Clamp(ew.x, -0.9f, 0.9f);
            earWobV = ew.y;

            // Stun flop: falls over with an overshooting wobble, pops back up after.
            var fl = Spring(flop, flopV, stunned ? flopDir * 1.45f : 0f, 90f, 0.22f, delta);
            flop = fl.x; flopV = fl.y;

            // Walk cycle: heavier bears take frantic tiny steps.
            float moving = Gd.Clamp(speed / 60f, 0f, 1f);
            if (stunned) moving = 0f;
            float stride = 18f / (0.5f + 0.5f * Mathf.Pow(Mathf.Max(g, 0.2f), 1.3f));
            float prevPhase = phase;
            phase += speed * delta / stride * (stunned ? 0f : 1f);
            if (Mathf.FloorToInt(phase / Gd.PI) != Mathf.FloorToInt(prevPhase / Gd.PI) && moving > 0.3f) OnStep(moving);
            float bob = -Mathf.Abs(Mathf.Sin(phase)) * (1.2f + 1.3f * g) * moving;
            float sway = Mathf.Sin(phase) * (0.035f + 0.045f * g) * moving;
            float idle = 1f - moving;
            float breathe = Mathf.Sin(t * 2.4f + seedOffset) * 0.025f * (0.5f + 0.5f * g) * idle;
            sway += Mathf.Sin(t * 1.7f + seedOffset) * 0.012f * Mathf.Max(g - 0.8f, 0f) * idle;

            // Bouncy floors make bears boing.
            if (source.OnBouncy && !stunned)
            {
                float targetHop = Mathf.Abs(Mathf.Sin(t * 7f + seedOffset)) * Mathf.Max(10f - 1.5f * g, 4f);
                hop = Gd.Lerp(hop, targetHop, 1f - Mathf.Exp(-delta * 18f));
            }
            else hop = Gd.Lerp(hop, 0f, 1f - Mathf.Exp(-delta * 10f));

            // --- proportions, all continuous in g ---
            float gb = Mathf.Max(g, 0f);
            float bsx = 0.62f + 0.38f * Mathf.Pow(gb, 0.9f);
            float bsy = (0.68f + 0.32f * Mathf.Pow(gb, 0.75f)) * (1f - 0.22f * sag);
            bsx = Gd.Lerp(bsx, 0.8f, sag * 0.6f); // an empty bear flattens like a pillowcase
            float s = squash + breathe;
            if (stunned) s += 0.08f + 0.05f * Mathf.Min(g, 4f); // a big bear collapses into a heap
            float sx = bsx * (1f + s), sy = bsy * (1f - s);
            body.scale = new Vector2(sx, sy) * unit;
            float bodyHw = 46f * PART_SCALE * sx;
            float bodyHh = 50f * PART_SCALE * sy;
            const float legH = 7f;
            float bodyY = -legH - bodyHh * 0.9f + bob;
            body.pos = new Vector2(bodyOff.x * 0.6f, bodyY + bodyOff.y * 0.4f);
            body.rot = sway * 0.5f;
            body.col = Gd.Lerp(tint, new Color(0.72f, 0.7f, 0.68f), 0.3f * sag);

            // Belly grows faster than the body and jiggles on its own spring.
            float brel = Gd.Clamp(0.55f + 0.17f * g, 0.42f, 0.98f);
            float jig = Gd.Clamp(bellyOff.y * 0.012f, -0.2f, 0.2f);
            belly.scale = new Vector2(brel * (1f + jig) * (1f - 0.15f * sag), brel * (1f - jig));
            belly.pos = new Vector2(bellyOff.x * 1.6f, 10f + 4f * Mathf.Min(g, 4f) + bellyOff.y * 1.4f) / Mathf.Max(bsx, 0.3f);
            wrinkles = sag;

            // Head sits on the body, grows a little, lags a little more.
            float hs = 0.9f + 0.12f * Mathf.Sqrt(gb);
            head.scale = new Vector2(hs * (1f + s * 0.3f), hs * (1f - s * 0.3f)) * unit;
            headR = 50f * PART_SCALE * hs;
            head.pos = new Vector2(bodyOff.x * 1.1f + Mathf.Sin(phase) * 1.2f * moving, bodyY - bodyHh * 0.82f - headR * 0.55f + bodyOff.y * 0.7f + bob * 0.3f);
            head.rot = sway * 0.7f + sag * Mathf.Sin(t * 1.3f) * 0.08f - lean * 0.25f;
            headTop = head.pos.y - headR;
            for (int i = 0; i < 2; i++)
            {
                float side = i == 0 ? -1f : 1f;
                ears[i].pos = new Vector2(side * 36f, -38f + sag * 10f);
                ears[i].rot = side * (0.12f + sag * 0.75f) + earWob * (1f + 0.4f * i) + Mathf.Sin(phase * 2f) * 0.06f * moving;
            }

            // Arms stick out further on a round bear and swing with the waddle.
            Vector2 stealDir = source.Stealing ? source.StealDir : Vector2.zero;
            for (int i = 0; i < 2; i++)
            {
                float side = i == 0 ? -1f : 1f;
                arms[i].pos = new Vector2(side * bodyHw * 0.9f + bodyOff.x * 0.8f, bodyY - bodyHh * 0.25f + bodyOff.y * 0.5f);
                float spread = 0.25f + 0.2f * Mathf.Min(g, 4f) - sag * 0.25f;
                float swing = Mathf.Sin(phase + Gd.PI * i) * 0.5f * moving;
                float rot = -side * spread + swing;
                if (stealDir != Vector2.zero) rot = Gd.Angle(stealDir) - Gd.PI * 0.5f + Mathf.Sin(t * 16f + i * 1.7f) * 0.35f; // grabby paws
                else if (stunned) rot = -side * (1.2f + Mathf.Sin(t * 3f + i) * 0.1f);
                arms[i].rot = rot;
                arms[i].scale = Vector2.one * unit * (0.85f + 0.1f * Mathf.Min(g, 4f));
            }

            // Taunt reactions: purely visual, layered on top of the normal animation.
            float tauntRot = 0f;
            Vector2 tauntOff = Vector2.zero;
            if (tauntT > 0f && !stunned)
            {
                tauntT -= delta;
                float k = 1f - tauntT / TAUNT_TIME;
                float env = Mathf.Sin(Gd.Clamp01(k) * Gd.PI);
                switch (tauntKind)
                {
                    case "wiggle":
                        body.rot += Mathf.Sin(t * 30f) * 0.3f * env;
                        bellyV.x += Mathf.Sin(t * 30f) * 40f * env * delta * 60f;
                        break;
                    case "spin": tauntRot = Gd.TAU * (k * k * (3f - 2f * k)); break;
                    case "hop": tauntOff.y = -Mathf.Sin(k * Gd.PI) * 16f; break;
                    case "cheer":
                        for (int i = 0; i < 2; i++) { float side = i == 0 ? -1f : 1f; arms[i].rot = side * (2.7f + Mathf.Sin(t * 22f + i) * 0.35f); }
                        break;
                    case "tilt": head.rot += 1.15f * env; break;
                    case "twitch":
                        head.rot += ((t * 9f) % 1f < 0.5f ? 0.7f : -0.5f) * env;
                        tauntOff.x = ((t * 13f) % 1f < 0.5f ? 1.5f : -1.5f) * env;
                        break;
                    case "lean":
                        tauntRot = 0.4f * env * (seedOffset > 2f ? 1f : -1f);
                        head.rot -= 0.5f * env;
                        break;
                    case "shudder":
                        tauntOff.x = rng.Range(-2.5f, 2.5f) * env;
                        body.rot += rng.Range(-0.1f, 0.1f) * env;
                        break;
                }
            }
            if (horror && !stunned)
            {
                // every so often the head snaps sideways, holds... and snaps back
                twitchT -= delta;
                if (twitchT <= 0f) { twitchT = rng.Range(3f, 8f); twitch = 0.35f; }
                if (twitch > 0f) { twitch -= delta; head.rot += 0.55f * (seedOffset % 2f < 1f ? 1f : -1f); }
            }

            // Tiny legs that barely grow at all.
            for (int i = 0; i < 2; i++)
            {
                float side = i == 0 ? -1f : 1f;
                float lift = Mathf.Max(0f, Mathf.Sin(phase + Gd.PI * i)) * 3.5f * moving;
                legs[i].pos = new Vector2(side * (5.5f + 1.8f * Mathf.Min(g, 4f)) + bodyOff.x * 0.15f, -lift + 1f);
                legs[i].rot = Mathf.Sin(phase + Gd.PI * i) * 0.35f * moving + (stunned ? side * 0.6f : 0f);
                legs[i].scale = Vector2.one * unit * (0.82f + 0.05f * Mathf.Min(g, 3f));
            }

            // Expression
            int f = FACE_NORMAL;
            if (stunned) f = FACE_STUNNED;
            else if (source.Stealing || source.Smug) f = FACE_SMUG;
            else if (source.RobbedT > 0f) f = FACE_INDIGNANT;
            faceIdx = f;
            Vector2 facing = source.Facing;
            faceVisible = stunned || facing.y >= 0f || Mathf.Abs(facing.x) > 0f;
            face.pos = new Vector2(facing.x * 11f, Mathf.Max(facing.y, 0f) * 4f);

            // Whole rig: lean + stun flop, pivoting at the feet. Hop on bouncy floors.
            rigRot = lean + flop + tauntRot;
            rigPos = new Vector2(-flop * 10f, 14f - hop) + tauntOff;
            shadowW = bodyHw * 1.15f + 4f;
            alpha = 1f;
            if (source.ImmuneT > 0f && !stunned) alpha = (t * 12f) % 1f < 0.5f ? 0.55f : 1f;
        }

        void OnStep(float moving)
        {
            squashV += 0.6f * moving * (0.3f + 0.3f * g);
            bellyV.y += 22f * g * moving;
            earWobV += (rng.F() - 0.5f) * 2f * moving;
        }

        // ---- drawing ----
        /// The rig's transform for a bear standing at `bearXf`.
        public Xf RigXf(Xf bearXf) => bearXf * Xf.TRS(rigPos, rigRot, Vector2.one);

        /// Head centre in bear-local coordinates (for stars/bubbles above it).
        public Vector2 HeadLocal() => Xf.TRS(rigPos, rigRot, Vector2.one).Apply(head.pos);

        Xf DrawPart(Painter p, Xf parent, Part part, Tex cell, float a)
        {
            Xf x = parent * Xf.TRS(part.pos, part.rot, part.scale);
            p.SetBase(x);
            p.ResetTransform();
            float w = cw, h = cw;
            p.TextureRect(cell, new Rect(-w * 0.5f + part.offset.x, -h * 0.5f + part.offset.y, w, h), Gd.WithAlpha(part.col, part.col.a * a));
            return x;
        }

        public void Draw(Painter p, Xf bearXf, float extraAlpha = 1f)
        {
            Tex sheet = Assets.Get("bears/bear");
            float a = alpha * extraAlpha;
            Xf rig = RigXf(bearXf);
            for (int i = 0; i < 2; i++) DrawPart(p, rig, legs[i], sheet.Region(Assets.BEAR_CELLS, 5), a);
            Xf bodyX = DrawPart(p, rig, body, sheet.Region(Assets.BEAR_CELLS, 0), a);
            DrawPart(p, bodyX, belly, sheet.Region(Assets.BEAR_CELLS, 1), a);
            if (wrinkles >= 0.05f)
            {
                p.SetBase(bodyX);
                p.ResetTransform();
                Color wc = Gd.Darkened(tint, 0.6f);
                var c = new Color(wc.r, wc.g, wc.b, 0.45f * wrinkles * a);
                for (int i = 0; i < 4; i++)
                {
                    float y = -26f + i * 15f, x = Mathf.Sin(i * 1.9f) * 12f;
                    p.Arc(new Vector2(x, y), 13f, Gd.PI * 0.15f, Gd.PI * 0.85f, 8, c, 3f);
                }
                p.Arc(new Vector2(-22, 10), 10f, -Gd.PI * 0.2f, Gd.PI * 0.4f, 6, c, 3f);
                p.Arc(new Vector2(22, 10), 10f, Gd.PI * 0.6f, Gd.PI * 1.2f, 6, c, 3f);
            }
            for (int i = 0; i < 2; i++) DrawPart(p, rig, arms[i], sheet.Region(Assets.BEAR_CELLS, 4), a);
            Xf headX = rig * Xf.TRS(head.pos, head.rot, head.scale);
            for (int i = 0; i < 2; i++) DrawPart(p, headX, ears[i], sheet.Region(Assets.BEAR_CELLS, 3), a); // behind the head
            DrawPart(p, rig, head, sheet.Region(Assets.BEAR_CELLS, 2), a);
            if (faceVisible) DrawPart(p, headX, face, sheet.Region(Assets.BEAR_CELLS, 6 + faceIdx), a);
            p.SetBase(Xf.Identity);
            p.ResetTransform();
        }
    }
}
