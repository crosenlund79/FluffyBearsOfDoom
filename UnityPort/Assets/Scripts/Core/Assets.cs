// Replaceable art loader (port of assets.gd). For "bears/bear" in the current
// mode it uses the first file that exists under StreamingAssets/Sprites/:
//   1. bears/<mode>/bear.png            your mode-specific art
//   2. bears/bear.png                   your shared art
//   3. bears/<mode>/template_bear.png   built-in mode placeholder
//   4. bears/template_bear.png          built-in placeholder
// Creator files always win; templates never overwrite anything. Files are read
// at runtime, so art can be replaced even in a built game.
// All sheets of a mode are packed into one atlas (plus a white patch for shapes).
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace FBD
{
    /// A rectangle of the atlas plus its size in source pixels.
    public struct Tex
    {
        public Rect uv; public Vector2 size;
        public float Width => size.x;
        public float Height => size.y;
        /// Cell `index` of a single-row sheet with `cells` cells.
        public Tex Region(int cells, int index)
        {
            float w = uv.width / cells;
            return new Tex { uv = new Rect(uv.xMin + w * index, uv.yMin, w, uv.height), size = new Vector2(size.x / cells, size.y) };
        }
    }

    public static class Assets
    {
        public const int BEAR_CELLS = 10;    // body, belly, head, ear, arm, leg, face x4
        public const int TILE_CELLS = 9;     // rug, rug alt, ice, honey, bouncy, conveyor, pillar, cushion block, border
        public const int POWERUP_CELLS = 10; // bomb, blast, speed, shuffle, kick, line, rubber, immortal, reverse, diarrhea
        public const int EFFECT_CELLS = 8;   // blast centre, blast arm, blast end, star, dust, sparkle, bird, floor splat

        public static readonly string[] SHEETS = { "bears/bear", "tiles/tiles", "objects/bomb", "objects/fluff", "objects/duck", "powerups/powerups", "effects/effects" };

        public static Texture2D Atlas;
        public static Vector2 WhiteUV;
        static readonly Dictionary<string, Tex> texs = new Dictionary<string, Tex>();
        static string builtFor = "";
        public static readonly Dictionary<string, string> Resolved = new Dictionary<string, string>();

        public static string Root => Path.Combine(Application.streamingAssetsPath, "Sprites");

        public static Tex Get(string rel)
        {
            Ensure();
            return texs.TryGetValue(rel, out Tex t) ? t : new Tex { uv = new Rect(WhiteUV, Vector2.zero), size = new Vector2(8, 8) };
        }

        /// Rebuild the atlas when the mode changed (or on first use).
        public static void Ensure()
        {
            if (builtFor == Settings.mode && Atlas != null) return;
            builtFor = Settings.mode;
            Build();
        }

        public static void Invalidate() { builtFor = ""; }

        /// The file `Get(rel)` uses in the current mode ("" if none exists).
        public static string Resolve(string rel)
        {
            string mode = Settings.mode;
            string folder = Path.Combine(Root, Path.GetDirectoryName(rel));
            string file = Path.GetFileName(rel);
            string[] candidates =
            {
                Path.Combine(folder, mode, file + ".png"),
                Path.Combine(folder, file + ".png"),
                Path.Combine(folder, mode, "template_" + file + ".png"),
                Path.Combine(folder, "template_" + file + ".png"),
            };
            foreach (string c in candidates)
                if (File.Exists(c)) return c;
            return "";
        }

        static void Build()
        {
            var list = new List<Texture2D>();
            var white = new Texture2D(4, 4, TextureFormat.RGBA32, false);
            var px = new Color32[16];
            for (int i = 0; i < 16; i++) px[i] = new Color32(255, 255, 255, 255);
            white.SetPixels32(px);
            white.Apply();
            list.Add(white);
            Resolved.Clear();
            foreach (string rel in SHEETS)
            {
                string path = Resolve(rel);
                Resolved[rel] = path;
                Texture2D t = null;
                if (path != "")
                {
                    t = new Texture2D(2, 2, TextureFormat.RGBA32, false);
                    if (!t.LoadImage(File.ReadAllBytes(path))) t = null;
                }
                if (t == null)
                {
                    Debug.LogWarning("Missing sprite: " + rel);
                    t = new Texture2D(8, 8, TextureFormat.RGBA32, false);
                    var m = new Color[64];
                    for (int i = 0; i < 64; i++) m[i] = Color.magenta;
                    t.SetPixels(m);
                    t.Apply();
                }
                list.Add(t);
            }
            if (Atlas != null) Object.Destroy(Atlas);
            Atlas = new Texture2D(2, 2, TextureFormat.RGBA32, false);
            Rect[] rects = Atlas.PackTextures(list.ToArray(), 2, 8192, false);
            Atlas.filterMode = FilterMode.Bilinear;
            Atlas.wrapMode = TextureWrapMode.Clamp;
            Rect wr = rects[0];
            WhiteUV = wr.center;
            texs.Clear();
            for (int i = 0; i < SHEETS.Length; i++)
            {
                texs[SHEETS[i]] = new Tex { uv = rects[i + 1], size = new Vector2(list[i + 1].width, list[i + 1].height) };
            }
            foreach (var t in list) Object.Destroy(t);
        }
    }
}
