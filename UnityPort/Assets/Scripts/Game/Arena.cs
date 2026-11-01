// The fixed grid: walls, cushion blocks, terrain and their drawing (port of arena.gd).
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public class Arena
    {
        public const int EMPTY = 0, WALL = 1, BORDER = 2, BLOCK = 3;
        public static readonly Vector2Int[] SPAWNS = { new Vector2Int(1, 1), new Vector2Int(13, 11), new Vector2Int(13, 1), new Vector2Int(1, 11) };

        public int cols = Tuning.COLS, rows = Tuning.ROWS;
        public float T = Tuning.TILE;
        public int[] cells, terrain, baseTerrain;
        public readonly Dictionary<Vector2Int, int> hiddenPowerups = new Dictionary<Vector2Int, int>();
        public readonly Dictionary<Vector2Int, Bomb> bombs = new Dictionary<Vector2Int, Bomb>();
        public readonly Dictionary<Vector2Int, int> warn = new Dictionary<Vector2Int, int>();
        public float warnT;
        public string mapName = "";
        public float animT;
        public bool hasConveyors;
        public float shake;
        public Vector2 origin;          // where the grid sits on the canvas
        public Vector2 jitter;          // screen-shake offset
        readonly Rng shakeRng = new Rng();

        public Vector2 Position => origin + jitter;

        public void Setup(MapDef map, Rng rng, float[] powerupWeights)
        {
            mapName = map.name;
            cells = new int[cols * rows];
            terrain = new int[cols * rows];
            string[] rowsDef = map.terrain ?? new string[0];
            for (int y = 0; y < rows; y++)
                for (int x = 0; x < cols; x++)
                {
                    int i = y * cols + x;
                    int t = Terrain.NORMAL;
                    if (y < rowsDef.Length && x < rowsDef[y].Length && Terrain.CHARS.TryGetValue(rowsDef[y][x], out int tt)) t = tt;
                    terrain[i] = t;
                    if (Terrain.IsConveyor(t)) hasConveyors = true;
                    if (x == 0 || y == 0 || x == cols - 1 || y == rows - 1) cells[i] = BORDER;
                    else if (x % 2 == 0 && y % 2 == 0) cells[i] = WALL;
                    else if (IsSpawnZone(new Vector2Int(x, y))) cells[i] = EMPTY;
                    else if (rng.F() < map.blockDensity) cells[i] = BLOCK;
                    else cells[i] = EMPTY;
                }
            baseTerrain = (int[])terrain.Clone();
            // Hide power-ups under some blocks, guaranteeing a couple of Biome Shuffles.
            var blocks = new List<Vector2Int>();
            for (int y = 0; y < rows; y++)
                for (int x = 0; x < cols; x++)
                    if (cells[y * cols + x] == BLOCK) blocks.Add(new Vector2Int(x, y));
            rng.Shuffle(blocks);
            float totalW = 0f;
            foreach (float w in powerupWeights) totalW += w;
            foreach (var c in blocks)
            {
                if (rng.F() < Tuning.POWERUP_CHANCE)
                {
                    float r = rng.F() * totalW;
                    for (int k = 0; k < powerupWeights.Length; k++)
                    {
                        r -= powerupWeights[k];
                        if (r <= 0f) { hiddenPowerups[c] = k; break; }
                    }
                }
            }
            int shuffles = 0;
            foreach (var kv in hiddenPowerups) if (kv.Value == Powerup.SHUFFLE) shuffles++;
            foreach (var c in blocks)
            {
                if (shuffles >= 2) break;
                if (!hiddenPowerups.TryGetValue(c, out int k) || k != Powerup.SHUFFLE) { hiddenPowerups[c] = Powerup.SHUFFLE; shuffles++; }
            }
        }

        public bool IsSpawnZone(Vector2Int c)
        {
            foreach (var s in SPAWNS) if (Mathf.Abs(c.x - s.x) + Mathf.Abs(c.y - s.y) <= 1) return true;
            return false;
        }

        public bool InBounds(Vector2Int c) => c.x >= 0 && c.y >= 0 && c.x < cols && c.y < rows;
        public int CellType(Vector2Int c) => InBounds(c) ? cells[c.y * cols + c.x] : BORDER;
        public bool IsSolid(Vector2Int c) => CellType(c) != EMPTY;
        public bool IsWalkable(Vector2Int c) => !IsSolid(c) && !bombs.ContainsKey(c);
        public bool BlocksBear(Vector2Int c, Bear bear)
        {
            if (IsSolid(c)) return true;
            return bombs.TryGetValue(c, out Bomb b) && b != null && !b.passThrough.Contains(bear);
        }
        public Vector2Int WorldToCell(Vector2 p) => new Vector2Int(Mathf.FloorToInt(p.x / T), Mathf.FloorToInt(p.y / T));
        public Vector2 CellCenter(Vector2Int c) => new Vector2((c.x + 0.5f) * T, (c.y + 0.5f) * T);
        public int TerrainAt(Vector2Int c) => InBounds(c) ? terrain[c.y * cols + c.x] : Terrain.NORMAL;

        public void SetTerrain(Vector2Int c, int t)
        {
            if (!InBounds(c)) return;
            terrain[c.y * cols + c.x] = t;
            if (Terrain.IsConveyor(t)) hasConveyors = true;
        }

        /// Destroys a cushion block, returning the hidden power-up kind or -1.
        public int DestroyBlock(Vector2Int c)
        {
            if (CellType(c) != BLOCK) return -1;
            cells[c.y * cols + c.x] = EMPTY;
            int p = hiddenPowerups.TryGetValue(c, out int k) ? k : -1;
            hiddenPowerups.Remove(c);
            return p;
        }

        public void AddShake(float amount) { shake = Mathf.Max(shake, amount); }

        public void Process(float delta)
        {
            animT += delta;
            if (warn.Count > 0) warnT += delta;
            if (shake > 0f)
            {
                shake = Mathf.Max(0f, shake - delta * 30f);
                jitter = new Vector2(shakeRng.Range(-1f, 1f), shakeRng.Range(-1f, 1f)) * shake;
            }
            else jitter = Vector2.zero;
        }

        // ---- drawing ----
        public void Draw(Painter p)
        {
            Tex tiles = Assets.Get("tiles/tiles");
            p.SetBase(Xf.Translate(Position));
            p.ResetTransform();
            // soft drop shadow under the whole arena
            p.Rect(new Rect(new Vector2(6, 10), new Vector2(cols, rows) * T), new Color(0.35f, 0.25f, 0.2f, 0.18f));
            // floors
            for (int y = 0; y < rows; y++)
                for (int x = 0; x < cols; x++)
                {
                    int i = y * cols + x;
                    var r = new Rect(x * T, y * T, T, T);
                    if (cells[i] == BORDER) continue;
                    int t = terrain[i];
                    int idx = Terrain.Props(t).tile;
                    if (t == Terrain.NORMAL && (x + y) % 2 == 1) idx = 1;
                    if (Terrain.IsConveyor(t))
                    {
                        p.SetTransform(r.center, Terrain.ConveyorRotation(t), Vector2.one);
                        p.TextureRect(tiles.Region(Assets.TILE_CELLS, idx), new Rect(-T * 0.5f, -T * 0.5f, T, T));
                        float off = (animT * 40f) % (T / 3f);
                        for (int k = 0; k < 3; k++)
                        {
                            float cx = -T * 0.5f + off + k * T / 3f;
                            if (cx > T * 0.5f - 4f) continue;
                            p.Polyline(new[] { new Vector2(cx - 4, -7), new Vector2(cx + 3, 0), new Vector2(cx - 4, 7) }, new Color(1, 1, 1, 0.55f), 2.5f);
                        }
                        p.ResetTransform();
                    }
                    else p.TextureRect(tiles.Region(Assets.TILE_CELLS, idx), r);
                }
            // shadows cast by walls and blocks
            for (int y = 0; y < rows; y++)
                for (int x = 0; x < cols; x++)
                {
                    int ct = cells[y * cols + x];
                    if (ct == WALL) p.Rect(new Rect(x * T + 5, y * T + 8, T - 2, T - 4), new Color(0.2f, 0.12f, 0.08f, 0.3f));
                    else if (ct == BLOCK) p.Rect(new Rect(x * T + 5, y * T + 8, T - 2, T - 4), new Color(0.3f, 0.2f, 0.15f, 0.16f));
                }
            // shuffle warnings: pulsing stitched squares showing the coming terrain
            if (warn.Count > 0)
            {
                float pulse = 0.5f + 0.5f * Mathf.Sin(warnT * 14f);
                foreach (var kv in warn)
                {
                    var c = kv.Key;
                    var r = new Rect(c.x * T, c.y * T, T, T);
                    Color col = Terrain.Props(kv.Value).color;
                    p.Rect(Grow(r, -3), new Color(col.r, col.g, col.b, 0.35f + 0.4f * pulse));
                    Stitch(p, Grow(r, -5), new Color(0.55f, 0.3f, 0.35f, 0.5f + 0.5f * pulse));
                }
            }
            // walls, pillars and cushion blocks with a little pseudo height.
            // Permanent walls are tinted darker so they read clearly against floor and cushions.
            Color wallCol = ModeTheme.WallTint, borderCol = ModeTheme.BorderTint;
            for (int y = 0; y < rows; y++)
                for (int x = 0; x < cols; x++)
                {
                    int ct = cells[y * cols + x];
                    var r = new Rect(x * T, y * T, T, T);
                    if (ct == BORDER) p.TextureRect(tiles.Region(Assets.TILE_CELLS, 8), r, borderCol);
                    else if (ct == WALL) p.TextureRect(tiles.Region(Assets.TILE_CELLS, 6), new Rect(r.position - new Vector2(0, 6), new Vector2(T, T + 6)), wallCol);
                    else if (ct == BLOCK)
                    {
                        float squish = 1f + 0.02f * Mathf.Sin(animT * 2f + x * 1.3f + y * 0.7f);
                        float h = (T + 4) * squish;
                        p.TextureRect(tiles.Region(Assets.TILE_CELLS, 7), new Rect(new Vector2(r.x, r.yMax - h), new Vector2(T, h)));
                    }
                }
        }

        public static Rect Grow(Rect r, float by) => new Rect(r.x - by, r.y - by, r.width + 2 * by, r.height + 2 * by);

        static void Stitch(Painter p, Rect r, Color col)
        {
            p.DashedLine(r.min, new Vector2(r.xMax, r.yMin), col, 2f, 5f);
            p.DashedLine(new Vector2(r.xMax, r.yMin), r.max, col, 2f, 5f);
            p.DashedLine(r.max, new Vector2(r.xMin, r.yMax), col, 2f, 5f);
            p.DashedLine(new Vector2(r.xMin, r.yMax), r.min, col, 2f, 5f);
        }
    }
}
