Shader "Unlit/VRCTrace Camera"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
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

            float4 frag (v2f i) : SV_Target
            {
                float3 P = i.positionWS;
                float3 N = i.normalWS;
                float2 xi = GetRand(i.vertex.xy * _Time.y);

                float3 lightPosition = float3(0,1,0);
                float lightRadius = 0.1;
                lightPosition = RandomPointOnSphere(lightPosition, lightRadius, xi);
                float3 lightColor = 1;

                float3 positionToLight = lightPosition - P;
                float3 L = normalize(positionToLight);
                float attenuation = 1.0 / length(positionToLight);

                float3 diffuseColor = _Color;

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

                    // hitN = TriangleSmoothNormal(isect);

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

                return float4(directDiffuse + indirectDiffuse, 1);
            }
            ENDCG
        }
    }
}
