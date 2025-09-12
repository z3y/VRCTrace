
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class VRCTraceGI : UdonSharpBehaviour
{
    [Header("Lightmap")]
    public bool traceLightmap = false;
    public Camera computeCam;
    public int lightmapResolution = 512;
    public int sampleCount = 512;
    public bool monoSH;

    [Header("Light Probes")]
    public bool traceProbes = false;
    public Camera computeProbesCam;
    public Texture2D probesPositionBuffer;
    public Material probesCopyMat;
    public int probeSampleCount = 64;
    public CustomRenderTexture probeCopy;

    RenderTexture _rtL0;
    RenderTexture _rtL1;
    RenderTexture _rtL0Copy;
    RenderTexture _rtL1Copy;
    int _sample = 0;

    int _probeSample = 0;

    int[] _sampleIndices;
    int[] _probeSampleIndices;

    public int BakedSamples => _sample;

    RenderTexture _rtProbeTex0, _rtProbeTex0Copy;
    RenderTexture _rtProbeTex1, _rtProbeTex1Copy;
    RenderTexture _rtProbeTex2, _rtProbeTex2Copy;


    void Start()
    {
        computeCam.enabled = false;
        computeProbesCam.enabled = false;

        InitRt();

        InitRandomSample();
        ResetSamples();
    }

    void InitRt()
    {
        var desc = new RenderTextureDescriptor();
        desc.autoGenerateMips = false;
        desc.width = lightmapResolution;
        desc.height = lightmapResolution;
        desc.useMipMap = false;
        desc.colorFormat = RenderTextureFormat.ARGBFloat;
        desc.sRGB = false;
        desc.volumeDepth = 1;
        desc.msaaSamples = 1;
        desc.dimension = UnityEngine.Rendering.TextureDimension.Tex2D;

        if (traceLightmap)
        {
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
        }

        if (traceProbes)
        {
            desc.width = probesPositionBuffer.width;
            desc.height = probesPositionBuffer.height;

            _rtProbeTex0 = new RenderTexture(desc);
            _rtProbeTex0.depth = 0;

            _rtProbeTex1 = new RenderTexture(desc);
            _rtProbeTex1.depth = 0;

            _rtProbeTex2 = new RenderTexture(desc);
            _rtProbeTex2.depth = 0;

            _rtProbeTex0Copy = new RenderTexture(desc);
            _rtProbeTex0Copy.depth = 0;

            _rtProbeTex1Copy = new RenderTexture(desc);
            _rtProbeTex1Copy.depth = 0;

            _rtProbeTex2Copy = new RenderTexture(desc);
            _rtProbeTex2Copy.depth = 0;


            probesCopyMat.SetTexture("_BufferTex0", _rtProbeTex0);
            probesCopyMat.SetTexture("_BufferTex1", _rtProbeTex1);
            probesCopyMat.SetTexture("_BufferTex2", _rtProbeTex2);
        }
    }


    void InitRandomSample()
    {
        if (traceLightmap)
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
        if (traceProbes)
        {
            _probeSampleIndices = new int[probeSampleCount];
            for (int i = 0; i < probeSampleCount; i++)
            {
                _probeSampleIndices[i] = i;
            }

            for (int i = 0; i < _probeSampleIndices.Length; i++)
            {
                int swapIndex = Random.Range(i, _probeSampleIndices.Length);
                int temp = _probeSampleIndices[i];
                _probeSampleIndices[i] = _probeSampleIndices[swapIndex];
                _probeSampleIndices[swapIndex] = temp;
            }
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
        _probeSample = 0;

        if (traceLightmap)
        {
            VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceSampleCount"), sampleCount);

            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceLightmap"), _rtL0);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceLightmapCopy"), _rtL0Copy);


            VRCGraphics.Blit(Texture2D.blackTexture, _rtL0);
            VRCGraphics.Blit(Texture2D.blackTexture, _rtL0Copy);

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
        }

        if (traceProbes)
        {
            VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceProbeSampleCount"), probeSampleCount);

            VRCGraphics.Blit(Texture2D.blackTexture, _rtProbeTex0Copy);
            VRCGraphics.Blit(Texture2D.blackTexture, _rtProbeTex1Copy);
            VRCGraphics.Blit(Texture2D.blackTexture, _rtProbeTex2Copy);

            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceProbesTex0Copy"), _rtProbeTex0Copy);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceProbesTex1Copy"), _rtProbeTex1Copy);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_UdonVRCTraceProbesTex2Copy"), _rtProbeTex2Copy);

            var probeBuffers = new RenderBuffer[] { _rtProbeTex0.colorBuffer, _rtProbeTex1.colorBuffer, _rtProbeTex2.colorBuffer };
            computeProbesCam.SetTargetBuffers(probeBuffers, _rtProbeTex0.depthBuffer);
        }
    }



    void BakeLightmapSample()
    {
        VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceSample"), _sample);
        int randSample = _sampleIndices[_sample];
        VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceRandomSample"), randSample);
        _sample++;

        computeCam.Render();
        VRCGraphics.Blit(_rtL0, _rtL0Copy);

        if (monoSH)
        {
            VRCGraphics.Blit(_rtL1, _rtL1Copy);
        }

    }

    void BakeProbeSample()
    {
        VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceProbeSample"), _probeSample);
        int randSample = _probeSampleIndices[_probeSample];
        VRCShader.SetGlobalInteger(VRCShader.PropertyToID("_UdonVRCTraceProbeRandomSample"), randSample);
        _probeSample++;

        computeProbesCam.Render();

        VRCGraphics.Blit(_rtProbeTex0, _rtProbeTex0Copy);
        VRCGraphics.Blit(_rtProbeTex1, _rtProbeTex1Copy);
        VRCGraphics.Blit(_rtProbeTex2, _rtProbeTex2Copy);

        probeCopy.Update();
    }

    void Update()
    {
        if (_reset)
        {
            HandleResetSamples();
        }
        if (traceLightmap)
        {
            if (_sample < sampleCount)
            {
                BakeLightmapSample();
            }
        }

        if (traceProbes)
        {
            if (_probeSample < probeSampleCount)
            {
                BakeProbeSample();
            }
        }
    }
}
