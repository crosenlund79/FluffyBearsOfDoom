// A small "now playing" pill that slides in briefly when a track starts or
// changes (port of now_playing.gd). Drawn outside the play area.
using UnityEngine;

namespace FBD
{
    public static class NowPlaying
    {
        const float SHOW_TIME = 4f;
        static string title = "";
        static float age = 99f;
        static bool hooked;

        public static void Init()
        {
            if (hooked) return;
            hooked = true;
            Music.TrackChanged += t => { if (!string.IsNullOrEmpty(t)) { title = t; age = 0f; } };
        }

        public static void Update(float delta) { if (age < SHOW_TIME + 1f) age += delta; }

        public static void Draw(Painter p, Vector2 pos)
        {
            if (title == "" || age > SHOW_TIME + 0.6f) return;
            float appear = Gd.Clamp(age / 0.35f, 0f, 1f);
            float fade = 1f - Gd.Clamp((age - SHOW_TIME) / 0.6f, 0f, 1f);
            float a = appear * fade;
            string text = "Now playing: " + title;
            const int fs = 15;
            float w = p.TextWidth(text, fs) + 44f;
            p.SetBase(Xf.Translate(pos));
            p.ResetTransform();
            float x = -18f * (1f - appear);
            var r = new Rect(x, 0, w, 26);
            p.Rect(r, Gd.WithAlpha(UiStyle.PAPER, 0.9f * a));
            p.Rect(r, Gd.WithAlpha(UiStyle.ROSE_DARK, 0.8f * a), false, 1.4f);
            // a little drawn music note (no special glyph needed)
            Vector2 n = new Vector2(x + 14, 18);
            Color ink = Gd.WithAlpha(UiStyle.ROSE_DARK, a);
            p.Circle(n, 3.6f, ink);
            p.Line(n + new Vector2(3.2f, 0), n + new Vector2(3.2f, -11), ink, 1.6f);
            p.Line(n + new Vector2(3.2f, -11), n + new Vector2(8, -8), ink, 1.6f);
            p.String(new Vector2(x + 28, 18), text, HAlign.Left, -1, fs, Gd.WithAlpha(UiStyle.INK, a));
            p.SetBase(Xf.Identity);
        }
    }
}
