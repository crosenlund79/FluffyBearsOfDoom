// Computer opponents (port of ai_controller.gd). They only press the same
// "buttons" a human has, so an overstuffed AI bear wobbles, slides and
// overshoots just like you.
//
// EASY   - slow to react, sometimes misses danger, bombs carelessly, never
//          brakes early (so it overshoots), steals for a random short while.
// NORMAL - understands blast lines, escapes, bombs opponents in line,
//          seeks power-ups and theft, releases the stick to brake in time.
// HARD   - predicts chain reactions and timing, traps opponents, prefers
//          rich targets, weighs theft risk, counter-steers to brake, avoids
//          ice when it is heavy, kicks bombs and lays line bombs at rivals,
//          and charges recklessly while immortal.
// Everyone struggles under Reverse Controls: the curse flips the AI's stick
// too, and it only sometimes remembers to compensate.
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public class AiController : IController
    {
        public const int EASY = 0, NORMAL = 1, HARD = 2;
        static readonly float[] THINK_TIME = { 0.5f, 0.26f, 0.13f };
        static readonly float[] NOTICE_DANGER = { 0.6f, 0.93f, 1f };
        static readonly float[] COMPENSATE = { 0.15f, 0.45f, 0.62f };
        static readonly Vector2Int[] DIRS = { new Vector2Int(1, 0), new Vector2Int(-1, 0), new Vector2Int(0, 1), new Vector2Int(0, -1) };
        const float FAR = 999f;

        readonly Bear bear;
        readonly Game game;
        readonly Arena arena;
        public readonly int level;
        readonly Rng rng = new Rng();

        List<Vector2Int> path = new List<Vector2Int>();
        public string goal = "idle";
        Vector2Int goalCell = new Vector2Int(-1, -1);
        float thinkT, stuckT;
        Vector2 lastPos;
        Lootable stealVictim;
        float stealBudget, clock, curseT, hesitateT;
        bool compensating;
        readonly Dictionary<Vector2Int, float> badSpots = new Dictionary<Vector2Int, float>();

        public AiController(Bear b, Game g, int lvl)
        {
            bear = b; game = g; arena = g.arena; level = lvl;
            thinkT = rng.Range(0.2f, 0.6f);
        }

        public void Update(float delta)
        {
            thinkT -= delta;
            clock += delta;
            if (bear.stealing) stealBudget -= delta;
            if (path.Count > 0 && Vector2.Distance(bear.position, lastPos) < 0.4f) stuckT += delta;
            else stuckT = 0f;
            lastPos = bear.position;
            if (stuckT > 0.7f) { path.Clear(); stuckT = 0f; thinkT = 0f; }
            if (thinkT <= 0f)
            {
                thinkT = THINK_TIME[level] * rng.Range(0.8f, 1.25f);
                Think();
            }
            Steer(delta);
        }

        // ---- decision making ----
        void Think()
        {
            Vector2Int me = bear.Cell;
            var danger = game.ComputeDanger(level, bear);
            bool fearless = level > EASY && bear.immortalT > 2.5f;
            if (fearless) danger = new Dictionary<Vector2Int, float>(); // can't be stunned: ignore blasts

            // 0a. Set off our remote bombs when a rival is in a blast and we're clear of all of them.
            if (bear.hasRemote && TryDetonate(me)) return;

            // 0. Kick a nearby bomb at a rival.
            if (bear.canKick && level > EASY && TryKick(me)) return;

            // 1. Get out of blast lines.
            if (Threat(danger, me) && rng.F() < NOTICE_DANGER[level])
            {
                bear.wantSteal = false;
                if (level == HARD || goal != "flee" || path.Count == 0 || !PathSafe(path, danger))
                {
                    path = EscapePath(me, danger, FAR);
                    goal = "flee";
                }
                return;
            }
            if (level > EASY && path.Count > 0 && !PathSafe(path, danger)) path.Clear();

            // 2. Rob a stunned bear right next to us.
            Lootable victim = game.FindStealTarget(bear);
            if (victim == null) victim = game.FindChair(bear);   // or loot a delivered chair
            if (victim != null && ShouldSteal(victim, danger))
            {
                bear.wantSteal = true;
                path.Clear();
                goal = "steal";
                return;
            }
            bear.wantSteal = false;

            // 3. Drop a bomb when it is worth it and we can get away.
            if (bear.CanPlaceBomb)
            {
                string reason = BombReason(me);
                if (reason != "")
                {
                    var esc = EscapeAfterBomb(me, danger);
                    bool careless = level == EASY && rng.F() < 0.12f;
                    if (esc.Count > 0 || careless || fearless)
                    {
                        bear.wantBomb = true;
                        path = esc;
                        goal = "flee";
                        return;
                    }
                    if (reason == "block") { badSpots[me] = clock + 8f; goal = "idle"; } // nowhere to hide from here
                }
            }

            // 4. Lay a line of bombs toward a rival.
            if (bear.hasLine && level > EASY && bear.bombsMax - bear.activeBombs >= 2 && TryLine(me, danger, fearless)) return;

            if (goal == "flee" && path.Count > 0) return;
            ChooseGoal(me, danger);
        }

        bool TryDetonate(Vector2Int me)
        {
            var zone = new HashSet<Vector2Int>();
            bool any = false;
            foreach (var b in game.bombs)
            {
                if (!b.remote || b.owner != bear || b.exploded) continue;
                any = true;
                foreach (var c in game.BlastCells(b.cell, b.blastRange)) zone.Add(c);
            }
            if (!any) return false;
            if (zone.Contains(me) && level > EASY) return false; // Easy sometimes blows itself up
            foreach (var o in game.bears)
                if (Targetable(o) && zone.Contains(o.Cell))
                {
                    if (level == EASY && rng.F() < 0.5f) return false;
                    bear.wantSpecial = true;
                    return true;
                }
            return false;
        }

        bool Targetable(Bear b) => b != bear && !b.IsStunned && b.immortalT <= 0.5f && b.immuneT <= 0.4f;

        bool TryKick(Vector2Int me)
        {
            foreach (var d in DIRS)
            {
                Vector2Int n = me + d;
                if (!arena.bombs.TryGetValue(n, out Bomb bomb) || bomb.IsMoving || bomb.fuse < 0.6f) continue;
                Vector2Int c = n + d;
                for (int i = 0; i < 9; i++)
                {
                    if (arena.IsSolid(c) || arena.bombs.ContainsKey(c)) break;
                    foreach (var b in game.bears)
                        if (Targetable(b) && b.Cell == c && (level == HARD || rng.F() < 0.5f))
                        {
                            path = new List<Vector2Int> { n };
                            goal = "kick";
                            return true;
                        }
                    c += d;
                }
            }
            return false;
        }

        bool TryLine(Vector2Int me, Dictionary<Vector2Int, float> danger, bool fearless)
        {
            var cells = game.LineCells(bear);
            if (cells.Count < 2) return false;
            var d2 = new Dictionary<Vector2Int, float>(danger);
            foreach (var c in cells)
                foreach (var x in game.BlastCells(c, bear.bombRange))
                    d2[x] = Mathf.Min(d2.TryGetValue(x, out float v) ? v : FAR, Tuning.BOMB_FUSE);
            bool hits = false;
            foreach (var b in game.bears)
                if (Targetable(b) && d2.ContainsKey(b.Cell) && !danger.ContainsKey(b.Cell)) hits = true;
            if (!hits) return false;
            var esc = EscapePath(me, d2, Tuning.BOMB_FUSE - 0.45f);
            if (!fearless && (esc.Count == 0 || d2.ContainsKey(esc[esc.Count - 1]))) return false;
            bear.wantSpecial = true;
            path = esc;
            goal = "flee";
            return true;
        }

        /// Imminent danger (a far-off duck countdown isn't worth panicking over yet).
        static bool Threat(Dictionary<Vector2Int, float> danger, Vector2Int c) => danger.TryGetValue(c, out float t) && t < 4f;

        bool ShouldSteal(Lootable victim, Dictionary<Vector2Int, float> danger)
        {
            if (Threat(danger, bear.Cell)) return false;
            if (victim != stealVictim)
            {
                stealVictim = victim;
                stealBudget = level == EASY ? rng.Range(0.5f, 2.5f) : FAR;
                if (level == EASY && rng.F() < 0.3f) stealBudget = 0f;
            }
            if (stealBudget <= 0f) return false;
            if (level == HARD)
            {
                if (victim.stunT < 0.15f) return false;
                // Greed check: a bulging bear with an armed opponent nearby takes the loot and runs.
                Bear threat = NearestThreat(3);
                if (threat != null && bear.FluffRatio > 2.2f && threat.CanPlaceBomb) return false;
            }
            return true;
        }

        Bear NearestThreat(int maxDist)
        {
            Vector2Int me = bear.Cell;
            foreach (var b in game.bears)
            {
                if (b == bear || b.IsStunned) continue;
                Vector2Int c = b.Cell;
                if (Mathf.Abs(c.x - me.x) + Mathf.Abs(c.y - me.y) <= maxDist) return b;
            }
            return null;
        }

        string BombReason(Vector2Int me)
        {
            var blast = game.BlastCells(me, bear.bombRange);
            foreach (var b in game.bears)
            {
                if (!Targetable(b)) continue;
                Vector2Int bc = b.Cell;
                if (blast.Contains(bc))
                {
                    if (level == EASY && rng.F() < 0.5f) continue;
                    return "opponent";
                }
                if (level == HARD)
                {
                    Vector2Int predicted = arena.WorldToCell(b.position + b.velocity * 0.6f);
                    if (blast.Contains(predicted)) return "opponent";
                    if (Mathf.Abs(bc.x - me.x) + Mathf.Abs(bc.y - me.y) <= 3 && IsTrapped(b, me, blast)) return "trap";
                }
            }
            if (goal == "block" && me == goalCell) return "block";
            if (level == EASY && rng.F() < 0.06f && CountBlocks(blast) > 0) return "block";
            return "";
        }

        /// Would `victim` have no safe cell within reach if we bombed `bombCell`?
        bool IsTrapped(Bear victim, Vector2Int bombCell, List<Vector2Int> blast)
        {
            Vector2Int start = victim.Cell;
            var seen = new Dictionary<Vector2Int, int> { { start, 0 } };
            var queue = new Queue<Vector2Int>();
            queue.Enqueue(start);
            while (queue.Count > 0)
            {
                Vector2Int c = queue.Dequeue();
                if (!blast.Contains(c)) return false;
                if (seen[c] >= 4) continue;
                foreach (var d in DIRS)
                {
                    Vector2Int n = c + d;
                    if (seen.ContainsKey(n) || n == bombCell || !arena.IsWalkable(n)) continue;
                    seen[n] = seen[c] + 1;
                    queue.Enqueue(n);
                }
            }
            return true;
        }

        int CountBlocks(List<Vector2Int> blast)
        {
            int n = 0;
            foreach (var c in blast) if (arena.CellType(c) == Arena.BLOCK) n++;
            return n;
        }

        void ChooseGoal(Vector2Int me, Dictionary<Vector2Int, float> danger)
        {
            Dijkstra(me, danger, 30f, out var dist, out var parent);
            float bestScore = -FAR;
            Vector2Int bestCell = me;
            string bestGoal = "idle";
            float tpt = TimePerTile();

            // Stunned bears are walking treasure chests.
            foreach (var b in game.bears)
            {
                if (b == bear || !b.IsStunned || b.fluff < 3f) continue;
                Vector2Int c = b.Cell;
                if (!dist.TryGetValue(c, out float d)) continue;
                if (d * tpt > b.stunT + (level == EASY ? 0.6f : 0.2f)) continue;
                float score = level == EASY ? (rng.F() < 0.5f ? 45f : -FAR) : level == NORMAL ? 70f : 40f + b.fluff * 0.4f;
                score -= d * 4f;
                if (score > bestScore) { bestScore = score; bestCell = c; bestGoal = "rob"; }
            }

            // A crane-delivered chair stuffed with fluff.
            if (game.chair != null && game.chair.fluff > 1f && dist.TryGetValue(game.chair.cell, out float cd))
            {
                float cv = 40f + 0.5f * game.chair.fluff;
                if (level == EASY) cv = rng.F() < 0.6f ? 30f : -FAR;
                float score = cv - cd * 3f;
                if (score > bestScore) { bestScore = score; bestCell = game.chair.cell; bestGoal = "loot"; }
            }

            // Power-ups.
            if (level != EASY || rng.F() < 0.4f)
            {
                foreach (var kv in game.powerups)
                {
                    Vector2Int c = kv.Key;
                    if (!dist.TryGetValue(c, out float dc)) continue;
                    int kind = kv.Value.kind;
                    float value = 35f;
                    if (Powerup.IsBad(kind)) { if (level != EASY) continue; } // Easy doesn't read the labels
                    else if (kind == Powerup.IMMORTAL) value = 55f;
                    else if (kind == Powerup.KICK) value = !bear.canKick ? 32f : 8f;
                    else if (kind == Powerup.LINE) value = !bear.hasLine ? 32f : 8f;
                    else if (kind == Powerup.RUBBER) value = !bear.hasRubber ? 22f : 6f;
                    else if (kind == Powerup.REMOTE) value = !bear.hasRemote ? (level == HARD ? 36f : 30f) : 5f;
                    if (level == HARD)
                    {
                        if (kind == Powerup.SHUFFLE) value = bear.FluffRatio < 1.3f ? 30f : 12f;
                        else if (kind == Powerup.SPEED) value = 30f + 10f * bear.FluffRatio;
                    }
                    float score = value - dc * 4f;
                    if (score > bestScore) { bestScore = score; bestCell = c; bestGoal = "powerup"; }
                }
            }

            // Places from which a bomb would open up cushion blocks.
            foreach (var kv in dist)
            {
                Vector2Int c = kv.Key;
                if (kv.Value > 9f || (badSpots.TryGetValue(c, out float until) ? until : -1f) > clock) continue;
                int blocks = CountBlocks(game.BlastCells(c, bear.bombRange));
                if (blocks == 0) continue;
                float score = 14f + 6f * blocks - kv.Value * 3f;
                if (c == goalCell && goal == "block") score += 4f; // a little stubbornness avoids dithering
                if (score > bestScore) { bestScore = score; bestCell = c; bestGoal = "block"; }
            }

            // Hunt opponents.
            foreach (var b in game.bears)
            {
                if (!Targetable(b)) continue;
                Vector2Int c = b.Cell;
                if (!dist.TryGetValue(c, out float dc)) continue;
                float score = level == EASY ? 6f + rng.F() * 10f : level == NORMAL ? 16f : 10f + b.fluff * 0.1f - Mathf.Max(bear.FluffRatio - 2.5f, 0f) * 8f;
                score -= dc * 1.5f;
                if (score > bestScore) { bestScore = score; bestCell = c; bestGoal = "hunt"; }
            }

            if (bestScore < 0f && dist.Count > 1)
            {
                var keys = new List<Vector2Int>(dist.Keys);
                bestCell = keys[rng.Int(keys.Count)];
                bestGoal = "wander";
            }
            goal = bestGoal;
            goalCell = bestCell;
            path = Reconstruct(parent, me, bestCell);
        }

        // ---- path finding ----
        float TimePerTile() => arena.T / Mathf.Max(bear.MaxSpeed, 30f) * (1f + 0.12f * bear.FluffRatio);

        /// A cell is unsafe if it will be ablaze around the time we'd be in it.
        bool Unsafe(Vector2Int c, float arrival, Dictionary<Vector2Int, float> danger)
        {
            if (!danger.TryGetValue(c, out float t)) return false;
            switch (level)
            {
                case EASY: return t < 0.4f;
                case NORMAL: return t < arrival + 0.5f;
                default: return t < arrival + 0.7f && t > arrival - 0.6f - Tuning.FLAME_TIME;
            }
        }

        float StepCost(Vector2Int c)
        {
            float cost = 1f;
            if (level == EASY) return cost;
            int tr = arena.TerrainAt(c);
            if (tr == Terrain.HONEY) cost += 1f;
            if (level == HARD && tr == Terrain.ICE) cost += 0.5f * Mathf.Min(bear.FluffRatio, 4f);
            return cost;
        }

        /// Cost-weighted search over walkable, safe cells.
        void Dijkstra(Vector2Int start, Dictionary<Vector2Int, float> danger, float limit,
            out Dictionary<Vector2Int, float> dist, out Dictionary<Vector2Int, Vector2Int> parent)
        {
            dist = new Dictionary<Vector2Int, float> { { start, 0f } };
            parent = new Dictionary<Vector2Int, Vector2Int>();
            var steps = new Dictionary<Vector2Int, int> { { start, 0 } };
            var open = new List<Vector2Int> { start };
            float tpt = TimePerTile();
            while (open.Count > 0)
            {
                int bi = 0;
                for (int i = 0; i < open.Count; i++) if (dist[open[i]] < dist[open[bi]]) bi = i;
                Vector2Int c = open[bi];
                open.RemoveAt(bi);
                if (dist[c] > limit) continue;
                foreach (var d in DIRS)
                {
                    Vector2Int n = c + d;
                    if (!arena.IsWalkable(n)) continue;
                    if (level != EASY && game.powerups.TryGetValue(n, out Powerup pu) && Powerup.IsBad(pu.kind)) continue;
                    int s = steps[c] + 1;
                    if (Unsafe(n, s * tpt, danger)) continue;
                    float nd = dist[c] + StepCost(n);
                    if (!dist.TryGetValue(n, out float old) || nd < old)
                    {
                        dist[n] = nd;
                        steps[n] = s;
                        parent[n] = c;
                        if (!open.Contains(n)) open.Add(n);
                    }
                }
            }
        }

        static List<Vector2Int> Reconstruct(Dictionary<Vector2Int, Vector2Int> parent, Vector2Int start, Vector2Int goalC)
        {
            var o = new List<Vector2Int>();
            Vector2Int c = goalC;
            while (c != start && parent.TryGetValue(c, out Vector2Int pc)) { o.Insert(0, c); c = pc; }
            return o;
        }

        bool PathSafe(List<Vector2Int> p, Dictionary<Vector2Int, float> danger)
        {
            float tpt = TimePerTile();
            for (int i = 0; i < p.Count; i++)
            {
                if (!arena.IsWalkable(p[i])) return false;
                if (i < p.Count - 1 && Unsafe(p[i], (i + 1) * tpt, danger)) return false;
                if (i == p.Count - 1 && danger.ContainsKey(p[i]) && goal != "flee") return false;
            }
            return true;
        }

        /// Path to the nearest cell outside every blast line.
        List<Vector2Int> EscapePath(Vector2Int start, Dictionary<Vector2Int, float> danger, float maxTime)
        {
            Dijkstra(start, danger, 14f, out var dist, out var parent);
            Vector2Int best = start, fallback = start;
            float bestD = FAR, fallbackT = -1f;
            foreach (var kv in dist)
            {
                Vector2Int c = kv.Key;
                if (!danger.TryGetValue(c, out float dt))
                {
                    float d = kv.Value;
                    if (level == HARD) d -= Exits(c) * 0.3f; // prefer hiding spots that aren't dead ends
                    if (d < bestD) { bestD = d; best = c; }
                }
                else if (dt > fallbackT) { fallbackT = dt; fallback = c; }
            }
            if (best == start && danger.ContainsKey(start)) best = fallback;
            var p = Reconstruct(parent, start, best);
            if (maxTime < FAR && TravelTime(start, p) > maxTime) return new List<Vector2Int>();
            if (danger.ContainsKey(best)) return maxTime < FAR ? new List<Vector2Int>() : p;
            return p;
        }

        int Exits(Vector2Int c)
        {
            int n = 0;
            foreach (var d in DIRS) if (arena.IsWalkable(c + d)) n++;
            return n;
        }

        /// How long the path would take - each level estimates differently.
        float TravelTime(Vector2Int start, List<Vector2Int> p)
        {
            if (p.Count == 0) return 0f;
            if (level == EASY) return p.Count * 0.22f; // forgets that it's heavy!
            if (level == NORMAL) return p.Count * TimePerTile() * 1.1f + 0.15f;
            float ms = bear.MaxSpeed;
            int turns = 0;
            Vector2Int prev = start, prevDir = Vector2Int.zero;
            foreach (var c in p)
            {
                Vector2Int d = c - prev;
                if (prevDir != Vector2Int.zero && d != prevDir) turns++;
                prevDir = d;
                prev = c;
            }
            return p.Count * arena.T / ms + ms / bear.Accel + turns * ms / bear.Brake * 0.5f + 0.1f;
        }

        List<Vector2Int> EscapeAfterBomb(Vector2Int me, Dictionary<Vector2Int, float> danger)
        {
            var d2 = new Dictionary<Vector2Int, float>(danger);
            foreach (var c in game.BlastCells(me, bear.bombRange))
                d2[c] = Mathf.Min(d2.TryGetValue(c, out float v) ? v : FAR, Tuning.BOMB_FUSE);
            var p = EscapePath(me, d2, Tuning.BOMB_FUSE - (level == EASY ? 0.25f : 0.45f));
            if (p.Count == 0 || d2.ContainsKey(p[p.Count - 1])) return new List<Vector2Int>();
            return p;
        }

        // ---- steering ----
        void Steer(float delta)
        {
            if (bear.stealing || (bear.wantSteal && goal == "steal")) { bear.inputDir = Vector2.zero; return; }
            while (path.Count > 0)
            {
                Vector2Int c0 = path[0];
                Vector2 center = arena.CellCenter(c0);
                if (Vector2.Distance(bear.position, center) < 7f) { path.RemoveAt(0); continue; }
                if (bear.Cell == c0 && path.Count > 1)
                {
                    Vector2Int nd = path[1] - c0;
                    if (nd.x != 0 && Mathf.Abs(bear.position.y - center.y) < 6f) { path.RemoveAt(0); continue; }
                    if (nd.y != 0 && Mathf.Abs(bear.position.x - center.x) < 6f) { path.RemoveAt(0); continue; }
                }
                break;
            }
            if (path.Count == 0) { bear.inputDir = Vector2.zero; return; }
            Vector2 target = arena.CellCenter(path[0]);
            Vector2 d = target - bear.position;
            Vector2 dir = Mathf.Abs(d.x) > Mathf.Abs(d.y) ? new Vector2(Gd.Sign(d.x), 0) : new Vector2(0, Gd.Sign(d.y));
            // Brake early for the next turn or stop (Easy never does: it overshoots).
            if (level >= NORMAL)
            {
                float vAlong = Vector2.Dot(bear.velocity, dir);
                if (vAlong > 20f)
                {
                    Vector2 stopPt = StopPoint(dir);
                    float dist = Vector2.Dot(stopPt - bear.position, dir);
                    float br = bear.Brake * Terrain.Props(arena.TerrainAt(bear.Cell)).brake;
                    float need = vAlong * vAlong / (2f * Mathf.Max(br, 1f));
                    float margin = level == HARD ? 1.15f : 1f;
                    if (dist < need * margin + 2f) dir = (level == HARD && dist < need * 0.8f) ? -dir : Vector2.zero;
                }
            }
            bear.inputDir = Cursed(dir, delta);
        }

        /// Under Reverse Controls the bear flips our stick. We only sometimes remember
        /// to flip it back, and now and then freeze up in confusion.
        Vector2 Cursed(Vector2 dir, float delta)
        {
            if (bear.reverseT <= 0f) return dir;
            curseT -= delta;
            hesitateT -= delta;
            if (curseT <= 0f)
            {
                curseT = rng.Range(0.3f, 0.9f);
                compensating = rng.F() < COMPENSATE[level];
                if (rng.F() < 0.25f) hesitateT = rng.Range(0.15f, 0.45f);
            }
            if (hesitateT > 0f) return Vector2.zero;
            return compensating ? -dir : dir;
        }

        /// The centre of the last cell before the path turns or ends.
        Vector2 StopPoint(Vector2 dir)
        {
            var di = new Vector2Int((int)dir.x, (int)dir.y);
            Vector2Int last = path[0];
            for (int i = 1; i < path.Count; i++)
            {
                if (path[i] - path[i - 1] != di) break;
                last = path[i];
            }
            return arena.CellCenter(last);
        }
    }
}
