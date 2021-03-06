﻿    //***************************************************
//
//  Author: Ben Hopkins
//  Copyright (C) 2016 kode80 LLC, 
//  all rights reserved
// 
//  Free to use for non-commercial purposes, 
//  see full license in project root:
//  kode80CloudsNonCommercialLicense.html
//  
//  Commercial licenses available for purchase from:
//  http://kode80.com/
//
//***************************************************

using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;
using System.Collections;

namespace kode80.Clouds
{
    public class CloudManager : MonoBehaviour
    {
        public enum SubPixelSize
        {
            Sub1x1,
            Sub2x2,
            Sub4x4,
            Sub8x8,
        }

        public enum RenderSize
        {
            CameraDimensions,
            FixedDimensions
        }

        public delegate void OnValidateDelegate();
        public OnValidateDelegate onValidateDelegate;


        [HeaderAttribute("Render")]
        public Camera targetCamera;
        public SubPixelSize subPixelSize = SubPixelSize.Sub2x2;
        public int maxIterations = 128;
        [Space(10)]
        public RenderSize renderSize = RenderSize.CameraDimensions;
        public int fixedWidth = 0;
        public int fixedHeight = 0;
        [Range(1.0f, 8.0f)]
        public int downsample = 2;

        [HeaderAttribute("Coverage")]
        public Texture cloudCoverage;
        [Range(0.0f, 1.0f)]
        public float coverageOffsetX;
        [Range(0.0f, 1.0f)]
        public float coverageOffsetY;
        [Range(0.0f, 1.0f)]
        public float horizonCoverageStart = 0.3f;
        [Range(0.0f, 1.0f)]
        public float horizonCoverageEnd = 0.4f;

        [HeaderAttribute("Lighting")]
        public Color cloudBaseColor = new Color32(132, 170, 208, 255);
        public Color cloudTopColor = new Color32(255, 255, 255, 255);
        public Light sunLight;
        [Range(0.0f, 5.0f)]
        public float sunScalar = 1.0f;
        [Range(0.0f, 5.0f)]
        public float ambientScalar = 1.0f;
        [Range(0.0f, 1.0f)]
        public float sunRayLength = 0.08f;
        [Range(0.0f, 1.0f)]
        public float coneRadius = 0.08f;
        [Range(0.0f, 30.0f)]
        public float density = 1.0f;
        [Range(0.0f, 1.0f)]
        public float forwardScatteringG = 0.8f;
        [Range(0.0f, -1.0f)]
        public float backwardScatteringG = -0.5f;
        [Range(0.0f, 1.0f)]
        public float darkOutlineScalar = 1.0f;

        [HeaderAttribute("Animation")]
        [Range(-10.0f, 10.0f)]
        public float animationScale = 1.0f;
        public Vector2 coverageOffsetPerFrame;
        public Vector3 baseOffsetPerFrame = new Vector3(0.0f, -0.001f, 0.0f);
        public Vector3 detailOffsetPerFrame;

        [HeaderAttribute("Modeling (Base)")]
        public float baseScale = 1.0f;
        [Range(0,10)]
        public float baseFbmScale = 1.0f;
        public Gradient cloudGradient1;
        public Gradient cloudGradient2;
        public Gradient cloudGradient3;

        [Space(10)]
        [Range(0.0f, 1.0f)]
        public float sampleScalar = 1.0f;
        [Range(0.0f, 1.0f)]
        public float sampleThreshold = 0.05f;
        [Range(0.0f, 1.0f)]
        public float cloudBottomFade = 0.3f;

        [HeaderAttribute("Modeling (Detail)")]
        public float detailScale = 8.0f;
        [Range(0, 1)]
        public float detailFbmScale = 1.0f;
        [Space(10)]
        [RangeAttribute(0.0f, 1.0f)]
        public float erosionEdgeSize = 0.5f;
        [RangeAttribute(0.0f, 1.0f)]
        public float cloudDistortion = 0.45f;
        public float cloudDistortionScale = 0.5f;

        [HeaderAttribute("Optimization")]
        [RangeAttribute(0.0f, 1.0f)]
        public float lodDistance = 0.3f;
        [RangeAttribute(0.0f, 1.0f)]
        public float horizonLevel = 0.0f;
        [Range(0.0f, 1.0f)]
        public float horizonFade = 0.25f;
        [Range(0.0f, 1.0f)]
        public float horizonFadeStartAlpha = 0.9f;

        [HeaderAttribute("Atmosphere:")]
        public float horizonDistance = 35000.0f;
        public float atmosphereStartHeight = 1500.0f;
        public float atmosphereEndHeight = 4000.0f;
        public Vector3 cameraPositionScaler = new Vector3(1.0f, 1.0f, 1.0f);


        private Material _cloudMaterial;
        private Material _cloudCombinerMaterial;
        private Material _cloudBlenderMaterial;
        private Material _cloudShadowPassMaterial;
        private Camera _camera;
        private Texture3D _perlin3D;
        private Texture3D _detail3D;
        private Texture2D _curlTexture;

        private Vector2 _coverageOffset;
        public Vector2 coverageOffset { get { return _coverageOffset; } }

        private Vector3 _baseOffset;
        private Vector3 _detailOffset;

        private RenderTexture _subFrame;
        private RenderTexture _previousFrame;
        public RenderTexture currentFrame { get { return _previousFrame; } }

        private Vector4 _cloudGradientVector1;
        private Vector4 _cloudGradientVector2;
        private Vector4 _cloudGradientVector3;

        private Vector3[] _randomVectors;

        private bool _isFirstFrame;

        private Clouds.SharedProperties _cloudsSharedProperties;
        public Clouds.SharedProperties cloudsSharedProperties { get { return _cloudsSharedProperties; } }

        private FullScreenQuad _fullScreenQuad;
        public FullScreenQuad fullScreenQuad { get { return _fullScreenQuad; } }

        public Shader ourShader;

        public Texture2D _weatherTexture2D;


        //OnEnable is called everytime the camera object goes from inactive to active object state
        void OnEnable()
        {
            //Check function comments
            Camera.onPreCull += CloudsOnPreCull;

            //Check function comments
            CreateMaterialsIfNeeded();

            CreateRenderTextures();
            CreateFullscreenQuad();
        }

        //OnDrawGizmoz basically makes the gizmos visible, but only in scene view! You can also customize them etc.
        void OnDrawGizmos()
        {
            float earthRadius = cloudsSharedProperties.earthRadius;
            float startHeight = cloudsSharedProperties.atmosphereStartHeight;
            float endHeight = cloudsSharedProperties.atmosphereEndHeight;

            float innerRadius = earthRadius + startHeight;
            float outerRadius = earthRadius + endHeight;
            float distant = cloudsSharedProperties.maxDistance - cloudsSharedProperties.maxRayDistance;

            Vector3 position = transform.position;
            Vector3 center = position;
            center.y -= earthRadius;

            Gizmos.color = Color.gray;
            Gizmos.DrawWireSphere(center, innerRadius);
            Gizmos.color = Color.black;
            Gizmos.DrawWireSphere(center, outerRadius);
            Gizmos.color = Color.white;
            Gizmos.DrawLine(position + new Vector3(0.0f, startHeight, 0.0f),
                             position + new Vector3(0.0f, endHeight, 0.0f));

            Gizmos.color = Color.red;
            Gizmos.DrawLine(position,
                             position + new Vector3(distant, 0.0f, 0.0f));

            Gizmos.color = Color.green;
            Gizmos.DrawLine(position,
                             position + new Vector3(0.0f, cloudsSharedProperties.atmosphereStartHeight, 0.0f));

            Gizmos.color = Color.blue;
            Gizmos.DrawLine(position,
                             position + new Vector3(0.0f, 0.0f, distant));
        }

        //OnDisable is called when the camera becoves inactive or destroyed
        void OnDisable()
        {
            Camera.onPreCull -= CloudsOnPreCull;
            DestroyMaterials();
            DestroyRenderTextures();
            DestroyFullscreenQuad();
        }

        //OnValidate is called everytime something changes in the inspector. Neat.
        void OnValidate()
        {
            if (_cloudsSharedProperties == null)
            {
                _cloudsSharedProperties = new Clouds.SharedProperties();
            }

            _coverageOffset.Set(coverageOffsetX, coverageOffsetY);

            UpdateGradientVectors();
            UpdateSharedFromPublicProperties();

            if (onValidateDelegate != null)
            {
                onValidateDelegate();
            }
        }

        //Reset basically resets stuff. It is only called and/or used in editor mode.
        void Reset()
        {
            targetCamera = Camera.main;
            sunLight = FindDirectionalLightInScene();

            cloudGradient1 = cloudGradient1 ?? CreateCloudGradient(0.011f, 0.098f, 0.126f, 0.225f);
            cloudGradient2 = cloudGradient2 ?? CreateCloudGradient(0.0f, 0.096f, 0.311f, 0.506f);
            cloudGradient3 = cloudGradient3 ?? CreateCloudGradient(0.0f, 0.087f, 0.749f, 1.0f);

            UpdateGradientVectors();

            _cloudsSharedProperties = new Clouds.SharedProperties();
            UpdateSharedFromPublicProperties();
        }

        //Start... does it need explanation?
        void Start()
        {
            SetCamera(targetCamera);
            _cloudsSharedProperties = new Clouds.SharedProperties();
            UpdateSharedFromPublicProperties();
            CreateMaterialsIfNeeded();
            CreateRenderTextures();
            CreateFullscreenQuad();
        }

        //Awake is called before start and is used to initialize itself
        void Awake()
        {
            UpdateGradientVectors();

            _cloudsSharedProperties = new Clouds.SharedProperties();
            UpdateSharedFromPublicProperties();
        }



        //Used to animate our lovely clouds by offsetting three variables: _coverage, base (what is this?) and level of detail
        public void UpdateAnimatedProperties()
        {
            if (animationScale != 0.0f)
            {
                _coverageOffset += coverageOffsetPerFrame * animationScale;
                _baseOffset += baseOffsetPerFrame * animationScale;
                _detailOffset += detailOffsetPerFrame * animationScale;
            }
        }

        //Used to cull or show visibility of clouds to the camera
        void CloudsOnPreCull(Camera currentCamera)
        {

            //If our _camera variable is set to our camera in the scene call the following to functions
            bool validCamera = _camera != null && currentCamera == _camera;

            if (validCamera)
            {
                //Used for animation purposes
                UpdateAnimatedProperties();

                RenderClouds();
            }
        }

        //Used to change couple of render variables via the Clouds namespace thingy. 
        public void CopyPropertiesToRenderSettings(Clouds.RenderSettings settings)
        {
            settings.sunColor = sunLight.color;
            settings.sunDirection = sunLight.transform.eulerAngles;
            settings.cloudBaseColor = cloudBaseColor;
            settings.cloudTopColor = cloudTopColor;
        }

        //Used to set  the private camera variable to the same as the public one. Why not just use a public one and thats it?
        public void SetCamera(Camera theCamera)
        {
            if (theCamera != _camera)
            {
                _camera = theCamera;
            }
        }

        //Used to create our gradients. Duh!
        private Gradient CreateCloudGradient(float position0, float position1, float position2, float position3)
        {
            Gradient gradient = new Gradient();
            gradient.colorKeys = new GradientColorKey[] { new GradientColorKey(Color.black, position0),
                                                          new GradientColorKey( Color.white, position1),
                                                          new GradientColorKey( Color.white, position2),
                                                          new GradientColorKey( Color.black, position3)};

            return gradient;
        }

        //Used to return the gradients as Vector4 variables.  x,y,z,w = 4 positions of a black,white,white,black gradient
        private Vector4 CloudHeightGradient(Gradient gradient)
        {
            int l = gradient.colorKeys.Length;
            float a = l > 0 ? gradient.colorKeys[0].time : 0.0f;
            float b = l > 1 ? gradient.colorKeys[1].time : a;
            float c = l > 2 ? gradient.colorKeys[2].time : b;
            float d = l > 3 ? gradient.colorKeys[3].time : c;

            return new Vector4(a, b, c, d);
        }

        //Used to Update our vector4 representations of our gradients
        private void UpdateGradientVectors()
        {
            _cloudGradientVector1 = CloudHeightGradient(cloudGradient1);
            _cloudGradientVector2 = CloudHeightGradient(cloudGradient2);
            _cloudGradientVector3 = CloudHeightGradient(cloudGradient3);
        }

        //Used to fill all all our shader and material variables
        private void CreateMaterialsIfNeeded()
        {
            if (_randomVectors == null || _randomVectors.Length < 1)
            {
                _randomVectors = new Vector3[] { Random.onUnitSphere,
                    Random.onUnitSphere,
                    Random.onUnitSphere,
                    Random.onUnitSphere,
                    Random.onUnitSphere,
                    Random.onUnitSphere};

            }

            //Our main shader, where the cloud modeling happens
            if (_cloudMaterial == null)
            {
                //_cloudMaterial = new Material(Shader.Find("Hidden/kode80/VolumeClouds"));
                _cloudMaterial = new Material(Shader.Find("Custom/P5/HorizonClouds"));
                _cloudMaterial.hideFlags = HideFlags.HideAndDontSave;
            }

            //This shader combines clouds? The code in it is not long.
            if (_cloudCombinerMaterial == null)
            {
                _cloudCombinerMaterial = new Material(Shader.Find("Hidden/kode80/CloudCombiner"));
                _cloudCombinerMaterial.hideFlags = HideFlags.HideAndDontSave;
            }

            //This shader blends clouds, transparency style.
            if (_cloudBlenderMaterial == null)
            {
                _cloudBlenderMaterial = new Material(Shader.Find("Hidden/kode80/CloudBlender"));
                _cloudBlenderMaterial.hideFlags = HideFlags.HideAndDontSave;
            }

            //This shader is used to cast shadows on non cloud object. I think.
            if (_cloudShadowPassMaterial == null)
            {
                _cloudShadowPassMaterial = new Material(Shader.Find("Hidden/kode80/CloudShadowPass"));
                _cloudShadowPassMaterial.hideFlags = HideFlags.HideAndDontSave;
            }

            //Perlin noise 3D texture - but we need a perlin-worly noise combined with three worley noises
            if (_perlin3D == null)
            {
                //_perlin3D = Texture3dConverter.GenerateNoiseTexture3D(128, TextureFormat.RGBA32);
                _perlin3D = Load3DTexture("kode80Clouds/noise", 128, TextureFormat.RGBA32);
            }

            //The second 3D texture. No idea whether it is worley or whatever. 
            //In Horizon guys case, we need this to be three, high frequency worley noises at increasing frequencies
            if (_detail3D == null)
            {
                //_detail3D = Texture3dConverter.GenerateNoiseTexture3D(32, TextureFormat.RGB24);

                //_detail3D = Texture3dConverter.GeneratePerlinWorleyTexture3D(32, TextureFormat.RGB24);
                _detail3D = Load3DTexture("kode80Clouds/noise_detail", 32, TextureFormat.RGB24);
            }

            //The curl texture - this we can re-use for our own purposes
            if (_curlTexture == null)
            {
                _curlTexture = Resources.Load("kode80Clouds/CurlNoise") as Texture2D;
            }
        }

        //Used to destroy all materials, and also setting them to null for some weird reason
        private void DestroyMaterials()
        {
            DestroyImmediate(_cloudMaterial);
            _cloudMaterial = null;

            DestroyImmediate(_cloudCombinerMaterial);
            _cloudCombinerMaterial = null;

            DestroyImmediate(_cloudBlenderMaterial);
            _cloudBlenderMaterial = null;

            DestroyImmediate(_cloudShadowPassMaterial);
            _cloudShadowPassMaterial = null;

            DestroyImmediate(_perlin3D);
            _perlin3D = null;

            DestroyImmediate(_detail3D);
            _detail3D = null;

            Resources.UnloadAsset(_curlTexture);
            _curlTexture = null;
        }

        //Used to find the directional light in the scene and returns it
        private Light FindDirectionalLightInScene()
        {
            Light[] lights = GameObject.FindObjectsOfType<Light>();

            foreach (Light light in lights)
            {
                if (light.type == LightType.Directional) { return light; }
            }

            return null;
        }

        //Used to set a shit ton of variables in our shader
        private void UpdateMaterialsPublicProperties()
        {
            if (_cloudMaterial && _camera)
            {
                Vector3 lightDirection = sunLight.transform.forward;

                _cloudMaterial.SetFloat("_CloudBottomFade", cloudBottomFade);

                _cloudMaterial.SetFloat("_MaxIterations", maxIterations);
                _cloudMaterial.SetFloat("_SampleScalar", sampleScalar);
                _cloudMaterial.SetFloat("_SampleThreshold", sampleThreshold);
                _cloudMaterial.SetFloat("_LODDistance", lodDistance);
                _cloudMaterial.SetFloat("_RayMinimumY", horizonLevel);
                _cloudMaterial.SetFloat("_DetailScale", detailScale);
                _cloudMaterial.SetFloat("_ErosionEdgeSize", erosionEdgeSize);
                _cloudMaterial.SetFloat("_CloudDistortion", cloudDistortion);
                _cloudMaterial.SetFloat("_CloudDistortionScale", cloudDistortionScale);
                _cloudMaterial.SetFloat("_HorizonFadeScalar", horizonFade);
                _cloudMaterial.SetFloat("_HorizonFadeStartAlpha", horizonFadeStartAlpha);
                _cloudMaterial.SetFloat("_OneMinusHorizonFadeStartAlpha", 1.0f - horizonFadeStartAlpha);
                _cloudMaterial.SetTexture("_PerlinWorleyNoise", _perlin3D);
                _cloudMaterial.SetTexture("_WorleyNoise", _detail3D);
                _cloudMaterial.SetVector("_BaseOffset", _baseOffset);
                _cloudMaterial.SetVector("_DetailOffset", _detailOffset);
                _cloudMaterial.SetFloat("_BaseScale", 1.0f / atmosphereEndHeight * baseScale);
                _cloudMaterial.SetFloat("_LightScalar", sunScalar);
                _cloudMaterial.SetFloat("_AmbientScalar", ambientScalar);
                _cloudMaterial.SetVector("_CloudHeightGradient1", _cloudGradientVector1);
                _cloudMaterial.SetVector("_CloudHeightGradient2", _cloudGradientVector2);
                _cloudMaterial.SetVector("_CloudHeightGradient3", _cloudGradientVector3);
                _cloudMaterial.SetVector("_Gradient1", _cloudGradientVector1);
                _cloudMaterial.SetVector("_Gradient2", _cloudGradientVector2);
                _cloudMaterial.SetVector("_Gradient3", _cloudGradientVector3);
                _cloudMaterial.SetTexture("_Coverage", cloudCoverage);
                _cloudMaterial.SetTexture("_WeatherTexture", cloudCoverage);

                _cloudMaterial.SetVector("_LightDirection", lightDirection);

                _cloudMaterial.SetColor("_LightColor", sunLight.color);
                _cloudMaterial.SetColor("_CloudBaseColor", cloudBaseColor);
                _cloudMaterial.SetColor("_CloudTopColor", cloudTopColor);

                _cloudMaterial.SetFloat("_HorizonCoverageStart", horizonCoverageStart);
                _cloudMaterial.SetFloat("_HorizonCoverageEnd", horizonCoverageEnd);
                _cloudMaterial.SetFloat("_BaseFBMScale", baseFbmScale);
                _cloudMaterial.SetFloat("_DetailFBMScale", detailFbmScale);

                _cloudMaterial.SetFloat("_Density", density);
                _cloudMaterial.SetFloat("_ForwardScatteringG", forwardScatteringG);
                _cloudMaterial.SetFloat("_BackwardScatteringG", backwardScatteringG);
                _cloudMaterial.SetFloat("_DarkOutlineScalar", darkOutlineScalar);

                float atmosphereThickness = atmosphereEndHeight - atmosphereStartHeight;
                _cloudMaterial.SetFloat("_SunRayLength", sunRayLength * atmosphereThickness);
                _cloudMaterial.SetFloat("_ConeRadius", coneRadius * atmosphereThickness);
                _cloudMaterial.SetFloat("_RayStepLength", atmosphereThickness / Mathf.Floor(maxIterations / 2.0f));

                _cloudMaterial.SetTexture("_Curl2D", _curlTexture);
                _cloudMaterial.SetFloat("_CoverageScale", 1.0f / _cloudsSharedProperties.maxDistance);
                _cloudMaterial.SetVector("_CoverageOffset", _coverageOffset);
                _cloudMaterial.SetFloat("_MaxRayDistance", _cloudsSharedProperties.maxRayDistance);

                _cloudMaterial.SetVector("_Random0", _randomVectors[0]);
                _cloudMaterial.SetVector("_Random1", _randomVectors[1]);
                _cloudMaterial.SetVector("_Random2", _randomVectors[2]);
                _cloudMaterial.SetVector("_Random3", _randomVectors[3]);
                _cloudMaterial.SetVector("_Random4", _randomVectors[4]);
                _cloudMaterial.SetVector("_Random5", _randomVectors[5]);
            }
        }

        //This is a method used to load 3D textures. It is forexample used in the CreateMaterialsIfNeeded function
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



        void CreateFullscreenQuad()
        {
            if (Application.isPlaying && _fullScreenQuad == null)
            {
                GameObject quadGO = new GameObject("CloudsFullscreenQuad", typeof(FullScreenQuad));
                quadGO.hideFlags = HideFlags.HideAndDontSave;
                _fullScreenQuad = quadGO.GetComponent<FullScreenQuad>();
                _fullScreenQuad.material = _cloudBlenderMaterial;
                _fullScreenQuad.renderWhenPlaying = true;
            }
        }

        void DestroyFullscreenQuad()
        {
            if (_fullScreenQuad != null)
            {
                DestroyImmediate(_fullScreenQuad.gameObject);
                _fullScreenQuad = null;
            }
        }


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

        private void DestroyRenderTextures()
        {
            DestroyImmediate(_subFrame);
            _subFrame = null;

            DestroyImmediate(_previousFrame);
            _previousFrame = null;
        }


        public void UpdateSharedFromPublicProperties()
        {
            float earthRadius = _cloudsSharedProperties.CalculatePlanetRadius(atmosphereStartHeight, horizonDistance);

            _coverageOffset.Set(coverageOffsetX, coverageOffsetY);

            _cloudsSharedProperties.earthRadius = earthRadius;
            _cloudsSharedProperties.atmosphereStartHeight = atmosphereStartHeight;
            _cloudsSharedProperties.atmosphereEndHeight = atmosphereEndHeight;
            _cloudsSharedProperties.cameraPosition = new Vector3(0.0f, earthRadius, 0.0f);
            _cloudsSharedProperties.subPixelSize = SubPixelSizeToInt(subPixelSize);
            _cloudsSharedProperties.downsample = downsample;
            _cloudsSharedProperties.useFixedDimensions = renderSize == RenderSize.FixedDimensions;
            _cloudsSharedProperties.fixedWidth = fixedWidth;
            _cloudsSharedProperties.fixedHeight = fixedHeight;
        }

        private int SubPixelSizeToInt(SubPixelSize size)
        {
            int value = 2;

            switch (size)
            {
                case SubPixelSize.Sub1x1: value = 1; break;
                case SubPixelSize.Sub2x2: value = 2; break;
                case SubPixelSize.Sub4x4: value = 4; break;
                case SubPixelSize.Sub8x8: value = 8; break;
            }

            return value;
        }

        public void RenderClouds()
        {
            if (_camera == null)
            {
                return;
            }

            CreateMaterialsIfNeeded();

            _cloudsSharedProperties.BeginFrame(_camera);

            if (_subFrame == null || _previousFrame == null ||
                _cloudsSharedProperties.dimensionsChangedSinceLastFrame)
            {
                DestroyRenderTextures();
                CreateRenderTextures();
            }

            Vector3 pos = Vector3.Scale(_camera.transform.position - transform.position, cameraPositionScaler);
            pos.y += _cloudsSharedProperties.earthRadius;
            _cloudsSharedProperties.cameraPosition = pos;

            _cloudsSharedProperties.ApplyToMaterial(_cloudMaterial, true);
            UpdateMaterialsPublicProperties();

            // If we don't store the current active RT and
            // restore it when done, rendering breaks the Editor
            // quite horrifically. Unity panels (inspector et el) 
            // get rendered into our buffers and stop working properly.
            // This only seems to happen for in-editor rendering, such
            // as to a custom EditorWindow. In-game the active RT restoration
            // doesn't seem to be required. Of course, this is undocumented...
            RenderTexture previousActiveRenderTexture = RenderTexture.active;

            Graphics.Blit(null, _subFrame, _cloudMaterial);

            if (_isFirstFrame)
            {
                Graphics.Blit(_subFrame, _previousFrame);
                _isFirstFrame = false;
            }

            _cloudCombinerMaterial.SetTexture("_SubFrame", _subFrame);
            _cloudCombinerMaterial.SetTexture("_PrevFrame", _previousFrame);
            _cloudsSharedProperties.ApplyToMaterial(_cloudCombinerMaterial);

            RenderTextureFormat format = _camera.hdr ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
            RenderTexture combined = RenderTexture.GetTemporary(_previousFrame.width, _previousFrame.height, 0, format, RenderTextureReadWrite.Linear);
            combined.filterMode = FilterMode.Bilinear;

            Graphics.Blit(null, combined, _cloudCombinerMaterial);
            Graphics.Blit(combined, _previousFrame);

            RenderTexture.active = previousActiveRenderTexture;
            RenderTexture.ReleaseTemporary(combined);


            _cloudsSharedProperties.EndFrame();

            _cloudBlenderMaterial.SetTexture("_MainTex", currentFrame);
            _cloudBlenderMaterial.SetInt("_IsGamma", QualitySettings.activeColorSpace == ColorSpace.Gamma ? 1 : 0);
        }



    }
}