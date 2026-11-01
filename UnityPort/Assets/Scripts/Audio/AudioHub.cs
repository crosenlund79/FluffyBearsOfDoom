// Hosts all AudioSources and applies the volume settings. Unity has no audio
// buses without a mixer asset, so Master/Music/SFX are applied as gains here.
using UnityEngine;

namespace FBD
{
    public class AudioHub : MonoBehaviour
    {
        public static float SfxGain => Settings.muted ? 0f : Settings.master_volume * Settings.sfx_volume;
        public static float MusicGain => Settings.muted ? 0f : Settings.master_volume * Settings.music_volume;

        void Awake()
        {
            Sfx.Init(gameObject);
            Music.Init(this);
            StartCoroutine(Sfx.LoadReplacements());
        }

        void Update()
        {
            Music.Tick();
            if (Input.GetKeyDown(KeyCode.N) || Input.GetKeyDown(KeyCode.Joystick1Button6)) Music.NextTrack();
        }
    }
}
