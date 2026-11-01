// Entry point. Created automatically after the first scene loads, so the
// Main scene only needs to exist. Owns the camera, the Painter, the audio hub
// and switches between the menu and a match (port of main.gd).
using UnityEngine;

namespace FBD
{
    public class App : MonoBehaviour
    {
        Camera cam;
        Painter painter;
        Gui gui;
        Menu menu;
        Game game;
        Hud hud;
        System.Action pending;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot()
        {
            if (FindObjectOfType<App>() != null) return;
            new GameObject("Fluffy Bears of Doom").AddComponent<App>();
        }

        void Awake()
        {
            DontDestroyOnLoad(gameObject);
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 1;
            Time.fixedDeltaTime = 1f / 60f;   // Godot's default 60 physics ticks per second
            Settings.Load();
            Assets.Ensure();
            SetupCamera();
            gameObject.AddComponent<AudioHub>();
            painter = new Painter();
            gui = new Gui(painter);
            ShowMenu();
        }

        void SetupCamera()
        {
            foreach (var c in FindObjectsOfType<Camera>()) c.enabled = false;
            var go = new GameObject("Canvas Camera");
            go.transform.SetParent(transform);
            cam = go.AddComponent<Camera>();
            cam.orthographic = true;
            cam.orthographicSize = 360f;
            cam.transform.position = new Vector3(640f, -360f, -10f);
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = Color.black;
            cam.nearClipPlane = 0.1f;
            cam.farClipPlane = 100f;
            go.AddComponent<AudioListener>();
        }

        /// Keep 1280x720 visible with letterboxing (Godot stretch aspect "keep").
        void Letterbox()
        {
            float target = 1280f / 720f;
            float screen = (float)Screen.width / Mathf.Max(1, Screen.height);
            if (screen > target) { float w = target / screen; cam.rect = new Rect((1f - w) * 0.5f, 0f, w, 1f); }
            else { float h = screen / target; cam.rect = new Rect(0f, (1f - h) * 0.5f, 1f, h); }
            painter.pixelScale = cam.pixelHeight / 720f;
        }

        Vector2 CanvasMouse()
        {
            Vector3 w = cam.ScreenToWorldPoint(Input.mousePosition);
            return new Vector2(w.x, -w.y);
        }

        void ShowMenu()
        {
            game = null;
            hud = null;
            Assets.Ensure();
            menu = new Menu(gui);
            menu.StartRequested += () => pending = StartGame;
            menu.ModeChanged += () => pending = () => { Assets.Ensure(); ShowMenu(); };
            menu.QuitRequested += () => pending = Quit;
        }

        void StartGame()
        {
            menu = null;
            Assets.Ensure();
            Controls.ClearDowns();
            game = new Game();
            hud = new Hud(game, gui);
            game.hud = hud;
            game.QuitToMenu += () => pending = ShowMenu;
            game.RestartRequested += () => pending = StartGame;
            game.Setup();
        }

        static void Quit()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.isPlaying = false;
#else
            Application.Quit();
#endif
        }

        void Update()
        {
            Controls.Poll();
            float dt = Time.deltaTime;
            if (game != null)
            {
                if (Controls.PausePressed() && !gui.PopupOpen)
                {
                    if (hud.AudioOpen) hud.CloseAudio();
                    else game.TogglePause();
                }
                game.Process(dt);
                hud.Update(dt);
            }
            else menu?.Update(dt);
        }

        void FixedUpdate()
        {
            game?.PhysicsStep(Time.fixedDeltaTime);
        }

        void LateUpdate()
        {
            Letterbox();
            painter.BeginFrame();
            gui.Begin(CanvasMouse());
            if (game != null) { game.Draw(painter); hud.Draw(); }
            else menu?.Draw();
            gui.End();
            painter.Flush(cam);
            if (pending != null) { var a = pending; pending = null; a(); }
        }
    }
}
