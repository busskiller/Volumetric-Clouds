Shader "Custom/Volumetric Clouds Example"
{

	Properties{
		// How many iterations we should step through space
		_Iterations("Iterations", Range(0, 200)) = 100
		// How long through space we should step
		_ViewDistance("View Distance", Range(0, 5)) = 2
		// Essentially the background color
		_SkyColor("Sky Color", Color) = (0.176, 0.478, 0.871, 1)
		// Cloud color
		_CloudColor("Cloud Color", Color) = (1, 1, 1, 1)
		// How dense our clouds should be
		_CloudDensity("Cloud Density", Range(0, 1)) = 0.5
	}

	SubShader{ 
	Pass{

	Blend SrcAlpha Zero

	CGPROGRAM
	#pragma vertex vert
	#pragma fragment frag
	#include "UnityCG.cginc"


	//Our defined global variables
	sampler2D _NoiseOffsets;
	sampler3D _PerlinWorleyNoise;
	sampler3D _WorleyNoise;

	float3 _CamPos;
	float3 _CamRight;
	float3 _CamUp;
	float3 _CamForward;

	float _AspectRatio;
	float _FieldOfView;

	//Our defined local properties
	int _Iterations;
	float3 _SkyColor;
	float4 _CloudColor;
	float _ViewDistance;
	float _CloudDensity;

	//Base input struct
	struct v2f
	{
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
	};

	//Vertex shader
	v2f vert(appdata_base v)
	{
		v2f o;
		o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
		o.uv = v.texcoord;
		return o;
	}



	///////////////////////////////////////
	///////////////////////////////////////
	///////////////////////////////////////
	//NEW CODE FROM HERE. HOPEFULLY WE CAN MAKE THIS BABY WORK.
	

	//A remapping function, that maps values from one range to another, to be used when combining noises to make our clouds
	//This function is litterally just ripped from the book. In fact, most of this code is ripped from the book.
	float Remap(float original_value, float original_min, float original_max, float new_min, float new_max)
	{
		return new_min + (((original_value - original_min)
			/ (original_max - original_min)) * (new_max - new_min));
	}
	
	//We need to figure out the density height function. I'll leave it blank for now
	//weather data is our weather texture channels. R is the Cloud Coverage, G is our Precipitation and B is our Cloud Type
	//Remember, this function is used to figure out which clouds should be drawn and so forth
	float GetDensityHeightGradientForPoint(float3 p, float3 weather_data) {
		
		float InsertDamnFunctionHere = 1;
		
		return InsertDamnFunctionHere;
	}

	//p is perhaps our current position, whilse weather_data is our weather texture
	float SampleCloudDensity(float3 p, float3 weather_data, float3 ray) 
	{
		//These two floats are wrong valued, as I have no idea what they should be. Used in "low_frequency_noises"
		float4 whereToLookInThe3DTexture = (1, 0, 0, 0);
		float mip_level = 0.6;

		//Used to read the first 3D texture, namely the PerlinWorleyNoise
		//As stated in the book, this texture consists of 1 Perlin-Worley noise & 3 Worley noise
		//In order, i think each of them is going to be stored in the color channels, that is Perlin-Worley in R, and GBA is Worley
		//float4 low_frequency_noises = tex3Dlod(_PerlinWorleyNoise, whereToLookInThe3DTexture, float4 (p, mip_level)).rgba;
		//float4 low_frequency_noises = (1, 2, 3, 4);

		float4 test = (ray, 0.0);

		float4 low_frequency_noises = tex3Dlod(_PerlinWorleyNoise, test);

		//Here we make an FBM out of the 3 worley noises found in the GBA channels of the low_frequency_noises. Again, not super sure.
		//We will be using this FBM to add detail to the low-frequency Perlin-Worley noise (the R channel)
		float low_freq_FBM = (low_frequency_noises.g * 0.625) + (low_frequency_noises.b * 0.25) + +(low_frequency_noises.a * 0.125);

		//Here we use our previously defined remap function to basically combine our "low_freq_FBM" with "low_frequency_noises"
		//We store this in what we will call our base_cloud
		float base_cloud = Remap(low_frequency_noises.r, -(1.0 - low_freq_FBM), 1.0, 0.0, 1.0);

		//We use the density height function to figure out which clouds should be drawn
		float density_height_gradient = GetDensityHeightGradientForPoint(p, weather_data);

		//Here we apply height function to our base_cloud, to get the correct cloud
		base_cloud *= density_height_gradient;


		
		//At this point, we can stop working on base_cloud, however, it is really low-detailed and stuff 
		//(basically, you are not done with it)
		//We need to apply the cloud coverage attribute from the weather texture to ensure that we can control how much clouds cover the sky

		//The cloud coverage is stored in the weather_data's R channel
		float cloud_coverage = weather_data.r;

		//Funny enough, we use the remap function to combine the cloud coverage with our base_cloud
		float base_cloud_with_coverage = Remap(base_cloud, cloud_coverage, 1.0, 0.0, 1.0);

		//We when multipy our newly mapped base_cloud with the coverage so that we get the correct coverage of different cloud types
		//An example of this, is that smaller clouds should look lighter now. Stuff like that.
		base_cloud_with_coverage *= cloud_coverage;



	}




















	/*
	float distFunc(float3 pos)
	{
		const float sphereRadius = 1;
		return length(pos) - sphereRadius;
	}

	fixed4 renderSurface(float3 pos)
	{
		const float2 eps = float2(0.0, 0.01);

		float ambientIntensity = 0.1;
		float3 lightDir = float3(0, -0.5, 0.5);

		float3 normal = normalize(float3(
			distFunc(pos + eps.yxx) - distFunc(pos - eps.yxx),
			distFunc(pos + eps.xyx) - distFunc(pos - eps.xyx),
			distFunc(pos + eps.xxy) - distFunc(pos - eps.xxy)));

		float diffuse = ambientIntensity + max(dot(-lightDir, normal), 0);

		return fixed4(diffuse, diffuse, diffuse, 1);
	}
	*/


	// Noise function by Inigo Quilez - https://www.shadertoy.com/view/4sfGzS
	float noise(float3 x) { x *= 4.0; float3 p = floor(x); float3 f = frac(x); f = f*f*(3.0 - 2.0*f); float2 uv = (p.xy + float2(37.0, 17.0)*p.z) + f.xy; float2 rg = tex2D(_NoiseOffsets, (uv + 0.5) / 256.0).yx; return lerp(rg.x, rg.y, f.z); }
    
	// This function is the actual noise function we are going to be using.
	// The more octaves you give it, the more details we'll get in our nois
	float fbm(float3 pos, int octaves) 
		{ 
			float f = 0.; for (int i = 0; i < octaves; i++) 
				
				{
					f += noise(pos) / pow(2, i + 1); pos *= 2.01; 
				}

			f /= 1 - 1 / pow(2, octaves + 1); 
			
			return f; 
	}


	//Fragment shader
	fixed4 frag(v2f i) : SV_Target
	{
		
		float2 uv = (i.uv - 0.5) * _FieldOfView;
		uv.x *= _AspectRatio;

		float3 pos = _CamPos;
		float3 ray = _CamUp * uv.y + _CamRight * uv.x + _CamForward;



		// So now we have a position, and a ray defined for our current fragment, and we know from earlier in this article that it matches the field of view and aspect ratio of the camera. 
		// And we can now start iterating and creating our clouds. 
		// We will not be ray-marching twoards any distance field in this example. So the following code should be much easier to understand.
		// pos is our original position, and p is our current position which we are going to be using later on.
		float3 p = pos;

		// For each iteration, we read from our noise function the density of our current position, and adds it to this density variable.
		float density = 0;

		for (float i = 0; i < _Iterations; i++)
		{
			// f gives a number between 0 and 1.
			// We use that to fade our clouds in and out depending on how far and close from our camera we are.
			float f = i / _Iterations;
			// And here we do just that:
			float alpha = smoothstep(0, _Iterations * 0.2, i) * (1 - f) * (1 - f);
			// Note that smoothstep here doesn't do the same as Mathf.SmoothStep() in Unity C# - which is frustrating btw. Get a grip Unity!
			// Smoothstep in shader languages interpolates between two values, given t, and returns a value between 0 and 1. 

			// To get a bit of variety in our clouds we collect two different samples for each iteration.
			float denseClouds = smoothstep(_CloudDensity, 0.75, fbm(p, 5));
			float lightClouds = (smoothstep(-0.2, 1.2, fbm(p * 2, 2)) - 0.5) * 0.5;
			// Note that I smoothstep again to tell which range of the noise we should consider clouds.

			// Here we add our result to our density variable
			density += (lightClouds + denseClouds) * alpha;
			// And then we move one step further away from the camera.
			p = pos + ray * f * _ViewDistance;
		}
		// And here i just melted all our variables together with random numbers until I had something that looked good.
		// You can try playing around with them too.
		float3 color = _SkyColor + (_CloudColor.rgb - 0.5) * (density / _Iterations) * 20 * _CloudColor.a;

		return fixed4(color, 1);















		/*
		fixed4 color = 0;

		for (int i = 0; i < 30; i++)
		{
			float d = distFunc(pos);

			if (d < 0.01)
			{
				color = renderSurface(pos);
				break;
			}

			pos += ray * d;

			if (d > 40)
			{
				break;
			}
		*/


	}

	ENDCG
	}
	}
}
