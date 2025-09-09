#if UNITY_EDITOR
using System.Collections;
using System.Collections.Generic;
using System.IO;
using Unity.Mathematics;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;

public class ProbeBufferGenerator : MonoBehaviour
{
    public LightProbeGroup lightProbeGroup;
}

[CustomEditor(typeof(ProbeBufferGenerator))]
public class ProbeBufferGeneratorEditor : Editor
{
    public override void OnInspectorGUI()
    {
        if (GUILayout.Button("Generate Buffer"))
        {
            var gen = target as ProbeBufferGenerator;
            var probes = gen.lightProbeGroup;

            var positions = probes.probePositions;

            int bufferRes = Mathf.NextPowerOfTwo((int)math.ceil(math.sqrt(positions.Length)));

            // Debug.Log(positions.Length);

            var positionBuffer = new Texture2D(bufferRes, bufferRes, TextureFormat.RGBAFloat, false);
            positionBuffer.wrapMode = TextureWrapMode.Clamp;
            positionBuffer.filterMode = FilterMode.Point;

            for (int i = 0; i < positions.Length; i++)
            {
                var p = positions[i];
                int y = i / bufferRes;
                int x = i % bufferRes;
                positionBuffer.SetPixel(x, y, new Color(p.x, p.y, p.z, 1));
            }

            string sceneFolder = Path.GetDirectoryName(SceneManager.GetActiveScene().path);

            string path = Path.Combine(sceneFolder, $"VRCTraceProbePositions.asset");

            AssetDatabase.CreateAsset(positionBuffer, path);
            AssetDatabase.ImportAsset(path);
        }

        base.OnInspectorGUI();
    }
}
#endif