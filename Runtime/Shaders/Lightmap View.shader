Shader "Unlit/Lightmap View"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BumpScale("Scale", Float) = 1.0
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}
        _Color ("Color", Color) = (1,1,1,1)

        [Toggle(_MONOSH)] _MonoSH("Mono SH", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityStandardUtils.cginc"

            #pragma shader_feature_local _MONOSH

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
            };

            struct v2f
            {
                float2 uv1 : TEXCOORD0;
                float2 uv : TEXCOORD3;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _BumpScale;

            Texture2D _UdonVRCTraceLightmap;
            Texture2D _BumpMap;
            SamplerState sampler_BumpMap;
            Texture2D _UdonVRCTraceLightmapL1;
            SamplerState sampler_UdonVRCTraceLightmap;
            SamplerState sampler_UdonVRCTraceLightmapL1;
            float4 _Color;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.tangentWS = float4(UnityObjectToWorldDir(v.tangent), v.tangent.w);
                o.uv1 = v.uv1;
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 L0 = _UdonVRCTraceLightmap.SampleLevel(sampler_UdonVRCTraceLightmap, i.uv1, 0) ;

                float4 normalMap = _BumpMap.Sample(sampler_BumpMap, i.uv);

                float3 normalTS = UnpackScaleNormal(normalMap, _BumpScale);

                float3 normalWS = i.normalWS;
                float3 tangentWS = i.tangentWS;

                float crossSign = (i.tangentWS.w > 0.0 ? 1.0 : -1.0) * unity_WorldTransformParams.w;
                float3 bitangentWS = crossSign * cross(normalWS.xyz, tangentWS.xyz);
                float3x3 tbn = float3x3(tangentWS, bitangentWS, normalWS);

                normalWS = normalize(mul(normalTS, tbn));

                float3 lightmap;
                #ifdef _MONOSH
                float4 L1 = _UdonVRCTraceLightmapL1.SampleLevel(sampler_UdonVRCTraceLightmap, i.uv1, 0);
                float3 nL1 = L1.rgb * 2.0 - 1.0;
                float3 L1x = nL1.x * L0 * 2.0;
                float3 L1y = nL1.y * L0 * 2.0;
                float3 L1z = nL1.z * L0 * 2.0;

                lightmap = L0 + normalWS.x * L1x + normalWS.y * L1y + normalWS.z * L1z;
                lightmap = max(0, lightmap);
                #else
                lightmap = L0;
                #endif

                return float4(lightmap * _Color, 1);
            }
            ENDCG
        }
    }
}
