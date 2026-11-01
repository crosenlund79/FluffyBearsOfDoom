// A small immediate-mode widget kit drawn with the Painter: buttons, toggle
// buttons, option (dropdown) buttons with popup lists, sliders and check boxes,
// styled like the Godot theme in ui_style.gd. Supports mouse, keyboard
// (arrows/WASD + Enter/Space, Esc) and gamepad (d-pad/stick + A/B) focus.
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public class Gui
    {
        public Painter p;
        public Vector2 mouse;
        bool mouseDown, mouseHeld;
        int nextId;
        public int focus = -1;
        int focusCount;
        int prevFocusCount;
        int navDelta;
        bool accept, back;
        int horiz;

        // popup (OptionButton list)
        int popupOwner = -1;
        Rect popupRect;
        string[] popupItems;
        int popupHover;
        readonly Dictionary<int, int> popupResult = new Dictionary<int, int>();
        int dragSlider = -1;
        public bool blockInput;    // set while another overlay owns input
        public bool inert;         // draw widgets but ignore input (panel under a modal)

        public Gui(Painter painter) { p = painter; }

        public bool PopupOpen => popupOwner >= 0;

        public void Begin(Vector2 canvasMouse)
        {
            mouse = canvasMouse;
            mouseDown = Input.GetMouseButtonDown(0);
            mouseHeld = Input.GetMouseButton(0);
            if (!mouseHeld) dragSlider = -1;
            prevFocusCount = focusCount;
            focusCount = 0;
            nextId = 0;
            navDelta = 0; accept = false; back = false; horiz = 0;
            if (blockInput) { mouseDown = false; return; }
            if (popupOwner >= 0)
            {
                int v = Controls.NavVertical();
                if (v != 0) popupHover = Mathf.Clamp(popupHover + v, 0, popupItems.Length - 1);
                if (Controls.AcceptPressed()) { popupResult[popupOwner] = popupHover; popupOwner = -1; Sfx.Play("menu"); }
                else if (Controls.BackPressed()) popupOwner = -1;
                return;
            }
            navDelta = Controls.NavVertical();
            horiz = Controls.NavHorizontal();
            accept = Controls.AcceptPressed();
            back = Controls.BackPressed();
            if (navDelta != 0 && prevFocusCount > 0)
            {
                focus = focus < 0 ? 0 : (focus + navDelta + prevFocusCount) % prevFocusCount;
                Sfx.Play("menu", 1f, -8f);
            }
        }

        public bool BackPressed => back;

        int Register(out bool focused)
        {
            nextId++;
            if (inert) { focused = false; return -1000 - nextId; }
            int fi = focusCount++;
            focused = fi == focus;
            return fi;
        }

        bool Hover(Rect r) => !inert && !blockInput && popupOwner < 0 && r.Contains(mouse);

        public void Focus(int index) { focus = index; }

        // ---- widgets ----
        public bool Button(Rect r, string text, int size = 20, bool toggled = false)
        {
            int fi = Register(out bool focused);
            bool hover = Hover(r);
            if (hover && mouseDown && focus != fi) { focus = fi; Sfx.Play("menu", 1f, -8f); }
            Color bg = toggled ? UiStyle.ROSE : (hover ? Gd.Lerp(UiStyle.PAPER, UiStyle.ROSE, 0.15f) : UiStyle.PAPER);
            Color border = hover || toggled ? UiStyle.ROSE_DARK : UiStyle.ROSE;
            UiStyle.Box(p, r, bg, border);
            if (focused) UiStyle.RoundRectOutline(p, Arena.Grow(r, 1), 14f, UiStyle.BLUE, 3f);
            p.String(new Vector2(r.x, r.center.y + size * 0.35f), text, HAlign.Center, r.width, size, UiStyle.INK);
            return (hover && mouseDown) || (focused && accept);
        }

        /// A dropdown: shows the selected item, opens a popup list.
        public int Option(Rect r, string[] items, int selected, int size = 18)
        {
            int fi = Register(out bool focused);
            int id = fi;
            if (popupResult.TryGetValue(id, out int res)) { popupResult.Remove(id); selected = res; }
            bool hover = Hover(r);
            Color bg = hover ? Gd.Lerp(UiStyle.PAPER, UiStyle.ROSE, 0.15f) : UiStyle.PAPER;
            UiStyle.Box(p, r, bg, hover ? UiStyle.ROSE_DARK : UiStyle.ROSE);
            if (focused) UiStyle.RoundRectOutline(p, Arena.Grow(r, 1), 14f, UiStyle.BLUE, 3f);
            p.String(new Vector2(r.x + 14, r.center.y + size * 0.35f), items[Mathf.Clamp(selected, 0, items.Length - 1)], HAlign.Left, -1, size, UiStyle.INK);
            // chevron
            Vector2 cc = new Vector2(r.xMax - 16, r.center.y);
            p.Polyline(new[] { cc + new Vector2(-4, -2), cc + new Vector2(0, 2), cc + new Vector2(4, -2) }, UiStyle.INK_SOFT, 1.6f);
            bool open = (hover && mouseDown) || (focused && accept);
            if (focused && horiz != 0) { selected = Mathf.Clamp(selected + horiz, 0, items.Length - 1); Sfx.Play("menu", 1f, -8f); }
            if (open)
            {
                focus = fi;
                popupOwner = id;
                popupItems = items;
                popupHover = selected;
                float h = items.Length * (size + 14) + 12;
                popupRect = new Rect(r.x, r.yMax + 2, Mathf.Max(r.width, 180), h);
                if (popupRect.yMax > 712) popupRect.y = r.y - h - 2;
                Sfx.Play("menu");
                mouseDown = false;
            }
            return selected;
        }

        public float Slider(Rect r, float v)
        {
            int fi = Register(out bool focused);
            bool hover = Hover(r);
            if (hover && mouseDown) { dragSlider = fi; focus = fi; }
            if (dragSlider == fi && mouseHeld) v = Gd.Clamp01((mouse.x - r.x) / r.width);
            if (focused && horiz != 0) { v = Gd.Clamp01(v + horiz * 0.05f); Sfx.Play("menu", 1f, -8f); }
            v = Mathf.Round(v / 0.05f) * 0.05f;
            var track = new Rect(r.x, r.center.y - 4, r.width, 8);
            UiStyle.Box(p, track, UiStyle.BAR, UiStyle.FRAME, 6f, 1f, false);
            UiStyle.Box(p, new Rect(track.x, track.y, track.width * v, track.height), UiStyle.ROSE, UiStyle.ROSE_DARK, 6f, 1f, false);
            Vector2 knob = new Vector2(r.x + r.width * v, r.center.y);
            p.Circle(knob, 9f, focused ? UiStyle.BLUE : UiStyle.ROSE_DARK);
            p.Circle(knob, 6.5f, UiStyle.PAPER);
            return v;
        }

        public bool Check(Rect r, string text, bool v, int size = 18)
        {
            int fi = Register(out bool focused);
            bool hover = Hover(r);
            var box = new Rect(r.x, r.center.y - 10, 20, 20);
            UiStyle.Box(p, box, UiStyle.PAPER, focused ? UiStyle.BLUE : UiStyle.ROSE_DARK, 4f, focused ? 3f : 2f, false);
            if (v) p.Polyline(new[] { box.center + new Vector2(-6, 0), box.center + new Vector2(-1, 5), box.center + new Vector2(6, -6) }, UiStyle.ROSE_DARK, 2.6f);
            p.String(new Vector2(r.x + 30, r.center.y + size * 0.35f), text, HAlign.Left, -1, size, UiStyle.INK);
            if ((hover && mouseDown) || (focused && accept)) { v = !v; focus = fi; Sfx.Play("menu"); }
            return v;
        }

        /// Draw the open popup list last so it sits on top of everything.
        public void End()
        {
            if (popupOwner < 0) return;
            UiStyle.Box(p, popupRect, UiStyle.PAPER, UiStyle.ROSE, 10f);
            float rowH = (popupRect.height - 12) / popupItems.Length;
            for (int i = 0; i < popupItems.Length; i++)
            {
                var row = new Rect(popupRect.x + 6, popupRect.y + 6 + i * rowH, popupRect.width - 12, rowH);
                if (row.Contains(mouse)) popupHover = i;
                if (i == popupHover) UiStyle.RoundRect(p, row, 8f, Gd.Lerp(UiStyle.PAPER, UiStyle.ROSE, 0.3f));
                p.String(new Vector2(row.x + 10, row.center.y + 6), popupItems[i], HAlign.Left, -1, 18, UiStyle.INK);
            }
            if (Input.GetMouseButtonDown(0))
            {
                if (popupRect.Contains(mouse)) { popupResult[popupOwner] = popupHover; Sfx.Play("menu"); }
                popupOwner = -1;
            }
        }
    }
}
