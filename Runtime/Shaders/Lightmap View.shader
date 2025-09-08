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

namespace BicubicSampling
{
    // https://ndotl.wordpress.com/2018/08/29/baking-artifact-free-lightmaps
    // bicubicw0, bicubicw1, bicubicw2, and bicubicw3 are the four cubic B-spline basis functions
    float bicubicw0(float a)
    {
        return (1.0f/6.0f)*(a*(a*(-a + 3.0f) - 3.0f) + 1.0f);   // optimized
    }

    float bicubicw1(float a)
    {
        return (1.0f/6.0f)*(a*a*(3.0f*a - 6.0f) + 4.0f);
    }

    float bicubicw2(float a)
    {
        return (1.0f/6.0f)*(a*(a*(-3.0f*a + 3.0f) + 3.0f) + 1.0f);
    }

    float bicubicw3(float a)
    {
        return (1.0f/6.0f)*(a*a*a);
    }

    // bicubicg0 and bicubicg1 are the two amplitude functions
    float bicubicg0(float a)
    {
        return bicubicw0(a) + bicubicw1(a);
    }

    float bicubicg1(float a)
    {
        return bicubicw2(a) + bicubicw3(a);
    }

    // bicubich0 and bicubich1 are the two offset functions
    float bicubich0(float a)
    {
        // note +0.5 offset to compensate for CUDA linear filtering convention
        return -1.0f + bicubicw1(a) / (bicubicw0(a) + bicubicw1(a)) + 0.5f;
    }

    float bicubich1(float a)
    {
        return 1.0f + bicubicw3(a) / (bicubicw2(a) + bicubicw3(a)) + 0.5f;
    }

    float4 GetTexelSize(Texture2D t)
    {
        float4 texelSize;
        t.GetDimensions(texelSize.x, texelSize.y);
        texelSize.zw = 1.0 / texelSize.xy;
        return texelSize;
    }

    half4 SampleBicubic(Texture2D t, SamplerState s, float2 uv, float4 texelSize, float lod = 0)
    {
        float2 xy = uv * texelSize.xy - 0.5;
        float2 pxy = floor(xy);
        float2 fxy = xy - pxy;

        // note: we could store these functions in a lookup table texture, but maths is cheap
        float bicubicg0x = bicubicg0(fxy.x);
        float bicubicg1x = bicubicg1(fxy.x);
        float bicubich0x = bicubich0(fxy.x);
        float bicubich1x = bicubich1(fxy.x);
        float bicubich0y = bicubich0(fxy.y);
        float bicubich1y = bicubich1(fxy.y);

        //float lod = ComputeTextureLOD(uv);

        float4 t0 = bicubicg0x * t.SampleLevel(s, float2(pxy.x + bicubich0x, pxy.y + bicubich0y) * texelSize.zw, lod);
        float4 t1 = bicubicg1x * t.SampleLevel(s, float2(pxy.x + bicubich1x, pxy.y + bicubich0y) * texelSize.zw, lod);
        float4 t2 = bicubicg0x * t.SampleLevel(s, float2(pxy.x + bicubich0x, pxy.y + bicubich1y) * texelSize.zw, lod);
        float4 t3 = bicubicg1x * t.SampleLevel(s, float2(pxy.x + bicubich1x, pxy.y + bicubich1y) * texelSize.zw, lod);

        return bicubicg0(fxy.y) * (t0 + t1) + bicubicg1(fxy.y) * (t2 + t3);
    }
}

            float4 frag (v2f i) : SV_Target
            {
                float4 texelSize = BicubicSampling::GetTexelSize(_UdonVRCTraceLightmap);

                float4 L0 = BicubicSampling::SampleBicubic(_UdonVRCTraceLightmap, sampler_UdonVRCTraceLightmap, i.uv1, texelSize);

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
                float4 L1 = BicubicSampling::SampleBicubic(_UdonVRCTraceLightmapL1, sampler_UdonVRCTraceLightmap, i.uv1, texelSize);

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
