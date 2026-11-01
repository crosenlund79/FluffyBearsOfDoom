// Small helpers that reproduce Godot's math/colour semantics so the port
// behaves exactly like the original (e.g. sign(0) == 0, y-down rotation).
using System;
using UnityEngine;

namespace FBD
{
    public static class Gd
    {
        public const float PI = Mathf.PI;
        public const float TAU = Mathf.PI * 2f;

        public static float Sign(float v) => v > 0f ? 1f : (v < 0f ? -1f : 0f);
        public static int FloorI(float v) => Mathf.FloorToInt(v);
        public static int CeilI(float v) => Mathf.CeilToInt(v);
        public static float Lerp(float a, float b, float t) => a + (b - a) * t;
        public static float SmoothStep(float from, float to, float x) { if (from == to) return x < from ? 0f : 1f; float k = Clamp01((x - from) / (to - from)); return k * k * (3f - 2f * k); }
        public static float Clamp(float v, float a, float b) => v < a ? a : (v > b ? b : v);
        public static float Clamp01(float v) => Clamp(v, 0f, 1f);
        public static float MoveToward(float from, float to, float delta)
        {
            if (Mathf.Abs(to - from) <= delta) return to;
            return from + Sign(to - from) * delta;
        }
        public static float Fmod(float a, float b) => a % b;
        public static float PosMod(float a, float b) { float r = a % b; return r < 0 ? r + b : r; }

        public static Vector2 Rotated(Vector2 v, float a)
        {
            float c = Mathf.Cos(a), s = Mathf.Sin(a);
            return new Vector2(v.x * c - v.y * s, v.x * s + v.y * c);
        }
        public static float Angle(Vector2 v) => Mathf.Atan2(v.y, v.x);
        public static Vector2 LimitLength(Vector2 v, float len) => v.magnitude > len ? v.normalized * len : v;
        public static Vector2 MoveToward(Vector2 from, Vector2 to, float delta)
        {
            Vector2 d = to - from;
            float l = d.magnitude;
            return l <= delta || l < 1e-6f ? to : from + d / l * delta;
        }

        // ---- colours (Godot semantics) ----
        public static Color Hex(string hex)
        {
            hex = hex.TrimStart('#');
            float r = Convert.ToInt32(hex.Substring(0, 2), 16) / 255f;
            float g = Convert.ToInt32(hex.Substring(2, 2), 16) / 255f;
            float b = Convert.ToInt32(hex.Substring(4, 2), 16) / 255f;
            float a = hex.Length >= 8 ? Convert.ToInt32(hex.Substring(6, 2), 16) / 255f : 1f;
            return new Color(r, g, b, a);
        }
        public static Color Lerp(Color a, Color b, float t) => Color.LerpUnclamped(a, b, t);
        public static Color Darkened(Color c, float amount) => new Color(c.r * (1f - amount), c.g * (1f - amount), c.b * (1f - amount), c.a);
        public static Color Lightened(Color c, float amount) => new Color(c.r + (1f - c.r) * amount, c.g + (1f - c.g) * amount, c.b + (1f - c.b) * amount, c.a);
        public static Color WithAlpha(Color c, float a) => new Color(c.r, c.g, c.b, a);
        public static Color Mul(Color a, Color b) => new Color(a.r * b.r, a.g * b.g, a.b * b.b, a.a * b.a);
        public static Color FromHsv(float h, float s, float v, float a = 1f) { var c = Color.HSVToRGB(PosMod(h, 1f), Clamp01(s), Clamp01(v)); c.a = a; return c; }
        public static float Hue(Color c) { Color.RGBToHSV(c, out float h, out _, out _); return h; }
        public static float Sat(Color c) { Color.RGBToHSV(c, out _, out float s, out _); return s; }
    }

    /// <summary>Seedable RNG (managed only, so game logic also runs outside the engine).</summary>
    public class Rng
    {
        public static readonly Rng Global = new Rng();
        System.Random r;
        public Rng() { r = new System.Random(Guid.NewGuid().GetHashCode()); }
        public Rng(int seed) { r = new System.Random(seed); }
        public float F() => (float)r.NextDouble();
        public float Range(float a, float b) => a + (b - a) * F();
        public int RangeI(int a, int b) => r.Next(a, b + 1); // inclusive like Godot randi_range
        public int Int(int n) => n <= 0 ? 0 : r.Next(n);
        public T Pick<T>(System.Collections.Generic.IList<T> list) => list[Int(list.Count)];
        public void Shuffle<T>(System.Collections.Generic.IList<T> list)
        {
            for (int i = list.Count - 1; i > 0; i--) { int j = r.Next(i + 1); T t = list[i]; list[i] = list[j]; list[j] = t; }
        }
    }
}
