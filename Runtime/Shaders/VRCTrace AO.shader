Shader "Unlit/VRCTrace AO"
{
    Properties
    {
        _UdonVRCTraceLightmapPositionBuffer ("Position Buffer", 2D) = "black" {}
        _UdonVRCTraceLightmapNormalBuffer ("Normal Buffer", 2D) = "black" {}
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

            #pragma shader_feature_local _MONOSH

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                // o.vertex = UnityObjectToClipPos(v.vertex);

                float4 uv = float4(0,0,0,1);
                uv.xy = v.uv.xy * 2 - 1;
                uv.y *= _ProjectionParams.x;
                o.vertex = uv;
                o.uv = v.uv.xy;

                // o.uv = v.uv;
                float3 objectPosition = UNITY_MATRIX_M._m03_m13_m23;
                if (distance(_WorldSpaceCameraPos.xyz, objectPosition) > 2)
                {
                    o.vertex = asfloat(-1);
                }
                return o;
            }

            Texture2D<float4> _UdonVRCTraceLightmapPositionBuffer;
            SamplerState sampler_UdonVRCTraceLightmapPositionBuffer;
            Texture2D<float4> _UdonVRCTraceLightmapNormalBuffer;
            Texture2D<float4> _UdonVRCTraceLightmapCopy;

            int _UdonVRCTraceSampleCount;
            int _UdonVRCTraceSample;
            int _UdonVRCTraceRandomSample;

            float4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;

                float4 positionBuffer = _UdonVRCTraceLightmapPositionBuffer.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);
                float3 P = positionBuffer.rgb;
                float3 N = _UdonVRCTraceLightmapNormalBuffer.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);

                N = normalize(N);

                [branch]
                if (positionBuffer.a <= 0)
                {
                    return 1;
                }

                float4 previousRt = _UdonVRCTraceLightmapCopy.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);

                float2 xi = Hammersley(_UdonVRCTraceRandomSample, _UdonVRCTraceSampleCount);
                xi = frac(xi + GetRand(i.vertex.xy));

                float3 diffuseColor = 1;

                Ray ray;
                ray.D = RandomDirectionInHemisphere(N, xi);
                ray.P = RayOffset(P, N);
                float3 ao = 1;

                Intersection isect;
                if (SceneIntersects(ray, isect))
                {
                    ao *= 0;
                }

                float3 accumulated = (previousRt.rgb * _UdonVRCTraceSample + ao) / (_UdonVRCTraceSample + 1);

                return float4(accumulated, 1);
            }
            ENDCG
        }
    }
}
