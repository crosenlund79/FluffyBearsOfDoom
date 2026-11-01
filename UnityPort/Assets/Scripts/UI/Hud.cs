// In-match interface (port of hud.gd): timer, bear cards, banners, toasts,
// pause menu, audio settings and the results screen.
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public class Hud : IHud
    {
        readonly Game game;
        readonly Gui gui;
        Painter p => gui.p;
        readonly float[] shown;

        // banner
        string bannerText = "";
        float bannerAge = 99f, bannerDur;
        // toasts
        class ToastItem { public string text; public Color col; public float age; }
        readonly List<ToastItem> toasts = new List<ToastItem>();
        // panels
        bool pauseOpen, audioOpen, resultsOpen;
        List<Bear> ranking;
        float resultsAge, wobT;
        BearVisual champ;
        Puppet champPuppet;
        public bool AudioOpen => audioOpen;

        public Hud(Game g, Gui gu)
        {
            game = g; gui = gu;
            shown = new float[4];
            for (int i = 0; i < shown.Length; i++) shown[i] = Tuning.START_FLUFF;
        }

        // ---- IHud ----
        public void Banner(string text, float duration) { bannerText = text; bannerAge = 0f; bannerDur = duration; }
        public void Toast(string text, Color col)
        {
            toasts.Add(new ToastItem { text = text, col = col });
            if (toasts.Count > 3) toasts.RemoveAt(0);
        }
        public void ShowPause(bool paused)
        {
            pauseOpen = paused;
            if (!paused) audioOpen = false;
            gui.Focus(0);
        }
        public void ShowResults(List<Bear> r)
        {
            ranking = r;
            resultsOpen = true;
            resultsAge = 0f;
            Bear winner = r[0];
            champPuppet = new Puppet { fluff = Mathf.Max(winner.fluff, 20f), smug = true };
            champ = new BearVisual(champPuppet, winner.color, 0f);
            gui.Focus(0);
        }

        public void CloseAudio() { audioOpen = false; gui.Focus(1); }

        public void Update(float delta)
        {
            for (int i = 0; i < game.bears.Count; i++) shown[i] = Gd.Lerp(shown[i], game.bears[i].fluff, 1f - Mathf.Exp(-delta * 10f));
            bannerAge += delta;
            foreach (var t in toasts) t.age += delta;
            toasts.RemoveAll(t => t.age > 2.1f);
            if (resultsOpen)
            {
                resultsAge += delta;
                wobT += delta;
                if (wobT >= 0.9f) { wobT = 0f; champ.Kick(0.25f); }
                champ.Update(delta);
            }
        }

        static string ControlsText()
        {
            if (Settings.human_count == 1)
                return "Move WASD/Arrows · Bomb Space/Enter · Steal (hold) L-Shift/R-Ctrl\nLine Bomb E/R-Shift · Pause Esc · Next song N";
            return "P1: WASD · Space bomb · L-Shift steal · E line bomb\nP2: Arrows · Enter bomb · R-Ctrl steal · R-Shift line bomb · Esc pause";
        }

        // ---- drawing ----
        public void Draw()
        {
            p.SetBase(Xf.Identity);
            p.ResetTransform();
            const float sx = 800f, sw = 450f;
            p.String(new Vector2(sx, 18 + 30), "Fluffy Bears of Doom", HAlign.Center, sw, 30, UiStyle.ROSE_DARK);
            p.String(new Vector2(sx, 62 + 16), ArenaMaps.MAPS[Settings.arena_index].name, HAlign.Center, sw, 16, UiStyle.INK_SOFT);
            float tl = Mathf.Max(game.timeLeft, 0f);
            Color tc = UiStyle.INK;
            if (tl < 10f && game.ControlsEnabled) tc = tl % 1f > 0.5f ? UiStyle.ROSE_DARK : UiStyle.INK;
            p.String(new Vector2(sx, 90 + 40), string.Format("{0}:{1:00}", (int)tl / 60, (int)tl % 60), HAlign.Center, sw, 40, tc);
            float y = 146f;
            for (int i = 0; i < game.bears.Count; i++) { DrawCard(game.bears[i], shown[i], new Rect(sx, y, sw, 104)); y += 112f; }
            p.Text(new Vector2(sx, y), ControlsText(), 13, UiStyle.INK_SOFT, sw, HAlign.Center);

            DrawBanner();
            DrawToasts();

            gui.inert = false;
            if (resultsOpen) DrawResults();
            if (pauseOpen)
            {
                gui.inert = audioOpen;
                DrawPause();
                gui.inert = false;
                if (audioOpen && AudioPanel.Draw(gui, new Vector2(180, 160))) CloseAudio();
            }
        }

        void DrawCard(Bear bear, float sh, Rect rr)
        {
            p.SetBase(Xf.Translate(rr.position));
            p.ResetTransform();
            Vector2 size = rr.size;
            var r = new Rect(Vector2.zero, size);
            p.Rect(r, UiStyle.PAPER);
            p.Rect(new Rect(0, 0, 8, size.y), bear.color);
            UiStyle.StitchRect(p, Arena.Grow(r, -5), Gd.WithAlpha(Gd.Darkened(bear.color, 0.2f), 0.7f), 1.4f, 5f);
            // little bear face
            Vector2 c = new Vector2(48, 52);
            float g = Gd.Clamp(sh / Tuning.START_FLUFF, 0f, 5f);
            float rad = 18f + 3f * Mathf.Sqrt(g);
            p.Circle(c + new Vector2(-rad * 0.75f, -rad * 0.72f), rad * 0.38f, bear.color);
            p.Circle(c + new Vector2(rad * 0.75f, -rad * 0.72f), rad * 0.38f, bear.color);
            p.Circle(c, rad, bear.color);
            p.Circle(c + new Vector2(0, rad * 0.35f), rad * 0.42f, Gd.Hex("f7ead8"));
            float eyeY = c.y - rad * 0.15f;
            Color eye = Gd.Hex("2b2220");
            if (bear.IsStunned)
            {
                foreach (float ex in new[] { -1f, 1f })
                {
                    Vector2 e = new Vector2(c.x + ex * rad * 0.4f, eyeY);
                    p.Line(e - new Vector2(3, 3), e + new Vector2(3, 3), eye, 2f);
                    p.Line(e - new Vector2(3, -3), e + new Vector2(3, -3), eye, 2f);
                }
            }
            else
            {
                p.Circle(new Vector2(c.x - rad * 0.4f, eyeY), 2.8f, eye);
                p.Circle(new Vector2(c.x + rad * 0.4f, eyeY), 2.8f, eye);
            }
            p.Circle(c + new Vector2(0, rad * 0.25f), 2.6f, Gd.Hex("4a3127"));
            // name + controller
            p.String(new Vector2(84, 32), bear.bearName, HAlign.Left, -1, 22, UiStyle.INK);
            p.String(new Vector2(84, 52), bear.ctrlLabel, HAlign.Left, -1, 14, UiStyle.INK_SOFT);
            // fluff
            p.String(new Vector2(size.x - 220, 40), Mathf.RoundToInt(sh).ToString(), HAlign.Right, 200, 30, UiStyle.INK);
            p.String(new Vector2(size.x - 220, 58), "fluff", HAlign.Right, 200, 13, UiStyle.INK_SOFT);
            var bar = new Rect(84, 64, size.x - 170, 10);
            p.Rect(bar, UiStyle.BAR);
            float frac = Gd.Clamp(sh / (Tuning.START_FLUFF * 4f), 0f, 1f);
            p.Rect(new Rect(bar.position, new Vector2(bar.width * frac, bar.height)), bear.color);
            p.Rect(new Rect(bar.position + new Vector2(bar.width * 0.25f, 0), new Vector2(1, bar.height)), new Color(0.4f, 0.3f, 0.25f, 0.4f));
            // stats: bombs ready/capacity, blast range, speed, then owned abilities
            Tex icons = Assets.Get("powerups/powerups");
            float x = 84f;
            string[] vals = { (bear.bombsMax - bear.activeBombs) + "/" + bear.bombsMax, bear.bombRange.ToString(), bear.speedLevel.ToString() };
            for (int i = 0; i < 3; i++)
            {
                p.TextureRect(icons.Region(Assets.POWERUP_CELLS, i), new Rect(x, 77, 20, 20));
                p.String(new Vector2(x + 22, 93), vals[i], HAlign.Left, -1, 15, UiStyle.INK);
                x += i == 0 ? 58f : 44f;
            }
            bool[] has = { bear.canKick, bear.hasLine, bear.hasRubber };
            for (int i = 0; i < 3; i++)
                if (has[i]) { p.TextureRect(icons.Region(Assets.POWERUP_CELLS, 4 + i), new Rect(x, 77, 20, 20)); x += 23f; }
            string status = "";
            Color scol = UiStyle.INK_SOFT;
            var timed = new List<string>();
            if (bear.immortalT > 0f) timed.Add("immortal " + Mathf.CeilToInt(bear.immortalT) + "s");
            if (bear.reverseT > 0f) timed.Add("reversed " + Mathf.CeilToInt(bear.reverseT) + "s");
            if (bear.diarrheaT > 0f) timed.Add("bomb diarrhea " + Mathf.CeilToInt(bear.diarrheaT) + "s");
            if (bear.IsStunned) { status = "stunned!"; scol = UiStyle.ROSE_DARK; }
            else if (bear.stealing) { status = "stealing stuffing..."; scol = UiStyle.GOOD; }
            else if (bear.robbedT > 0f) { status = "robbed!!"; scol = UiStyle.ROSE_DARK; }
            else if (timed.Count > 0) { status = string.Join(" · ", timed); scol = bear.immortalT > 0f && timed.Count == 1 ? UiStyle.GOLD : UiStyle.CURSE; }
            else if (g > 2.5f) status = "dangerously huggable";
            else if (g < 0.4f) status = "sadly deflated";
            p.String(new Vector2(size.x - 230, 93), status, HAlign.Right, 210, 13, scol);
            p.SetBase(Xf.Identity);
        }

        static float EaseOutBack(float t)
        {
            const float c1 = 1.70158f, c3 = c1 + 1f;
            t = Mathf.Clamp01(t) - 1f;
            return 1f + c3 * t * t * t + c1 * t * t;
        }

        void DrawBanner()
        {
            if (bannerText == "") return;
            float hold = Mathf.Max(bannerDur - 0.6f, 0.1f);
            float scale = 0.6f + 0.4f * EaseOutBack(bannerAge / 0.35f);
            float alpha = 1f;
            float fadeStart = 0.35f + hold;
            if (bannerAge > fadeStart) alpha = 1f - Mathf.Clamp01((bannerAge - fadeStart) / 0.3f);
            if (alpha <= 0f) return;
            // label at (40,260) 720x120, pivot at its centre
            Vector2 pivot = new Vector2(40 + 360, 260 + 60);
            p.SetBase(Xf.TRS(pivot, 0f, new Vector2(scale, scale)));
            p.ResetTransform();
            p.StringOutlined(new Vector2(-360, 64 * 0.36f), bannerText, HAlign.Center, 720, 64, Gd.WithAlpha(UiStyle.ROSE_DARK, alpha), Gd.WithAlpha(UiStyle.PAPER, alpha), 5f);
            p.SetBase(Xf.Identity);
        }

        void DrawToasts()
        {
            // bottom-aligned stack in a 720x80 box at (40,600)
            float y = 680f - toasts.Count * 26f;
            foreach (var t in toasts)
            {
                float a = t.age < 1.6f ? 1f : 1f - Mathf.Clamp01((t.age - 1.6f) / 0.5f);
                Color c = Gd.WithAlpha(Gd.Darkened(t.col, 0.45f), a);
                p.StringOutlined(new Vector2(40, y + 20), t.text, HAlign.Center, 720, 18, c, Gd.WithAlpha(UiStyle.PAPER, a), 2.5f);
                y += 26f;
            }
        }

        Rect PanelRect(Vector2 sz) => new Rect(new Vector2(400, 364) - sz * 0.5f, sz);

        void DrawPause()
        {
            var r = PanelRect(new Vector2(360, 300));
            Panel.Draw(p, r);
            float x = r.x + 22, w = r.width - 44, y = r.y + 22;
            p.String(new Vector2(x, y + 36), "Paused", HAlign.Center, w, 36, UiStyle.ROSE_DARK);
            y += 50;
            if (gui.Button(new Rect(x, y, w, 44), "Resume", 20)) { game.TogglePause(); return; }
            y += 50;
            if (gui.Button(new Rect(x, y, w, 44), "Audio settings", 20)) { audioOpen = true; gui.Focus(0); }
            y += 50;
            if (gui.Button(new Rect(x, y, w, 44), "Restart match", 20)) { game.RequestRestart(); return; }
            y += 50;
            if (gui.Button(new Rect(x, y, w, 44), "Back to menu", 20)) { game.RequestMenu(); return; }
        }

        void DrawResults()
        {
            Bear winner = ranking[0];
            bool tie = ranking.Count > 1 && Mathf.Abs(ranking[1].fluff - winner.fluff) < 0.5f;
            var r = PanelRect(new Vector2(640, 470));
            float fade = Mathf.Clamp01(resultsAge / 0.4f);
            Color prev = p.Modulate;
            p.Modulate = new Color(1, 1, 1, fade);
            Panel.Draw(p, r);
            float x = r.x + 22, w = r.width - 44, y = r.y + 22;
            p.String(new Vector2(x, y + 24), "Time's up!", HAlign.Center, w, 24, UiStyle.INK_SOFT);
            y += 36;
            p.String(new Vector2(x, y + 38), tie ? "It's a fluffy tie!" : winner.bearName + " is the fluffiest!", HAlign.Center, w, 38, Gd.Darkened(winner.color, 0.45f));
            y += 52;
            // The champion, smug and wobbling.
            champ.Draw(p, Xf.TRS(new Vector2(x + 300, y + 118), 0f, new Vector2(1.9f, 1.9f)), fade);
            y += 156;
            string[] places = { "1st", "2nd", "3rd", "4th" };
            int place = 1;
            for (int i = 0; i < ranking.Count; i++)
            {
                Bear b = ranking[i];
                if (i > 0 && Mathf.Abs(b.fluff - ranking[i - 1].fluff) >= 0.5f) place = i + 1;
                float base_ = y + 22;
                p.String(new Vector2(x, base_), places[place - 1], HAlign.Left, -1, 22, place == 1 ? UiStyle.ROSE_DARK : UiStyle.INK_SOFT);
                p.Rect(new Rect(x + 74, y + 6, 18, 18), b.color);
                p.String(new Vector2(x + 106, base_), b.bearName, HAlign.Left, -1, 22, UiStyle.INK);
                p.String(new Vector2(x + 250, base_), Mathf.RoundToInt(b.fluff) + " fluff", HAlign.Left, -1, 22, UiStyle.INK);
                p.String(new Vector2(x + 384, base_), "stole " + Mathf.RoundToInt(b.stolenTotal) + " · stunned " + b.timesStunned + "×", HAlign.Left, -1, 16, UiStyle.INK_SOFT);
                y += 32;
            }
            y += 8;
            p.Modulate = prev;
            float bx = r.center.x - 248;
            gui.inert = pauseOpen;
            if (gui.Button(new Rect(bx, y, 240, 44), "Rematch", 20)) game.RequestRestart();
            if (gui.Button(new Rect(bx + 256, y, 240, 44), "Menu", 20)) game.RequestMenu();
            gui.inert = false;
        }
    }
}
