// Title menu (port of menu.gd): mode, players, AI difficulty, arena, round
// length, audio, controls, quit - plus the parade of waddling bears.
using System;
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public class Menu
    {
        readonly Gui gui;
        Painter p => gui.p;
        readonly List<Puppet> puppets = new List<Puppet>();
        readonly List<BearVisual> visuals = new List<BearVisual>();
        readonly float[] holderX = new float[4];
        float t;
        string overlay = "";   // "", "audio", "controls"
        static readonly float[] FLUFFS = { 25f, 100f, 210f, 360f };
        static readonly string[] NAMES = { "Player", "Oswald", "Harald", "Theodor" };

        public event Action StartRequested, ModeChanged, QuitRequested;

        public Menu(Gui g)
        {
            gui = g;
            Color[] colors = { Settings.HUMAN_COLORS[0], Settings.AI_COLORS[0], Settings.AI_COLORS[1], Settings.AI_COLORS[2] };
            for (int i = 0; i < 4; i++)
            {
                var pp = new Puppet { fluff = FLUFFS[i] };
                puppets.Add(pp);
                visuals.Add(new BearVisual(pp, ModeTheme.BearColor(colors[i]), i * 2f, Species.ForName(NAMES[i])));
            }
            gui.Focus(IndexOfStart());
            Music.PlayContext("menu");
        }

        // focus order: mode x3, players, 3 AI levels, (sitting out), arena, round length, Start
        int IndexOfStart() => 3 + 1 + 3 + (Settings.human_count == 2 ? 1 : 0) + 1 + 1;

        public void Update(float delta)
        {
            t += delta;
            // waddle back and forth: heavier bears are slower and clumsier
            for (int i = 0; i < puppets.Count; i++)
            {
                var pp = puppets[i];
                float g = pp.fluff / 100f;
                float w = 1.4f / (0.6f + 0.4f * g);
                const float amp = 34f;
                float x = Mathf.Sin(t * w + i) * amp;
                float vx = Mathf.Cos(t * w + i) * amp * w;
                holderX[i] = 110 + i * 150 + x;
                pp.velocity = new Vector2(vx * 1.6f, 0);
                pp.facing = Mathf.Abs(vx) > 12f ? new Vector2(Gd.Sign(vx), 0) : new Vector2(0, 1);
                visuals[i].Update(delta);
            }
        }

        public void Draw()
        {
            p.SetBase(Xf.Identity);
            p.ResetTransform();
            UiStyle.Wallpaper(p, new Rect(0, 0, 1280, 720));
            p.Rect(new Rect(40, 380, 640, 90), Gd.WithAlpha(UiStyle.FRAME, 0.8f));
            UiStyle.StitchRect(p, new Rect(46, 386, 628, 78), Gd.WithAlpha(UiStyle.ROSE_DARK, 0.6f), 1.6f, 6f);

            p.StringOutlined(new Vector2(48, 40 + 64), "Fluffy Bears of Doom", HAlign.Left, -1, 64, UiStyle.ROSE_DARK, UiStyle.PAPER, 4f);
            p.String(new Vector2(54, 124 + 22), ModeTheme.Text(ModeTheme.SUBTITLE), HAlign.Left, -1, 22, UiStyle.INK_SOFT);
            for (int i = 0; i < 4; i++)
            {
                visuals[i].Draw(p, Xf.TRS(new Vector2(holderX[i], 430), 0f, new Vector2(1.6f, 1.6f)));
                p.SetBase(Xf.Identity);
                p.Text(new Vector2(30 + i * 150, 470), NAMES[i] + "\n" + Species.Info(Species.ForName(NAMES[i])).label, 16, UiStyle.INK_SOFT, 160, HAlign.Center);
            }
            p.Text(new Vector2(54, 560), ModeTheme.Text(ModeTheme.BLURB), 16, UiStyle.INK, 640);

            gui.inert = overlay != "";
            DrawPanel();
            gui.inert = false;
            if (overlay == "audio" && AudioPanel.Draw(gui, new Vector2(420, 150))) CloseOverlay();
            if (overlay == "controls") DrawControls();
            if (overlay != "" && gui.BackPressed && !gui.PopupOpen) CloseOverlay();
        }

        void CloseOverlay() { overlay = ""; gui.Focus(IndexOfStart()); }

        void DrawPanel()
        {
            var r = new Rect(740, 70, 500, 590);
            Panel.Draw(p, r);
            float x = r.x + 22, w = r.width - 44, y = r.y + 22;
            // Normal / Horror / Custom: same game, different nursery. Switches immediately.
            // Custom = your own sprites from Sprites/<folder>/custom/, Normal for the rest.
            p.String(new Vector2(x, y + 28), "Mode", HAlign.Left, -1, 24, UiStyle.ROSE_DARK);
            string[] modeLabels = { "Normal", "Horror", "Custom" };
            for (int i = 0; i < 3; i++)
                if (gui.Button(new Rect(x + 110 + i * 110, y, 100, 38), modeLabels[i], 18, Settings.mode == Settings.MODES[i])) SetMode(Settings.MODES[i]);
            y += 46;
            p.String(new Vector2(x, y + 28), "Players", HAlign.Left, -1, 24, UiStyle.ROSE_DARK);
            int hc = gui.Option(new Rect(x + 152, y, 220, 38), new[] { "One Human", "Two Humans" }, Mathf.Clamp(Settings.human_count, 1, 2) - 1) + 1;
            if (hc != Settings.human_count) { Settings.human_count = hc; Settings.Save(); }
            y += 46;
            p.String(new Vector2(x, y + 24), "Opponents", HAlign.Left, -1, 22, UiStyle.ROSE_DARK);
            y += 34;
            for (int i = 0; i < 3; i++)
            {
                p.Rect(new Rect(x, y + 7, 22, 22), ModeTheme.BearColor(Settings.AI_COLORS[i]));
                p.String(new Vector2(x + 34, y + 25), Settings.AI_NAMES[i], HAlign.Left, -1, 20, UiStyle.INK);
                int cur = Array.IndexOf(Settings.LEVELS, Settings.ai_levels[i]);
                int sel = gui.Option(new Rect(x + 166, y, 170, 36), Settings.LEVEL_LABELS, cur);
                if (sel != cur) { Settings.ai_levels[i] = Settings.LEVELS[sel]; Settings.Save(); }
                y += 44;
            }
            if (Settings.human_count == 2)
            {
                p.String(new Vector2(x, y + 24), "Sitting out", HAlign.Left, -1, 18, UiStyle.INK_SOFT);
                int so = gui.Option(new Rect(x + 166, y, 170, 36), Settings.AI_NAMES, Settings.sitting_out);
                if (so != Settings.sitting_out) { Settings.sitting_out = so; Settings.Save(); }
                y += 44;
            }
            p.String(new Vector2(x, y + 24), "Arena", HAlign.Left, -1, 22, UiStyle.ROSE_DARK);
            y += 34;
            var mapNames = new string[ArenaMaps.MAPS.Length];
            for (int i = 0; i < mapNames.Length; i++) mapNames[i] = ArenaMaps.MAPS[i].name;
            int ai = gui.Option(new Rect(x, y, w, 36), mapNames, Settings.arena_index);
            if (ai != Settings.arena_index) { Settings.arena_index = ai; Settings.Save(); }
            y += 42;
            float dh = p.Text(new Vector2(x, y), ArenaMaps.MAPS[Settings.arena_index].desc, 15, UiStyle.INK_SOFT, 440);
            y += Mathf.Max(40f, dh) + 6;
            p.String(new Vector2(x, y + 25), "Round length", HAlign.Left, -1, 20, UiStyle.INK);
            int ti = gui.Option(new Rect(x + 152, y, 100, 36), new[] { "1:30", "2:30", "4:00" }, Settings.round_time_index);
            if (ti != Settings.round_time_index) { Settings.round_time_index = ti; Settings.Save(); }
            y += 46;
            if (gui.Button(new Rect(x, y, w, 54), "Start Game", 26)) { Sfx.Play("go"); StartRequested?.Invoke(); }
            y += 62;
            float bx = x + (w - (136 * 3 + 20)) * 0.5f;
            if (gui.Button(new Rect(bx, y, 136, 40), "Settings", 18)) { Sfx.Play("menu"); overlay = "audio"; gui.Focus(0); }
            if (gui.Button(new Rect(bx + 146, y, 136, 40), "Controls", 18)) { Sfx.Play("menu"); overlay = "controls"; gui.Focus(0); }
            if (gui.Button(new Rect(bx + 292, y, 136, 40), "Quit", 18)) QuitRequested?.Invoke();
        }

        void SetMode(string m)
        {
            if (m == Settings.mode) return;
            Settings.SetMode(m);
            Settings.Save();
            Sfx.Play("mode");
            ModeChanged?.Invoke(); // the app rebuilds the menu in the new look; music switches
        }

        void DrawControls()
        {
            var r = new Rect(250, 120, 780, 470);
            Panel.Draw(p, r);
            float x = r.x + 22, y = r.y + 22;
            p.String(new Vector2(x, y + 30), "Controls", HAlign.Left, -1, 30, UiStyle.ROSE_DARK);
            y += 46;
            string[][] rows =
            {
                new[] { "", "Player 1", "Player 2" }, new[] { "Move", "W A S D", "Arrow keys" }, new[] { "Place bomb", "Space", "Enter" },
                new[] { "Steal fluff (hold)", "Left Shift", "Right Ctrl" }, new[] { "Line Bomb", "E", "Right Shift" },
                new[] { "Gamepad", "stick/d-pad, A, X/B/RT, Y/LB", "second pad" },
            };
            float[] colX = new float[3];
            float cx = x;
            for (int c = 0; c < 3; c++)
            {
                colX[c] = cx;
                float mw = 0f;
                foreach (var row in rows) mw = Mathf.Max(mw, p.TextWidth(row[c], 18));
                cx += mw + 40f;
            }
            foreach (var row in rows)
            {
                for (int c = 0; c < 3; c++) p.String(new Vector2(colX[c], y + 20), row[c], HAlign.Left, -1, 18, row[0] == "" ? UiStyle.ROSE_DARK : UiStyle.INK);
                y += 28;
            }
            y += 6;
            y += p.Text(new Vector2(x, y), "Playing alone? Both keyboard layouts work for you.\nKick: every bear kicks bombs by walking into them.  Rubber Bombs bounce off walls.\nRemote Detonator: the special key (E / R-Shift) sets off your remote bombs.\nPause: Esc / P    Next music track: N\n\nCurses: Reverse Controls flips your steering and spreads to bears you touch.\nBomb Diarrhea drops bombs on its own. Immortality: no stuns, no theft for 20 s.", 16, UiStyle.INK_SOFT) + 10;
            if (gui.Button(new Rect(x, y, r.width - 44, 40), "Done", 18)) CloseOverlay();
        }
    }
}
