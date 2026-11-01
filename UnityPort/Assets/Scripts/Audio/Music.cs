// Music playlists per screen and mode (port of music.gd), discovered
// automatically - no code changes needed. Folders (mp3 / ogg / wav):
//   StreamingAssets/Audio/music/menu/normal/      .../menu/horror/
//   StreamingAssets/Audio/music/gameplay/normal/  .../gameplay/horror/
// Loose files directly in menu/ or gameplay/ are shared by both modes.
// In a built game you can also drop files into the same sub-folders under
// "music/" next to the executable, or under <persistentDataPath>/music/.
// If a Horror playlist is empty the Normal tracks play slowed and detuned.
// Only one track ever plays: switching fades the old one out first.
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace FBD
{
    public static class Music
    {
        public static readonly string[] SCREENS = { "menu", "gameplay" };
        public static readonly string[] MODES = { "normal", "horror" };
        static readonly string[] EXTS = { ".mp3", ".ogg", ".wav" };
        const float FADE_OUT = 0.7f, FADE_IN = 0.8f;
        public const float HORROR_FALLBACK_PITCH = 0.82f;

        public static readonly Dictionary<string, List<string>> playlists = new Dictionary<string, List<string>>();
        static readonly Dictionary<string, List<int>> orders = new Dictionary<string, List<int>>();
        static readonly Dictionary<string, int> positions = new Dictionary<string, int>();
        public static string context = "";
        public static string title = "";
        public static event System.Action<string> TrackChanged;

        static AudioSource player;
        static MonoBehaviour host;
        static float fade;           // 0..1 gain
        static int switchId;
        static bool started;         // a track is meant to be playing
        static string source = "";
        static readonly System.Random rnd = new System.Random();

        public static string Root => Path.Combine(Application.streamingAssetsPath, "Audio", "music");

        public static void Init(MonoBehaviour h)
        {
            host = h;
            player = h.gameObject.AddComponent<AudioSource>();
            player.playOnAwake = false;
            player.loop = false;
            Scan();
        }

        public static void Scan()
        {
            var roots = new List<string> { Root, Path.Combine(Application.persistentDataPath, "music") };
            if (!Application.isEditor) roots.Add(Path.Combine(Path.GetDirectoryName(Application.dataPath), "music"));
            foreach (string screen in SCREENS)
                foreach (string mode in MODES)
                {
                    string key = screen + "/" + mode;
                    playlists[key] = new List<string>();
                    orders[key] = new List<int>();
                    positions[key] = -1;
                    foreach (string b in roots)
                    {
                        ScanDir(Path.Combine(b, screen, mode), key);
                        ScanDir(Path.Combine(b, screen), key); // shared by both modes
                    }
                }
        }

        static void ScanDir(string dir, string key)
        {
            if (!Directory.Exists(dir)) return;
            var files = new List<string>(Directory.GetFiles(dir));
            files.Sort(System.StringComparer.Ordinal);
            foreach (string f in files)
            {
                string ext = Path.GetExtension(f).ToLowerInvariant();
                if (System.Array.IndexOf(EXTS, ext) < 0) continue;
                if (!playlists[key].Contains(f)) playlists[key].Add(f);
            }
        }

        static string Key(string screen) => screen + "/" + Settings.mode;

        /// The playlist that will really play for `key`, applying the Horror fallback.
        static string Resolve(string key)
        {
            if (playlists.TryGetValue(key, out var l) && l.Count > 0) return key;
            if (key.EndsWith("/horror"))
            {
                string normal = key.Replace("/horror", "/normal");
                if (playlists.TryGetValue(normal, out var n) && n.Count > 0) return normal;
            }
            return key;
        }

        public static bool HasTracks(string screen = "")
        {
            string key = screen == "" ? context : Key(screen);
            return key != "" && playlists.TryGetValue(Resolve(key), out var l) && l.Count > 0;
        }

        /// Switch to "menu" or "gameplay" music for the current mode, fading out first.
        public static void PlayContext(string screen)
        {
            if (player == null) return;
            string key = Key(screen);
            if (key == context && started) return;
            context = key;
            switchId++;
            host.StartCoroutine(FadeThen(switchId, true));
        }

        public static void Stop()
        {
            if (player == null) return;
            context = "";
            switchId++;
            host.StartCoroutine(FadeThen(switchId, false));
        }

        public static void NextTrack()
        {
            if (player == null || context == "" || !HasTracks()) return;
            switchId++;
            host.StartCoroutine(FadeThen(switchId, true));
        }

        public static void Reshuffle()
        {
            foreach (var k in new List<string>(orders.Keys)) orders[k] = new List<int>();
        }

        static IEnumerator FadeThen(int id, bool startNext)
        {
            if (player.isPlaying)
            {
                float f0 = fade;
                for (float t = 0f; t < FADE_OUT; t += Time.unscaledDeltaTime)
                {
                    if (id != switchId) yield break; // a newer switch took over
                    fade = Mathf.Lerp(f0, 0f, t / FADE_OUT);
                    yield return null;
                }
            }
            if (id != switchId) yield break;
            player.Stop();
            started = false;
            if (startNext) yield return StartNext(id);
        }

        static IEnumerator StartNext(int id)
        {
            title = "";
            if (context == "") yield break;
            source = Resolve(context);
            if (!playlists.TryGetValue(source, out var list) || list.Count == 0) { TrackChanged?.Invoke(title); yield break; }
            if (orders[source].Count != list.Count) BuildOrder(source);
            positions[source]++;
            if (positions[source] >= orders[source].Count) { BuildOrder(source); positions[source] = 0; }
            string path = list[orders[source][positions[source]]];
            AudioClip clip = null;
            yield return AudioLoader.Load(path, c => clip = c);
            if (id != switchId) yield break;
            if (clip == null) { TrackChanged?.Invoke(title); yield break; }
            player.clip = clip;
            player.pitch = source != context ? HORROR_FALLBACK_PITCH : 1f;
            fade = 0f;
            player.Play();
            started = true;
            title = Path.GetFileNameWithoutExtension(path).Replace("_", " ");
            if (source != context) title += " (slowed - no horror track yet)";
            TrackChanged?.Invoke(title);
            for (float t = 0f; t < FADE_IN; t += Time.unscaledDeltaTime)
            {
                if (id != switchId) yield break;
                fade = t / FADE_IN;
                yield return null;
            }
            fade = 1f;
        }

        static void BuildOrder(string key)
        {
            var o = new List<int>();
            for (int i = 0; i < playlists[key].Count; i++) o.Add(i);
            if (Settings.shuffle_music)
                for (int i = o.Count - 1; i > 0; i--) { int j = rnd.Next(i + 1); int t = o[i]; o[i] = o[j]; o[j] = t; }
            orders[key] = o;
        }

        /// Called every frame by the AudioHub: volume and end-of-track detection.
        public static void Tick()
        {
            if (player == null) return;
            // perceptual fade similar to Godot's -40 dB -> 0 dB volume tween
            float fadeGain = fade <= 0f ? 0f : Mathf.Pow(10f, Mathf.Lerp(-40f, 0f, fade) / 20f);
            player.volume = AudioHub.MusicGain * fadeGain;
            if (started && player.clip != null && !player.isPlaying && Application.isFocused
                && player.timeSamples == 0 && context != "")
            {
                started = false;
                switchId++;
                host.StartCoroutine(StartNext(switchId)); // track finished: advance
            }
        }
    }
}
