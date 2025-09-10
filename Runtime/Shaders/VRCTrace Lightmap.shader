Shader "Unlit/VRCTrace Lightmap"
{
    Properties
    {
        _UdonVRCTraceLightmapPositionBuffer ("Position Buffer", 2D) = "black" {}
        _UdonVRCTraceLightmapNormalBuffer ("Normal Buffer", 2D) = "black" {}
        // _BlueNoise ("Blue Noise", 2D) = "black" {}

        _LightPosition ("Light Position", Vector) = (0,1,0,0)
        _LightRadius ("Light Position", Float) = 0.1

        [Toggle(_MONOSH)] _MonoSH("Mono SH", Float) = 0
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
            Texture2D<float4> _UdonVRCTraceLightmapL1Copy;
            // Texture2D<float4> _BlueNoise;

            int _UdonVRCTraceSampleCount;
            int _UdonVRCTraceSample;
            int _UdonVRCTraceRandomSample;

            float3 _LightPosition;
            float _LightRadius;

            struct Fragout
            {
                float4 color0 : SV_Target0;
                float4 color1 : SV_Target1;
            };


            Fragout frag (v2f i)
            {
                float2 uv = i.uv;

                float4 positionBuffer = _UdonVRCTraceLightmapPositionBuffer.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);
                float3 P = positionBuffer.rgb;
                float3 N = _UdonVRCTraceLightmapNormalBuffer.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);

                N = normalize(N);

                [branch]
                if (positionBuffer.a <= 0)
                {
                    Fragout Out1;
                    Out1.color0 = 0;
                    Out1.color1 = 0;
                    return Out1;
                }

                // P.xz -= 0.01;

                // float4 noise = _BlueNoise[int2(i.vertex.xy)];

                float4 previousRt = _UdonVRCTraceLightmapCopy.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);
                float4 previousRt1 = _UdonVRCTraceLightmapL1Copy.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);

                float2 xi = Hammersley(_UdonVRCTraceRandomSample, _UdonVRCTraceSampleCount);
                xi = frac(xi + GetRand(i.vertex.xy));
                // xi = frac(xi + noise.xy);

                float3 lightPosition = _LightPosition;
                float lightRadius = _LightRadius;
                lightPosition = RandomPointOnSphere(lightPosition, lightRadius, xi);
                float3 lightColor = 2;

                float3 positionToLight = lightPosition - P;
                float3 L = normalize(positionToLight);
                float attenuation = 1.0 / dot(positionToLight, positionToLight);

                float3 diffuseColor = 1;
                
                float3 L0 = 0;
                float3 L1x = 0;
                float3 L1y = 0;
                float3 L1z = 0;
                
                // float Y0 = 0.282095;
                float Y0 = 0.25;
                // float Y1 = 0.488603;
                float Y1 = 0.5;

                Ray ray;
                ray.D = L;
                ray.P = RayOffset(P, ray.D);


                float3 color = 1;

                float3 Li = attenuation * lightColor * diffuseColor;
                float cosTheta = max(0.0, dot(N, L));
                float3 directDiffuse = Li * cosTheta;

                L0 = Li * cosTheta * Y0;
                L1x = Li * (cosTheta * L.x) * Y1;
                L1y = Li * (cosTheta * L.y) * Y1;
                L1z = Li * (cosTheta * L.z) * Y1;


                Intersection isect;
                if (TraceRay(ray, isect))
                {
                    if (isect.t < length(positionToLight))
                    {
                        directDiffuse = 0;
                        L0 = 0;
                        L1x = 0;
                        L1y = 0;
                        L1z = 0;
                    }
                }

                float3 newDir = RandomDirectionInHemisphere(N, xi);

                ray.D = newDir;
                ray.P = RayOffset(P, ray.D);

                float3 indirectDiffuse = 0;
                float3 L0_1 = 0;
                float3 L1x_1 = 0;
                float3 L1y_1 = 0;
                float3 L1z_1 = 0;

                if (TraceRay(ray, isect))
                {
                    float3 hitP, hitN;
                    TrianglePointNormal(isect, hitP, hitN);
                    bool isBackFace = dot(ray.D, hitN) > 0.0;

                    hitN = TriangleSmoothNormal(isect, hitN);

                    positionToLight = lightPosition - hitP;
                    L = normalize(positionToLight);
                    attenuation = 1.0 / dot(positionToLight, positionToLight);

                    ray.D = L;
                    ray.P = RayOffset(hitP, ray.D);

                    diffuseColor = isect.object == 9 ? float3(0,1,0) : diffuseColor;

                    Li = attenuation * lightColor * diffuseColor;
                    cosTheta = max(0.0, dot(hitN, L));


                    [branch]
                    if (cosTheta > 0 && !isBackFace)
                    {
                        
                        indirectDiffuse = Li * cosTheta;

                        L0_1 = Li * cosTheta * Y0;
                        L1x_1 = Li * (cosTheta * newDir.x) * Y1;
                        L1y_1 = Li * (cosTheta * newDir.y) * Y1;
                        L1z_1 = Li * (cosTheta * newDir.z) * Y1;

                        if (TraceRay(ray, isect)) {
                            if (isect.t < length(positionToLight))
                            {
                                indirectDiffuse = 0;
                                L0_1 = 0;
                                L1x_1 = 0;
                                L1y_1 = 0;
                                L1z_1 = 0;
                            }
                        }
                    }
                }
                L0 += L0_1;
                L1x += L1x_1;
                L1y += L1y_1;
                L1z += L1z_1;

                L0 *= UNITY_PI;
                L1x *= 2.0 * UNITY_PI / 3.0;
                L1y *= 2.0 * UNITY_PI / 3.0;
                L1z *= 2.0 * UNITY_PI / 3.0;

                Fragout Out;

                #ifdef _MONOSH


                    float3 previousDiffuse0 = previousRt.rgb;
                    float3 previousDiffuse1 = previousRt1.rgb;

                    L1x = (L1x / max(L0, 0.001)) * 0.5;
                    L1y = (L1y / max(L0, 0.001)) * 0.5;
                    L1z = (L1z / max(L0, 0.001)) * 0.5;

                    float3 monoSHL2 = float3(dot(L1x, 1.0 / 3.0), dot(L1y, 1.0 / 3.0), dot(L1z, 1.0 / 3.0));

                    monoSHL2 = monoSHL2 * 0.5 + 0.5;

                    float3 accumulated0 = (previousDiffuse0 * _UdonVRCTraceSample + L0) / (_UdonVRCTraceSample + 1);
                    float3 accumulated1 = (previousDiffuse1 * _UdonVRCTraceSample + monoSHL2) / (_UdonVRCTraceSample + 1);
                    Out.color0 = float4(accumulated0, 1);
                    Out.color1 = float4(accumulated1, 1);

                #else

                    float3 diffuse = directDiffuse + indirectDiffuse;
                    float3 previousDiffuse = previousRt.rgb;

                    float3 accumulated = (previousDiffuse * _UdonVRCTraceSample + diffuse) / (_UdonVRCTraceSample + 1);

                    Out.color0 = float4(accumulated, 1);

                #endif

                return Out;
            }
            ENDCG
        }
    }
}
