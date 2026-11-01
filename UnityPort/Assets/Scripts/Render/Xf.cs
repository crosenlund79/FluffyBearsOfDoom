// 2D affine transform in Godot's y-down canvas space (x axis, y axis, origin).
using UnityEngine;

namespace FBD
{
    public struct Xf
    {
        public Vector2 x, y, o;
        public static readonly Xf Identity = new Xf { x = new Vector2(1, 0), y = new Vector2(0, 1), o = Vector2.zero };

        public static Xf TRS(Vector2 pos, float rot, Vector2 scale)
        {
            float c = Mathf.Cos(rot), s = Mathf.Sin(rot);
            return new Xf { x = new Vector2(c, s) * scale.x, y = new Vector2(-s, c) * scale.y, o = pos };
        }
        public static Xf Translate(Vector2 pos) => TRS(pos, 0f, Vector2.one);

        public Vector2 Apply(Vector2 p) => o + x * p.x + y * p.y;
        public Vector2 ApplyVec(Vector2 v) => x * v.x + y * v.y;

        /// a * b : apply b first, then a (parent * child).
        public static Xf operator *(Xf a, Xf b)
        {
            return new Xf { x = a.ApplyVec(b.x), y = a.ApplyVec(b.y), o = a.Apply(b.o) };
        }

        public Xf Inverse()
        {
            float det = x.x * y.y - y.x * x.y;
            if (Mathf.Abs(det) < 1e-9f) return Identity;
            float id = 1f / det;
            var inv = new Xf
            {
                x = new Vector2(y.y * id, -x.y * id),
                y = new Vector2(-y.x * id, x.x * id),
            };
            inv.o = -(inv.x * o.x + inv.y * o.y);
            return inv;
        }
    }
}
