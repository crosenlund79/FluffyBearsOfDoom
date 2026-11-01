// Reads one or more input schemes ("p1"/"p2") into a bear's inputs (port of human_controller.gd).
using UnityEngine;

namespace FBD
{
    public class HumanController : IController
    {
        readonly Bear bear;
        readonly string[] schemes;
        int lastAxis;     // 0 = horizontal, 1 = vertical: the most recently pressed axis wins
        Vector2 prev;

        public HumanController(Bear b, string[] s) { bear = b; schemes = s; }

        public void Update(float delta)
        {
            Vector2 v = Vector2.zero;
            bool bomb = false, steal = false, special = false;
            foreach (string p in schemes)
            {
                v.x += Controls.Get(p, Controls.RIGHT) - Controls.Get(p, Controls.LEFT);
                v.y += Controls.Get(p, Controls.DOWN) - Controls.Get(p, Controls.UP);
                bomb |= Controls.ConsumeDown(p, Controls.BOMB);
                steal |= Controls.Held(p, Controls.STEAL);
                special |= Controls.ConsumeDown(p, Controls.SPECIAL);
            }
            float sx = Mathf.Abs(v.x) > 0.3f ? Gd.Sign(v.x) : 0f;
            float sy = Mathf.Abs(v.y) > 0.3f ? Gd.Sign(v.y) : 0f;
            if (sx != 0f && prev.x == 0f) lastAxis = 0;
            if (sy != 0f && prev.y == 0f) lastAxis = 1;
            prev = new Vector2(sx, sy);
            Vector2 dir = Vector2.zero;
            if (sx != 0f && sy != 0f) dir = lastAxis == 0 ? new Vector2(sx, 0) : new Vector2(0, sy);
            else if (sx != 0f) dir = new Vector2(sx, 0);
            else if (sy != 0f) dir = new Vector2(0, sy);
            bear.inputDir = dir;
            if (bomb) bear.wantBomb = true;
            bear.wantSteal = steal;
            if (special) bear.wantSpecial = true;
        }
    }
}
