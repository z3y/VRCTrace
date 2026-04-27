using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

namespace TinyBVH
{
    /// <summary>
    /// Managed wrapper around a native BVH8_CWBVH built by tinybvh.
    /// Dispose() when done — this frees the native memory.
    /// </summary>
    public sealed class BVH : IDisposable
    {
        // -----------------------------------------------------------------
        // P/Invoke
        // -----------------------------------------------------------------
        const string DLL = "tinybvh_unity"; // place tinybvh_unity.dll next to the executable / in Plugins/

        [DllImport(DLL)] static extern IntPtr bvh_build(Vector4[] triangles, uint triCount);
        [DllImport(DLL)] static extern uint bvh_get_nodes_size(IntPtr handle);
        [DllImport(DLL)] static extern uint bvh_get_nodes_count(IntPtr handle);
        [DllImport(DLL)] static extern uint bvh_get_triangles_size(IntPtr handle);
        [DllImport(DLL)] static extern uint bvh_get_triangles_count(IntPtr handle);
        [DllImport(DLL)] static extern void bvh_copy_nodes(IntPtr handle, IntPtr dst);
        [DllImport(DLL)] static extern void bvh_copy_triangles(IntPtr handle, IntPtr dst);
        [DllImport(DLL)] static extern void bvh_free(IntPtr handle);

        // -----------------------------------------------------------------
        // State
        // -----------------------------------------------------------------
        IntPtr _handle;
        bool _disposed;

        public uint NodesCount { get; private set; }
        public uint TrianglesCount { get; private set; } // number of triangles (not verts)

        // -----------------------------------------------------------------
        // Construction
        // -----------------------------------------------------------------

        /// <summary>
        /// Build a BVH8_CWBVH from a flat triangle array.
        /// triangles must be laid out as: v0.xyzw, v1.xyzw, v2.xyzw per triangle
        /// (i.e. 12 floats per triangle).
        /// </summary>
        public static BVH Build(List<Vector4> triangles)
        {
            var arr = triangles.ToArray();
            if (triangles == null) throw new ArgumentNullException(nameof(triangles));

            uint triCount = (uint)(triangles.Count / 3);
            IntPtr handle = bvh_build(arr, triCount);
            if (handle == IntPtr.Zero)
                throw new InvalidOperationException("bvh_build returned null.");

            return new BVH(handle);
        }

        private BVH(IntPtr handle)
        {
            _handle = handle;
            NodesCount = bvh_get_nodes_count(handle);
            TrianglesCount = bvh_get_triangles_count(handle);
        }

        // -----------------------------------------------------------------
        // Data access — copy into managed arrays
        // -----------------------------------------------------------------

        /// <summary>
        /// Copy node data into a managed byte array.
        /// Each element is 16 bytes (bvhvec4). Upload as-is to a GPU buffer.
        /// </summary>
        public byte[] GetNodesRaw()
        {
            ThrowIfDisposed();
            uint size = bvh_get_nodes_size(_handle);
            byte[] buf = new byte[size];
            unsafe
            {
                fixed (byte* p = buf)
                    bvh_copy_nodes(_handle, (IntPtr)p);
            }
            return buf;
        }

        /// <summary>
        /// Copy node data into a typed BVHNode array.
        /// </summary>
        public Vector4[] GetNodes()
        {
            ThrowIfDisposed();
            uint count = bvh_get_nodes_count(_handle);
            var result = new Vector4[count];
            uint bytes = (uint)(count * Marshal.SizeOf<Vector4>());
            GCHandle pin = GCHandle.Alloc(result, GCHandleType.Pinned);
            try { bvh_copy_nodes(_handle, pin.AddrOfPinnedObject()); }
            finally { pin.Free(); }
            return result;
        }

        /// <summary>
        /// Copy triangle data into a managed byte array.
        /// Each triangle = 3 × bvhvec4 = 48 bytes. Upload as-is to a GPU buffer.
        /// </summary>
        public byte[] GetTrianglesRaw()
        {
            ThrowIfDisposed();
            uint size = bvh_get_triangles_size(_handle);
            byte[] buf = new byte[size];
            unsafe
            {
                fixed (byte* p = buf)
                    bvh_copy_triangles(_handle, (IntPtr)p);
            }
            return buf;
        }

        /// <summary>
        /// Copy triangle vert data into a typed BVHTriangleVert array.
        /// Array length = TrianglesCount * 3.
        /// </summary>
        public Vector4[] GetTriangleVerts()
        {
            ThrowIfDisposed();
            uint vertCount = TrianglesCount * 3;
            var result = new Vector4[vertCount];
            GCHandle pin = GCHandle.Alloc(result, GCHandleType.Pinned);
            try { bvh_copy_triangles(_handle, pin.AddrOfPinnedObject()); }
            finally { pin.Free(); }
            return result;
        }

        // -----------------------------------------------------------------
        // Disposal
        // -----------------------------------------------------------------
        public void Dispose()
        {
            if (_disposed) return;
            bvh_free(_handle);
            _handle = IntPtr.Zero;
            _disposed = true;
        }

        void ThrowIfDisposed()
        {
            if (_disposed) throw new ObjectDisposedException(nameof(BVH));
        }
    }

    // ---------------------------------------------------------------------
    // Example usage (not compiled in Unity — just for reference)
    // ---------------------------------------------------------------------
    /*
    // 1. Gather your mesh triangles as float[12*N] (v0.xyzw, v1.xyzw, v2.xyzw):
    float[] tris = BuildTriangleArray(mesh);

    // 2. Build the BVH:
    using var bvh = BVH.Build(tris);

    // 3. Upload to GPU:
    var nodesBuffer = new ComputeBuffer((int)bvh.NodesCount, 16);       // 16 = sizeof(bvhvec4)
    nodesBuffer.SetData(bvh.GetNodes());

    var triBuffer = new ComputeBuffer((int)(bvh.TrianglesCount * 3), 16);
    triBuffer.SetData(bvh.GetTriangleVerts());

    // 4. Pass to your shader:
    raytraceShader.SetBuffer(kernel, "_BVHNodes",     nodesBuffer);
    raytraceShader.SetBuffer(kernel, "_BVHTriangles", triBuffer);
    */
}
