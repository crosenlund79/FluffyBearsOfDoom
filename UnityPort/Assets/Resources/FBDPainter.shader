// Unlit vertex-colour shader used by the Painter for every sprite, shape and
// glyph. _AlphaOnly samples only the alpha channel (dynamic font atlases).
Shader "FBD/Painter"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _AlphaOnly ("Alpha only", Float) = 0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "PreviewType"="Plane" }
        Cull Off
        ZWrite Off
        ZTest Always
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _MainTex;
            float _AlphaOnly;
            struct appdata { float4 vertex : POSITION; float4 color : COLOR; float2 uv : TEXCOORD0; };
            struct v2f { float4 pos : SV_POSITION; float4 color : COLOR; float2 uv : TEXCOORD0; };
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.color = v.color;
                o.uv = v.uv;
                return o;
            }
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 t = tex2D(_MainTex, i.uv);
                if (_AlphaOnly > 0.5) t = fixed4(1, 1, 1, t.a);
                return t * i.color;
            }
            ENDCG
        }
    }
}
