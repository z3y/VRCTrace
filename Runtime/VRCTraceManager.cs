
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

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
        public Texture2D boundsBuffer;
        public Texture2D verticesBuffer;
        public Texture2D normalsBuffer;

        void Start()
        {
            SetGlobals();
        }

        public void SetGlobals()
        {
            if (!verticesBuffer)
            {
                return;
            }

            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceBounds"), boundsBuffer);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceVertices"), verticesBuffer);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceNormals"), normalsBuffer);

            VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceBoundsWidth"), boundsBuffer.width);
            VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceDataWidth"), verticesBuffer.width);
        }

        object _bvh = null;
#if UNITY_EDITOR && !COMPILER_UDONSHARP
        private void OnDrawGizmosSelected()
        {
            if (_bvh == null)
            {
                return;
            }

            var nodes = (_bvh as BVH).GetNodes();

            foreach (var node in nodes)
            {
                var center = node.CalculateBoundsCentre();
                var size = node.CalculateBoundsSize();


                Gizmos.DrawWireCube(center, size);
            }
        }

        public void GenerateBuffers()
        {

            var renderer = GetStaticRenderers();


            //List<Vector3Int> triangles = new List<Vector3Int>();
            List<Vector3> vertices = new List<Vector3>();
            List<int> indices = new List<int>();
            List<Vector3> normals = new List<Vector3>();
            List<int> objectIds = new List<int>();


            List<Bounds> allBounds = new List<Bounds>();

            int vert_offset = 0;
            //int tri_offset = 0;
            int objectId = 0;
            foreach (var r in renderer)
            {
                var f = r.GetComponent<MeshFilter>();
                var m = f.sharedMesh;

                var tris = m.triangles;
                var verts = m.vertices;
                var norm = m.normals;

                for (int i = 0; i < tris.Length;)
                {
                    //var a = new Vector3Int(tris[i] + vert_offset, tris[i+1] + vert_offset, tris[i+2] + vert_offset);

                    //triangles.Add(a);
                    indices.Add(tris[i++] + vert_offset);
                    indices.Add(tris[i++] + vert_offset);
                    indices.Add(tris[i++] + vert_offset);
                }

                var bounds = r.bounds;
                var c = bounds.min;
                var e = bounds.max;

                //var b0 = new Color(c.x, c.y, c.z, tri_offset);

                for (int i = 0; i < verts.Length; i++)
                {
                    var p = f.transform.TransformPoint(verts[i]);
                    vertices.Add(p);
                    objectIds.Add(objectId);

                    var n = f.transform.TransformVector(norm[i]);
                    normals.Add(n);
                }

                vert_offset += verts.Length;

                //tri_offset += tris.Length / 3;
                //var b1 = new Color(e.x, e.y, e.z, tri_offset);

                //bounds_all.Add(b0);
                //bounds_all.Add(b1);

                allBounds.Add(bounds);
                objectId++;
            }

            _bvh = new BVH(vertices.ToArray(), indices.ToArray(), normals.ToArray(), objectIds.ToArray());

            var bvh_tris = (_bvh as BVH).GetTriangles();
            var nodes = (_bvh as BVH).GetNodes();


            int tri_verts_buffer_x = Mathf.NextPowerOfTwo((int)math.ceil(math.sqrt(bvh_tris.Length)));

            var tri_verts_buffer = new Texture2D(tri_verts_buffer_x, tri_verts_buffer_x * 3, TextureFormat.RGBAFloat, false);
            var tri_normals_buffer = new Texture2D(tri_verts_buffer_x, tri_verts_buffer_x * 3, TextureFormat.RGBAFloat, false);


            int bounds_buffer_x = Mathf.NextPowerOfTwo((int)math.ceil(math.sqrt(nodes.Length)));
            var bounds_buffer = new Texture2D(bounds_buffer_x, bounds_buffer_x * 2, TextureFormat.RGBAFloat, false);


            tri_verts_buffer.wrapMode = TextureWrapMode.Clamp;
            tri_normals_buffer.wrapMode = TextureWrapMode.Clamp;
            bounds_buffer.wrapMode = TextureWrapMode.Clamp;

            tri_verts_buffer.filterMode = FilterMode.Point;
            tri_normals_buffer.filterMode = FilterMode.Point;
            bounds_buffer.filterMode = FilterMode.Point;

            for (int i = 0; i < bvh_tris.Length; i++)
            {
                var tri = bvh_tris[i];

                int y = (i / tri_verts_buffer_x) * 3;
                int x = i % tri_verts_buffer_x;
                tri_verts_buffer.SetPixel(x, y + 0, new Color(tri.PosA.x, tri.PosA.y, tri.PosA.z, math.asfloat(tri.ObjectId)));
                tri_verts_buffer.SetPixel(x, y + 1, new Color(tri.PosB.x, tri.PosB.y, tri.PosB.z, math.asfloat(tri.ObjectId)));
                tri_verts_buffer.SetPixel(x, y + 2, new Color(tri.PosC.x, tri.PosC.y, tri.PosC.z, math.asfloat(tri.ObjectId)));

                tri_normals_buffer.SetPixel(x, y + 0, new Color(tri.NormalA.x, tri.NormalA.y, tri.NormalA.z, math.asfloat(tri.ObjectId)));
                tri_normals_buffer.SetPixel(x, y + 1, new Color(tri.NormalB.x, tri.NormalB.y, tri.NormalB.z, math.asfloat(tri.ObjectId)));
                tri_normals_buffer.SetPixel(x, y + 2, new Color(tri.NormalC.x, tri.NormalC.y, tri.NormalC.z, math.asfloat(tri.ObjectId)));
            }


            for (int i = 0; i < nodes.Length; i++)
            {
                var n = nodes[i];

                var c = n.BoundsMin;
                var b0 = new Color(c.x, c.y, c.z, math.asfloat(n.StartIndex));
                c = n.BoundsMax;
                var b1 = new Color(c.x, c.y, c.z, math.asfloat(n.TriangleCount));

                int y = (i / bounds_buffer_x) * 2;
                int x = i % bounds_buffer_x;

                bounds_buffer.SetPixel(x, y + 0, b0);
                bounds_buffer.SetPixel(x, y + 1, b1);
            }

            string sceneFolder = Path.GetDirectoryName(SceneManager.GetActiveScene().path);

            string vertPath = Path.Combine(sceneFolder, "VRCTraceVertices.asset");
            string normPath = Path.Combine(sceneFolder, "VRCTraceNormals.asset");
            string boundPath = Path.Combine(sceneFolder, "VRCTraceBounds.asset");

            AssetDatabase.CreateAsset(tri_verts_buffer, vertPath);
            AssetDatabase.CreateAsset(tri_normals_buffer, normPath);
            AssetDatabase.CreateAsset(bounds_buffer, boundPath);

            AssetDatabase.ImportAsset(vertPath);
            AssetDatabase.ImportAsset(normPath);
            AssetDatabase.ImportAsset(boundPath);

            boundsBuffer = AssetDatabase.LoadAssetAtPath<Texture2D>(boundPath);
            verticesBuffer = AssetDatabase.LoadAssetAtPath<Texture2D>(vertPath);
            normalsBuffer = AssetDatabase.LoadAssetAtPath<Texture2D>(normPath);

            EditorUtility.SetDirty(this);
            SetGlobals();
        }

        public static List<MeshRenderer> GetStaticRenderers()
        {
            Scene scene = SceneManager.GetActiveScene();
            var rootGameObjects = scene.GetRootGameObjects();
            return GetStaticRenderers(rootGameObjects);
        }
        public static List<MeshRenderer> GetStaticRenderers(GameObject[] rootObjs)
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

            base.OnInspectorGUI();
        }

    }
#endif
}
