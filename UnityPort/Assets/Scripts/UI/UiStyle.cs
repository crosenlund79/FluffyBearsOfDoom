// Nursery-of-Doom palette and drawing helpers (port of ui_style.gd).
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public static class UiStyle
    {
        public static Color CREAM, PAPER, INK, INK_SOFT, ROSE, ROSE_DARK, BLUE, GREEN, BROWN, STRIPE, BAR, FRAME, GOOD, GOLD, CURSE;
        static string mode = "normal";

        static readonly Dictionary<string, Dictionary<string, string>> PALETTES = new Dictionary<string, Dictionary<string, string>>
        {
            { "normal", new Dictionary<string, string> { {"CREAM","f4ecdc"}, {"PAPER","fbf5e8"}, {"INK","5b4636"}, {"INK_SOFT","8a7563"}, {"ROSE","d8a0a6"},
                {"ROSE_DARK","b9787f"}, {"BLUE","9db4c8"}, {"GREEN","a9bf98"}, {"BROWN","8a6a50"}, {"STRIPE","d9a8ad1a"},
                {"BAR","eadfcb"}, {"FRAME","dbc2a8"}, {"GOOD","6c8f5e"}, {"GOLD","b08a2e"}, {"CURSE","7a5a8c"} } },
            { "horror", new Dictionary<string, string> { {"CREAM","1e1719"}, {"PAPER","2e2426"}, {"INK","e3d4c1"}, {"INK_SOFT","a08d82"}, {"ROSE","6e1f27"},
                {"ROSE_DARK","c9363f"}, {"BLUE","3e4a57"}, {"GREEN","4f5a44"}, {"BROWN","4a3329"}, {"STRIPE","00000040"},
                {"BAR","3e3033"}, {"FRAME","3b2a2a"}, {"GOOD","9fae78"}, {"GOLD","d1a548"}, {"CURSE","a77fc0"} } },
        };

        static UiStyle() { ApplyMode("normal"); }

        public static void ApplyMode(string m)
        {
            if (!PALETTES.ContainsKey(m)) m = "normal";
            mode = m;
            var p = PALETTES[m];
            CREAM = Gd.Hex(p["CREAM"]); PAPER = Gd.Hex(p["PAPER"]); INK = Gd.Hex(p["INK"]); INK_SOFT = Gd.Hex(p["INK_SOFT"]);
            ROSE = Gd.Hex(p["ROSE"]); ROSE_DARK = Gd.Hex(p["ROSE_DARK"]); BLUE = Gd.Hex(p["BLUE"]); GREEN = Gd.Hex(p["GREEN"]);
            BROWN = Gd.Hex(p["BROWN"]); STRIPE = Gd.Hex(p["STRIPE"]); BAR = Gd.Hex(p["BAR"]); FRAME = Gd.Hex(p["FRAME"]);
            GOOD = Gd.Hex(p["GOOD"]); GOLD = Gd.Hex(p["GOLD"]); CURSE = Gd.Hex(p["CURSE"]);
        }

        /// Dashed "stitch" outline inset inside `rect`.
        public static void StitchRect(Painter p, Rect r, Color color, float width = 2f, float dash = 7f)
        {
            Vector2 a = r.min, b = new Vector2(r.xMax, r.yMin), c = r.max, d = new Vector2(r.xMin, r.yMax);
            p.DashedLine(a, b, color, width, dash);
            p.DashedLine(b, c, color, width, dash);
            p.DashedLine(c, d, color, width, dash);
            p.DashedLine(d, a, color, width, dash);
        }

        /// Gingham nursery wallpaper (dim and stained in Horror mode).
        public static void Wallpaper(Painter p, Rect rect)
        {
            p.Rect(rect, CREAM);
            float step = 36f;
            for (float x = rect.xMin; x < rect.xMax; x += step) p.Rect(new Rect(x, rect.yMin, step * 0.5f, rect.height), STRIPE);
            for (float y = rect.yMin; y < rect.yMax; y += step) p.Rect(new Rect(rect.xMin, y, rect.width, step * 0.5f), STRIPE);
            if (mode == "horror")
            {
                for (int i = 0; i < 14; i++)
                {
                    float dx = rect.xMin + (i * 397f) % rect.width;
                    float len = 60f + (i * 131f) % 220f;
                    var col = new Color(0.35f, 0.02f, 0.05f, 0.35f);
                    p.Rect(new Rect(dx, rect.yMin, 3f + i % 3, len), col);
                    p.Circle(new Vector2(dx + 2f, rect.yMin + len), 4f, col);
                    p.Circle(new Vector2(dx + (i * 53f) % 90f, rect.yMin + (i * 211f) % rect.height), 10f + (i * 7f) % 18f, new Color(0, 0, 0, 0.18f));
                }
            }
        }

        /// Rounded "StyleBoxFlat" look: shadow, fill, border.
        public static void Box(Painter p, Rect r, Color bg, Color border, float radius = 14f, float bw = 2f, bool shadow = true)
        {
            if (shadow) RoundRect(p, new Rect(r.x, r.y + 2f, r.width, r.height + 1f), radius, new Color(0.36f, 0.27f, 0.2f, 0.18f));
            if (bw > 0f && border.a > 0f) RoundRect(p, r, radius, border);
            RoundRect(p, new Rect(r.x + bw, r.y + bw, r.width - bw * 2f, r.height - bw * 2f), Mathf.Max(0f, radius - bw), bg);
        }

        /// Rounded outline only (focus ring), like a StyleBoxFlat with a transparent fill.
        public static void RoundRectOutline(Painter p, Rect r, float radius, Color c, float width)
        {
            radius = Mathf.Min(radius, Mathf.Min(r.width, r.height) * 0.5f);
            float h = width * 0.5f;
            p.Rect(new Rect(r.x + radius, r.y, r.width - 2f * radius, width), c);
            p.Rect(new Rect(r.x + radius, r.yMax - width, r.width - 2f * radius, width), c);
            p.Rect(new Rect(r.x, r.y + radius, width, r.height - 2f * radius), c);
            p.Rect(new Rect(r.xMax - width, r.y + radius, width, r.height - 2f * radius), c);
            p.Arc(new Vector2(r.x + radius, r.y + radius), radius - h, Mathf.PI, Mathf.PI * 1.5f, 8, c, width);
            p.Arc(new Vector2(r.xMax - radius, r.y + radius), radius - h, Mathf.PI * 1.5f, Mathf.PI * 2f, 8, c, width);
            p.Arc(new Vector2(r.xMax - radius, r.yMax - radius), radius - h, 0f, Mathf.PI * 0.5f, 8, c, width);
            p.Arc(new Vector2(r.x + radius, r.yMax - radius), radius - h, Mathf.PI * 0.5f, Mathf.PI, 8, c, width);
        }

        public static void RoundRect(Painter p, Rect r, float radius, Color c)
        {
            radius = Mathf.Min(radius, Mathf.Min(r.width, r.height) * 0.5f);
            if (radius <= 0.5f) { p.Rect(r, c); return; }
            p.Rect(new Rect(r.x + radius, r.y, r.width - 2f * radius, r.height), c);
            p.Rect(new Rect(r.x, r.y + radius, radius, r.height - 2f * radius), c);
            p.Rect(new Rect(r.xMax - radius, r.y + radius, radius, r.height - 2f * radius), c);
            Corner(p, new Vector2(r.x + radius, r.y + radius), radius, Mathf.PI, c);
            Corner(p, new Vector2(r.xMax - radius, r.y + radius), radius, Mathf.PI * 1.5f, c);
            Corner(p, new Vector2(r.xMax - radius, r.yMax - radius), radius, 0f, c);
            Corner(p, new Vector2(r.x + radius, r.yMax - radius), radius, Mathf.PI * 0.5f, c);
        }

        static void Corner(Painter p, Vector2 center, float radius, float a0, Color c)
        {
            const int segs = 6;
            var pts = new List<Vector2> { center };
            for (int i = 0; i <= segs; i++)
            {
                float a = a0 + Mathf.PI * 0.5f * i / segs;
                pts.Add(center + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * radius);
            }
            p.Polygon(pts, c);
        }
    }
}
