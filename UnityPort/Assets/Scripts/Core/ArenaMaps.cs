// Arena definitions (port of arena_maps.gd). Walls follow the classic pillar
// grid; terrain rows use  . rug  i ice  h honey  b bouncy  > v < ^ conveyors.
namespace FBD
{
    public class MapDef
    {
        public string name, desc; public float blockDensity; public string[] terrain;
        public MapDef(string n, string d, float bd, string[] t) { name = n; desc = d; blockDensity = bd; terrain = t; }
    }

    public static class ArenaMaps
    {
        public static readonly MapDef[] MAPS =
        {
            new MapDef("Traditional Nursery", "A cosy rug, pillow blocks and wooden toy pillars. Honest, classic mayhem.", 0.72f, new string[0]),
            new MapDef("Frozen Nursery", "Somebody left the window open. Tiny feet, slippery floor, enormous bellies.", 0.62f, new[]
            {
                "...............",
                "...iiiiiiiii...",
                "...iiiiiiiii...",
                "iiiiiiiiiiiiiii",
                "iiiiiii.iiiiiii",
                "iiiiiii.iiiiiii",
                "iiiii.....iiiii",
                "iiiiiii.iiiiiii",
                "iiiiiii.iiiiiii",
                "iiiiiiiiiiiiiii",
                "...iiiiiiiii...",
                "...iiiiiiiii...",
                "...............",
            }),
            new MapDef("Playroom Mayhem", "Honey spills, bouncy mattresses and toy-train conveyor belts.", 0.66f, new[]
            {
                "...............",
                "....>>>>>>>....",
                "...............",
                ".hh.........bb.",
                ".hh.........bb.",
                "...v.......^...",
                "...v..iii..^...",
                "...v.......^...",
                ".bb.........hh.",
                ".bb.........hh.",
                "...............",
                "....<<<<<<<....",
                "...............",
            }),
        };
    }
}
