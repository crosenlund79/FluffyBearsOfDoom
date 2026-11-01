// Immediate-mode 2D painter: a faithful stand-in for Godot's CanvasItem
// draw_* calls. Everything drawn in a frame is batched (in call order) into
// meshes and rendered with the FBD/Painter shader. Coordinates are Godot's
// 1280x720 y-down canvas pixels.
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public enum HAlign { Left, Center, Right }

    public class Painter
    {
        class Batch
        {
            public Texture tex; public bool alphaOnly;
            public readonly List<Vector3> v = new List<Vector3>();
            public readonly List<Color> c = new List<Color>();
            public readonly List<Vector2> uv = new List<Vector2>();
            public readonly List<int> tri = new List<int>();
            public Mesh mesh;
            public void Clear() { v.Clear(); c.Clear(); uv.Clear(); tri.Clear(); }
        }

        readonly List<Batch> pool = new List<Batch>();
        int used;
        Batch cur;
        readonly List<Material> materials = new List<Material>();
        Shader shader;
        MaterialPropertyBlock mpb;

        public Xf Base = Xf.Identity;    // like a node's global transform
        public Xf Local = Xf.Identity;   // like draw_set_transform
        public Color Modulate = Color.white;  // like CanvasModulate / node modulate
        Xf M;

        public Font font;
        public float pixelScale = 1f;       // screen pixels per canvas pixel (for crisp text)
        bool fontRebuilt;

        public Painter()
        {
            shader = Resources.Load<Shader>("FBDPainter");
            if (shader == null) shader = Shader.Find("Sprites/Default");
            mpb = new MaterialPropertyBlock();
            font = UiFont.Get();
            Font.textureRebuilt += f => { if (f == font) fontRebuilt = true; };
            M = Xf.Identity;
        }

        public void BeginFrame()
        {
            for (int i = 0; i < used; i++) pool[i].Clear();
            used = 0;
            cur = null;
            Base = Xf.Identity;
            Local = Xf.Identity;
            Modulate = Color.white;
            M = Xf.Identity;
            fontRebuilt = false;
        }

        // ---- transforms ----
        public void SetBase(Xf b) { Base = b; M = Base * Local; }
        public void SetTransform(Vector2 pos, float rot, Vector2 scale) { Local = Xf.TRS(pos, rot, scale); M = Base * Local; }
        public void SetTransform(Xf local) { Local = local; M = Base * Local; }
        public void ResetTransform() { Local = Xf.Identity; M = Base; }
        public Xf Current => M;

        Batch Get(Texture tex, bool alphaOnly)
        {
            if (cur != null && cur.tex == tex && cur.alphaOnly == alphaOnly && cur.v.Count < 60000) return cur;
            if (used == pool.Count) pool.Add(new Batch { mesh = NewMesh() });
            cur = pool[used++];
            cur.tex = tex;
            cur.alphaOnly = alphaOnly;
            return cur;
        }

        static Mesh NewMesh()
        {
            var m = new Mesh();
            m.MarkDynamic();
            return m;
        }

        static Vector3 W(Vector2 p) => new Vector3(p.x, -p.y, 0f);
        Color Mod(Color c) => new Color(c.r * Modulate.r, c.g * Modulate.g, c.b * Modulate.b, c.a * Modulate.a);

        void Quad(Texture tex, bool alphaOnly, Vector2 a, Vector2 b, Vector2 c, Vector2 d, Vector2 ua, Vector2 ub, Vector2 uc, Vector2 ud, Color col)
        {
            var bt = Get(tex, alphaOnly);
            int i = bt.v.Count;
            col = Mod(col);
            bt.v.Add(W(M.Apply(a))); bt.v.Add(W(M.Apply(b))); bt.v.Add(W(M.Apply(c))); bt.v.Add(W(M.Apply(d)));
            bt.uv.Add(ua); bt.uv.Add(ub); bt.uv.Add(uc); bt.uv.Add(ud);
            bt.c.Add(col); bt.c.Add(col); bt.c.Add(col); bt.c.Add(col);
            bt.tri.Add(i); bt.tri.Add(i + 1); bt.tri.Add(i + 2);
            bt.tri.Add(i); bt.tri.Add(i + 2); bt.tri.Add(i + 3);
        }

        void Tri(Vector2 a, Vector2 b, Vector2 c, Color col)
        {
            var bt = Get(Assets.Atlas, false);
            int i = bt.v.Count;
            col = Mod(col);
            Vector2 w = Assets.WhiteUV;
            bt.v.Add(W(M.Apply(a))); bt.v.Add(W(M.Apply(b))); bt.v.Add(W(M.Apply(c)));
            bt.uv.Add(w); bt.uv.Add(w); bt.uv.Add(w);
            bt.c.Add(col); bt.c.Add(col); bt.c.Add(col);
            bt.tri.Add(i); bt.tri.Add(i + 1); bt.tri.Add(i + 2);
        }

        // ---- shapes ----
        public void Rect(Rect r, Color col, bool filled = true, float width = 1f)
        {
            if (filled)
            {
                Vector2 w = Assets.WhiteUV;
                Quad(Assets.Atlas, false, r.min, new Vector2(r.xMax, r.yMin), r.max, new Vector2(r.xMin, r.yMax), w, w, w, w, col);
                return;
            }
            float h = width * 0.5f;
            Rect(new Rect(r.xMin - h, r.yMin - h, r.width + width, width), col);
            Rect(new Rect(r.xMin - h, r.yMax - h, r.width + width, width), col);
            Rect(new Rect(r.xMin - h, r.yMin + h, width, r.height - width), col);
            Rect(new Rect(r.xMax - h, r.yMin + h, width, r.height - width), col);
        }

        public void Circle(Vector2 center, float radius, Color col, int segs = 0)
        {
            if (radius <= 0f) return;
            if (segs <= 0) segs = Mathf.Clamp((int)(radius * 1.2f) + 12, 12, 64);
            Vector2 prev = center + new Vector2(radius, 0);
            for (int i = 1; i <= segs; i++)
            {
                float a = Gd.TAU * i / segs;
                Vector2 p = center + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * radius;
                Tri(center, prev, p, col);
                prev = p;
            }
        }

        public void Line(Vector2 a, Vector2 b, Color col, float width = 1f)
        {
            Vector2 d = b - a;
            float l = d.magnitude;
            if (l < 1e-5f) return;
            Vector2 n = new Vector2(-d.y, d.x) / l * Mathf.Max(width, 1f) * 0.5f;
            Vector2 w = Assets.WhiteUV;
            Quad(Assets.Atlas, false, a + n, b + n, b - n, a - n, w, w, w, w, col);
        }

        public void Polyline(IList<Vector2> pts, Color col, float width = 1f)
        {
            for (int i = 0; i + 1 < pts.Count; i++)
            {
                Line(pts[i], pts[i + 1], col, width);
                if (width > 2f && i + 1 < pts.Count - 1) Circle(pts[i + 1], width * 0.5f, col, 8);
            }
        }

        public void Arc(Vector2 center, float radius, float a0, float a1, int points, Color col, float width = 1f)
        {
            points = Mathf.Max(points, 2);
            Vector2 prev = center + new Vector2(Mathf.Cos(a0), Mathf.Sin(a0)) * radius;
            for (int i = 1; i < points; i++)
            {
                float a = Mathf.Lerp(a0, a1, (float)i / (points - 1));
                Vector2 p = center + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * radius;
                Line(prev, p, col, width);
                prev = p;
            }
        }

        /// Godot draw_dashed_line: dash and gap both `dash` long.
        public void DashedLine(Vector2 a, Vector2 b, Color col, float width = 1f, float dash = 2f)
        {
            float len = (b - a).magnitude;
            if (len < 1e-4f || dash <= 0f) return;
            Vector2 dir = (b - a) / len;
            int steps = Mathf.Max(1, Mathf.CeilToInt(len / (dash * 2f)));
            float step = len / steps;   // aligned: evenly stretch so both ends get a dash
            float dl = step * 0.5f;
            for (int i = 0; i < steps; i++)
            {
                float t = i * step;
                Line(a + dir * t, a + dir * Mathf.Min(t + dl, len), col, width);
            }
        }

        /// Convex (fan) polygon fill - all shapes in the game are convex.
        public void Polygon(IList<Vector2> pts, Color col)
        {
            for (int i = 1; i + 1 < pts.Count; i++) Tri(pts[0], pts[i], pts[i + 1], col);
        }

        // ---- textures ----
        public void TextureRect(Tex t, Rect dst, Color col)
        {
            Quad(Assets.Atlas, false, dst.min, new Vector2(dst.xMax, dst.yMin), dst.max, new Vector2(dst.xMin, dst.yMax),
                new Vector2(t.uv.xMin, t.uv.yMax), new Vector2(t.uv.xMax, t.uv.yMax), new Vector2(t.uv.xMax, t.uv.yMin), new Vector2(t.uv.xMin, t.uv.yMin), col);
        }
        public void TextureRect(Tex t, Rect dst) => TextureRect(t, dst, Color.white);

        /// The sprite's alpha only, filled with `col` (silhouettes / outlines).
        public void TextureSilhouette(Tex t, Rect dst, Color col)
        {
            Quad(Assets.Atlas, true, dst.min, new Vector2(dst.xMax, dst.yMin), dst.max, new Vector2(dst.xMin, dst.yMax),
                new Vector2(t.uv.xMin, t.uv.yMax), new Vector2(t.uv.xMax, t.uv.yMax), new Vector2(t.uv.xMax, t.uv.yMin), new Vector2(t.uv.xMin, t.uv.yMin), col);
        }

        /// A whole non-atlas texture (e.g. the generated Horror vignette).
        public void RawTexture(Texture tex, Rect dst, Color col)
        {
            Quad(tex, false, dst.min, new Vector2(dst.xMax, dst.yMin), dst.max, new Vector2(dst.xMin, dst.yMax),
                new Vector2(0, 1), new Vector2(1, 1), new Vector2(1, 0), new Vector2(0, 0), col);
        }

        // ---- text (Godot draw_string semantics: pos = baseline start) ----
        int ReqSize(int size) => Mathf.Clamp(Mathf.RoundToInt(size * pixelScale), 4, 300);

        public float TextWidth(string text, int size)
        {
            if (string.IsNullOrEmpty(text) || font == null) return 0f;
            int rs = ReqSize(size);
            font.RequestCharactersInTexture(text, rs, FontStyle.Normal);
            float w = 0f;
            foreach (char ch in text)
                if (font.GetCharacterInfo(ch, out CharacterInfo ci, rs, FontStyle.Normal)) w += ci.advance;
            return w * size / rs;
        }

        public void String(Vector2 pos, string text, HAlign align, float width, int size, Color col)
        {
            if (string.IsNullOrEmpty(text) || font == null) return;
            int rs = ReqSize(size);
            float k = (float)size / rs;
            font.RequestCharactersInTexture(text, rs, FontStyle.Normal);
            float tw = TextWidth(text, size);
            float x = pos.x;
            if (width > 0f)
            {
                if (align == HAlign.Center) x += (width - tw) * 0.5f;
                else if (align == HAlign.Right) x += width - tw;
            }
            foreach (char ch in text)
            {
                if (!font.GetCharacterInfo(ch, out CharacterInfo ci, rs, FontStyle.Normal)) continue;
                // glyph box in canvas space (y down: top = baseline - maxY)
                float x0 = x + ci.minX * k, x1 = x + ci.maxX * k;
                float y0 = pos.y - ci.maxY * k, y1 = pos.y - ci.minY * k;
                Quad(font.material.mainTexture, true, new Vector2(x0, y0), new Vector2(x1, y0), new Vector2(x1, y1), new Vector2(x0, y1),
                    ci.uvTopLeft, ci.uvTopRight, ci.uvBottomRight, ci.uvBottomLeft, col);
                x += ci.advance * k;
            }
        }

        /// Text with an outline (Label outline_size equivalent).
        public void StringOutlined(Vector2 pos, string text, HAlign align, float width, int size, Color col, Color outline, float thickness)
        {
            for (int i = 0; i < 8; i++)
            {
                float a = i * Gd.TAU / 8f;
                String(pos + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * thickness, text, align, width, size, outline);
            }
            String(pos, text, align, width, size, col);
        }

        /// Multi-line text, `\n` separated; returns total height.
        public float Text(Vector2 topLeft, string text, int size, Color col, float width = 0f, HAlign align = HAlign.Left, float lineGap = 1.25f)
        {
            float y = topLeft.y + size;
            foreach (string line in Wrap(text, size, width))
            {
                String(new Vector2(topLeft.x, y), line, align, width, size, col);
                y += size * lineGap;
            }
            return y - topLeft.y - size * (lineGap - 1f);
        }

        public List<string> Wrap(string text, int size, float width)
        {
            var lines = new List<string>();
            foreach (string para in text.Split('\n'))
            {
                if (width <= 0f) { lines.Add(para); continue; }
                string line = "";
                foreach (string word in para.Split(' '))
                {
                    string test = line.Length == 0 ? word : line + " " + word;
                    if (line.Length > 0 && TextWidth(test, size) > width) { lines.Add(line); line = word; }
                    else line = test;
                }
                lines.Add(line);
            }
            return lines;
        }

        // ---- submit ----
        public void Flush(Camera cam)
        {
            if (fontRebuilt) return; // glyph UVs moved this frame; next frame redraws correctly
            for (int i = 0; i < used; i++)
            {
                var b = pool[i];
                if (b.v.Count == 0) continue;
                b.mesh.Clear();
                b.mesh.SetVertices(b.v);
                b.mesh.SetColors(b.c);
                b.mesh.SetUVs(0, b.uv);
                b.mesh.SetTriangles(b.tri, 0);
                while (materials.Count <= i)
                {
                    var m = new Material(shader) { renderQueue = 3000 + materials.Count };
                    materials.Add(m);
                }
                mpb.Clear();
                if (b.tex != null) mpb.SetTexture("_MainTex", b.tex);
                mpb.SetFloat("_AlphaOnly", b.alphaOnly ? 1f : 0f);
                Graphics.DrawMesh(b.mesh, Matrix4x4.identity, materials[i], 0, cam, 0, mpb);
            }
        }
    }

    /// The serif UI font (Georgia & friends, like the Godot SystemFont).
    public static class UiFont
    {
        static Font font;
        public static Font Get()
        {
            if (font != null) return font;
            try
            {
                font = Font.CreateDynamicFontFromOSFont(new[] { "Georgia", "Palatino Linotype", "Palatino", "Book Antiqua",
                    "Bookman Old Style", "DejaVu Serif", "Liberation Serif", "Noto Serif", "Times New Roman" }, 32);
            }
            catch { font = null; }
            if (font == null)
            {
                try { font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); } catch { font = null; }
            }
            if (font == null)
            {
                try { font = Resources.GetBuiltinResource<Font>("Arial.ttf"); } catch { font = null; }
            }
            return font;
        }
    }
}
