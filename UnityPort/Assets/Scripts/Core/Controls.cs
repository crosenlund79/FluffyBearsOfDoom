// Input bindings (port of the Godot InputMap setup in settings.gd), using
// Unity's built-in Input Manager. Presses are latched every rendered frame and
// consumed in the fixed physics step, so nothing is missed or double counted.
//   P1: WASD, Space bomb, Left Shift steal, E special (Line Bomb)
//   P2: Arrows, Enter bomb, Right Ctrl steal, Right Shift special
//   Gamepad: left stick / d-pad, A bomb, X/B/RT steal, Y/LB special, Start pause
// A lone player may use either keyboard layout and any gamepad.
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public static class Controls
    {
        public const string UP = "up", DOWN = "down", LEFT = "left", RIGHT = "right", BOMB = "bomb", STEAL = "steal", SPECIAL = "special";
        static readonly string[] ACTIONS = { UP, DOWN, LEFT, RIGHT, BOMB, STEAL, SPECIAL };

        static readonly Dictionary<string, KeyCode[]>[] KEYS =
        {
            new Dictionary<string, KeyCode[]> {
                { UP, new[] { KeyCode.W } }, { DOWN, new[] { KeyCode.S } }, { LEFT, new[] { KeyCode.A } }, { RIGHT, new[] { KeyCode.D } },
                { BOMB, new[] { KeyCode.Space } }, { STEAL, new[] { KeyCode.LeftShift } }, { SPECIAL, new[] { KeyCode.E } } },
            new Dictionary<string, KeyCode[]> {
                { UP, new[] { KeyCode.UpArrow } }, { DOWN, new[] { KeyCode.DownArrow } }, { LEFT, new[] { KeyCode.LeftArrow } }, { RIGHT, new[] { KeyCode.RightArrow } },
                { BOMB, new[] { KeyCode.Return, KeyCode.KeypadEnter } }, { STEAL, new[] { KeyCode.RightControl } }, { SPECIAL, new[] { KeyCode.RightShift } } },
        };

        // Xbox-style button numbers in Unity's legacy input on Windows.
        const int A = 0, B = 1, X = 2, Y = 3, LB = 4, START = 7;

        static readonly Dictionary<string, float> held = new Dictionary<string, float>();
        static readonly HashSet<string> down = new HashSet<string>();
        static readonly Dictionary<string, bool> axisOk = new Dictionary<string, bool>();

        /// Which joystick a scheme uses: 0 = any (solo), 1/2 = specific pad.
        static int PadFor(int scheme) => Settings.human_count <= 1 ? (scheme == 0 ? 0 : -1) : scheme + 1;

        static KeyCode JoyButton(int joy, int button) =>
            joy <= 0 ? (KeyCode)((int)KeyCode.JoystickButton0 + button) : (KeyCode)((int)KeyCode.Joystick1Button0 + (joy - 1) * 20 + button);

        static float Axis(string name)
        {
            if (axisOk.TryGetValue(name, out bool ok) && !ok) return 0f;
            try { float v = Input.GetAxisRaw(name); axisOk[name] = true; return v; }
            catch { axisOk[name] = false; return 0f; }
        }

        static float Strength(int scheme, string action)
        {
            float s = 0f;
            foreach (var k in KEYS[scheme][action]) if (Input.GetKey(k)) s = 1f;
            int pad = PadFor(scheme);
            if (pad < 0) return s;
            string j = "J" + pad + "_";
            switch (action)
            {
                case UP: s = Mathf.Max(s, -Axis(j + "LY"), Axis(j + "DY")); break;
                case DOWN: s = Mathf.Max(s, Axis(j + "LY"), -Axis(j + "DY")); break;
                case LEFT: s = Mathf.Max(s, -Axis(j + "LX"), -Axis(j + "DX")); break;
                case RIGHT: s = Mathf.Max(s, Axis(j + "LX"), Axis(j + "DX")); break;
                case BOMB: if (Input.GetKey(JoyButton(pad, A))) s = 1f; break;
                case STEAL: if (Input.GetKey(JoyButton(pad, X)) || Input.GetKey(JoyButton(pad, B))) s = 1f; s = Mathf.Max(s, Axis(j + "RT")); break;
                case SPECIAL: if (Input.GetKey(JoyButton(pad, Y)) || Input.GetKey(JoyButton(pad, LB))) s = 1f; break;
            }
            return s >= 0.4f ? s : 0f; // action deadzone 0.4 like the Godot InputMap
        }

        /// Call once per rendered frame (before game logic).
        public static void Poll()
        {
            for (int sch = 0; sch < 2; sch++)
                foreach (string a in ACTIONS)
                {
                    string key = sch + a;
                    float prev = held.TryGetValue(key, out float h) ? h : 0f;
                    float now = Strength(sch, a);
                    if (now > 0f && prev <= 0f) down.Add(key);
                    held[key] = now;
                }
        }

        static int Scheme(string s) => s == "p2" ? 1 : 0;
        public static float Get(string scheme, string action) => held.TryGetValue(Scheme(scheme) + action, out float v) ? v : 0f;
        public static bool Held(string scheme, string action) => Get(scheme, action) > 0f;
        /// "Just pressed" since the last consume (physics-step safe).
        public static bool ConsumeDown(string scheme, string action) => down.Remove(Scheme(scheme) + action);
        public static void ClearDowns() => down.Clear();

        // ---- menu / global keys ----
        public static bool PausePressed() => Input.GetKeyDown(KeyCode.Escape) || Input.GetKeyDown(KeyCode.P) || Input.GetKeyDown(JoyButton(0, START));
        public static bool BackPressed() => Input.GetKeyDown(KeyCode.Escape) || Input.GetKeyDown(JoyButton(0, B));
        public static bool AcceptPressed() => Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter) || Input.GetKeyDown(KeyCode.Space) || Input.GetKeyDown(JoyButton(0, A));
        public static int NavVertical()
        {
            if (Input.GetKeyDown(KeyCode.UpArrow) || Input.GetKeyDown(KeyCode.W)) return -1;
            if (Input.GetKeyDown(KeyCode.DownArrow) || Input.GetKeyDown(KeyCode.S)) return 1;
            return PadNav("J0_DY", "J0_LY", true);
        }
        public static int NavHorizontal()
        {
            if (Input.GetKeyDown(KeyCode.LeftArrow) || Input.GetKeyDown(KeyCode.A)) return -1;
            if (Input.GetKeyDown(KeyCode.RightArrow) || Input.GetKeyDown(KeyCode.D)) return 1;
            return PadNav("J0_DX", "J0_LX", false);
        }

        static readonly Dictionary<string, float> padRepeat = new Dictionary<string, float>();
        static int PadNav(string dpad, string stick, bool vertical)
        {
            float v = Axis(stick);
            float d = Axis(dpad);
            float val = Mathf.Abs(d) > 0.5f ? (vertical ? -d : d) : v;
            int dir = val > 0.5f ? 1 : (val < -0.5f ? -1 : 0);
            float last = padRepeat.TryGetValue(stick, out float l) ? l : 0f;
            padRepeat[stick] = dir;
            return dir != 0 && last == 0f ? dir : 0;
        }
    }
}
