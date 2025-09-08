Shader "Unlit/VRCTrace Lightmap"
{
    Properties
    {
        _UdonVRCTraceLightmapPositionBuffer ("Position Buffer", 2D) = "black" {}
        _UdonVRCTraceLightmapNormalBuffer ("Normal Buffer", 2D) = "black" {}

        _LightPosition ("Light Position", Vector) = (0,1,0,0)
        _LightRadius ("Light Position", Float) = 0.1
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

            float3 _LightPosition;
            float _LightRadius;

            float4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;

                float4 positionBuffer = _UdonVRCTraceLightmapPositionBuffer.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);
                float3 P = positionBuffer.rgb;
                float3 N = _UdonVRCTraceLightmapNormalBuffer.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);

                [branch]
                if (positionBuffer.a <= 0)
                {
                    return 0;
                }

                float4 previousRt = _UdonVRCTraceLightmapCopy.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);

                float2 xi = Hammersley(_UdonVRCTraceRandomSample, _UdonVRCTraceSampleCount);
                xi = frac(xi + GetRand(i.vertex.xy));

                float3 lightPosition = _LightPosition;
                float lightRadius = _LightRadius;
                lightPosition = RandomPointOnSphere(lightPosition, lightRadius, xi);
                float3 lightColor = 1;

                float3 positionToLight = lightPosition - P;
                float3 L = normalize(positionToLight);
                float attenuation = 1.0 / length(positionToLight);

                float3 diffuseColor = 1;

                Ray ray;
                ray.D = L;
                ray.P = RayOffset(P, ray.D);


                float3 color = 1;

                float3 Li = attenuation * lightColor * diffuseColor;
                float cosTheta = max(0.0, dot(N, L));
                float3 directDiffuse = Li * cosTheta;

                Intersection isect;
                if (SceneIntersects(ray, isect))
                {
                    if (isect.t < length(positionToLight))
                    {
                        directDiffuse = 0;
                    }
                }

                float3 newDir = RandomDirectionInHemisphere(N, xi);

                ray.D = newDir;
                ray.P = RayOffset(P, ray.D);

                float3 indirectDiffuse = 0;

                if (SceneIntersects(ray, isect))
                {
                    float3 hitP, hitN;
                    TrianglePointNormal(isect, hitP, hitN);

                    // hitN = TriangleSmoothNormal(isect, hitN);

                    positionToLight = lightPosition - hitP;
                    L = normalize(positionToLight);
                    attenuation = 1.0 / length(positionToLight);

                    ray.D = L;
                    ray.P = RayOffset(hitP, ray.D);

                    diffuseColor = isect.object == 3 ? float3(0,1,0) : diffuseColor;

                    Li = attenuation * lightColor * diffuseColor;
                    cosTheta = max(0.0, dot(hitN, -L));

                    indirectDiffuse = Li * cosTheta;

                    [branch]
                    if (cosTheta > 0)
                    {
                        if (SceneIntersects(ray, isect)) {
                            if (isect.t < length(positionToLight)) {
                                indirectDiffuse = 0;
                            }
                        }
                    }
                }

                float3 diffuse = directDiffuse + indirectDiffuse;
                float3 previousDiffuse = previousRt.rgb;

                float3 accumulated = (previousDiffuse * _UdonVRCTraceSample + diffuse) / (_UdonVRCTraceSample + 1);

                return float4(accumulated, 1);
            }
            ENDCG
        }
    }
}
