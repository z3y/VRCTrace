#define TINYBVH_IMPLEMENTATION
#include "tiny_bvh.h"

#include <cstdlib>
#include <cstring>
#include <cstdint>

using namespace tinybvh;

#if defined(_WIN32) || defined(_WIN64)
    #define EXPORT extern "C" __declspec(dllexport)
#else
    #define EXPORT extern "C" __attribute__((visibility("default")))
#endif

// Opaque handle — caller never touches internals
struct BVHHandle
{
    void  *nodesData;
    size_t nodesSizeBytes;
    uint32_t nodesCount;      // usedBlocks

    void  *trianglesData;
    size_t trianglesSizeBytes;
    uint32_t trianglesCount;  // idxCount * 3 verts, each bvhvec4
};

// -----------------------------------------------------------------------
// bvh_build
//   triangles  : flat array of { float[4] v0, float[4] v1, float[4] v2 }
//   triCount   : number of triangles
//   Returns    : opaque BVHHandle* (free with bvh_free)
// -----------------------------------------------------------------------
EXPORT BVHHandle* bvh_build(float *triangles, uint32_t triCount)
{
    BVH8_CWBVH gpu_bvh;

    bvhvec4 *verts = reinterpret_cast<bvhvec4*>(triangles);
    gpu_bvh.BuildHQ(verts, triCount);

    BVHHandle *h = new BVHHandle();

    // --- nodes ---
    h->nodesCount      = gpu_bvh.usedBlocks;
    h->nodesSizeBytes  = (size_t)gpu_bvh.usedBlocks * sizeof(bvhvec4);
    h->nodesData       = malloc(h->nodesSizeBytes);
    memcpy(h->nodesData, gpu_bvh.bvh8Data, h->nodesSizeBytes);

    // --- triangles (reindexed, packed as bvhvec4 triples) ---
    h->trianglesCount      = gpu_bvh.idxCount;
    h->trianglesSizeBytes  = (size_t)gpu_bvh.idxCount * 3 * sizeof(bvhvec4);
    h->trianglesData       = malloc(h->trianglesSizeBytes);
    memcpy(h->trianglesData, gpu_bvh.bvh8Tris, h->trianglesSizeBytes);

    return h;
}

// -----------------------------------------------------------------------
// Accessors — Unity reads raw byte counts then calls bvh_copy_*
// to fill caller-allocated buffers (avoids unsafe pointer arithmetic in C#)
// -----------------------------------------------------------------------
EXPORT uint32_t bvh_get_nodes_size(BVHHandle *h)
{
    return h ? (uint32_t)h->nodesSizeBytes : 0;
}

EXPORT uint32_t bvh_get_nodes_count(BVHHandle *h)
{
    return h ? h->nodesCount : 0;
}

EXPORT uint32_t bvh_get_triangles_size(BVHHandle *h)
{
    return h ? (uint32_t)h->trianglesSizeBytes : 0;
}

EXPORT uint32_t bvh_get_triangles_count(BVHHandle *h)
{
    return h ? h->trianglesCount : 0;
}

// Copy node data into a caller-allocated buffer.
// dst must be at least bvh_get_nodes_size() bytes.
EXPORT void bvh_copy_nodes(BVHHandle *h, void *dst)
{
    if (h && dst)
        memcpy(dst, h->nodesData, h->nodesSizeBytes);
}

// Copy triangle data into a caller-allocated buffer.
// dst must be at least bvh_get_triangles_size() bytes.
EXPORT void bvh_copy_triangles(BVHHandle *h, void *dst)
{
    if (h && dst)
        memcpy(dst, h->trianglesData, h->trianglesSizeBytes);
}

// -----------------------------------------------------------------------
// bvh_free  — release the handle and all owned memory
// -----------------------------------------------------------------------
EXPORT void bvh_free(BVHHandle *h)
{
    if (!h) return;
    free(h->nodesData);
    free(h->trianglesData);
    delete h;
}
