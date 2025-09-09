
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class VRCTraceLightmapBaker : UdonSharpBehaviour
{
    public Camera computeCam;
    public Camera computeProbesCam;
    public Texture2D probesPositionBuffer;
    public Material probesCopyMat;
    public int resolution = 512;

    RenderTexture _rtL0;
    RenderTexture _rtL1;
    RenderTexture _rtL0Copy;
    RenderTexture _rtL1Copy;
    int _sample = 0;
    public int sampleCount = 512;

    int[] _sampleIndices;

    public bool monoSH;

    RenderTexture _rtProbeL0, _rtProbeL0Copy;
    RenderTexture _rtProbeL1x, _rtProbeL1xCopy;
    RenderTexture _rtProbeL1y, _rtProbeL1yCopy;
    RenderTexture _rtProbeL1z, _rtProbeL1zCopy;

    void Start()
    {
        InitRt();

        InitRandomSample();
        ResetSamples();
    }

    void InitRt()
    {
        var desc = new RenderTextureDescriptor();
        desc.autoGenerateMips = false;
        desc.width = resolution;
        desc.height = resolution;
        desc.useMipMap = false;
        desc.colorFormat = RenderTextureFormat.ARGBFloat;
        desc.sRGB = false;
        desc.volumeDepth = 1;
        desc.msaaSamples = 1;
        desc.dimension = UnityEngine.Rendering.TextureDimension.Tex2D;

        _rtL0 = new RenderTexture(desc);
        _rtL0.depth = 0;

        _rtL0Copy = new RenderTexture(desc);
        _rtL0Copy.depth = 0;

        if (monoSH)
        {
            _rtL1 = new RenderTexture(desc);
            _rtL1.depth = 0;

            _rtL1Copy = new RenderTexture(desc);
            _rtL1Copy.depth = 0;
        }

        if (probesPositionBuffer)
        {
            desc.width = probesPositionBuffer.width;
            desc.height = probesPositionBuffer.height;

            _rtProbeL0 = new RenderTexture(desc);
            _rtProbeL0.depth = 0;

            _rtProbeL1x = new RenderTexture(desc);
            _rtProbeL1x.depth = 0;

            _rtProbeL1y = new RenderTexture(desc);
            _rtProbeL1y.depth = 0;

            _rtProbeL1z = new RenderTexture(desc);
            _rtProbeL1z.depth = 0;

            _rtProbeL0Copy = new RenderTexture(desc);
            _rtProbeL0Copy.depth = 0;

            _rtProbeL1xCopy = new RenderTexture(desc);
            _rtProbeL1xCopy.depth = 0;

            _rtProbeL1yCopy = new RenderTexture(desc);
            _rtProbeL1yCopy.depth = 0;

            _rtProbeL1zCopy = new RenderTexture(desc);
            _rtProbeL1zCopy.depth = 0;

            probesCopyMat.SetTexture("_BufferL0", _rtProbeL0);
            probesCopyMat.SetTexture("_BufferL1x", _rtProbeL1x);
            probesCopyMat.SetTexture("_BufferL1y", _rtProbeL1y);
            probesCopyMat.SetTexture("_BufferL1z", _rtProbeL1z);
        }
    }


    void InitRandomSample()
    {
        _sampleIndices = new int[sampleCount];
        for (int i = 0; i < sampleCount; i++)
        {
            _sampleIndices[i] = i;
        }

        for (int i = 0; i < _sampleIndices.Length; i++)
        {
            int swapIndex = Random.Range(i, _sampleIndices.Length);
            int temp = _sampleIndices[i];
            _sampleIndices[i] = _sampleIndices[swapIndex];
            _sampleIndices[swapIndex] = temp;
        }
    }
    bool _reset;
    public void ResetSamples()
    {
        _reset = true;
    }

    void HandleResetSamples()
    {
        _reset = false;
        _sample = 0;

        VRCGraphics.Blit(Texture2D.blackTexture, _rtL0);
        VRCGraphics.Blit(Texture2D.blackTexture, _rtL0Copy);
        VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceSampleCount"), sampleCount);

        VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceLightmap"), _rtL0);
        VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceLightmapCopy"), _rtL0Copy);

        RenderBuffer[] buffers;
        if (monoSH)
        {
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceLightmapL1"), _rtL1);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceLightmapL1Copy"), _rtL1Copy);

            VRCGraphics.Blit(Texture2D.blackTexture, _rtL1);
            VRCGraphics.Blit(Texture2D.blackTexture, _rtL1Copy);

            buffers = new RenderBuffer[] { _rtL0.colorBuffer, _rtL1.colorBuffer };
        }
        else
        {
            buffers = new RenderBuffer[] { _rtL0.colorBuffer };
        }
        computeCam.SetTargetBuffers(buffers, _rtL0.depthBuffer);
        computeCam.enabled = false;

        computeProbesCam.enabled = false;
        if (probesPositionBuffer)
        {

            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceProbesL0Copy"), _rtProbeL0Copy);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceProbesL1xCopy"), _rtProbeL1xCopy);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceProbesL1yCopy"), _rtProbeL1yCopy);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceProbesL1zCopy"), _rtProbeL1zCopy);

            var probeBuffers = new RenderBuffer[] { _rtProbeL0.colorBuffer, _rtProbeL1x.colorBuffer, _rtProbeL1y.colorBuffer, _rtProbeL1z.colorBuffer };
            computeProbesCam.SetTargetBuffers(probeBuffers, _rtProbeL0.depthBuffer);
        }
    }

    void BakeSample()
    {
        VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceSample"), _sample);
        int randSample = _sampleIndices[_sample];
        VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceRandomSample"), randSample);
        computeCam.Render();
        VRCGraphics.Blit(_rtL0, _rtL0Copy);

        if (monoSH)
        {
            VRCGraphics.Blit(_rtL1, _rtL1Copy);
        }

        _sample++;
    }

    void BakeProbeSample()
    {
        computeProbesCam.Render();

        VRCGraphics.Blit(_rtProbeL0, _rtProbeL0Copy);
        VRCGraphics.Blit(_rtProbeL1x, _rtProbeL1xCopy);
        VRCGraphics.Blit(_rtProbeL1y, _rtProbeL1yCopy);
        VRCGraphics.Blit(_rtProbeL1z, _rtProbeL1zCopy);
    }

    void Update()
    {
        if (_reset)
        {
            HandleResetSamples();
        }
        if (_sample < sampleCount)
        {

            // BakeSample();
            BakeSample();

            if (probesPositionBuffer)
            {
                // BakeProbeSample();
                BakeProbeSample();
            }

        }

    }
}
