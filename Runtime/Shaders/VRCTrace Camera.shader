Shader "Unlit/VRCTrace Camera"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"
            #include "VRCTrace.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.positionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

SamplerState sampler_UdonVRCTraceBounds;

            float4 frag (v2f i) : SV_Target
            {
                float3 P = i.positionWS;
                float3 lightPosition = float3(0,1,0);

                float3 positionToLight = lightPosition - P;
                float3 L = normalize(positionToLight);

                Ray ray;
                ray.D = L;
                ray.P = RayOffset(P, ray.D);

                float3 color = 1;

                Intersection isec;
                if (SceneIntersects(ray, isec))
                {
                    if (isec.t < length(positionToLight))
                    {
                        color = 0;
                    }
                }

                // return _UdonVRCTraceBounds.Sample(sampler_UdonVRCTraceBounds, i.uv);

                return float4(color, 1);
            }
            ENDCG
        }
    }
}
