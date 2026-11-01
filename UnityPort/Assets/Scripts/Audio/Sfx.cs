// Sound effects (port of sfx.gd). Each is a tiny procedural placeholder,
// generated with the same formulas as the Godot version. To replace one, drop
// a file with the same name (ogg / wav / mp3) into
//   StreamingAssets/Audio/sfx/          (both modes)
//   StreamingAssets/Audio/sfx/horror/   (Horror only)
// Lookup in Horror: sfx/horror/<name> -> sfx/<name> -> built-in horror
// placeholder -> built-in normal placeholder (played lower and slower).
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Networking;

namespace FBD
{
    public static class Sfx
    {
        const int RATE = 22050;
        static readonly Dictionary<string, AudioClip> streams = new Dictionary<string, AudioClip>();
        static readonly Dictionary<string, AudioClip> horror = new Dictionary<string, AudioClip>();
        static readonly Dictionary<string, Dictionary<string, AudioClip>> over = new Dictionary<string, Dictionary<string, AudioClip>>
        { { "normal", new Dictionary<string, AudioClip>() }, { "horror", new Dictionary<string, AudioClip>() } };
        static readonly List<AudioSource> players = new List<AudioSource>();
        static readonly System.Random rnd = new System.Random();
        public static bool Enabled;     // false in the headless test harness

        public static string SfxDir => Path.Combine(Application.streamingAssetsPath, "Audio", "sfx");

        public static void Init(GameObject host)
        {
            for (int i = 0; i < 16; i++)
            {
                var s = host.AddComponent<AudioSource>();
                s.playOnAwake = false;
                players.Add(s);
            }
            streams["place"] = Tone("place", 0.09f, 420, 260, 0.5f, 0, 0.1f);
            streams["fuse"] = Tone("fuse", 0.04f, 1500, 1400, 0.2f, 0, 0.4f);
            streams["confetti"] = Clip("confetti", ConfettiSamples(0.5f));
            streams["concussion"] = Concat("concussion", Bonk(), Samples(0.05f, 0, 0, 0, 0, 0),
                Samples(0.09f, 2300, 3100, 0.25f, 35, 0), Samples(0.04f, 0, 0, 0, 0, 0),
                Samples(0.09f, 2400, 3300, 0.25f, 35, 0), Samples(0.12f, 2600, 2000, 0.22f, 30, 0));
            streams["steal"] = Tone("steal", 0.05f, 1300, 1600, 0.25f, 0, 0.15f);
            streams["pickup"] = Concat("pickup", Samples(0.07f, 660, 660, 0.4f, 0, 0), Samples(0.1f, 990, 990, 0.4f, 0, 0));
            streams["curse"] = Concat("curse", Samples(0.18f, 400, 340, 0.4f, 7, 0), Samples(0.3f, 330, 220, 0.4f, 7, 0));
            streams["squeak"] = Tone("squeak", 0.13f, 1100, 1750, 0.5f, 28, 0);
            streams["bump"] = Tone("bump", 0.09f, 700, 520, 0.4f, 0, 0.05f);
            streams["kick"] = Tone("kick", 0.08f, 220, 120, 0.6f, 0, 0.3f);
            streams["boing"] = Tone("boing", 0.25f, 300, 600, 0.45f, 18, 0);
            streams["pop"] = Tone("pop", 0.07f, 620, 300, 0.5f, 0, 0);
            streams["menu"] = Tone("menu", 0.04f, 900, 1100, 0.3f, 0, 0);
            streams["tick"] = Tone("tick", 0.08f, 880, 880, 0.35f, 0, 0);
            streams["go"] = Concat("go", Samples(0.08f, 660, 660, 0.4f, 0, 0), Samples(0.08f, 880, 880, 0.4f, 0, 0), Samples(0.2f, 1320, 1320, 0.4f, 6, 0));
            streams["shuffle"] = Tone("shuffle", 0.6f, 250, 950, 0.3f, 9, 0.35f);
            streams["immortal"] = Concat("immortal", Samples(0.1f, 784, 784, 0.35f, 0, 0), Samples(0.1f, 988, 988, 0.35f, 0, 0), Samples(0.25f, 1568, 1568, 0.3f, 8, 0));
            streams["victory"] = Concat("victory", Samples(0.14f, 523, 523, 0.4f, 0, 0), Samples(0.14f, 659, 659, 0.4f, 0, 0), Samples(0.14f, 784, 784, 0.4f, 0, 0), Samples(0.4f, 1046, 1046, 0.4f, 5, 0));
            // Doom Duck Parade
            streams["portal"] = Concat("portal", Samples(0.5f, 200, 1200, 0.3f, 14, 0.25f), Samples(0.25f, 1200, 900, 0.2f, 20, 0.1f));
            streams["clock_tick"] = Tone("clock_tick", 0.025f, 2600, 2200, 0.35f, 0, 0.6f);
            streams["quack"] = Clip("quack", Quack(0.2f, 330));
            streams["duckling_quack"] = Clip("duckling_quack", Quack(0.11f, 560));
            streams["duck_warning"] = Tone("duck_warning", 0.06f, 1760, 1760, 0.3f, 0, 0);
            streams["duck_confetti"] = Concat("duck_confetti", Quack(0.16f, 300), ConfettiSamples(0.9f));
            streams["taunt"] = Concat("taunt", Samples(0.07f, 700, 1100, 0.35f, 0, 0), Samples(0.07f, 900, 1300, 0.35f, 0, 0), Samples(0.12f, 800, 1500, 0.35f, 12, 0));
            streams["mode"] = Concat("mode", Samples(0.08f, 784, 784, 0.35f, 0, 0), Samples(0.08f, 988, 988, 0.35f, 0, 0), Samples(0.2f, 1175, 1175, 0.3f, 6, 0));
            BuildHorror();
            Enabled = true;
        }

        /// Loads creator replacements from StreamingAssets (call as a coroutine).
        public static IEnumerator LoadReplacements()
        {
            var names = new List<string>(streams.Keys);
            foreach (string n in names)
            {
                foreach (string sub in new[] { "", "horror" })
                {
                    string key = sub == "" ? "normal" : "horror";
                    foreach (string ext in new[] { "ogg", "wav", "mp3" })
                    {
                        if (over[key].ContainsKey(n)) break;
                        string path = sub == "" ? Path.Combine(SfxDir, n + "." + ext) : Path.Combine(SfxDir, sub, n + "." + ext);
                        if (!File.Exists(path)) continue;
                        AudioClip clip = null;
                        yield return AudioLoader.Load(path, c => clip = c);
                        if (clip != null) over[key][n] = clip;
                    }
                }
            }
        }

        static void BuildHorror()
        {
            horror["taunt"] = Clip("h_taunt", Chuckle());
            horror["confetti"] = Clip("h_confetti", Splat(0.5f));
            horror["duck_confetti"] = Concat("h_duck_confetti", Quack(0.2f, 180), Splat(0.9f));
            horror["concussion"] = Concat("h_concussion", Bonk(), Samples(0.08f, 0, 0, 0, 0, 0), Samples(0.35f, 900, 500, 0.3f, 6, 0.45f));
            horror["pickup"] = Concat("h_pickup", Samples(0.1f, 330, 330, 0.4f, 0, 0), Samples(0.18f, 311, 311, 0.4f, 4, 0));
            horror["victory"] = Concat("h_victory", Samples(0.25f, 440, 440, 0.4f, 0, 0), Samples(0.25f, 415, 415, 0.4f, 0, 0), Samples(0.25f, 392, 392, 0.4f, 0, 0), Samples(0.6f, 370, 370, 0.4f, 5, 0));
            horror["mode"] = Concat("h_mode", Samples(0.5f, 110, 70, 0.5f, 3, 0.2f), Samples(0.4f, 233, 220, 0.25f, 8, 0.3f));
            horror["steal"] = Clip("h_steal", Splat(0.08f));
        }

        public static void Play(string sound, float pitch = 1f, float volumeDb = 0f)
        {
            if (!Enabled) return;
            AudioClip s = null;
            if (Settings.mode == "horror")
            {
                over["horror"].TryGetValue(sound, out s);
                if (s == null) over["normal"].TryGetValue(sound, out s);
                if (s == null) horror.TryGetValue(sound, out s);
                if (s == null) { streams.TryGetValue(sound, out s); pitch *= 0.8f; } // borrowed cheerful placeholder, slowed
            }
            else
            {
                if (!over["normal"].TryGetValue(sound, out s)) streams.TryGetValue(sound, out s);
            }
            if (s == null) return;
            foreach (var p in players)
            {
                if (p.isPlaying) continue;
                p.clip = s;
                p.pitch = Mathf.Clamp(pitch, 0.3f, 3f);
                p.volume = Mathf.Pow(10f, volumeDb / 20f) * AudioHub.SfxGain;
                p.Play();
                return;
            }
        }

        // ---- generators (identical formulas to the Godot version) ----
        static float RandRange(float a, float b) => a + (b - a) * (float)rnd.NextDouble();

        static float[] Samples(float dur, float f0, float f1, float vol, float vibrato, float noise)
        {
            int n = (int)(dur * RATE);
            var o = new float[n];
            float phase = 0f;
            for (int i = 0; i < n; i++)
            {
                float k = (float)i / n;
                float f = Gd.Lerp(f0, f1, k) * (1f + 0.06f * Mathf.Sin(Gd.TAU * vibrato * i / RATE));
                phase += Gd.TAU * f / RATE;
                float env = Mathf.Min(1f, k * 30f) * Mathf.Pow(1f - k, 1.5f);
                float v = Mathf.Sin(phase) * 0.8f + Mathf.Sin(phase * 2f) * 0.15f;
                v = v * (1f - noise) + RandRange(-1f, 1f) * noise;
                o[i] = v * env * vol;
            }
            return o;
        }

        /// Cartoon "BONK": a hollow wood-block knock with a falling pitch.
        static float[] Bonk()
        {
            int n = (int)(0.16f * RATE);
            var o = new float[n];
            float ph = 0f;
            for (int i = 0; i < n; i++)
            {
                float k = (float)i / n;
                ph += Gd.TAU * Gd.Lerp(820f, 380f, Mathf.Pow(k, 0.5f)) / RATE;
                o[i] = (Mathf.Sin(ph) * 0.8f + Mathf.Sin(ph * 2.7f) * 0.25f) * Mathf.Pow(1f - k, 3f) * 0.7f;
            }
            return o;
        }

        /// A nasal, buzzy toy quack.
        static float[] Quack(float dur, float f)
        {
            int n = (int)(dur * RATE);
            var o = new float[n];
            float ph = 0f;
            for (int i = 0; i < n; i++)
            {
                float k = (float)i / n;
                ph += Gd.TAU * f * (1f + 0.25f * Mathf.Sin(k * Gd.PI) - 0.3f * k) / RATE;
                float w = Gd.Sign(Mathf.Sin(ph)) * 0.5f + Mathf.Sin(ph * 3f) * 0.3f + Mathf.Sin(ph * 5f) * 0.15f;
                float env = Mathf.Min(1f, k * 25f) * (1f - k) * (0.7f + 0.3f * Mathf.Sin(k * Gd.TAU * 2f));
                o[i] = w * env * 0.35f;
            }
            return o;
        }

        /// A party-popper: a sharp pop followed by papery crackle.
        static float[] ConfettiSamples(float dur)
        {
            int n = (int)(dur * RATE);
            var o = new float[n];
            float ph = 0f;
            for (int i = 0; i < n; i++)
            {
                float k = (float)i / n;
                ph += Gd.TAU * Gd.Lerp(300f, 90f, k) / RATE;
                float pop = Mathf.Sin(ph) * Mathf.Pow(Mathf.Max(0f, 1f - k * 6f), 2f);
                float crackle = 0f;
                if (rnd.NextDouble() < 0.05f * (1f - k)) crackle = RandRange(-1f, 1f);
                float hiss = RandRange(-1f, 1f) * 0.25f * Mathf.Pow(1f - k, 2f);
                o[i] = (pop * 0.8f + crackle * 0.6f + hiss) * 0.55f;
            }
            return o;
        }

        /// A low, breathy "heh heh heh".
        static float[] Chuckle()
        {
            var o = new List<float>();
            for (int k = 0; k < 3; k++)
            {
                o.AddRange(Samples(0.11f, 150f - k * 12f, 110f, 0.4f, 0f, 0.55f));
                o.AddRange(Samples(0.05f, 0, 0, 0, 0, 0));
            }
            return o.ToArray();
        }

        /// A wet, muffled splat.
        static float[] Splat(float dur)
        {
            int n = (int)(dur * RATE);
            var o = new float[n];
            float lp = 0f;
            for (int i = 0; i < n; i++)
            {
                float k = (float)i / n;
                lp = Gd.Lerp(lp, RandRange(-1f, 1f), 0.05f + 0.1f * (1f - k));
                float drip = 0f;
                if (rnd.NextDouble() < 0.004f * (1f - k)) drip = RandRange(-0.6f, 0.6f);
                o[i] = (lp * 2.2f * Mathf.Pow(1f - k, 2.5f) + drip) * 0.6f;
            }
            return o;
        }

        static AudioClip Tone(string name, float dur, float f0, float f1, float vol, float vibrato, float noise)
            => Clip(name, Samples(dur, f0, f1, vol, vibrato, noise));

        static AudioClip Concat(string name, params float[][] parts)
        {
            var all = new List<float>();
            foreach (var p in parts) all.AddRange(p);
            return Clip(name, all.ToArray());
        }

        static AudioClip Clip(string name, float[] samples)
        {
            // quantise like the Godot 16-bit WAV (x30000) so loudness matches
            var data = new float[Mathf.Max(1, samples.Length)];
            for (int i = 0; i < samples.Length; i++) data[i] = Mathf.Clamp(samples[i], -1f, 1f) * (30000f / 32768f);
            var c = AudioClip.Create(name, data.Length, 1, RATE, false);
            c.SetData(data, 0);
            return c;
        }
    }

    /// Loads an audio file from disk (StreamingAssets or an external folder).
    public static class AudioLoader
    {
        public static AudioType TypeFor(string path)
        {
            switch (Path.GetExtension(path).ToLowerInvariant())
            {
                case ".ogg": return AudioType.OGGVORBIS;
                case ".wav": return AudioType.WAV;
                case ".mp3": return AudioType.MPEG;
                default: return AudioType.UNKNOWN;
            }
        }

        public static IEnumerator Load(string path, System.Action<AudioClip> done)
        {
            string url = new System.Uri(Path.GetFullPath(path)).AbsoluteUri;
            using (var req = UnityWebRequestMultimedia.GetAudioClip(url, TypeFor(path)))
            {
                yield return req.SendWebRequest();
                if (req.result != UnityWebRequest.Result.Success)
                {
                    Debug.LogWarning("Could not load audio " + path + ": " + req.error);
                    done(null);
                    yield break;
                }
                var clip = DownloadHandlerAudioClip.GetContent(req);
                if (clip != null) clip.name = Path.GetFileNameWithoutExtension(path);
                done(clip);
            }
        }
    }
}
