Shader "Unlit/VRCTrace Camera"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
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
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.positionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float4 _Color;
            float3 _LightPosition;
            float _LightRadius;

            float4 frag (v2f i) : SV_Target
            {
                float3 P = i.positionWS;
                float3 N = i.normalWS;

                float2 xi = GetRand(i.vertex.xy * _Time.y);

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
                ray.P = RayOffset(P, ray.D);


                float3 color = 1;

                float3 Li = attenuation * lightColor * diffuseColor;
                float cosTheta = max(0.0, dot(N, L));
                float3 directDiffuse = Li * cosTheta;

                Intersection isect;
                if (TraceRay(ray, isect))
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

                if (TraceRay(ray, isect))
                {
                    float3 hitP, hitN;
                    TrianglePointNormal(isect, hitP, hitN);

                    hitN = TriangleSmoothNormal(isect, hitN);

                    bool isBackFace = dot(ray.D, hitN) > 0.0;

                    positionToLight = lightPosition - hitP;
                    L = normalize(positionToLight);
                    attenuation = 1.0 / dot(positionToLight, positionToLight);

                    ray.D = L;
                    ray.P = RayOffset(hitP, ray.D);

                    diffuseColor = isect.object == 3 ? float3(0,1,0) : diffuseColor;

                    Li = attenuation * lightColor * diffuseColor;
                    cosTheta = max(0.0, dot(hitN, L));


                    [branch]
                    if (cosTheta > 0 && !isBackFace)
                    {
                        indirectDiffuse = Li * cosTheta;
                        if (TraceRay(ray, isect)) {
                            if (isect.t < length(positionToLight)) {
                                indirectDiffuse = 0;
                            }
                        }
                    }
                }

                return float4(directDiffuse + indirectDiffuse, 1);
            }
            ENDCG
        }
    }
}
