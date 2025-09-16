Shader "Unlit/VRCTrace Camera"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        _LightPosition ("Light Position", Vector) = (0,1,0,0)
        _LightRadius ("Light Position", Float) = 0.1
        _Roughness("Roughness", Range(0, 1)) = 0
        [IntRange] _Resolution("Resolution", Range(1,4)) = 1
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

            // #define _VERTEXTRACE
            // #define _REFLECTIONS

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                uint id : SV_VertexID;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 diffuse : TEXCOORD3;
                float4 vertex : SV_POSITION;
            };

            float4 _Color;
            float3 _LightPosition;
            float _LightRadius;
            float _Roughness;
            int _Resolution;

            float3 TraceDiffuse(float3 P, float3 N, float2 xi)
            {

                float3 lightPosition = _LightPosition;
                float lightRadius = _LightRadius;
                lightPosition = RandomPointOnSphere(lightPosition, lightRadius, xi);
                float3 lightColor = 1;

                float3 positionToLight = lightPosition - P;
                float3 L = normalize(positionToLight);
                float attenuation = 1.0 / dot(positionToLight, positionToLight);

                float3 diffuseColor = _Color;

                Ray ray;
                ray.D = L;
                ray.P = RayOffset(P, N);


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

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - P);
                float3 reflDir = reflect(-viewDir, N);
                float3 newDir = lerp(reflDir, RandomDirectionInHemisphere(N, xi), _Roughness * _Roughness);

                ray.D = newDir;
                ray.P = RayOffset(P, N);

                float3 indirectDiffuse = 0;

                if (SceneIntersects(ray, isect))
                {
                    float3 hitP, hitN;
                    TrianglePointNormal(isect, hitP, hitN);

                    hitN = TriangleSmoothNormal(isect, hitN);

                    bool isBackFace = dot(ray.D, hitN) > 0.0;

                    positionToLight = lightPosition - hitP;
                    L = normalize(positionToLight);
                    attenuation = 1.0 / dot(positionToLight, positionToLight);

                    ray.D = L;
                    ray.P = RayOffset(hitP, hitN);

                    diffuseColor = isect.object == 9 ? float3(0,1,0) : diffuseColor;

                    Li = attenuation * lightColor * diffuseColor;
                    cosTheta = max(0.0, dot(hitN, L));


                    [branch]
                    if (cosTheta > 0 && !isBackFace)
                    {
                        indirectDiffuse = Li * cosTheta;
                        if (SceneIntersects(ray, isect)) {
                            if (isect.t < length(positionToLight)) {
                                indirectDiffuse = 0;
                            }
                        }
                    }
                }

                return lerp(0, directDiffuse, _Roughness * _Roughness) + indirectDiffuse;
            }


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.positionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normalWS = UnityObjectToWorldNormal(v.normal);

                #ifdef _VERTEXTRACE
                float2 xi = GetRand(v.id.xx * _Time.y);
                float3 P = o.positionWS;
                float3 N = o.normalWS;
                o.diffuse = TraceDiffuse(P, N, xi) * 0.5;
                #endif

                return o;
            }


            float4 frag (v2f i) : SV_Target
            {
                float3 P = i.positionWS;
                float3 N = i.normalWS;

                float2 vpos = floor(i.vertex.xy / _Resolution) * _Resolution;
                if (_Resolution <= 1) vpos = i.vertex.xy;

                float2 xi = GetRand(vpos.xy * _Time.y);

                #ifndef _VERTEXTRACE
                float3 diffuse = TraceDiffuse(P, N, xi);
                #else
                float3 diffuse = i.diffuse;
                #endif

                #ifdef _REFLECTIONS
                    float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - P);
                    float3 reflDir = reflect(-viewDir, N);

                    Ray ray;
                    ray.D = reflDir;
                    ray.P = RayOffset(P, ray.D);

                    Intersection intersection;
                    if (SceneIntersects(ray, intersection))
                    {
                        float3 hitP, hitN;
                        TrianglePointNormal(intersection, hitP, hitN);
                        hitN = TriangleSmoothNormal(intersection, hitN);
                        return float4(hitN * 0.5 + 0.5, 1);
                    }
                    return 0;
                #endif

                return float4(diffuse, 1);
            }
            ENDCG
        }
    }
}
