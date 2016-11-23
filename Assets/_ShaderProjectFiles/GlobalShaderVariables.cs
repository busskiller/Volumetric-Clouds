using UnityEngine;
using System.Collections;





[RequireComponent(typeof(Camera))]
public class GlobalShaderVariables : MonoBehaviour {


    [HeaderAttribute("Our 3D noise textures")]
    public Texture3D LowFrequency_PerlinWorleyNoise;
    public Texture3D HighFrequency_WorleyNoise;

    [HeaderAttribute("Our 2D textures")]
    public Texture2D Curl_Noise;
    public Texture2D Weather_Texture;

    [HeaderAttribute("Gradients representing Cloudtype")]
    public Gradient cloudGradient1;
    public Gradient cloudGradient2;
    public Gradient cloudGradient3;

    private Vector4 _cloudGradientVector1;
    private Vector4 _cloudGradientVector2;
    private Vector4 _cloudGradientVector3;

    public Material _cloudMaterial;

    private void Awake()
    {
        _camera = Camera.main;
       // CreateRenderTextures();
        GetTextures();
        Shader.SetGlobalTexture("_PerlinWorleyNoise", this.LowFrequency_PerlinWorleyNoise);
        Shader.SetGlobalTexture("_WorleyNoise", this.HighFrequency_WorleyNoise);
        Shader.SetGlobalTexture("_CurlNoise", this.Curl_Noise);
        Shader.SetGlobalTexture("_WeatherTexture", this.Weather_Texture);
        thisShader = _cloudMaterial.shader;

        UpdateGradientVectors();
    }

    private Camera _camera;
    private RenderTexture _subFrame;
    private RenderTexture _previousFrame;
    public RenderTexture currentFrame { get { return _previousFrame; } }
    private bool _isFirstFrame;

    private kode80.Clouds.SharedProperties _cloudsSharedProperties;
    public kode80.Clouds.SharedProperties cloudsSharedProperties { get { return _cloudsSharedProperties; } }

    private Shader thisShader;

    private void CreateRenderTextures()
    {
        if (_subFrame == null && _camera != null)
        {
            RenderTextureFormat format = _camera.hdr ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
            _subFrame = new RenderTexture(_cloudsSharedProperties.subFrameWidth,
                _cloudsSharedProperties.subFrameHeight, 0, format, RenderTextureReadWrite.Linear);
            _subFrame.filterMode = FilterMode.Bilinear;
            _subFrame.hideFlags = HideFlags.HideAndDontSave;
            _isFirstFrame = true;
        }

        if (_previousFrame == null && _camera != null)
        {
            RenderTextureFormat format = _camera.hdr ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
            _previousFrame = new RenderTexture(_cloudsSharedProperties.frameWidth,
                _cloudsSharedProperties.frameHeight, 0, format, RenderTextureReadWrite.Linear);
            _previousFrame.filterMode = FilterMode.Bilinear;
            _previousFrame.hideFlags = HideFlags.HideAndDontSave;
            _isFirstFrame = true;
        }
    }


    void GetTextures()
    {
        if (LowFrequency_PerlinWorleyNoise == null)
        {
            LowFrequency_PerlinWorleyNoise = Load3DTexture("kode80Clouds/noise", 128, TextureFormat.RGBA32);
            _cloudMaterial.SetTexture("_PerlinWorleyNoise", LowFrequency_PerlinWorleyNoise);
        }

        if (HighFrequency_WorleyNoise == null)
        {
            HighFrequency_WorleyNoise = Load3DTexture("kode80Clouds/noise_detail", 32, TextureFormat.RGB24);
            _cloudMaterial.SetTexture("_WorleyNoise", HighFrequency_WorleyNoise);

        }

        if (Curl_Noise == null)
        {
            Curl_Noise = Resources.Load("kode80Clouds/CurlNoise") as Texture2D;
            _cloudMaterial.SetTexture("_CurlNoise", Curl_Noise);

        }
    }

    void SetShaderVariables()
    {
       _cloudMaterial.SetFloat("_MaxDistance", 400);
    }

    private Texture3D Load3DTexture(string name, int size, TextureFormat format)
    {
        int count = size * size * size;
        TextAsset asset = Resources.Load<TextAsset>(name);
        Color32[] colors = new Color32[count];
        byte[] bytes = asset.bytes;
        int j = 0;

        for (int i = 0; i < count; i++)
        {
            colors[i].r = bytes[j++];
            colors[i].g = bytes[j++];
            colors[i].b = bytes[j++];
            colors[i].a = format == TextureFormat.RGBA32 ? bytes[j++] : (byte)255;
        }

        Texture3D texture3D = new Texture3D(size, size, size, format, true);
        texture3D.hideFlags = HideFlags.HideAndDontSave;
        texture3D.wrapMode = TextureWrapMode.Repeat;
        texture3D.filterMode = FilterMode.Bilinear;
        texture3D.SetPixels32(colors, 0);
        texture3D.Apply();

        return texture3D;
    }

    private void Reset()
    {
        cloudGradient1 = cloudGradient1 ?? CreateCloudGradient(0.011f, 0.098f, 0.126f, 0.225f);
        cloudGradient2 = cloudGradient2 ?? CreateCloudGradient(0.0f, 0.096f, 0.311f, 0.506f);
        cloudGradient3 = cloudGradient3 ?? CreateCloudGradient(0.0f, 0.087f, 0.749f, 1.0f);
    }


    private void OnPreRender()
    {
        Shader.SetGlobalVector("_CamPos", this.transform.position);
        Shader.SetGlobalVector("_CamRight", this.transform.right);
        Shader.SetGlobalVector("_CamUp", this.transform.up);
        Shader.SetGlobalVector("_CamForward", this.transform.forward);

        Shader.SetGlobalFloat("_AspectRatio", (float)Screen.width / (float)Screen.height);
        Shader.SetGlobalFloat("_FieldOfView", Mathf.Tan(Camera.main.fieldOfView * Mathf.Deg2Rad * 0.5f) * 2f);

        Shader.SetGlobalVector("_Gradient1", _cloudGradientVector1);
        Shader.SetGlobalVector("_Gradient2", _cloudGradientVector2);
        Shader.SetGlobalVector("_Gradient3", _cloudGradientVector3);
    }


    //Creates our gradients
    private Gradient CreateCloudGradient(float position0, float position1, float position2, float position3)
    {
        Gradient gradient = new Gradient();
        gradient.colorKeys = new GradientColorKey[] { new GradientColorKey(Color.black, position0),
                                                          new GradientColorKey( Color.white, position1),
                                                          new GradientColorKey( Color.white, position2),
                                                          new GradientColorKey( Color.black, position3)};
        return gradient;
    }

    //Returns the gradients as Vector4 variables.  x,y,z,w = 4 positions of a black,white,white,black gradient
    private Vector4 CloudHeightGradient(Gradient gradient)
    {
        int l = gradient.colorKeys.Length;
        float a = l > 0 ? gradient.colorKeys[0].time : 0.0f;
        float b = l > 1 ? gradient.colorKeys[1].time : a;
        float c = l > 2 ? gradient.colorKeys[2].time : b;
        float d = l > 3 ? gradient.colorKeys[3].time : c;

        return new Vector4(a, b, c, d);
    }

    //Updates our vector4 representations of our gradients
    private void UpdateGradientVectors()
    {
        _cloudGradientVector1 = CloudHeightGradient(cloudGradient1);
        _cloudGradientVector2 = CloudHeightGradient(cloudGradient2);
        _cloudGradientVector3 = CloudHeightGradient(cloudGradient3);
    }
}
