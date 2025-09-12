#if UNITY_EDITOR && !COMPILER_UDONSHARP
using System;
using System.IO;
using UnityEditor;
using UnityEditor.Graphs;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace VRCTrace
{
    public class MetaTexture : IDisposable
    {
        RenderTexture _rt;
        RenderTexture _rtCopy;
        RenderTexture _rtFinal;

        // Material _dilationMat;
        int _resolution;
        public MetaTexture(int resolution)
        {
            _resolution = resolution;
            var desc = new RenderTextureDescriptor
            {
                autoGenerateMips = false,
                width = resolution,
                height = resolution,
                useMipMap = false,
                colorFormat = RenderTextureFormat.ARGBFloat,
                sRGB = false,
                volumeDepth = 1,
                msaaSamples = 1,
                dimension = TextureDimension.Tex2D
            };

            _rt = new RenderTexture(desc);
            _rtCopy = new RenderTexture(desc);
            _rtFinal = new RenderTexture(desc);

            _combineMat = new Material(Shader.Find("Hidden/VRCTrace/Combine"));
        }

        Material _combineMat;

        public enum AtlasType
        {
            Albedo = 0,
            Emission = 1,
        }
        public Texture2D CreateCombinedAtlas(MeshRenderer[] renderers, Texture2D lightmap)
        {
            string sceneFolder = Path.GetDirectoryName(SceneManager.GetActiveScene().path);

            CreateAtlas(renderers, AtlasType.Albedo);
            Graphics.Blit(_rt, _rtCopy);
            CreateAtlas(renderers, AtlasType.Emission);

            _combineMat.SetTexture("_Albedo", _rtCopy);
            _combineMat.SetTexture("_Emission", _rt);
            _combineMat.SetTexture("_Lightmap", lightmap);

            Graphics.Blit(Texture2D.blackTexture, _rtFinal, _combineMat, 0);

            var format = TextureFormat.ARGB32;
            var tex = new Texture2D(_rtFinal.width, _rtFinal.height, format, false, true);

            RenderTexture.active = _rtFinal;
            tex.ReadPixels(new Rect(0, 0, _rtFinal.width, _rtFinal.height), 0, 0);
            tex.Apply(false);
            RenderTexture.active = null;


            var bytes = tex.EncodeToTGA();
            string path = Path.Combine(sceneFolder, "VRCTraceCombinedAtlas.tga");
            File.WriteAllBytes(path, bytes);
            AssetDatabase.ImportAsset(path);

            Editor.DestroyImmediate(tex);


            return AssetDatabase.LoadAssetAtPath<Texture2D>(path);

        }
        public void CreateAtlas(MeshRenderer[] renderers, AtlasType type)
        {
            using var cmd = new CommandBuffer();
            cmd.SetRenderTarget(_rt);

            cmd.ClearRenderTarget(true, true, Color.clear);

            var transform = Matrix4x4.identity;

            float near = 0.01f;
            float far = 100f;

            // Ortho projection matrix
            Matrix4x4 proj = Matrix4x4.Ortho(0, 1, 0, 1, near, far);
            // View matrix (like a top-down or front view)
            Vector3 camPos = new Vector3(0, 0, -10);
            Vector3 target = Vector3.zero;
            Vector3 up = Vector3.up;
            Matrix4x4 view = Matrix4x4.LookAt(camPos, target, up);
            cmd.SetViewProjectionMatrices(view, proj);

            cmd.SetGlobalVector("unity_MetaVertexControl", new Vector4(1, 0, 0, 0));

            if (type == AtlasType.Albedo)
            {
                cmd.SetGlobalVector("unity_MetaFragmentControl", new Vector4(1, 0, 0, 0));
                cmd.SetGlobalFloat("unity_OneOverOutputBoost", 1.0f);
                cmd.SetGlobalFloat("unity_MaxOutputValue", 1.0f);
            }
            else if (type == AtlasType.Emission)
            {
                cmd.SetGlobalVector("unity_MetaFragmentControl", new Vector4(0, 1, 0, 0));
            }

            cmd.SetGlobalFloat("unity_VisualizationMode", -1);

            cmd.SetGlobalVector("unity_LightmapST", new Vector4(1f, 1f, 0, 0));



            // https://ndotl.wordpress.com/2018/08/29/baking-artifact-free-lightmaps/#raster
            Vector4[] uvOffset = new Vector4[]
            {
                    new (1f, 1f, -2, -2f),
                    new (1f, 1f, 2, -2f),
                    new (1f, 1f, -2, 2f),
                    new (1f, 1f, 2f, 2f),
                    new (1f, 1f, -1f, -2f),
                    new (1f, 1f, 1f, -2f),
                    new (1f, 1f, -2f, -1f),
                    new (1f, 1f, 2f, -1f),
                    new (1f, 1f, -2f, 1f),
                    new (1f, 1f, 2f, 1f),
                    new (1f, 1f, -1f, 2f),
                    new (1f, 1f, 1f, 2f),
                    new (1f, 1f, -2f, 0f),
                    new (1f, 1f, 2f, 0f),
                    new (1f, 1f, 0f, -2f),
                    new (1f, 1f, 0f, 2f),
                    new (1f, 1f, -1f, -1f),
                    new (1f, 1f, 1f, -1f),
                    new (1f, 1f, -1f, 0f),
                    new (1f, 1f, 1f, 0f),
                    new (1f, 1f, -1f, 1f),
                    new (1f, 1f, 1f, 1f),
                    new (1f, 1f, 0f, -1f),
                    new (1f, 1f, 0f, 1f),
                    new (1f, 1f, 0f, 0f)
            };

            float halfTexelSize = (1.0f / _resolution) * 0.5f;
            for (int i = 0; i < uvOffset.Length; i++)
            {
                uvOffset[i].z *= halfTexelSize;
                uvOffset[i].w *= halfTexelSize;
            }

            for (int offsetIndex = 0; offsetIndex < uvOffset.Length; offsetIndex++)
            {
                for (int rendererIndex = 0; rendererIndex < renderers.Length; rendererIndex++)
                {
                    var renderer = renderers[rendererIndex];
                    var mesh = renderer.GetComponent<MeshFilter>().sharedMesh;
                    var so = renderer.lightmapScaleOffset;
                    so.z += uvOffset[offsetIndex].z;
                    so.w += uvOffset[offsetIndex].w;

                    cmd.SetGlobalVector("unity_LightmapST", so);

                    for (int submeshIndex = 0; submeshIndex < mesh.subMeshCount; submeshIndex++)
                    {
                        var mat = renderer.sharedMaterials[submeshIndex];


                        // if (type == AtlasType.Emission)
                        // {
                        //     if (mat.globalIlluminationFlags.HasFlag(MaterialGlobalIlluminationFlags.BakedEmissive))
                        //     {

                        //     }
                        // }

                        int meta = mat.FindPass("META");
                        cmd.DrawRenderer(renderer, mat, submeshIndex, meta);

                    }
                }
            }

            cmd.SetGlobalVector("unity_LightmapST", new Vector4(1f, 1f, 0, 0));

            Graphics.ExecuteCommandBuffer(cmd);
        }

        public void Dispose()
        {
            if (_rt)
            {
                Editor.DestroyImmediate(_rt);
            }
            if (_rtCopy)
            {
                Editor.DestroyImmediate(_rtCopy);
            }
            if (_rtFinal)
            {
                Editor.DestroyImmediate(_rtCopy);
            }
            if (_combineMat)
            {
                Editor.DestroyImmediate(_combineMat);
            }
        }
    }
}
#endif