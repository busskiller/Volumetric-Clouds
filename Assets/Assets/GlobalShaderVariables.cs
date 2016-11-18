using UnityEngine;
using System.Collections;

[RequireComponent(typeof(Camera))]
public class GlobalShaderVariables : MonoBehaviour {

    public Texture2D NoiseOffsetTexture;

    public Texture3D PerlinWorleyNoise;
    public Texture3D WorleyNoise;

    private void Awake()
    {
        Shader.SetGlobalTexture("_NoiseOffsets", this.NoiseOffsetTexture);
        Shader.SetGlobalTexture("_PerlinWorleyNoise", this.PerlinWorleyNoise);
        Shader.SetGlobalTexture("_WorleyNoise", this.WorleyNoise);
    }

    private void OnPreRender()
    {
        Shader.SetGlobalVector("_CamPos", this.transform.position);
        Shader.SetGlobalVector("_CamRight", this.transform.right);
        Shader.SetGlobalVector("_CamUp", this.transform.up);
        Shader.SetGlobalVector("_CamForward", this.transform.forward);

        Shader.SetGlobalFloat("_AspectRatio", (float)Screen.width / (float)Screen.height);
        Shader.SetGlobalFloat("_FieldOfView", Mathf.Tan(Camera.main.fieldOfView * Mathf.Deg2Rad * 0.5f) * 2f);
    }


}
