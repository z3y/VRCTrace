Shader "Unlit/VRCTrace Light Probe"
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

                // only show on compute camera
                float3 objectPosition = UNITY_MATRIX_M._m03_m13_m23;
                if (distance(_WorldSpaceCameraPos.xyz, objectPosition) > 2)
                {
                    o.vertex = asfloat(-1);
                }
                return o;
            }

            Texture2D<float4> _ProbePositionBuffer;
            SamplerState sampler_ProbePositionBuffer;

            int _UdonVRCTraceProbeSampleCount;
            int _UdonVRCTraceProbeSample;
            int _UdonVRCTraceProbeRandomSample;

            float3 _LightPosition;
            float _LightRadius;

            struct Fragout
            {
                float4 Tex0 : SV_Target0;
                float4 Tex1 : SV_Target1;
                float4 Tex2 : SV_Target2;
            };

            Texture2D<float4> _UdonVRCTraceProbesTex0Copy;
            Texture2D<float4> _UdonVRCTraceProbesTex1Copy;
            Texture2D<float4> _UdonVRCTraceProbesTex2Copy;
            SamplerState sampler_UdonVRCTraceProbesTex0Copy;


            Fragout frag (v2f i)
            {
                float2 uv = i.uv;
                
                float4 previousTex0 = _UdonVRCTraceProbesTex0Copy.SampleLevel(sampler_UdonVRCTraceProbesTex0Copy, uv, 0);
                float4 previousTex1 = _UdonVRCTraceProbesTex1Copy.SampleLevel(sampler_UdonVRCTraceProbesTex0Copy, uv, 0);
                float4 previousTex2 = _UdonVRCTraceProbesTex2Copy.SampleLevel(sampler_UdonVRCTraceProbesTex0Copy, uv, 0);

                uv.y = 1.0 - uv.y;

                float4 positionBuffer = _ProbePositionBuffer.SampleLevel(sampler_ProbePositionBuffer, uv, 0);
                float3 P = positionBuffer.rgb;

                [branch]
                if (positionBuffer.a <= 0)
                {
                    Fragout Out1;
                    Out1.Tex0 = 0;
                    Out1.Tex1 = 0;
                    Out1.Tex2 = 0;
                    return Out1;
                }

                float2 xi = Hammersley(_UdonVRCTraceProbeRandomSample, _UdonVRCTraceProbeSampleCount);
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
                if (SceneIntersects(ray, isect))
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

                if (SceneIntersects(ray, isect))
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
                        L0_1 = Li * cosTheta * Y0;// * UNITY_PI * 4; // for some reason this makes it look worse
                        L1x_1 = Li * (cosTheta * newDir.x) * Y1;// * UNITY_PI * 4;
                        L1y_1 = Li * (cosTheta * newDir.y) * Y1;// * UNITY_PI * 4;
                        L1z_1 = Li * (cosTheta * newDir.z) * Y1;// * UNITY_PI * 4;

                        if (SceneIntersects(ray, isect)) {
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

                float4 tex0 = float4(L1x, L0.x);
                float4 tex1 = float4(L1y, L0.y);
                float4 tex2 = float4(L1z, L0.z);

                Fragout Out;
                Out.Tex0 = float4(previousTex0 * _UdonVRCTraceProbeSample + tex0) / (_UdonVRCTraceProbeSample + 1);
                Out.Tex1 = float4(previousTex1 * _UdonVRCTraceProbeSample + tex1) / (_UdonVRCTraceProbeSample + 1);
                Out.Tex2 = float4(previousTex2 * _UdonVRCTraceProbeSample + tex2) / (_UdonVRCTraceProbeSample + 1);
                return Out;
            }
            ENDCG
        }
    }
}
