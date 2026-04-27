#pragma once

static const float VRCTRACE_PI = 3.14159265359;
static const float RAY_MAX = 10000.0;

Texture2D<float4> _UdonVRCTraceBVHNodes;
Texture2D<float4> _UdonVRCTraceBVHTriangles;
Texture2D<float4> _UdonVRCTraceNormals;
// Texture2D<float4> _UdonVRCTraceUVs;


Texture2D _UdonVRCTraceCombinedAtlas;
TextureCube _UdonVRCTraceSkybox;
SamplerState sampler_UdonVRCTraceSkybox;

struct Ray
{
    float3 P;
    float3 D;
    float tMax;
    float tMin;
};

struct Intersection
{
    float t, u, v;
    uint prim;
    uint depth;
    uint shader;
    uint object;

    float3 p0;
    float3 p1;
    float3 p2;
};

float4 IndexTexture(Texture2D tex, uint index)
{
    uint2 resolution;
    tex.GetDimensions(resolution.x, resolution.y);

    uint2 coords = uint2(index % resolution.x, index / resolution.x);
    return tex[coords];
}

// "A Fast and Robust Method for Avoiding Self-Intersection"
// Normal points outward for rays exiting the surface, else is flipped.
float3 RayOffset(float3 p, float3 n)
{
    const float origin = 1.0f / 32.0f;
    const float floatScale = 1.0f / 65536.0f;
    const float intScale = 256.0f;

    int3 of_i = int3(intScale * n.x, intScale * n.y, intScale * n.z);

    float3 p_i = float3(
    asfloat(asint(p.x)+((p.x < 0) ? -of_i.x : of_i.x)),
    asfloat(asint(p.y)+((p.y < 0) ? -of_i.y : of_i.y)),
    asfloat(asint(p.z)+((p.z < 0) ? -of_i.z : of_i.z)));

    return float3(abs(p.x) < origin ? p.x + floatScale * n.x : p_i.x,
                  abs(p.y) < origin ? p.y + floatScale * n.y : p_i.y,
                  abs(p.z) < origin ? p.z + floatScale * n.z : p_i.z);
}

void TrianglePointNormal(Intersection intersection, out float3 P, out float3 Ng)
{
    uint primitiveID = intersection.prim;

    float u = intersection.u;
    float v = intersection.v;

    float3 p0 = intersection.p0;
    float3 p1 = intersection.p1;
    float3 p2 = intersection.p2;

    float w = 1.0 - u - v;
    P = (w * p0 + u * p1 + v * p2);
    Ng = normalize(cross(p1 - p0, p2 - p0));
}

float3 VRCTrace_SafeNormalize(float3 inVec)
{
    float dp3 = max(0.001f, dot(inVec, inVec));
    return inVec * rsqrt(dp3);
}

float3 TriangleSmoothNormal(Intersection intersection, float3 Ng)
{
    uint primitiveID = intersection.prim;

    float3 n0 = IndexTexture(_UdonVRCTraceNormals, primitiveID * 3 + 0).xyz;
    float3 n1 = IndexTexture(_UdonVRCTraceNormals, primitiveID * 3 + 1).xyz;
    float3 n2 = IndexTexture(_UdonVRCTraceNormals, primitiveID * 3 + 2).xyz;

    float u = intersection.u;
    float v = intersection.v;

    float3 N = VRCTrace_SafeNormalize((1.0 - u - v) * n0 + u * n1 + v * n2);
    return all(N == 0) ? Ng : N;
}

// float2 TriangleUV(Intersection intersection)
// {
//     uint tri_index = intersection.prim;
//     int2 data_idx = DataIndex(tri_index);
//     float2 n0 = _UdonVRCTraceUVs[data_idx].xy;
//     data_idx.y++;
//     float2 n1 = _UdonVRCTraceUVs[data_idx].xy;
//     data_idx.y++;
//     float2 n2 = _UdonVRCTraceUVs[data_idx].xy;

//     float u = intersection.u;
//     float v = intersection.v;

//     float2 uv = float2((1.0 - u - v) * n0 + u * n1 + v * n2);
//     return uv;
// }

uint ExtractByte(uint value, uint byteIndex)
{
    return (value >> (byteIndex * 8)) & 0xFF;
}

// Extracts each byte from the float into the channel of a float4
float4 ExtractBytes(float value)
{
    uint packed = asuint(value);

    float4 channels = float4(
        ExtractByte(packed, 0),
        ExtractByte(packed, 1),
        ExtractByte(packed, 2),
        ExtractByte(packed, 3));

    return channels;
}

bool SceneIntersects(Ray ray, out Intersection hit, bool anyHit = false)
{
    float3 O = ray.P;
    float3 D = ray.D;
    float tmax = ray.tMax;

    float3 invDir = rcp(D);
    uint octinv4 = (7u - ((D.x < 0 ? 4u : 0u) | (D.y < 0 ? 2u : 0u) | (D.z < 0 ? 1u : 0u))) * 0x1010101u;

    uint2 stack[32];
    uint stackPtr = 0;
    uint2 nodeGroup = uint2(0, 0x80000000u);
    uint2 triGroup = uint2(0, 0u);

    float2 uv = float2(0, 0);
    uint hitTriIndex = 0;

    while (true)
    {
        if (nodeGroup.y > 0x00FFFFFFu)
        {
            uint mask = nodeGroup.y;
            uint childBitIndex = firstbithigh(mask);
            uint childNodeBaseIndex = nodeGroup.x;

            nodeGroup.y &= ~(1u << childBitIndex);
            if (nodeGroup.y > 0x00FFFFFFu)
                stack[stackPtr++] = nodeGroup;

            uint slotIndex = (childBitIndex - 24u) ^ (octinv4 & 255u);
            uint relativeIndex = countbits(mask & ~(0xFFFFFFFFu << slotIndex));
            uint childNodeIndex = childNodeBaseIndex + relativeIndex;

            float4 n0 = IndexTexture(_UdonVRCTraceBVHNodes, childNodeIndex * 5 + 0);
            float4 n1 = IndexTexture(_UdonVRCTraceBVHNodes, childNodeIndex * 5 + 1);
            float4 n2 = IndexTexture(_UdonVRCTraceBVHNodes, childNodeIndex * 5 + 2);
            float4 n3 = IndexTexture(_UdonVRCTraceBVHNodes, childNodeIndex * 5 + 3);
            float4 n4 = IndexTexture(_UdonVRCTraceBVHNodes, childNodeIndex * 5 + 4);

            uint packed = asuint(n0.w);
            float nodeInvX = asfloat(((ExtractByte(packed, 0) ^ 0x80u) - 0x80u + 127u) << 23) * invDir.x;
            float nodeInvY = asfloat(((ExtractByte(packed, 1) ^ 0x80u) - 0x80u + 127u) << 23) * invDir.y;
            float nodeInvZ = asfloat(((ExtractByte(packed, 2) ^ 0x80u) - 0x80u + 127u) << 23) * invDir.z;
            float3 nodeInvDir = float3(nodeInvX, nodeInvY, nodeInvZ);
            float3 nodePos = (n0.xyz - O) * invDir;

            uint hitmask = 0;

            [unroll]
            for (int i = 0; i < 2; ++i)
            {
                uint meta = asuint(i == 0 ? n1.z : n1.w);

                float4 lox = ExtractBytes(invDir.x < 0 ? (i == 0 ? n3.z : n3.w) : (i == 0 ? n2.x : n2.y));
                float4 loy = ExtractBytes(invDir.y < 0 ? (i == 0 ? n4.x : n4.y) : (i == 0 ? n2.z : n2.w));
                float4 loz = ExtractBytes(invDir.z < 0 ? (i == 0 ? n4.z : n4.w) : (i == 0 ? n3.x : n3.y));
                float4 hix = ExtractBytes(invDir.x < 0 ? (i == 0 ? n2.x : n2.y) : (i == 0 ? n3.z : n3.w));
                float4 hiy = ExtractBytes(invDir.y < 0 ? (i == 0 ? n2.z : n2.w) : (i == 0 ? n4.x : n4.y));
                float4 hiz = ExtractBytes(invDir.z < 0 ? (i == 0 ? n3.x : n3.y) : (i == 0 ? n4.z : n4.w));

                float4 tminx = lox * nodeInvDir.x + nodePos.x;
                float4 tmaxx = hix * nodeInvDir.x + nodePos.x;
                float4 tminy = loy * nodeInvDir.y + nodePos.y;
                float4 tmaxy = hiy * nodeInvDir.y + nodePos.y;
                float4 tminz = loz * nodeInvDir.z + nodePos.z;
                float4 tmaxz = hiz * nodeInvDir.z + nodePos.z;

                float4 cmin = max(max(max(tminx, tminy), tminz), 0.0f);
                float4 cmax = min(min(min(tmaxx, tmaxy), tmaxz), tmax);

                uint isInner = (meta & (meta << 1)) & 0x10101010u;
                uint innerMask = (isInner >> 4) * 0xFFu;
                uint bitIndex = (meta ^ (octinv4 & innerMask)) & 0x1F1F1F1Fu;
                uint childBits = (meta >> 5) & 0x07070707u;

                [unroll]
                for (int j = 0; j < 4; ++j)
                {
                    if (cmin[j] <= cmax[j])
                    {
                        uint shiftBits = (childBits >> (j * 8)) & 255u;
                        uint bitShift = (bitIndex >> (j * 8)) & 31u;
                        hitmask |= shiftBits << bitShift;
                    }
                }
            }

            nodeGroup.x = asuint(n1.x);
            nodeGroup.y = (hitmask & 0xFF000000u) | (asuint(n0.w) >> 24);
            triGroup.x = asuint(n1.y);
            triGroup.y = hitmask & 0x00FFFFFFu;
        }
        else
        {
            triGroup = nodeGroup;
            nodeGroup = uint2(0, 0u);
        }

        while (triGroup.y != 0u)
        {
            int triangleIndex = firstbithigh(triGroup.y);
            int triAddr = triGroup.x + triangleIndex * 3;
            triGroup.y -= 1u << triangleIndex;

            // CWBVHTriangles layout: [e1, e2, v0] each a float4
            float3 e1 = IndexTexture(_UdonVRCTraceBVHTriangles, triAddr + 0).xyz;
            float3 e2 = IndexTexture(_UdonVRCTraceBVHTriangles, triAddr + 1).xyz;
            float4 v0 = IndexTexture(_UdonVRCTraceBVHTriangles, triAddr + 2);

            float3 r = cross(D, e1);
            float a = dot(e2, r);
            if (abs(a) > 1e-7f)
            {
                float f = 1.0f / a;
                float3 s = O - v0.xyz;
                float u = f * dot(s, r);
                if (u >= 0.0f && u <= 1.0f)
                {
                    float3 q = cross(s, e2);
                    float v = f * dot(D, q);
                    if (v >= 0.0f && u + v <= 1.0f)
                    {
                        float d = f * dot(e1, q);
                        if (d > 0.0f && d < tmax)
                        {
                            if (anyHit)
                            {
                                return true;
                            }
                            tmax = d;
                            uv = float2(u, v);
                            hitTriIndex = triAddr;
                        }
                    }
                }
            }
        }

        if (nodeGroup.y <= 0x00FFFFFFu)
        {
            if (stackPtr > 0)
                nodeGroup = stack[--stackPtr];
            else
                break;
        }
    }

    if (tmax < ray.tMax)
    {
        hit.u = uv.x;
        hit.v = uv.y;

        float3 e1 = IndexTexture(_UdonVRCTraceBVHTriangles, hitTriIndex + 0).xyz;
        float3 e2 = IndexTexture(_UdonVRCTraceBVHTriangles, hitTriIndex + 1).xyz;
        float4 v0 = IndexTexture(_UdonVRCTraceBVHTriangles, hitTriIndex + 2);

        hit.prim = asuint(v0.w);
        // hit.object = asuint(v1.w);

        hit.t = tmax;
        hit.object = 0;
        hit.shader = 0;
        hit.depth = 0;

        hit.p0 = v0;
        hit.p1 = v0.xyz + e2;
        hit.p2 = v0.xyz + e1;
        return true;
    }
    return false;
}

bool SceneIntersectsShadow(Ray ray)
{
    Intersection hit;
    return SceneIntersects(ray, hit, true);
}

float3 RandomDirectionInHemisphere(float3 normal, float2 rand)
{
    // rand.x and rand.y are random numbers in [0,1)
    float phi = 2.0 * 3.14159265 * rand.x; // random azimuth
    float cosTheta = sqrt(1.0 - rand.y);   // bias toward normal (cosine-weighted)
    float sinTheta = sqrt(rand.y);

    // Local direction in tangent space
    float3 localDir = float3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);

    // Build tangent basis around the normal
    float3 up = abs(normal.z) < 0.999 ? float3(0,0,1) : float3(1,0,0);
    float3 tangent   = normalize(cross(up, normal));
    float3 bitangent = cross(normal, tangent);

    // Transform to world space
    return tangent * localDir.x + bitangent * localDir.y + normal * localDir.z;
}

float2 Hammersley(uint i, uint N)
{
    // radical inverse (Van der Corput) in base 2
    uint bits = i;
    bits = (bits << 16) | (bits >> 16);
    bits = ((bits & 0x55555555u) << 1) | ((bits & 0xAAAAAAAAu) >> 1);
    bits = ((bits & 0x33333333u) << 2) | ((bits & 0xCCCCCCCCu) >> 2);
    bits = ((bits & 0x0F0F0F0Fu) << 4) | ((bits & 0xF0F0F0F0u) >> 4);
    bits = ((bits & 0x00FF00FFu) << 8) | ((bits & 0xFF00FF00u) >> 8);
    float radicalInverse = float(bits) * 2.3283064365386963e-10; // / 2^32

    return float2(float(i) / float(N), radicalInverse);
}

float3 RandomPointOnSphere(float3 center, float radius, float2 xi)
{
    // xi ∈ [0,1]^2 (stratified random sample, e.g. Hammersley)
    float z = 1.0 - 2.0 * xi.x;
    float r = sqrt(max(0.0, 1.0 - z*z));
    float phi = 2.0 * VRCTRACE_PI * xi.y;

    float3 dir = float3(r * cos(phi), r * sin(phi), z);
    return center + dir * radius;
}

float3 RandomDirection(float2 xi)
{
    // xi ∈ [0,1]^2 (stratified random sample, e.g. Hammersley)
    float z = 1.0 - 2.0 * xi.x;
    float r = sqrt(max(0.0, 1.0 - z*z));
    float phi = 2.0 * VRCTRACE_PI * xi.y;

    float3 dir = float3(r * cos(phi), r * sin(phi), z);
    return dir;
}

uint3 HashPcg3d(uint3 v)
{
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v = v ^ (v >> 16);
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return v;
}

float2 GetRand(float2 k)
{
    float2 f = HashPcg3d(k.xyy).xy;
    return f * (1.0f / (float)0xFFFFFFFFu);
}