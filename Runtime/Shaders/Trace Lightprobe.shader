Shader "Unlit/VRCTrace Lightprobe"
{
    Properties
    {
        _ProbePositionBuffer ("Probe Position Buffer", 2D) = "black" {}

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

            Texture2D<float4> _ProbePositionBuffer;
            SamplerState sampler_ProbePositionBuffer;

            int _UdonVRCTraceSampleCount;
            int _UdonVRCTraceSample;
            int _UdonVRCTraceRandomSample;

            float3 _LightPosition;
            float _LightRadius;

            struct Fragout
            {
                float3 L0 : SV_Target0;
                float3 L1x : SV_Target1;
                float3 L1y : SV_Target2;
                float3 L1z : SV_Target3;
            };

            Texture2D<float4> _UdonVRCTraceProbesL0Copy;
            SamplerState sampler_UdonVRCTraceProbesL0Copy;
            Texture2D<float4> _UdonVRCTraceProbesL1xCopy;
            Texture2D<float4> _UdonVRCTraceProbesL1yCopy;
            Texture2D<float4> _UdonVRCTraceProbesL1zCopy;



            Fragout frag (v2f i)
            {
                float2 uv = i.uv;
                
                float3 previousL0 = _UdonVRCTraceProbesL0Copy.SampleLevel(sampler_UdonVRCTraceProbesL0Copy, uv, 0);
                float3 previousL1x = _UdonVRCTraceProbesL1xCopy.SampleLevel(sampler_UdonVRCTraceProbesL0Copy, uv, 0);
                float3 previousL1y = _UdonVRCTraceProbesL1yCopy.SampleLevel(sampler_UdonVRCTraceProbesL0Copy, uv, 0);
                float3 previousL1z = _UdonVRCTraceProbesL1zCopy.SampleLevel(sampler_UdonVRCTraceProbesL0Copy, uv, 0);

                uv.y = 1.0 - uv.y;

                float4 positionBuffer = _ProbePositionBuffer.SampleLevel(sampler_ProbePositionBuffer, uv, 0);
                float3 P = positionBuffer.rgb;

                [branch]
                if (positionBuffer.a <= 0)
                {
                    Fragout Out1;
                    Out1.L0 = 0;
                    Out1.L1x = 0;
                    Out1.L1y = 0;
                    Out1.L1z = 0;
                    return Out1;
                }


                // float4 previousRt = _UdonVRCTraceLightmapCopy.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);
                // float4 previousRt1 = _UdonVRCTraceLightmapL1Copy.SampleLevel(sampler_UdonVRCTraceLightmapPositionBuffer, uv, 0);

                float2 xi = Hammersley(_UdonVRCTraceRandomSample, _UdonVRCTraceSampleCount);
                xi = frac(xi + GetRand(i.vertex.xy));

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
                
                float Y0 = 0.282095;
                float Y1 = 0.488603;

                Ray ray;
                ray.D = L;
                ray.P = P;

                float3 Li = attenuation * lightColor;

                L0 = Li * Y0;
                L1x = Li * L.x * Y1;
                L1y = Li * L.y * Y1;
                L1z = Li * L.z * Y1;


                Intersection isect;
                if (TraceRay(ray, isect))
                {
                    if (isect.t < length(positionToLight))
                    {
                        L0 = 0;
                        L1x = 0;
                        L1y = 0;
                        L1z = 0;
                    }
                }

                float3 newDir = RandomDirection(xi);

                ray.D = newDir;
                ray.P = RayOffset(P, ray.D);

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

                    float3 diffuseColor = isect.object == 9 ? float3(0,1,0) : 1;

                    Li = attenuation * lightColor * diffuseColor;
                    float cosTheta = max(0.0, dot(hitN, L));

                    [branch]
                    if (cosTheta > 0 && !isBackFace)
                    {
                        L0_1 = Li * cosTheta * Y0;// * UNITY_PI * 4;
                        L1x_1 = Li * (cosTheta * newDir.x) * Y1;// * UNITY_PI * 4;
                        L1y_1 = Li * (cosTheta * newDir.y) * Y1;// * UNITY_PI * 4;
                        L1z_1 = Li * (cosTheta * newDir.z) * Y1;// * UNITY_PI * 4;

                        if (TraceRay(ray, isect)) {
                            if (isect.t < length(positionToLight))
                            {
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

                // L0 *= UNITY_PI;
                // L1x *= 2.0 * UNITY_PI / 3.0;
                // L1y *= 2.0 * UNITY_PI / 3.0;
                // L1z *= 2.0 * UNITY_PI / 3.0;

                Fragout Out;
                Out.L0 = float3(previousL0 * _UdonVRCTraceSample + L0) / (_UdonVRCTraceSample + 1);
                Out.L1x = float3(previousL1x * _UdonVRCTraceSample + L1x) / (_UdonVRCTraceSample + 1);
                Out.L1y = float3(previousL1y * _UdonVRCTraceSample + L1y) / (_UdonVRCTraceSample + 1);
                Out.L1z = float3(previousL1z * _UdonVRCTraceSample + L1z) / (_UdonVRCTraceSample + 1);
                return Out;
            }
            ENDCG
        }
    }
}
