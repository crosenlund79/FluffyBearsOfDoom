// Everything that differs between Normal and Horror mode, in one place
// (port of mode_theme.gd). Gameplay is identical; only looks/sounds/words change.
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public static class ModeTheme
    {
        public static readonly Dictionary<string, Color[]> CONFETTI = new Dictionary<string, Color[]>
        {
            { "normal", new[] { Gd.Hex("f2a7b5"), Gd.Hex("a7c8e8"), Gd.Hex("f5dc8a"), Gd.Hex("a8dcc0"), Gd.Hex("c9b2e3"), Gd.Hex("f6c1a0") } },
            { "horror", new[] { Gd.Hex("7a0f16"), Gd.Hex("a3141e"), Gd.Hex("5c0a10"), Gd.Hex("c9b8a0"), Gd.Hex("2a1c1e"), Gd.Hex("8c2a2a") } },
        };
        public static readonly Dictionary<string, string> SUBTITLE = new Dictionary<string, string>
        {
            { "normal", "Four adorable teddy bears. One finite supply of stuffing." },
            { "horror", "Four teddy bears. They are hungry. They are always hungry." },
        };
        public static readonly Dictionary<string, string> BLURB = new Dictionary<string, string>
        {
            { "normal", "Confetti bombs don't hurt - they stun. Hold Steal beside a stunned bear to pull out its fluff.\nThe more you steal, the rounder, wobblier and harder to stop you become." },
            { "horror", "The bombs only stun. The stuffing comes out anyway.\nThe more you take, the heavier you get. Nothing that full can run." },
        };

        public static string Mode => Settings.mode;
        public static bool Horror => Settings.mode == "horror";
        public static Color[] Confetti => CONFETTI[Mode];
        public static string Text(Dictionary<string, string> table) => table[Mode];

        /// Bear fabric colour: faded, grimy and cold in Horror.
        public static Color BearColor(Color c) => Horror ? Gd.Darkened(Gd.Lerp(c, new Color(0.5f, 0.46f, 0.46f), 0.5f), 0.12f) : c;

        /// Bomb fabric: darker than the floor and cushions so bombs stand out.
        public static Color BombTint(Color c, bool rubber)
        {
            float h = Gd.Hue(c);
            if (Horror) return Gd.FromHsv(h, rubber ? 0.35f : 0.25f, rubber ? 0.48f : 0.36f);
            if (rubber) return Gd.FromHsv(Gd.PosMod(h + 0.08f, 1f), 0.62f, 0.78f);
            return Gd.FromHsv(h, 0.48f, 0.66f);
        }

        /// Tint for permanent walls/pillars and the border (darker than cushions and floor).
        public static Color WallTint => Horror ? new Color(0.7f, 0.62f, 0.62f) : new Color(0.62f, 0.52f, 0.46f);
        public static Color BorderTint => Horror ? new Color(0.75f, 0.68f, 0.68f) : new Color(0.74f, 0.64f, 0.58f);

        /// Bear outline colour (Settings > Bear outlines).
        public static Color OutlineColor => Horror ? new Color(0.05f, 0.02f, 0.02f, 0.95f) : new Color(0.24f, 0.15f, 0.11f, 0.9f);

        public static Color StuffingColor => Horror ? new Color(0.8f, 0.28f, 0.3f) : Color.white;
        public static Color SplatColor => Horror ? new Color(0.5f, 0.03f, 0.07f, 0.85f) : new Color(1f, 1f, 1f, 0.8f);
        public static Color WorldModulate => Horror ? new Color(0.74f, 0.66f, 0.68f) : Color.white;

        /// [background, text, outline] of taunt bubbles.
        public static Color[] BubbleColors => Horror
            ? new[] { new Color(0.1f, 0.06f, 0.07f, 0.88f), Gd.Hex("d9c9b6"), new Color(0.55f, 0.06f, 0.1f) }
            : new[] { new Color(1f, 0.98f, 0.94f, 0.92f), Gd.Hex("5b4636"), Gd.Hex("d8a0a6") };
    }

    /// Taunt lines and reaction animations (port of taunts.gd). Edit freely.
    public static class Taunts
    {
        static readonly Dictionary<string, Dictionary<string, string[]>> LINES = new Dictionary<string, Dictionary<string, string[]>>
        {
            { "normal", new Dictionary<string, string[]> {
                { "stun", new[] { "Boop!", "Nyah nyah!", "Nap time~", "Sorry not sorry!", "Ha! Fluffed!", "Bonk!", "Sweet dreams!", "Got your nose!" } },
                { "self_stun", new[] { "Pfft, own goal!", "Hee hee, nice one!", "Smooth moves!", "Did you mean to do that?" } },
                { "steal", new[] { "Mine now!", "Ooh, so fluffy!", "Yoink!", "Om nom nom!", "Thanks for sharing!", "Finders keepers!" } },
                { "greedy", new[] { "I'm a BALLOON!", "So... round...", "Too much? Never!", "Wheee, wobble!" } },
                { "robbed", new[] { "Hey! Give it back!", "My stuffing!", "Thief!!", "Not cool!", "I'm telling!" } },
            } },
            { "horror", new Dictionary<string, string[]> {
                { "stun", new[] { "Hush now.", "Sleep, little one.", "Shhhh...", "Don't fight it.", "Lie still.", "Heh heh heh..." } },
                { "self_stun", new[] { "Clumsy, clumsy...", "It found you first.", "The nursery remembers." } },
                { "steal", new[] { "So soft inside...", "Your stuffing is MINE.", "Just a little more...", "Join us.", "It doesn't hurt. Much." } },
                { "greedy", new[] { "Fuller... FULLER...", "Can't... stop... eating...", "So heavy. So happy." } },
                { "robbed", new[] { "Give... it... BACK.", "I'm so empty...", "I will find you.", "Cold... so cold..." } },
            } },
        };

        static readonly Dictionary<string, Dictionary<string, string[]>> PERSONAL = new Dictionary<string, Dictionary<string, string[]>>
        {
            { "normal", new Dictionary<string, string[]> {
                { "Oswald", new[] { "Too easy, darling.", "Oswald wins again~" } },
                { "Harald", new[] { "HARALD SMASH! ...gently.", "Hehe, squishy!" } },
                { "Theodor", new[] { "Behold, Theodor the Magnificent!", "A tragedy... for YOU." } },
            } },
            { "horror", new Dictionary<string, string[]> {
                { "Oswald", new[] { "Oswald is never full.", "Pretty seams. I'll keep them." } },
                { "Harald", new[] { "Harald wants to hug you. Forever.", "Hug. Hug. HUG." } },
                { "Theodor", new[] { "Theodor sees you.", "I counted your stitches." } },
            } },
        };

        static readonly Dictionary<string, string[]> ANIMS = new Dictionary<string, string[]>
        {
            { "normal", new[] { "wiggle", "spin", "hop", "cheer" } },
            { "horror", new[] { "tilt", "twitch", "lean", "shudder" } },
        };

        public static readonly Dictionary<string, float> VOICE = new Dictionary<string, float>
        {
            { "Player", 1f }, { "Player 1", 1f }, { "Player 2", 1.18f }, { "Oswald", 0.95f }, { "Harald", 0.82f }, { "Theodor", 1.1f },
        };

        public static string Line(string kind, string who, Rng rng)
        {
            string mode = Settings.mode;
            if (PERSONAL[mode].TryGetValue(who, out string[] personal) && (kind == "stun" || kind == "steal") && rng.F() < 0.3f)
                return personal[rng.Int(personal.Length)];
            string[] lines = LINES[mode][kind];
            return lines[rng.Int(lines.Length)];
        }

        public static string Anim(Rng rng)
        {
            string[] list = ANIMS[Settings.mode];
            return list[rng.Int(list.Length)];
        }
    }
}
