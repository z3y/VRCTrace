Shader "Unlit/VRCTrace/Debug View"
{
    Properties
    {
        [Enum(Ng, 0, N, 1, P, 2, UV, 3, Color, 4)] _Type ("Type", Int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"
            #include "VRCTrace.hlsl"

            // #define _VERTEXTRACE
            // #define _REFLECTIONS

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            uint _Type;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v); //Insert
                UNITY_INITIALIZE_OUTPUT(v2f, o); //Insert
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); //Insert

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.positionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            SamplerState sampler_BilinearClamp;

            float4 frag (v2f i) : SV_Target
            {
                float3 P = i.positionWS;
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - P);

                Ray ray;
                ray.P = _WorldSpaceCameraPos.xyz;
                ray.D = -viewDir;
                ray.tMin = 0;
                ray.tMax = RAY_MAX;

                float4 color = 0;
                Intersection intersection;
                if (SceneIntersects(ray, intersection))
                {
                    float3 hitP, hitNg;
                    TrianglePointNormal(intersection, hitP, hitNg);
                    float3 hitN = TriangleSmoothNormal(intersection, hitNg);
                    float2 hitUV = TriangleUV(intersection);

                    if (_Type == 0)
                    {
                        color.rgb = saturate(hitNg);
                    }
                    else if (_Type == 1) {
                        color.rgb = saturate(hitN);
                    }
                    else if (_Type == 2) {
                        color.rgb = saturate(hitP);
                    }
                    else if (_Type == 3) {
                        color.rg = saturate(hitUV);
                    }
                    else if (_Type == 4) {
                        float3 hitCombined = _UdonVRCTraceCombinedAtlas.SampleLevel(sampler_BilinearClamp, hitUV, 0).rgb;
                        color.rgb = hitCombined;
                    }
                }

                return color;
            }
            ENDCG
        }
    }
}
