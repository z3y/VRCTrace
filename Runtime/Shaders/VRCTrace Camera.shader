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

                Ray ray;
                ray.D = L;
                ray.P = RayOffset(P, ray.D);



                float3 color = 1;

                float3 Li = attenuation * lightColor * 1;
                float cosTheta = max(0.0, dot(N, L));
                float3 directDiffuse = Li * cosTheta;

                Intersection isec;
                if (SceneIntersects(ray, isec))
                {
                    if (isec.t < length(positionToLight))
                    {
                        directDiffuse = 0;
                    }
                }

                return float4(directDiffuse, 1);
            }
            ENDCG
        }
    }
}
