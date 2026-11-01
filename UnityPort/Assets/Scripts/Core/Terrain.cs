// Terrain types and their physical properties. Purely data: the look of a
// terrain is only the "tile" index into the tile sheet. (Port of terrain.gd)
using System.Collections.Generic;
using UnityEngine;

namespace FBD
{
    public struct TerrainProps
    {
        public string name; public float accel, brake, speed, bounce; public Vector2 push; public int tile; public Color color;
        public TerrainProps(string n, float a, float b, float s, float bo, Vector2 p, int t, Color c)
        { name = n; accel = a; brake = b; speed = s; bounce = bo; push = p; tile = t; color = c; }
    }

    public static class Terrain
    {
        public const int NORMAL = 0, ICE = 1, HONEY = 2, BOUNCY = 3, CONVEYOR_R = 4, CONVEYOR_D = 5, CONVEYOR_L = 6, CONVEYOR_U = 7;
        public const int COUNT = 8;

        public static readonly TerrainProps[] PROPS =
        {
            new TerrainProps("Rug", 1f, 1f, 1f, 0.15f, Vector2.zero, 0, new Color(0.94f, 0.9f, 0.82f)),
            new TerrainProps("Ice", 0.28f, 0.1f, 1.15f, 0.35f, Vector2.zero, 2, new Color(0.75f, 0.9f, 0.97f)),
            new TerrainProps("Honey", 0.75f, 2.6f, 0.45f, 0f, Vector2.zero, 3, new Color(0.93f, 0.72f, 0.3f)),
            new TerrainProps("Bouncy", 1f, 0.8f, 1.05f, 0.95f, Vector2.zero, 4, new Color(0.95f, 0.68f, 0.76f)),
            new TerrainProps("Conveyor", 1f, 1f, 1f, 0.15f, new Vector2(75, 0), 5, new Color(0.67f, 0.71f, 0.75f)),
            new TerrainProps("Conveyor", 1f, 1f, 1f, 0.15f, new Vector2(0, 75), 5, new Color(0.67f, 0.71f, 0.75f)),
            new TerrainProps("Conveyor", 1f, 1f, 1f, 0.15f, new Vector2(-75, 0), 5, new Color(0.67f, 0.71f, 0.75f)),
            new TerrainProps("Conveyor", 1f, 1f, 1f, 0.15f, new Vector2(0, -75), 5, new Color(0.67f, 0.71f, 0.75f)),
        };

        public static readonly Dictionary<char, int> CHARS = new Dictionary<char, int>
        {
            { '.', NORMAL }, { 'i', ICE }, { 'h', HONEY }, { 'b', BOUNCY },
            { '>', CONVEYOR_R }, { 'v', CONVEYOR_D }, { '<', CONVEYOR_L }, { '^', CONVEYOR_U },
        };

        public static TerrainProps Props(int t) => PROPS[Mathf.Clamp(t, 0, COUNT - 1)];
        public static bool IsConveyor(int t) => t >= CONVEYOR_R;
        public static float ConveyorRotation(int t) => (t - CONVEYOR_R) * Mathf.PI * 0.5f;
    }
}
