// The four playable characters (port of species.gd). They all share the bear
// rig (body, belly, head, ears, arms, legs, four faces); each has its own sprite
// sheet in Sprites/bears/ (+ horror/) and a couple of optional accessory cells:
//   cell 10 = tail ("puff" / "long") or skirt,   cell 11 = head topper.
// The plain teddy bear sheet keeps the original 10-cell layout.
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public class SpeciesSpec
    {
        public string id, label, sheet;
        public int cells = 10;
        public Vector2 earPos = new Vector2(36, -38);
        public float earOffset = -0.06f, earScale = 1f, earFlop = 1f;
        public string tail = "";          // "", "puff", "long"
        public bool tailTint, skirt;
        public string topper = "";        // "", "front", "back"
        public Vector2 topperPos;
        public float topperRot, topperScale = 1f;
        public bool topperTint;
    }

    public static class Species
    {
        public static readonly Dictionary<string, SpeciesSpec> ALL = new Dictionary<string, SpeciesSpec>
        {
            { "bear", new SpeciesSpec { id = "bear", label = "Teddy Bear", sheet = "bears/bear", cells = 10 } },
            { "bunny", new SpeciesSpec { id = "bunny", label = "Teddy Bunny", sheet = "bears/bunny", cells = 12,
                earPos = new Vector2(20, -34), earOffset = -0.3f, earFlop = 2.2f, tail = "puff",
                topper = "front", topperPos = new Vector2(32, -40), topperRot = 0.35f, topperScale = 0.42f } },
            { "dino", new SpeciesSpec { id = "dino", label = "Small Dino", sheet = "bears/dino", cells = 12,
                earPos = new Vector2(30, -40), earScale = 0.85f, earFlop = 0.35f, tail = "long", tailTint = true,
                topper = "back", topperPos = new Vector2(0, -42), topperScale = 0.85f, topperTint = true } },
            { "princess", new SpeciesSpec { id = "princess", label = "Teddy Bear Princess", sheet = "bears/princess", cells = 12,
                skirt = true, topper = "front", topperPos = new Vector2(0, -50), topperScale = 0.55f } },
        };

        /// Who is what. Player 2 takes the character of whichever AI sits out.
        public static readonly Dictionary<string, string> BY_NAME = new Dictionary<string, string>
        {
            { "Player", "bear" }, { "Player 1", "bear" }, { "Oswald", "bunny" }, { "Harald", "dino" }, { "Theodor", "princess" },
        };

        public static string ForName(string n)
        {
            if (n == "Player 2") return BY_NAME[Settings.AI_NAMES[Settings.sitting_out]];
            return BY_NAME.TryGetValue(n, out string s) ? s : "bear";
        }

        /// The spec for a species. If its sheet (and every placeholder for it) is
        /// missing, the character falls back to the plain teddy bear rig.
        public static SpeciesSpec Info(string s)
        {
            if (s == null || !ALL.TryGetValue(s, out SpeciesSpec sp)) return ALL["bear"];
            if (sp.id != "bear" && Assets.Resolve(sp.sheet) == "") return ALL["bear"];
            return sp;
        }
    }
}
