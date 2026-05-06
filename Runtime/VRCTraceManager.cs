#if UDONSHARP
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using Org.BouncyCastle.Crypto.Tls;




#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEngine.Rendering;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEngine.SceneManagement;
using System.IO;
using Unity.Mathematics;
using UnityEditor;
#endif

namespace VRCTrace
{
    [ExecuteInEditMode]
    public class VRCTraceManager : UdonSharpBehaviour
    {
        public Texture2D cwbvhNodesBuffer;
        public Texture2D cwbvhTrianglesBuffer;
        public Texture2D normalsBuffer;
        public Texture2D uvsBuffer;

        public Texture2D combinedAtlas;
        public Texture2D lightmap;
        public Texture2D lightmapL1;

        public Cubemap skybox;

        void Start()
        {
            SetGlobals();
        }

        void OnValidate()
        {
            SetGlobals();
        }

        public void SetGlobals()
        {
            if (!cwbvhTrianglesBuffer)
            {
                return;
            }

            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceBVHNodes"), cwbvhNodesBuffer);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceBVHTriangles"), cwbvhTrianglesBuffer);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceNormals"), normalsBuffer);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceUVs"), uvsBuffer);

            VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceBoundsWidth"), cwbvhNodesBuffer.width);
            VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceDataWidth"), cwbvhTrianglesBuffer.width);

            if (combinedAtlas)
            {
                VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceCombinedAtlas"), combinedAtlas);
            }

            if (skybox)
            {
                VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceSkybox"), skybox);
            }
        }

#if UNITY_EDITOR && !COMPILER_UDONSHARP
        // Texture2D BufferToTexture(IList<Vector4> buffer)
        // {
        //     int count = buffer.Count;
        //     int size = Mathf.NextPowerOfTwo(Mathf.CeilToInt(Mathf.Sqrt(count)));

        //     var texture = new Texture2D(size, size, TextureFormat.RGBAFloat, false)
        //     {
        //         wrapMode = TextureWrapMode.Clamp,
        //         filterMode = FilterMode.Point
        //     };

        //     var pixels = new Color[size * size];

        //     for (int i = 0; i < count; i++)
        //     {
        //         int x = i % size;
        //         int y = i / size;

        //         var b = buffer[i];
        //         pixels[y * size + x] = new Color(b.x, b.y, b.z, b.w);
        //     }

        //     texture.SetPixels(pixels);
        //     return texture;
        // }
        // Texture2D BufferToTexture(IList<Vector2> buffer)
        // {
        //     int count = buffer.Count;
        //     int size = Mathf.NextPowerOfTwo(Mathf.CeilToInt(Mathf.Sqrt(count)));

        //     var texture = new Texture2D(size, size, TextureFormat.RGFloat, false)
        //     {
        //         wrapMode = TextureWrapMode.Clamp,
        //         filterMode = FilterMode.Point
        //     };

        //     var pixels = new Color[size * size];

        //     for (int i = 0; i < count; i++)
        //     {
        //         int x = i % size;
        //         int y = i / size;

        //         var b = buffer[i];
        //         pixels[y * size + x] = new Color(b.x, b.y, 0, 0);
        //     }

        //     texture.SetPixels(pixels);
        //     return texture;
        // }

        Texture2D BufferToTexture(IList<Vector4> buffer)
        {
            int count = buffer.Count;

            int width = Mathf.NextPowerOfTwo(Mathf.CeilToInt(count / 16384.0f));
            width = Mathf.Max(width, 1);
            int height = Mathf.CeilToInt((float)count / width);

            var texture = new Texture2D(width, height, TextureFormat.RGBAFloat, false)
            {
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Point
            };

            var pixels = new Color[width * height];

            for (int i = 0; i < count; i++)
            {
                int x = i % width;
                int y = i / width;
                var b = buffer[i];
                pixels[y * width + x] = new Color(b.x, b.y, b.z, b.w);
            }

            texture.SetPixels(pixels);
            return texture;
        }

        Texture2D BufferToTexture(IList<Vector2> buffer)
        {
            int count = buffer.Count;

            int width = Mathf.NextPowerOfTwo(Mathf.CeilToInt(count / 16384.0f));
            width = Mathf.Max(width, 1);
            int height = Mathf.CeilToInt((float)count / width);

            var texture = new Texture2D(width, height, TextureFormat.RGFloat, false)
            {
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Point
            };

            var pixels = new Color[width * height];

            for (int i = 0; i < count; i++)
            {
                int x = i % width;
                int y = i / width;
                var b = buffer[i];
                pixels[y * width + x] = new Color(b.x, b.y, 0, 0);
            }

            texture.SetPixels(pixels);
            return texture;
        }

        public void GenerateBuffers()
        {
            var renderer = GetStaticRenderers();

            List<Vector4> bvhVertices = new();
            List<Vector4> allUVs = new();
            List<Vector4> allNormals = new();

            uint objectId = 0;
            foreach (var r in renderer)
            {
                var f = r.GetComponent<MeshFilter>();
                var m = f.sharedMesh;

                Vector3[] verts = m.vertices;
                Vector3[] norm = m.normals;
                Vector2[] uv;
                if (r.enlightenVertexStream)
                {
                    uv = r.enlightenVertexStream.uv2;
                }
                else
                {
                    uv = m.HasVertexAttribute(VertexAttribute.TexCoord1) ? m.uv2 : m.uv;
                }

                // uvs need to be transformed here when using lightmap scale and offset

                uint primitiveIDOffset = (uint)(bvhVertices.Count / 3);

                var triangles = m.triangles;

                for (int primitiveID = 0; primitiveID < (triangles.Length / 3); primitiveID++)
                {
                    int i0 = triangles[primitiveID * 3 + 0];
                    int i1 = triangles[primitiveID * 3 + 1];
                    int i2 = triangles[primitiveID * 3 + 2];

                    var p0 = verts[i0];
                    var p1 = verts[i1];
                    var p2 = verts[i2];
                    p0 = f.transform.TransformPoint(p0);
                    p1 = f.transform.TransformPoint(p1);
                    p2 = f.transform.TransformPoint(p2);


                    var n0 = norm[i0];
                    var n1 = norm[i1];
                    var n2 = norm[i2];
                    n0 = f.transform.TransformDirection(n0);
                    n1 = f.transform.TransformDirection(n1);
                    n2 = f.transform.TransformDirection(n2);
                    // allNormals.Add(n0);
                    // allNormals.Add(n1);
                    // allNormals.Add(n2);

                    uint n0e = EncodeNormalOctahedral(n0);
                    uint n1e = EncodeNormalOctahedral(n1);
                    uint n2e = EncodeNormalOctahedral(n2);
                    Vector4 packedNormals = new(math.asfloat(n0e), math.asfloat(n1e), math.asfloat(n2e), math.asfloat(0)); // .w unused
                    allNormals.Add(packedNormals);

                    var uv0 = uv[i0];
                    var uv1 = uv[i1];
                    var uv2 = uv[i2];
                    // allUVs.Add(uv0);
                    // allUVs.Add(uv1);
                    // allUVs.Add(uv2);

                    uint uv0c = CompressUV(uv0);
                    uint uv1c = CompressUV(uv1);
                    uint uv2c = CompressUV(uv2);
                    Vector4 packedUvs = new(math.asfloat(uv0c), math.asfloat(uv1c), math.asfloat(uv2c), math.asfloat(0)); // .w unused
                    allUVs.Add(packedUvs);

                    var v0 = new Vector4(p0.x, p0.y, p0.z, math.asfloat((uint)primitiveID + primitiveIDOffset));
                    var v1 = new Vector4(p1.x, p1.y, p1.z, math.asfloat(objectId));
                    var v2 = new Vector4(p2.x, p2.y, p2.z, math.asfloat(0)); // unused
                    bvhVertices.Add(v0);
                    bvhVertices.Add(v1);
                    bvhVertices.Add(v2);
                }

                objectId++;
            }

            var bvh = TinyBVH.BVH.Build(bvhVertices);
            var nodes = bvh.GetNodes();
            var bvhTris = bvh.GetTriangleVerts();

            string sceneFolder = Path.GetDirectoryName(SceneManager.GetActiveScene().path);

            var bvhNodesBuffer = BufferToTexture(nodes);
            var bvhTrianglesBuffer = BufferToTexture(bvhTris);
            var normalsBuffer = BufferToTexture(allNormals);
            var uvsBuffer = BufferToTexture(allUVs);

            string nodesPath = Path.Combine(sceneFolder, "VRCTraceBVHNodes.asset");
            string trianglesPath = Path.Combine(sceneFolder, "VRCTraceBVHTriangles.asset");
            string normalsPath = Path.Combine(sceneFolder, "VRCTraceNormals.asset");
            string uvsPath = Path.Combine(sceneFolder, "VRCTraceUVs.asset");

            AssetDatabase.CreateAsset(bvhNodesBuffer, nodesPath);
            AssetDatabase.CreateAsset(bvhTrianglesBuffer, trianglesPath);
            AssetDatabase.CreateAsset(normalsBuffer, normalsPath);
            AssetDatabase.CreateAsset(uvsBuffer, uvsPath);

            AssetDatabase.ImportAsset(nodesPath);
            AssetDatabase.ImportAsset(trianglesPath);
            AssetDatabase.ImportAsset(normalsPath);
            AssetDatabase.ImportAsset(uvsPath);

            this.cwbvhNodesBuffer = AssetDatabase.LoadAssetAtPath<Texture2D>(nodesPath);
            this.cwbvhTrianglesBuffer = AssetDatabase.LoadAssetAtPath<Texture2D>(trianglesPath);
            this.normalsBuffer = AssetDatabase.LoadAssetAtPath<Texture2D>(normalsPath);
            this.uvsBuffer = AssetDatabase.LoadAssetAtPath<Texture2D>(uvsPath);

            EditorUtility.SetDirty(this);
            SetGlobals();
        }

        public List<MeshRenderer> GetStaticRenderers()
        {
            Scene scene = SceneManager.GetActiveScene();
            var rootGameObjects = scene.GetRootGameObjects();
            return GetStaticRenderers(rootGameObjects);
        }
        public List<MeshRenderer> GetStaticRenderers(GameObject[] rootObjs)
        {
            var infoMsg = new StringBuilder();

            var roots = new List<Transform>();

            for (int i = 0; i < rootObjs.Length; i++)
            {
                var o = rootObjs[i];
                roots.AddRange(o.GetComponentsInChildren<Transform>(false));
            }

            roots.Distinct();

            var renderers = new List<MeshRenderer>();

            foreach (var root in roots)
            {
                var o = root.gameObject;
                if (!o.activeInHierarchy)
                {
                    continue;
                }

                if (!GameObjectUtility.GetStaticEditorFlags(o).HasFlag(StaticEditorFlags.ContributeGI))
                {
                    continue;
                }

                var objName = o.name;

                var r = root.GetComponent<MeshRenderer>();
                var f = root.GetComponent<MeshFilter>();

                if (!f || !r)
                {
                    continue;
                }

                if (r.receiveGI != ReceiveGI.Lightmaps)
                {
                    continue;
                }

                if (r.scaleInLightmap == 0)
                {
                    continue;
                }

                if (f.sharedMesh == null)
                {
                    //infoMsg.AppendLine($"{objName}: has no shared mesh");
                    continue;
                }


                var sm = f.sharedMesh;

                if (sm.vertices == null)
                {
                    infoMsg.AppendLine($"{objName}: mesh has no vertices");
                    continue;
                }

                if (sm.uv2 == null && sm.uv == null)
                {
                    infoMsg.AppendLine($"{objName}: mesh has no uvs");
                    continue;
                }

                var uv = sm.HasVertexAttribute(VertexAttribute.TexCoord1) ? sm.uv2 : sm.uv;

                if (uv.Length != sm.vertices.Length)
                {
                    infoMsg.AppendLine($"{objName}: uv length does not equal vertices length");
                    continue;
                }

                renderers.Add(r);
            }

            var msg = infoMsg.ToString();
            if (!string.IsNullOrEmpty(msg))
            {
                Debug.LogWarning(msg);
            }

            return renderers;
        }

        public static uint CompressUV(Vector2 uv)
        {
            ushort x = (ushort)Mathf.RoundToInt(Mathf.Clamp01(uv.x) * 65535f);
            ushort y = (ushort)Mathf.RoundToInt(Mathf.Clamp01(uv.y) * 65535f);

            return (uint)x | ((uint)y << 16);
        }

        public static uint EncodeNormalOctahedral(Vector3 n)
        {
            float invL1 = 1f / (Mathf.Abs(n.x) + Mathf.Abs(n.y) + Mathf.Abs(n.z));
            float ox = n.x * invL1;
            float oy = n.y * invL1;

            if (n.z < 0f)
            {
                float newX = (1f - Mathf.Abs(oy)) * Sign(ox);
                float newY = (1f - Mathf.Abs(ox)) * Sign(oy);
                ox = newX;
                oy = newY;
            }

            ushort ex = EncodeChannel(ox);
            ushort ey = EncodeChannel(oy);

            return (uint)ex | ((uint)ey << 16);
        }

        static ushort EncodeChannel(float f)
        {
            return (ushort)Mathf.RoundToInt(Mathf.Clamp01((f + 1f) * 0.5f) * 65535f);
        }

        // copysign(1, v) — returns +1 or -1 matching the sign of v
        static float Sign(float v) => v < 0f ? -1f : 1f;
#endif

    }

#if UNITY_EDITOR && !COMPILER_UDONSHARP
    [CustomEditor(typeof(VRCTraceManager))]
    public class VRCTraceManagerEditor : Editor
    {

        public override void OnInspectorGUI()
        {
            if (GUILayout.Button("Generate Buffers"))
            {
                var manager = target as VRCTraceManager;
                manager.GenerateBuffers();
            }

            if (GUILayout.Button("Generate Combined Atlas")) // only albedo for now
            {
                var manager = target as VRCTraceManager;
                using var meta = new MetaTexture(manager.lightmap.width);
                var atlas = meta.CreateCombinedAtlas(manager.GetStaticRenderers().ToArray(), manager.lightmap, manager.lightmapL1);
                manager.combinedAtlas = atlas;
                manager.SetGlobals();

            }

            base.OnInspectorGUI();
        }

    }

#endif
}
#endif
