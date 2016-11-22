using UnityEngine;
using System.Collections;
using CatlikeCoding.Noise;
using CatlikeCoding.NumberFlow;
using CatlikeCoding.NumberFlow.Functions.Colors;
using CatlikeCoding.NumberFlow.Functions.Floats;
using Gradient = CatlikeCoding.NumberFlow.Functions.Colors.Gradient;
using PerlinNoise = CatlikeCoding.Noise.PerlinNoise;

public static class Texture3dConverter
{
  
	// Use this for initialization


    public static Texture3D GenerateNoiseTexture3D(int size, TextureFormat format)
    {
        Texture3D tex3D = new Texture3D(size, size, size, format,false);
        int dim = size;
        Color[] newC = new Color[dim * dim * dim];
            float oneOverDim  = 1.0f / (1.0f * dim - 1.0f);
            for (int i = 0; i < dim; i++) {
                for (int j = 0; j < dim; j++) {
                    for (int k = 0; k < dim; k++) {
                        //newC[i + (j * dim) + (k * dim * dim)] = new Color((i * 1.0f) * oneOverDim, (j * 1.0f) * oneOverDim, (k * 1.0f) * oneOverDim, 1.0f);
                        newC[i + (j * dim) + (k * dim * dim)] = new Color(PerlinNoise.Sample3D(new Vector3(0,j,k), 10) *oneOverDim, PerlinNoise.Sample3D(new Vector3(i, 0, k), 10) * oneOverDim, PerlinNoise.Sample3D(new Vector3(i, j, 0), 10) * oneOverDim);
                    }
                }
            }
        tex3D.SetPixels(newC);
        tex3D.Apply();
        return tex3D;
    }
    public static Texture3D GenerateVoronoiNoiseTexture3D(int size, TextureFormat format)
    {
        Texture3D tex3D = new Texture3D(size, size, size, format, false);
        int dim = size;
        Color[] newC = new Color[dim * dim * dim];
        float oneOverDim = 1.0f / (1.0f * dim - 1.0f);
        for (int i = 0; i < dim; i++)
        {
            for (int j = 0; j < dim; j++)
            {
                for (int k = 0; k < dim; k++)
                {
                    //newC[i + (j * dim) + (k * dim * dim)] = new Color((i * 1.0f) * oneOverDim, (j * 1.0f) * oneOverDim, (k * 1.0f) * oneOverDim, 1.0f);
                    Vector3 samplingPoint = new Vector3(i, j, k);
                    Vector3 voronoiPoint = VoronoiNoise.SampleChebyshev3DTiledXYZ(samplingPoint, 0, 0, 0, 10);
                    voronoiPoint = voronoiPoint.normalized;
                    newC[i + (j * dim) + (k * dim * dim)] = new Color(voronoiPoint.x,voronoiPoint.y,voronoiPoint.z);
                }
            }
        }
        tex3D.SetPixels(newC);
        tex3D.Apply();
        return tex3D;
    }


    public static Texture3D GeneratePerlinWorleyTexture3D(int size, TextureFormat format)
    {
        Texture3D tex3D = new Texture3D(size, size, size, format, false);
        int dim = size;
        Color[] newC = new Color[dim * dim * dim];
        float oneOverDim = 1.0f / (1.0f * dim - 1.0f);
        for (int i = 0; i < dim; i++)
        {
            for (int j = 0; j < dim; j++)
            {
                for (int k = 0; k < dim; k++)
                {
                    //newC[i + (j * dim) + (k * dim * dim)] = new Color((i * 1.0f) * oneOverDim, (j * 1.0f) * oneOverDim, (k * 1.0f) * oneOverDim, 1.0f);
                    Vector3 samplingPoint = new Vector3(i, j, k);
                    Vector3 voronoiPoint = VoronoiNoise.SampleChebyshev3DTiledXYZ(samplingPoint, 0, 0, 0, 10);
                    Vector3 perlinPoint = new Vector3(PerlinNoise.Sample3D(new Vector3(0, j, k), 10) * oneOverDim, PerlinNoise.Sample3D(new Vector3(i, 0, k), 10) * oneOverDim, PerlinNoise.Sample3D(new Vector3(i, j, 0), 10) * oneOverDim);
                    voronoiPoint = voronoiPoint.normalized;
                    BlendSoftLight softLight = new BlendSoftLight();
                    softLight.returnType= ValueType.Color;
                    Value vorColorValue = new Value();
                    Value perlColorValue = new Value();
                    Value newColorValue = new Value();
                    vorColorValue.Color = new Color(voronoiPoint.x, voronoiPoint.y, voronoiPoint.z);
                    perlColorValue.Color = new Color(perlinPoint.x, perlinPoint.y, perlinPoint.z);
                    Value[] colors = { vorColorValue, perlColorValue };
                    softLight.Compute(newColorValue, colors);

                    Color testColor = new Color(perlinPoint.x +voronoiPoint.x, perlinPoint.y + voronoiPoint.y, perlinPoint.z + voronoiPoint.z);
                    newC[i + (j*dim) + (k*dim*dim)] = newColorValue.Color;
                }
            }
        }

        tex3D.SetPixels(newC);
        tex3D.Apply();
        return tex3D;
    }


    static float sampleVoronoi(Vector3 samplingPoint, Vector3 offset)
    {
        return VoronoiNoise.SampleManhattan3DTiledXYZ(samplingPoint,offset,10,4,1,0.5f).normalized.magnitude;
    }
    public static Texture3D convertTexture2DtoTexture3D(Texture2D inputTexture2D, int size, TextureFormat format)
    {
        // Create a temporary RenderTexture of the same size as the texture
        RenderTexture tmp = RenderTexture.GetTemporary(
                            inputTexture2D.width,
                            inputTexture2D.height,
                            0,
                            RenderTextureFormat.Default,
                            RenderTextureReadWrite.Linear);

        // Blit the pixels on texture to the RenderTexture
        Graphics.Blit(inputTexture2D, tmp);
        // Backup the currently set RenderTexture
        RenderTexture previous = RenderTexture.active;
        // Set the current RenderTexture to the temporary one we created
        RenderTexture.active = tmp;

        // Create a new readable Texture2D to copy the pixels to it
        Texture2D myTexture2D = new Texture2D(inputTexture2D.width, inputTexture2D.height);
        // Copy the pixels from the RenderTexture to the new Texture
        myTexture2D.ReadPixels(new Rect(0, 0, tmp.width, tmp.height), 0, 0);
        myTexture2D.Apply();

        // Reset the active RenderTexture
        RenderTexture.active = previous;
        // Release the temporary RenderTexture
        RenderTexture.ReleaseTemporary(tmp);

        // "myTexture2D" now has the same pixels from "texture" and it's readable.

        int dim = myTexture2D.height;
        //inputTexture2D.height = Mathf.FloorToInt(Mathf.Sqrt(inputTexture2D.width));
        Color[] c2D = myTexture2D.GetPixels();
        Color[] c3D = new Color[c2D.Length];
        //for (int x = 0; x < dim; ++x)
        //{
        //    for (int y = 0; y < dim; ++y)
        //    {
        //        for (int z = 0; z < dim; ++z)
        //        {
        //            int y_ = dim - y - 1;
        //            c3D[x + (y * dim) + (z * dim * dim)] = c2D[z * dim + x + y_ * dim * dim];
        //        }
        //    }
        //}
        int height = dim;
        int width = myTexture2D.width;
        int depth = 1;
        for (int y = 0; y < height; ++y)
            for (int x = 0; x < width * depth; ++x)
                c3D[(x % width) + y * width + (x / width) * width * height] = c2D[x + y * width * depth];

        Texture3D texture3D = new Texture3D(size, size, size, format, true);
        texture3D.hideFlags = HideFlags.HideAndDontSave;
        texture3D.wrapMode = TextureWrapMode.Repeat;
        texture3D.filterMode = FilterMode.Bilinear;
        texture3D.SetPixels(c3D);
        texture3D.Apply();

        return texture3D;
    }
}
