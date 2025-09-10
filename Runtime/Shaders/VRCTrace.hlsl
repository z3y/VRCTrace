#pragma once

Texture2D<float4> _UdonVRCTraceVertices;
Texture2D<float4> _UdonVRCTraceNormals;
Texture2D<float4> _UdonVRCTraceBounds;

uint _UdonVRCTraceBoundsWidth;
uint _UdonVRCTraceDataWidth;

struct Ray
{
    float3 P;
    float3 D;
    // float tmax;
    // float tmin;
};

struct Intersection
{
    float t, u, v;
    int prim;
    int depth;
    int shader;
    int object;
};

struct Bounds
{
    float3 Min;
    float3 Max;
};

int2 DataIndex(int index)
{
    uint width = _UdonVRCTraceDataWidth;
    uint h = (index / width) * 3;
    uint v = index % width;

    return int2(v, h);
}

int2 BoundsIndex(int index)
{
    uint width = _UdonVRCTraceBoundsWidth;
    uint h = (index / width) * 2;
    uint v = index % width;

    return int2(v, h);
}

// for some reason this is not precise
#if 0
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
#else
float3 RayOffset(float3 P, float3 Ng)
{
    return P + Ng * 0.001;
}
#endif

bool IntersectsTriangle(Ray ray, float3 v0, float3 v1, float3 v2, out float t, out float u, out float v)
{
    float3 e1 = v1 - v0;
    float3 e2 = v2 - v0;
    float3 p = cross(ray.D, e2);
    float det = dot(e1, p);

    if (abs(det) < 1e-8) return false; // parallel

    float invDet = 1.0 / det;
    float3 tvec = ray.P - v0;
    u = dot(tvec, p) * invDet;
    if (u < 0.0 || u > 1.0) return false;

    float3 q = cross(tvec, e1);
    v = dot(ray.D, q) * invDet;
    if (v < 0.0 || u + v > 1.0) return false;

    t = dot(e2, q) * invDet;
    if (t < 0.0) return false;

    return true;
}

float BoundsDistance(Ray ray, Bounds bounds)
{
    float3 invD = rcp(ray.D);

    float3 tMin = (bounds.Min - ray.P) * invD;
    float3 tMax = (bounds.Max - ray.P) * invD;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);

    bool hit = tFar >= tNear && tFar > 0;
    float dst = hit ? tNear > 0 ? tNear : 0 : 1.#INF;
    return dst;
}

void TrianglePointNormal(Intersection intersection, out float3 P, out float3 Ng)
{
    int tri_index = intersection.prim;
    int2 data_idx = DataIndex(tri_index);
    float3 v2 = _UdonVRCTraceVertices[data_idx].xyz;
    data_idx.y++;
    float3 v1 = _UdonVRCTraceVertices[data_idx].xyz;
    data_idx.y++;
    float3 v0 = _UdonVRCTraceVertices[data_idx].xyz;

    float u = intersection.u;
    float v = intersection.v;

    float w = 1.0 - u - v;
    P = (w * v0 + u * v1 + v * v2);
    Ng = normalize(cross(v2 - v0, v1 - v0));
}

inline float3 VRCTrace_SafeNormalize(float3 inVec)
{
    float dp3 = max(0.001f, dot(inVec, inVec));
    return inVec * rsqrt(dp3);
}

float3 TriangleSmoothNormal(Intersection intersection, float3 Ng)
{
    uint tri_index = intersection.prim;
    int2 data_idx = DataIndex(tri_index);
    float3 n0 = _UdonVRCTraceNormals[data_idx].xyz;
    data_idx.y++;
    float3 n1 = _UdonVRCTraceNormals[data_idx].xyz;
    data_idx.y++;
    float3 n2 = _UdonVRCTraceNormals[data_idx].xyz;

    float u = intersection.u;
    float v = intersection.v;

    float3 N = VRCTrace_SafeNormalize((1.0 - u - v) * n0 + u * n1 + v * n2);
    return all(N == 0) ? Ng : N;
}

bool SceneIntersects(Ray ray, out Intersection intersection)
{
    int stack[32];
    int stackIndex = 0;
    stack[stackIndex++] = 0;

    intersection.t = 1e30;
    intersection.u = 0;
    intersection.v = 0;
    intersection.prim = -1;
    intersection.depth = 0;
    intersection.shader = -1;
    intersection.object = -1;

    float t, u, v;
    bool hit = false;

    int safe = 0;
    bool globalsExist = _UdonVRCTraceBoundsWidth != 0;
    if (!globalsExist)
    {
        safe = 1024;
    }

    while (stackIndex > 0 && safe < 1024)
    {
        safe++;
        int boundsIndex = stack[--stackIndex];

        int2 boundsIndex0 = BoundsIndex(boundsIndex);
        float4 b0 = _UdonVRCTraceBounds[boundsIndex0];
        boundsIndex0.y++;
        float4 b1 = _UdonVRCTraceBounds[boundsIndex0];

        bool isLeaf = asint(b1.w) > 0;

        [branch]
        if (isLeaf)
        {
            int triangleStart = asint(b0.w);
            int triangleEnd = triangleStart + asint(b1.w);

            for (int triangleIndex = triangleStart; triangleIndex < triangleEnd; triangleIndex++)
            {
                int2 dataIndex = DataIndex(triangleIndex);
                float4 v0 = _UdonVRCTraceVertices[dataIndex];
                dataIndex.y++;
                float4 v1 = _UdonVRCTraceVertices[dataIndex];
                dataIndex.y++;
                float4 v2 = _UdonVRCTraceVertices[dataIndex];

                intersection.depth++;

                if (IntersectsTriangle(ray, v0.xyz, v1.xyz, v2.xyz, t, u, v))
                {
                    if (t < intersection.t)
                    {
                        intersection.t = t;
                        intersection.u = u;
                        intersection.v = v;
                        intersection.prim = triangleIndex;
                        intersection.shader = asint(v0.w);
                        intersection.object = asint(v1.w);
                        hit = true;
                    }
                }
            }
        }
        else {
            
            int childIndexA = asint(b0.w) + 0;
            int childIndexB = asint(b0.w) + 1;

            int2 bounds_idx = BoundsIndex(childIndexA);
            float4 l0 = _UdonVRCTraceBounds[bounds_idx];
            bounds_idx.y++;
            float4 l1 = _UdonVRCTraceBounds[bounds_idx];

            int2 bounds_id2 = BoundsIndex(childIndexB);
            float4 r0 = _UdonVRCTraceBounds[bounds_id2];
            bounds_id2.y++;
            float4 r1 = _UdonVRCTraceBounds[bounds_id2];

            Bounds boundsL;
            boundsL.Min = l0.xyz;
            boundsL.Max = l1.xyz;
            Bounds boundsR;
            boundsR.Min = r0.xyz;
            boundsR.Max = r1.xyz;

            intersection.depth++;
            float dstA = BoundsDistance(ray, boundsL);
            float dstB = BoundsDistance(ray, boundsR);
            bool isNearestA = dstA <= dstB;
            float dstNear = isNearestA ? dstA : dstB;
            float dstFar = isNearestA ? dstB : dstA;

            int childIndexNear = isNearestA ? childIndexA : childIndexB;
            int childIndexFar = isNearestA ? childIndexB : childIndexA;

            if (dstFar < intersection.t) stack[stackIndex++] = childIndexFar;
            if (dstNear < intersection.t) stack[stackIndex++] = childIndexNear;
        }
    }
    
    return hit;
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
    float phi = 2.0 * UNITY_PI * xi.y;

    float3 dir = float3(r * cos(phi), r * sin(phi), z);
    return center + dir * radius;
}

float3 RandomDirection(float2 xi)
{
    // xi ∈ [0,1]^2 (stratified random sample, e.g. Hammersley)
    float z = 1.0 - 2.0 * xi.x;
    float r = sqrt(max(0.0, 1.0 - z*z));
    float phi = 2.0 * UNITY_PI * xi.y;

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