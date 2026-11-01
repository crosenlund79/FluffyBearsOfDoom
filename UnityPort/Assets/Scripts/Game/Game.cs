// One match (port of game.gd): arena, four bears, bombs, blasts, power-ups,
// theft, curses, Biome Shuffle, the Doom Duck Parade, timer and results.
// Pure game logic + drawing; the App MonoBehaviour drives it (FixedUpdate =
// physics step at 60 Hz, Update = visual process, LateUpdate = draw).
using System;
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public class Game
    {
        public enum State { COUNTDOWN, PLAYING, ENDED }
        public static readonly Vector2 ARENA_ORIGIN = new Vector2(40, 52);
        static readonly Vector2Int[] DIRS = { new Vector2Int(1, 0), new Vector2Int(-1, 0), new Vector2Int(0, 1), new Vector2Int(0, -1) };

        public State state = State.COUNTDOWN;
        public float timeLeft = 150f;
        float countdown = 3f;
        int lastCount = 4;
        public readonly Rng rng = new Rng();
        public bool paused;

        public Arena arena;
        public readonly List<Bear> bears = new List<Bear>();
        public readonly List<Bomb> bombs = new List<Bomb>();
        public readonly Dictionary<Vector2Int, float> flames = new Dictionary<Vector2Int, float>();
        readonly Dictionary<Vector2Int, Bear> flameOwner = new Dictionary<Vector2Int, Bear>();
        public readonly Dictionary<Vector2Int, Powerup> powerups = new Dictionary<Vector2Int, Powerup>();
        readonly List<FluffPickup> pickups = new List<FluffPickup>();
        readonly List<Entity> decals = new List<Entity>();
        readonly List<Entity> floorItems = new List<Entity>();   // power-ups + fluff tufts (Godot powerup_layer)
        readonly List<Entity> blasts = new List<Entity>();
        readonly List<Entity> fx = new List<Entity>();
        readonly List<ShuffleEvent> shuffleEvents = new List<ShuffleEvent>();
        public DuckParade parade;
        public float duckTimer;
        float stealFxT, flicker;
        Color worldTint = Color.white;
        Texture2D vignette;

        public IHud hud = new NullHud();
        public event Action QuitToMenu, RestartRequested;

        class ShuffleEvent
        {
            public float t; public Dictionary<Vector2Int, int> cells; public Dictionary<Vector2Int, int> set; public bool revert, warned;
        }

        public void Setup()
        {
            timeLeft = Tuning.ROUND_TIMES[Settings.round_time_index];
            arena = new Arena { origin = ARENA_ORIGIN };
            arena.Setup(ArenaMaps.MAPS[Settings.arena_index], rng, Powerup.WEIGHTS);
            duckTimer = rng.Range(Tuning.DUCK_FIRST_DELAY[0], Tuning.DUCK_FIRST_DELAY[1]);
            var roster = Settings.Roster();
            for (int i = 0; i < roster.Count; i++)
            {
                var r = roster[i];
                var b = new Bear();
                b.Setup(this, i, r.name, ModeTheme.BearColor(r.color), Arena.SPAWNS[i]);
                if (r.controller == "human")
                {
                    b.isHuman = true;
                    b.controller = new HumanController(b, r.schemes);
                    b.ctrlLabel = Settings.human_count == 1 ? "you" : (r.schemes[0] == "p1" ? "WASD" : "Arrows");
                }
                else
                {
                    int lvl = Array.IndexOf(Settings.LEVELS, r.controller);
                    b.controller = new AiController(b, this, lvl);
                    b.ctrlLabel = Settings.LEVEL_LABELS[lvl] + " AI";
                }
                bears.Add(b);
            }
            Music.PlayContext("gameplay");
            worldTint = ModeTheme.WorldModulate;
            hud.Banner("3", 1f);
            Sfx.Play("tick");
        }

        public bool ControlsEnabled => state == State.PLAYING;

        // ---- per physics step (Godot _physics_process order: game, bombs, duck, bears) ----
        public void PhysicsStep(float delta)
        {
            if (paused) return;
            switch (state)
            {
                case State.COUNTDOWN:
                    countdown -= delta;
                    int n = Mathf.CeilToInt(countdown);
                    if (n != lastCount && n > 0) { lastCount = n; hud.Banner(n.ToString(), 1f); Sfx.Play("tick"); }
                    if (countdown <= 0f) { state = State.PLAYING; hud.Banner("Steal the stuffing!", 1.4f); Sfx.Play("go"); }
                    break;
                case State.PLAYING:
                    timeLeft -= delta;
                    UpdateDucks(delta);
                    if (timeLeft <= 0f) { timeLeft = 0f; EndMatch(); }
                    break;
            }
            UpdateFlames(delta);
            UpdatePickups();
            UpdateShuffles(delta);
            UpdateStealFx(delta);
            UpdateContagion();
            foreach (var b in bombs.ToArray()) if (!b.exploded) b.PhysicsUpdate(delta);
            if (parade != null) { parade.PhysicsUpdate(delta); if (parade != null && parade.done) parade = null; }
            foreach (var b in bears) b.PhysicsUpdate(delta);
        }

        // ---- per rendered frame (visual animation, Godot _process) ----
        public void Process(float delta)
        {
            if (paused) return;
            arena.Process(delta);
            foreach (var b in bears) b.visual.Update(delta);
            ProcessList(decals, delta);
            ProcessList(floorItems, delta);
            ProcessList(blasts, delta);
            ProcessList(fx, delta);
            if (ModeTheme.Horror)
            {
                // the nursery lamp flickers now and then
                flicker -= delta;
                if (flicker <= 0f && rng.F() < delta * 0.35f) flicker = rng.Range(0.05f, 0.18f);
                Color w = ModeTheme.WorldModulate;
                float k = flicker > 0f ? 0.6f : 1f;
                worldTint = new Color(w.r * k, w.g * k, w.b * k, 1f);
            }
        }

        static void ProcessList(List<Entity> list, float delta)
        {
            for (int i = 0; i < list.Count; i++) list[i].Process(delta);
            list.RemoveAll(e => e.dead);
        }

        // ---- bombs and blasts ----
        public void TryPlaceBomb(Bear bear)
        {
            if (!bear.CanPlaceBomb) return;
            Vector2Int c = bear.Cell;
            if (arena.IsSolid(c)) return;
            SpawnBomb(bear, c);
            Sfx.Play("place", rng.Range(0.8f, 1f));
        }

        /// Cells a Line Bomb from `bear` would fill (its facing direction).
        public List<Vector2Int> LineCells(Bear bear)
        {
            var o = new List<Vector2Int>();
            Vector2Int c = bear.Cell;
            var d = new Vector2Int((int)bear.facing.x, (int)bear.facing.y);
            int freeBombs = bear.bombsMax - bear.activeBombs;
            if (!arena.bombs.ContainsKey(c) && !arena.IsSolid(c)) o.Add(c);
            while (o.Count < freeBombs && d != Vector2Int.zero)
            {
                c += d;
                if (!arena.IsWalkable(c)) break;
                bool occupied = false;
                foreach (var b in bears) if (b != bear && b.Cell == c) occupied = true;
                if (occupied) break;
                o.Add(c);
            }
            return o;
        }

        public void PlaceLine(Bear bear)
        {
            var cells = LineCells(bear);
            foreach (var c in cells) SpawnBomb(bear, c);
            if (cells.Count > 0) { Sfx.Play("place", 0.8f); Sfx.Play("place", 1.1f, -4f); }
        }

        void SpawnBomb(Bear bear, Vector2Int c)
        {
            var b = new Bomb();
            b.Setup(this, bear, c, bear.bombRange);
            foreach (var other in bears) if (other.OverlapsCell(c)) b.passThrough.Add(other);
            bombs.Add(b);
            arena.bombs[c] = b;
            bear.activeBombs++;
        }

        /// Cells a blast from `origin` would cover (stops at walls, includes the first block).
        public List<Vector2Int> BlastCells(Vector2Int origin, int length)
        {
            var o = new List<Vector2Int> { origin };
            foreach (var d in DIRS)
                for (int i = 1; i <= length; i++)
                {
                    Vector2Int c = origin + d * i;
                    int t = arena.CellType(c);
                    if (t == Arena.WALL || t == Arena.BORDER) break;
                    o.Add(c);
                    if (t == Arena.BLOCK || arena.bombs.ContainsKey(c)) break;
                }
            return o;
        }

        public void Explode(Bomb bomb)
        {
            if (bomb.exploded) return;
            bomb.exploded = true;
            bombs.Remove(bomb);
            arena.bombs.Remove(bomb.cell);
            bomb.owner.activeBombs = Mathf.Max(0, bomb.owner.activeBombs - 1);
            Vector2Int origin = bomb.cell;
            var segs = new List<Segment> { new Segment { pos = arena.CellCenter(origin), kind = 0, rot = 0f } };
            var hit = new List<Vector2Int> { origin };
            var chain = new List<Bomb>();
            var broken = new List<Vector2Int>();
            foreach (var d in DIRS)
            {
                float rot = Gd.Angle(new Vector2(d.x, d.y));
                for (int i = 1; i <= bomb.blastRange; i++)
                {
                    Vector2Int c = origin + d * i;
                    int t = arena.CellType(c);
                    if (t == Arena.WALL || t == Arena.BORDER)
                    {
                        if (i > 1) { var s = segs[segs.Count - 1]; s.kind = 2; segs[segs.Count - 1] = s; }
                        break;
                    }
                    hit.Add(c);
                    bool last = i == bomb.blastRange || t == Arena.BLOCK || arena.bombs.ContainsKey(c);
                    segs.Add(new Segment { pos = arena.CellCenter(c), kind = last ? 2 : 1, rot = rot });
                    if (t == Arena.BLOCK) { broken.Add(c); break; }
                    if (arena.bombs.TryGetValue(c, out Bomb other)) { chain.Add(other); break; }
                }
            }
            foreach (var c in hit) { flames[c] = Tuning.FLAME_TIME; flameOwner[c] = bomb.owner; }
            BreakBlocks(broken);
            ApplyBlast(origin, hit, segs, chain, 14);
            arena.AddShake(4f);
            Sfx.Play("confetti", rng.Range(0.85f, 1.15f));
        }

        void BreakBlocks(List<Vector2Int> broken)
        {
            foreach (var c in broken)
            {
                int kind = arena.DestroyBlock(c);
                SpawnDust(arena.CellCenter(c), 4);
                Burst(arena.CellCenter(c), "objects/fluff", 1, 0, 3, 12f, new Color(0.95f, 0.85f, 0.85f));
                if (kind >= 0)
                {
                    var p = new Powerup { kind = kind, cell = c, position = arena.CellCenter(c) };
                    floorItems.Add(p);
                    powerups[c] = p;
                }
            }
        }

        /// Shared by bombs and the duck: confetti visuals, chained bombs, stuns.
        void ApplyBlast(Vector2Int origin, List<Vector2Int> hit, List<Segment> segs, List<Bomb> chain, int confetti)
        {
            blasts.Add(new Explosion { segments = segs.ToArray() });
            Confetti(arena.CellCenter(origin), confetti);
            for (int i = 1; i < hit.Count; i += 2) Confetti(arena.CellCenter(hit[i]), 2);
            foreach (var other in chain) if (!other.exploded) other.fuse = Mathf.Min(other.fuse, 0.06f);
            CheckFlameHits(origin, true);
        }

        void UpdateFlames(float delta)
        {
            if (flames.Count == 0) return;
            foreach (var c in new List<Vector2Int>(flames.Keys))
            {
                flames[c] -= delta;
                if (flames[c] <= 0f) { flames.Remove(c); flameOwner.Remove(c); }
            }
            CheckFlameHits(new Vector2Int(-1, -1), false);
        }

        void CheckFlameHits(Vector2Int origin, bool hasOrigin)
        {
            foreach (var b in bears)
            {
                if (flames.ContainsKey(b.Cell) && !b.IsStunned && b.immuneT <= 0f)
                {
                    Vector2 src = hasOrigin ? arena.CellCenter(origin) : b.position - b.velocity.normalized * 10f;
                    b.lastHitBy = flameOwner.TryGetValue(b.Cell, out Bear owner) ? owner : null;
                    b.Stun(src);
                }
            }
        }

        // ---- Doom Duck Parade ----
        void UpdateDucks(float delta)
        {
            if (!Tuning.DUCK_ENABLED || parade != null) return;
            duckTimer -= delta;
            if (duckTimer <= 0f && timeLeft > Tuning.DUCK_TIME + 4f) StartDuckParade();
        }

        public void StartDuckParade()
        {
            var walls = new List<Vector2Int>();
            for (int y = 0; y < arena.rows; y++)
                for (int x = 0; x < arena.cols; x++)
                {
                    var c = new Vector2Int(x, y);
                    var below = c + new Vector2Int(0, 1);
                    if (arena.CellType(c) == Arena.WALL && arena.CellType(below) == Arena.EMPTY && !arena.bombs.ContainsKey(below)) walls.Add(c);
                }
            if (walls.Count == 0) { duckTimer = 5f; return; }
            parade = new DuckParade();
            parade.Setup(this, walls[rng.Int(walls.Count)]);
            hud.Banner("Doom Duck Parade!", 1.6f);
        }

        /// Flood fill from `origin` along walkable cells, up to `reach` steps. Turns
        /// corners; permanent walls block it; cushion blocks stop it (and break).
        public List<Vector2Int> DuckBlastCells(Vector2Int origin, int reach)
        {
            var dist = new Dictionary<Vector2Int, int> { { origin, 0 } };
            var o = new List<Vector2Int> { origin };
            var queue = new Queue<Vector2Int>();
            queue.Enqueue(origin);
            while (queue.Count > 0)
            {
                Vector2Int c = queue.Dequeue();
                if (dist[c] >= reach) continue;
                foreach (var d in DIRS)
                {
                    Vector2Int n = c + d;
                    if (dist.ContainsKey(n)) continue;
                    int t = arena.CellType(n);
                    if (t == Arena.WALL || t == Arena.BORDER) continue;
                    dist[n] = dist[c] + 1;
                    o.Add(n);
                    if (t != Arena.BLOCK) queue.Enqueue(n);
                }
            }
            return o;
        }

        public void DuckExplode(DuckParade p)
        {
            Vector2Int origin = p.MotherCell;
            var hit = DuckBlastCells(origin, Tuning.DUCK_BLAST_RANGE);
            var broken = new List<Vector2Int>();
            var chain = new List<Bomb>();
            var segs = new List<Segment>();
            foreach (var c in hit)
            {
                flames[c] = Tuning.FLAME_TIME;
                flameOwner.Remove(c); // nobody to gloat: the duck did it
                if (arena.CellType(c) == Arena.BLOCK) broken.Add(c);
                if (arena.bombs.TryGetValue(c, out Bomb b)) chain.Add(b);
                segs.Add(new Segment { pos = arena.CellCenter(c), kind = 0, rot = rng.F() * Gd.TAU });
            }
            BreakBlocks(broken);
            ApplyBlast(origin, hit, segs, chain, 30);
            foreach (var c in hit) Confetti(arena.CellCenter(c), 2);
            arena.AddShake(8f);
            Sfx.Play("duck_confetti");
            parade = null;
            duckTimer = rng.Range(Tuning.DUCK_INTERVAL[0], Tuning.DUCK_INTERVAL[1]);
        }

        /// Danger map for the AI: cell -> seconds until ablaze (0 = now). level 0 easy .. 2 hard.
        public Dictionary<Vector2Int, float> ComputeDanger(int level)
        {
            bool chain = level == 2;
            var d = new Dictionary<Vector2Int, float>();
            foreach (var c in flames.Keys) d[c] = 0f;
            var times = new Dictionary<Bomb, float>();
            foreach (var b in bombs) times[b] = b.fuse;
            if (chain)
                for (int it = 0; it < 4; it++)
                    foreach (var b in bombs)
                        foreach (var c in BlastCells(b.cell, b.blastRange))
                            if (arena.bombs.TryGetValue(c, out Bomb other) && other != b && times.ContainsKey(other) && times[b] < times[other])
                                times[other] = times[b];
            foreach (var b in bombs)
                foreach (var c in BlastCells(b.cell, b.blastRange))
                    d[c] = Mathf.Min(d.TryGetValue(c, out float v) ? v : 999f, times[b]);
            // The duck: Easy only notices at the very end, Hard plans for its walk.
            if (parade != null && parade.Armed)
            {
                float rem = parade.countdown;
                if (level == 2 || (level == 1 && rem < 6f) || (level == 0 && rem < 2.5f))
                {
                    int reach = Tuning.DUCK_BLAST_RANGE + (level == 2 ? 1 : 0);
                    var origins = new List<Vector2Int> { parade.MotherCell };
                    if (level == 2) origins.Add(parade.nextCell);
                    foreach (var o in origins)
                        foreach (var c in DuckBlastCells(o, reach))
                            d[c] = Mathf.Min(d.TryGetValue(c, out float v) ? v : 999f, rem);
                }
            }
            return d;
        }

        // ---- stuffing ----
        public Bear FindStealTarget(Bear thief)
        {
            Bear best = null;
            float bestD = Tuning.STEAL_RANGE * arena.T;
            foreach (var b in bears)
            {
                if (b == thief || !b.IsStunned || b.fluff <= 0.01f || b.immortalT > 0f) continue;
                float d = Vector2.Distance(thief.position, b.position);
                if (d <= bestD) { bestD = d; best = b; }
            }
            return best;
        }

        public void OnBearStunned(Bear bear)
        {
            Burst(bear.position + new Vector2(0, -20), "effects/effects", Assets.EFFECT_CELLS, 3, 4, 14f, Color.white);
            Splat(bear.position + new Vector2(0, 10), 34f + 10f * Mathf.Min(bear.FluffRatio, 3f));
            if (ModeTheme.Horror) Confetti(bear.position + new Vector2(0, -12), 10); // a spray of red
            Gloat(bear);
            // A little stuffing pops out and lands nearby.
            float amount = Mathf.Min(Tuning.STUN_SPILL, bear.fluff);
            if (amount < 1f) return;
            bear.fluff -= amount;
            Vector2Int c = bear.Cell;
            var options = new List<Vector2Int>();
            foreach (var d in DIRS) if (arena.IsWalkable(c + d)) options.Add(c + d);
            Vector2Int dest = options.Count > 0 ? options[rng.Int(options.Count)] : c;
            var p = new FluffPickup { amount = amount, from = bear.position, to = arena.CellCenter(dest) + new Vector2(rng.Range(-6, 6), rng.Range(-6, 6)), cell = dest };
            p.Init();
            floorItems.Add(p);
            pickups.Add(p);
        }

        /// Floor mark where a bear went down (stuffing / blood). Old ones are recycled.
        void Splat(Vector2 pos, float size)
        {
            decals.Add(new Decal(rng) { position = pos, size = size, color = ModeTheme.SplatColor });
            if (decals.Count > 30) decals.RemoveAt(0);
        }

        // ---- taunts ----
        /// Someone stunned `victim`: the bomber gloats; an own goal gets mocked by a bystander.
        void Gloat(Bear victim)
        {
            Bear attacker = victim.lastHitBy;
            if (attacker != null && attacker != victim) { attacker.Taunt("stun"); return; }
            if (attacker == victim && attacker != null)
            {
                Bear best = null;
                float bestD = 7f * arena.T;
                foreach (var b in bears)
                    if (b != victim && !b.IsStunned && Vector2.Distance(b.position, victim.position) < bestD)
                    {
                        bestD = Vector2.Distance(b.position, victim.position);
                        best = b;
                    }
                best?.Taunt("self_stun");
            }
        }

        public void OnStealStarted(Bear thief, Bear victim)
        {
            if (rng.F() < 0.7f) thief.Taunt(thief.FluffRatio > 2.5f ? "greedy" : "steal");
        }

        public int BubbleCount()
        {
            int n = 0;
            foreach (var b in bears) if (b.bubbleT > 0f) n++;
            return n;
        }

        void UpdatePickups()
        {
            foreach (var b in bears)
            {
                if (b.IsStunned) continue;
                Vector2Int c = b.Cell;
                if (powerups.TryGetValue(c, out Powerup pu))
                {
                    ApplyPowerup(b, pu);
                    pu.dead = true;
                    powerups.Remove(c);
                }
                foreach (var p in pickups.ToArray())
                {
                    if (p.landed && p.cell == c)
                    {
                        b.AddFluff(p.amount);
                        pickups.Remove(p);
                        p.dead = true;
                        Sfx.Play("pickup", 1.3f);
                    }
                }
            }
        }

        void ApplyPowerup(Bear b, Powerup p)
        {
            switch (p.kind)
            {
                case Powerup.BOMB: b.bombsMax = Mathf.Min(b.bombsMax + 1, Tuning.MAX_BOMBS); break;
                case Powerup.FIRE: b.bombRange = Mathf.Min(b.bombRange + 1, Tuning.MAX_RANGE); break;
                case Powerup.SPEED: b.speedLevel = Mathf.Min(b.speedLevel + 1, Tuning.MAX_SPEED_LEVEL); break;
                case Powerup.SHUFFLE: BiomeShuffle(); break;
                case Powerup.KICK: b.canKick = true; break;
                case Powerup.LINE: b.hasLine = true; break;
                case Powerup.RUBBER: b.hasRubber = true; b.canKick = true; break; // rubber bombs need a kick to start bouncing
                case Powerup.IMMORTAL: b.immortalT = Tuning.IMMORTAL_TIME; Sfx.Play("immortal"); break;
                case Powerup.REVERSE: Infect(b); break;
                case Powerup.DIARRHEA: b.diarrheaT = Tuning.DIARRHEA_TIME; break;
            }
            bool bad = Powerup.IsBad(p.kind);
            Sfx.Play(bad ? "curse" : "pickup");
            b.visual.Kick(0.2f);
            Burst(p.position, "effects/effects", Assets.EFFECT_CELLS, 5, 6, 12f, bad ? new Color(0.8f, 0.95f, 0.75f) : new Color(1f, 0.95f, 0.8f));
            if (b.isHuman || bad || p.kind == Powerup.SHUFFLE || p.kind == Powerup.IMMORTAL)
                hud.Toast(b.bearName + ": " + Powerup.NAMES[p.kind], b.color);
        }

        public void Infect(Bear b)
        {
            b.reverseT = Tuning.REVERSE_TIME;
            b.infectCd = Tuning.INFECT_DELAY;
            b.visual.Kick(0.3f);
        }

        /// Reverse Controls is contagious: bumping into a cursed bear passes it on.
        void UpdateContagion()
        {
            if (state != State.PLAYING) return;
            float reach = Tuning.INFECT_DIST * arena.T;
            foreach (var a in bears)
            {
                if (a.reverseT <= 0f || a.infectCd > 0f) continue;
                foreach (var b in bears)
                {
                    if (b == a || b.reverseT > 0f || b.reinfectImmune > 0f) continue;
                    if (Vector2.Distance(a.position, b.position) < reach)
                    {
                        Infect(b);
                        a.infectCd = Tuning.INFECT_DELAY;
                        Sfx.Play("curse", 1.2f);
                        Burst((a.position + b.position) * 0.5f + new Vector2(0, -20), "effects/effects", Assets.EFFECT_CELLS, 5, 5, 10f, new Color(0.75f, 0.9f, 0.65f));
                        hud.Toast(b.bearName + " caught Reverse Controls from " + a.bearName + "!", b.color);
                    }
                }
            }
        }

        void UpdateStealFx(float delta)
        {
            stealFxT -= delta;
            if (stealFxT > 0f) return;
            stealFxT = 0.07f;
            foreach (var b in bears)
            {
                if (!b.stealing || b.stealTarget == null) continue;
                var v = b.stealTarget;
                var p = new Particle
                {
                    sheet = "objects/fluff",
                    start = v.position + new Vector2(rng.Range(-10, 10), -18 + rng.Range(-8, 8)),
                    target = b, life = 0.45f, size = rng.Range(10, 16), spin = rng.Range(-6, 6), arc = rng.Range(14, 34),
                    color = ModeTheme.StuffingColor,
                };
                p.position = p.start;
                fx.Add(p);
            }
        }

        void Confetti(Vector2 pos, int n)
        {
            Color[] pal = ModeTheme.Confetti;
            for (int i = 0; i < n; i++)
            {
                float a = rng.Range(0, Gd.TAU);
                fx.Add(new Particle
                {
                    hasTex = false,
                    position = pos + new Vector2(rng.Range(-8, 8), rng.Range(-8, 8)),
                    vel = new Vector2(Mathf.Cos(a), Mathf.Sin(a) - 0.9f) * rng.Range(60f, 190f),
                    gravity = 200f, drag = 3.5f, life = rng.Range(0.6f, 1.1f), size = rng.Range(5f, 8f), spin = rng.Range(-10, 10),
                    color = pal[rng.Int(pal.Length)],
                });
            }
        }

        public void SpawnDust(Vector2 pos, int n) => Burst(pos, "effects/effects", Assets.EFFECT_CELLS, 4, n, 22f, new Color(1, 1, 1, 0.9f), 60f);

        void Burst(Vector2 pos, string sheet, int cells, int cell, int n, float size, Color col, float speed = 140f)
        {
            for (int i = 0; i < n; i++)
            {
                float a = rng.Range(0, Gd.TAU);
                fx.Add(new Particle
                {
                    sheet = sheet, cells = cells, cell = cell, position = pos,
                    vel = new Vector2(Mathf.Cos(a), Mathf.Sin(a) - 0.6f) * rng.Range(speed * 0.4f, speed),
                    gravity = 260f, drag = 2f, life = rng.Range(0.4f, 0.75f), size = size * rng.Range(0.7f, 1.2f), spin = rng.Range(-8, 8), color = col,
                });
            }
        }

        // ---- Biome Shuffle ----
        public void BiomeShuffle()
        {
            Sfx.Play("shuffle");
            hud.Banner("Biome Shuffle!", 1.6f);
            // "cycle" (-2) turns rug -> ice -> honey -> rug; others paint the whole patch.
            int[] choices = { -2, -2, -2, Terrain.ICE, Terrain.BOUNCY, Terrain.BOUNCY, -1 };
            var cycle = new Dictionary<int, int> { { Terrain.NORMAL, Terrain.ICE }, { Terrain.ICE, Terrain.HONEY }, { Terrain.HONEY, Terrain.NORMAL } };
            var used = new HashSet<Vector2Int>();
            for (int i = 0; i < Tuning.SHUFFLE_REGIONS; i++)
            {
                int w = rng.RangeI(3, 5), h = rng.RangeI(3, 4);
                int x0 = rng.RangeI(1, Tuning.COLS - 1 - w), y0 = rng.RangeI(1, Tuning.ROWS - 1 - h);
                int t = choices[rng.Int(choices.Length)];
                if (t == -1) t = Terrain.CONVEYOR_R + rng.Int(4);
                var region = new Dictionary<Vector2Int, int>();
                for (int y = y0; y < y0 + h; y++)
                    for (int x = x0; x < x0 + w; x++)
                    {
                        var c = new Vector2Int(x, y);
                        if (used.Contains(c) || arena.CellType(c) == Arena.BORDER) continue;
                        int cur = arena.TerrainAt(c);
                        int nt = t;
                        if (t == -2) nt = cycle.TryGetValue(cur, out int cv) ? cv : Terrain.NORMAL;
                        else if (cur == t) nt = Terrain.NORMAL;
                        used.Add(c);
                        region[c] = nt;
                    }
                shuffleEvents.Add(new ShuffleEvent { t = Tuning.SHUFFLE_WARN, cells = region, revert = false });
            }
            foreach (var e in shuffleEvents)
                foreach (var kv in e.cells) arena.warn[kv.Key] = kv.Value;
            arena.warnT = 0f;
        }

        void UpdateShuffles(float delta)
        {
            foreach (var e in shuffleEvents.ToArray())
            {
                e.t -= delta;
                if (e.t > 0f)
                {
                    // warn shortly before a temporary shuffle wears off
                    if (e.revert && e.t < Tuning.SHUFFLE_WARN && !e.warned)
                    {
                        e.warned = true;
                        foreach (var kv in e.cells)
                            if (arena.TerrainAt(kv.Key) == e.set[kv.Key]) arena.warn[kv.Key] = arena.baseTerrain[kv.Key.y * arena.cols + kv.Key.x];
                    }
                    continue;
                }
                shuffleEvents.Remove(e);
                if (!e.revert)
                {
                    foreach (var kv in e.cells) { arena.SetTerrain(kv.Key, kv.Value); arena.warn.Remove(kv.Key); }
                    shuffleEvents.Add(new ShuffleEvent { t = Tuning.SHUFFLE_DURATION, cells = e.cells, set = e.cells, revert = true });
                }
                else
                {
                    foreach (var kv in e.cells)
                    {
                        arena.warn.Remove(kv.Key);
                        if (arena.TerrainAt(kv.Key) == e.set[kv.Key]) arena.SetTerrain(kv.Key, arena.baseTerrain[kv.Key.y * arena.cols + kv.Key.x]);
                    }
                }
            }
        }

        // ---- end of round ----
        void EndMatch()
        {
            state = State.ENDED;
            parade = null; // the ducks wind down quietly
            foreach (var b in bears) b.stealing = false;
            var ranking = new List<Bear>(bears);
            // stable sort, highest fluff first (like Godot's sort_custom)
            var indexed = new List<KeyValuePair<int, Bear>>();
            for (int i = 0; i < ranking.Count; i++) indexed.Add(new KeyValuePair<int, Bear>(i, ranking[i]));
            indexed.Sort((a, b) => b.Value.fluff != a.Value.fluff ? b.Value.fluff.CompareTo(a.Value.fluff) : a.Key.CompareTo(b.Key));
            ranking.Clear();
            foreach (var kv in indexed) ranking.Add(kv.Value);
            Sfx.Play("victory");
            hud.ShowResults(ranking);
        }

        public void TogglePause()
        {
            if (state == State.ENDED) return;
            paused = !paused;
            hud.ShowPause(paused);
        }

        public void RequestRestart() { paused = false; RestartRequested?.Invoke(); }
        public void RequestMenu() { paused = false; QuitToMenu?.Invoke(); }

        // ---- drawing (Godot z order: wallpaper, arena, decals, floor items, bombs, blasts, duck, bears(y-sorted), fx) ----
        public void Draw(Painter p)
        {
            p.Modulate = worldTint;   // CanvasModulate equivalent for the world layer
            p.SetBase(Xf.Identity);
            p.ResetTransform();
            UiStyle.Wallpaper(p, new Rect(0, 0, 1280, 720));
            var r = new Rect(ARENA_ORIGIN - new Vector2(10, 10), new Vector2(Tuning.COLS, Tuning.ROWS) * Tuning.TILE + new Vector2(20, 20));
            p.Rect(r, UiStyle.FRAME);
            UiStyle.StitchRect(p, Arena.Grow(r, -4), Gd.WithAlpha(UiStyle.ROSE_DARK, 0.6f), 1.6f, 6f);
            arena.Draw(p);
            Vector2 o = arena.Position;
            foreach (var e in decals) e.Draw(p, o);
            foreach (var e in floorItems) e.Draw(p, o);
            foreach (var b in bombs) b.Draw(p);
            foreach (var e in blasts) e.Draw(p, o);
            parade?.Draw(p);
            var sorted = new List<Bear>(bears);
            sorted.Sort((a, b) => a.position.y.CompareTo(b.position.y));
            foreach (var b in sorted) b.Draw(p);
            foreach (var e in fx) e.Draw(p, o);
            p.Modulate = Color.white;
            p.SetBase(Xf.Identity);
            p.ResetTransform();
            if (ModeTheme.Horror) DrawVignette(p);
        }

        /// Radial vignette centred on the arena (Horror mode), like the Godot GradientTexture2D.
        void DrawVignette(Painter p)
        {
            if (vignette == null)
            {
                const int N = 128;
                vignette = new Texture2D(N, N, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
                var px = new Color[N * N];
                float R = Vector2.Distance(new Vector2(0.5f, 0.5f), new Vector2(1.05f, 1.05f));
                for (int y = 0; y < N; y++)
                    for (int x = 0; x < N; x++)
                    {
                        float k = Mathf.Clamp01(Vector2.Distance(new Vector2((x + 0.5f) / N, (y + 0.5f) / N), new Vector2(0.5f, 0.5f)) / R);
                        Color c = k < 0.55f ? Color.Lerp(new Color(0, 0, 0, 0), new Color(0, 0, 0, 0.05f), k / 0.55f)
                                            : Color.Lerp(new Color(0, 0, 0, 0.05f), new Color(0.05f, 0f, 0.01f, 0.75f), (k - 0.55f) / 0.45f);
                        px[y * N + x] = c;
                    }
                vignette.SetPixels(px);
                vignette.Apply();
            }
            p.RawTexture(vignette, new Rect(-40, -60, 840, 840), Color.white);
        }
    }

    /// What the game needs from the HUD (null implementation for headless runs).
    public interface IHud
    {
        void Banner(string text, float duration);
        void Toast(string text, Color col);
        void ShowResults(List<Bear> ranking);
        void ShowPause(bool paused);
    }

    public class NullHud : IHud
    {
        public void Banner(string text, float duration) { }
        public void Toast(string text, Color col) { }
        public void ShowResults(List<Bear> ranking) { }
        public void ShowPause(bool paused) { }
    }
}
