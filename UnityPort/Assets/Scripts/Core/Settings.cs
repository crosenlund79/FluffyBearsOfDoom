// Match setup and saved preferences (port of settings.gd). Saved as JSON in
// Application.persistentDataPath/settings.json.
using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace FBD
{
    public class RosterEntry
    {
        public string name; public Color color; public string controller; public string[] schemes;
    }

    [Serializable]
    class SaveData
    {
        public float master_volume = 0.9f, music_volume = 0.6f, sfx_volume = 0.85f;
        public bool muted = false, shuffle_music = true;
        public int human_count = 1, sitting_out = 2, arena_index = 0, round_time_index = 1;
        public string[] ai_levels = { "normal", "normal", "normal" };
        public string mode = "normal";
        public bool bear_outlines = true;
    }

    public static class Settings
    {
        public static readonly string[] AI_NAMES = { "Oswald", "Harald", "Theodor" };
        public static readonly Color[] AI_COLORS = { Gd.Hex("8eaecb"), Gd.Hex("a3bf8c"), Gd.Hex("c39bcb") };
        public static readonly Color[] HUMAN_COLORS = { Gd.Hex("d9a66b"), Gd.Hex("e3a1a8") };
        public static readonly string[] LEVELS = { "easy", "normal", "hard" };
        public static readonly string[] LEVEL_LABELS = { "Easy", "Normal", "Hard" };

        public static int human_count = 1;
        public static string[] ai_levels = { "normal", "normal", "normal" };
        public static int sitting_out = 2;
        public static int arena_index = 0;
        public static int round_time_index = 1;

        public static float master_volume = 0.9f;
        public static float music_volume = 0.6f;
        public static float sfx_volume = 0.85f;
        public static bool muted = false;
        public static bool shuffle_music = true;
        public static string mode = "normal";
        public static bool bear_outlines = true;   // dark outline around bears for visibility

        /// Set false by the headless test harness (no files, no engine).
        public static bool persist = true;

        static string SavePath => Path.Combine(Application.persistentDataPath, "settings.json");

        /// The four bears of the next match.
        public static List<RosterEntry> Roster()
        {
            var o = new List<RosterEntry>();
            if (human_count == 0) // demo / smoke test: a Hard AI plays the player's bear
                o.Add(new RosterEntry { name = "Player", color = HUMAN_COLORS[0], controller = "hard", schemes = new string[0] });
            else if (human_count == 1)
                o.Add(new RosterEntry { name = "Player", color = HUMAN_COLORS[0], controller = "human", schemes = new[] { "p1", "p2" } });
            else
            {
                o.Add(new RosterEntry { name = "Player 1", color = HUMAN_COLORS[0], controller = "human", schemes = new[] { "p1" } });
                o.Add(new RosterEntry { name = "Player 2", color = HUMAN_COLORS[1], controller = "human", schemes = new[] { "p2" } });
            }
            for (int i = 0; i < AI_NAMES.Length; i++)
            {
                if (human_count == 2 && i == sitting_out) continue;
                o.Add(new RosterEntry { name = AI_NAMES[i], color = AI_COLORS[i], controller = ai_levels[i], schemes = new string[0] });
            }
            return o;
        }

        public static void SetMode(string m)
        {
            mode = (m == "horror") ? "horror" : "normal";
            UiStyle.ApplyMode(mode);
        }

        public static void Save()
        {
            if (!persist) return;
            var d = new SaveData
            {
                master_volume = master_volume, music_volume = music_volume, sfx_volume = sfx_volume, muted = muted,
                shuffle_music = shuffle_music, human_count = human_count, ai_levels = (string[])ai_levels.Clone(),
                sitting_out = sitting_out, arena_index = arena_index, round_time_index = round_time_index, mode = mode, bear_outlines = bear_outlines,
            };
            try { File.WriteAllText(SavePath, JsonUtility.ToJson(d, true)); }
            catch (Exception e) { Debug.LogWarning("Could not save settings: " + e.Message); }
        }

        public static void Load()
        {
            if (persist)
            {
                try
                {
                    if (File.Exists(SavePath))
                    {
                        var d = JsonUtility.FromJson<SaveData>(File.ReadAllText(SavePath));
                        master_volume = d.master_volume; music_volume = d.music_volume; sfx_volume = d.sfx_volume;
                        muted = d.muted; shuffle_music = d.shuffle_music; human_count = Mathf.Clamp(d.human_count, 1, 2);
                        if (d.ai_levels != null && d.ai_levels.Length == 3) ai_levels = d.ai_levels;
                        sitting_out = Mathf.Clamp(d.sitting_out, 0, 2);
                        arena_index = Mathf.Clamp(d.arena_index, 0, ArenaMaps.MAPS.Length - 1);
                        round_time_index = Mathf.Clamp(d.round_time_index, 0, Tuning.ROUND_TIMES.Length - 1);
                        mode = d.mode;
                        bear_outlines = d.bear_outlines;
                    }
                }
                catch (Exception e) { Debug.LogWarning("Could not load settings: " + e.Message); }
            }
            SetMode(mode);
        }
    }
}
