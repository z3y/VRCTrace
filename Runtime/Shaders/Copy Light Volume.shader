Shader "Unlit/VRCTrace Copy Light Volume"
{
    Properties
    {
        _BufferTex0 ("Tex0", 2D) = "black" {}
        _BufferTex1 ("Tex1", 2D) = "black" {}
        _BufferTex2 ("Tex2", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"
            #include "UnityCustomRenderTexture.cginc"
            #include "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc"

            Texture2D _BufferTex0;
            Texture2D _BufferTex1;
            Texture2D _BufferTex2;

            uint2 Get2DCoord(int probeIndex)
            {
                uint2 wh;
                _BufferTex0.GetDimensions(wh.x, wh.y);

                uint h = probeIndex / wh.x;
                uint v = probeIndex % wh.x;

                return uint2(v, h);
            }

            float4 frag(v2f_customrendertexture i) : COLOR
            {
                float3 localUVW = i.localTexcoord.xyz;
                localUVW.z = frac(localUVW.z * 3);

                int3 resolution = _CustomRenderTextureInfo.xyz;
                resolution.z /= 3;

                int3 pixelCoord = localUVW * resolution;
                int slice = _CustomRenderTexture3DSlice;

                resolution -= 2; // padding
                pixelCoord = clamp(pixelCoord, 1, resolution-1);

                uint width = resolution.x;
                uint height = resolution.y;
                uint probeIndex = pixelCoord.x + pixelCoord.y * width + pixelCoord.z * (width * height);

                // return float4(probeIndex == 2, 0, 0, 1);

                uint2 coord = Get2DCoord(probeIndex);

                float4 tex0 = _BufferTex0[coord];
                float4 tex1 = _BufferTex1[coord];
                float4 tex2 = _BufferTex2[coord];

                float3 L0 = float3(tex0.a, tex1.a, tex2.a);
                float3 L1x = tex0.xyz;
                float3 L1y = tex1.xyz;
                float3 L1z = tex2.xyz;

                L0 *= UNITY_PI;
                L1x *= 2.0 * UNITY_PI / 3.0;
                L1y *= 2.0 * UNITY_PI / 3.0;
                L1z *= 2.0 * UNITY_PI / 3.0;

                float3 L1r = float3(L1x.x, L1y.x, L1z.x) * 0.565;
                float3 L1g = float3(L1x.y, L1y.y, L1z.y) * 0.565;
                float3 L1b = float3(L1x.z, L1y.z, L1z.z) * 0.565;


                if (slice >= resolution.z * 2) // texture 2
                {
                    return float4(L1r.y, L1g.y, L1b.y, L1b.z);
                }
                else if (slice <= resolution.z) // texture 0
                {
                    return float4(L0, L1r.z);
                }
                else  // texture 1
                {
                    return float4(L1r.x, L1g.x, L1b.x, L1g.z);
                }

                return 0;
            }
            ENDCG
        }
    }
}
