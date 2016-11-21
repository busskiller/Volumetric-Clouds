using UnityEngine;
using System.Collections;





[RequireComponent(typeof(Camera))]
public class GlobalShaderVariables : MonoBehaviour {

    public Texture2D NoiseOffsetTexture;

    [HeaderAttribute("Our 3D noise textures")]
    public Texture3D LowFrequency_PerlinWorleyNoise;
    public Texture3D HighFrequency_WorleyNoise;

    [HeaderAttribute("Gradients representing Cloudtype")]
    public Gradient cloudGradient1;
    public Gradient cloudGradient2;
    public Gradient cloudGradient3;

    private Vector4 _cloudGradientVector1;
    private Vector4 _cloudGradientVector2;
    private Vector4 _cloudGradientVector3;


    private void Awake()
    {
        Shader.SetGlobalTexture("_NoiseOffsets", this.NoiseOffsetTexture);
        Shader.SetGlobalTexture("_PerlinWorleyNoise", this.LowFrequency_PerlinWorleyNoise);
        Shader.SetGlobalTexture("_WorleyNoise", this.HighFrequency_WorleyNoise);

        UpdateGradientVectors();
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
