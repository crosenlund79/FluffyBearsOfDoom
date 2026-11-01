// Audio settings panel (port of audio_panel.gd): volumes, mute, shuffle, next
// track. Changes apply and save immediately.
using UnityEngine;

namespace FBD
{
    public static class AudioPanel
    {
        /// Draws the panel at `pos` (440x400); returns true when "Done" is pressed.
        public static bool Draw(Gui gui, Vector2 pos)
        {
            Painter p = gui.p;
            var r = new Rect(pos, new Vector2(440, 400));
            Panel.Draw(p, r);
            float x = r.x + 22, y = r.y + 22;
            p.String(new Vector2(x, y + 30), "Audio", HAlign.Left, -1, 30, UiStyle.ROSE_DARK);
            y += 46;
            string[] labels = { "Master", "Music", "Sound effects" };
            for (int i = 0; i < 3; i++)
            {
                p.String(new Vector2(x, y + 21), labels[i], HAlign.Left, -1, 18, UiStyle.INK);
                float v = i == 0 ? Settings.master_volume : i == 1 ? Settings.music_volume : Settings.sfx_volume;
                float nv = gui.Slider(new Rect(x + 150, y + 2, 230, 28), v);
                if (Mathf.Abs(nv - v) > 1e-4f)
                {
                    if (i == 0) Settings.master_volume = nv; else if (i == 1) Settings.music_volume = nv; else Settings.sfx_volume = nv;
                    Settings.Save();
                }
                y += 38;
            }
            bool m = gui.Check(new Rect(x, y, 300, 32), "Mute everything", Settings.muted);
            if (m != Settings.muted) { Settings.muted = m; Settings.Save(); }
            y += 40;
            bool sh = gui.Check(new Rect(x, y, 300, 32), "Shuffle music", Settings.shuffle_music);
            if (sh != Settings.shuffle_music) { Settings.shuffle_music = sh; Music.Reshuffle(); Settings.Save(); }
            y += 44;
            if (gui.Button(new Rect(x, y, 170, 40), "Next track  (N)", 18)) Music.NextTrack();
            string np = !Music.HasTracks()
                ? "No music found for " + Music.context + ". Add mp3/ogg/wav files to StreamingAssets/Audio/music/" + Music.context + "/"
                : "Now playing: " + (Music.title != "" ? Music.title : "-");
            p.Text(new Vector2(x + 182, y - 2), np, 14, UiStyle.INK_SOFT, 214f);
            y += 64;
            if (gui.Button(new Rect(x, y, r.width - 44, 40), "Done", 18)) { Sfx.Play("menu"); return true; }
            return false;
        }
    }

    /// The stitched PanelContainer look (port of stitch_panel.gd).
    public static class Panel
    {
        public static void Draw(Painter p, Rect r)
        {
            UiStyle.Box(p, r, UiStyle.PAPER, Gd.Lerp(UiStyle.FRAME, UiStyle.INK_SOFT, 0.3f), 18f, 2f);
            var stitch = Gd.Lerp(UiStyle.ROSE, UiStyle.INK_SOFT, 0.4f);
            UiStyle.StitchRect(p, new Rect(r.x + 7, r.y + 7, r.width - 14, r.height - 14), stitch, 1.6f, 6f);
        }
    }
}
