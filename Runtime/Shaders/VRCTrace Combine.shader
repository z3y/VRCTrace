Shader "Hidden/VRCTrace/Combine"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _Albedo;
            sampler2D _Emission;
            sampler2D _Lightmap;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                float4 uv = float4(0,0,0,1);
                uv.xy = v.uv.xy * 2 - 1;
                uv.y *= _ProjectionParams.x;
                o.vertex = uv;
                o.uv = v.uv.xy;

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 lm = tex2D(_Lightmap, i.uv);
                float3 albedo = tex2D(_Albedo, i.uv);
                i.uv.y = 1.0 - i.uv.y;
                float3 emission = tex2D(_Emission, i.uv);

                emission.r = LinearToGammaSpaceExact(emission.r);
                emission.g = LinearToGammaSpaceExact(emission.g);
                emission.b = LinearToGammaSpaceExact(emission.b);
                
                float4 col = float4(albedo * lm + emission, 1);
                return col;
            }
            ENDCG
        }
    }
}
