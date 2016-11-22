//***************************************************
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
Shader "Custom/P5/HorizonClouds"
{

	Properties{
		// How many iterations we should step through space
		_Iterations("Iterations", Range(0, 200)) = 100
		// How long through space we should step
		_ViewDistance("View Distance", Range(0, 5)) = 2
		// Essentially the background color
		_SkyColor("Sky Color", Color) = (0.176, 0.478, 0.871, 1)
		// Cloud color
		_CloudColor("Cloud Color", Color) = (1,1,1, 1)
		// How dense our clouds should be
		_CloudDensity("Cloud Density", Range(0, 1)) = 0.5

		_RayMinimumY("Horizon height", float) = 30
	}

	SubShader{ 
	Tags { "RenderType"="Opaque" }
	Pass{

	ZTest off Cull Off ZWrite Off

	CGPROGRAM
	#pragma vertex vert
	#pragma fragment frag
	#include "UnityCG.cginc"
	#include "VolumeCloudsCommon.cginc"

	uniform fixed4 _LightColor0;
	//uniform float4 _WorldSpaceLightPos0;
	//Our defined global variables
	sampler3D _PerlinWorleyNoise;
	sampler3D _WorleyNoise;

	sampler2D _CurlNoise;
	sampler2D _WeatherTexture;

	float3 _CamPos;
	float3 _CamRight;
	float3 _CamUp;
	float3 _CamForward;

	float _AspectRatio;
	float _FieldOfView;

	float4 _Gradient1;
	float4 _Gradient2;
	float4 _Gradient3;

	//Cloud80DefinedVariables
	float _CoverageScale;
	float _RayStepLength;

	//Our defined local properties
	int _Iterations;
	float3 _SkyColor;
	float4 _CloudColor;
	float _ViewDistance;
	float _CloudDensity;
	float _RayMinimumY;
	float _BaseScale;
	float3 _BaseOffset;

	float3 _LightDirection;
	float _HorizonCoverageStart;
	float _HorizonCoverageEnd;
	float _CoverageOffset;
	#define FLOAT4_TYPE( f)		f.b
	#define FLOAT4_COVERAGE( f)	f.r
	#define FLOAT4_RAIN( f)		f.g
	//Base input struct
	struct v2f
	{
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
		float3 cameraRay : TEXCOORD2;
	};

	//Vertex shader
	v2f vert(appdata_base v)
	{
		v2f o;
		o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
		o.uv = v.texcoord;
		o.cameraRay = UVToCameraRay( o.uv);
		return o;
	}


	///////////////////////////////////////
	///////////////////////////////////////
	///////////////////////////////////////
	//NEW CODE FROM HERE. HOPEFULLY WE CAN MAKE THIS BABY WORK.

	//A function that calculates a normalized scalar values that represents the height of the current sample position (in the cloud layer)
	//inPosition is the current ray position. However, I have no clue what inCloudMinMax is.
	//This function is used during the last steps of the cloud modelling process. Ignore for now.
	float GetHeightFractionForPoint(float3 inPosition, float2 inCloudMinMax)
	{
		// Get global fractional p0sition in cloud zone.

		float height_fraction = (inPosition.z - inCloudMinMax.x) / (inCloudMinMax.y - inCloudMinMax.x);

		return saturate(height_fraction);
	}

	//A remapping function, that maps values from one range to another, to be used when combining noises to make our clouds
	//This function is litterally just ripped from the book. In fact, most of this code is ripped from the book.
	float Remap(float original_value, float original_min, float original_max, float new_min, float new_max)
	{
		return new_min + (((original_value - original_min)
			/ (original_max - original_min)) * (new_max - new_min));
	}
	
	//Our density height function. It is called three times, as we have three gradients for the three major cloud types. It gives us a float, representing the gradient.
	//This function is called within the function "GetDensityHeightGradientForPoint". In that function, we use the weather data. More on that in a bit.
	//float a is the height of the ray, namely the y value.
	inline float DensityHeightFunction(float a, float4 gradient)
	{
		return smoothstep(gradient.x, gradient.y, a) - smoothstep(gradient.z, gradient.w, a);
	}

	//This function is used to figure out which clouds should be drawn and so forth
	//Weather data is our weather texture channels. R is the Cloud Coverage, G is our Precipitation and B is our Cloud Type
	//This function samples the B channel (Cloud type) using the ray position. 
	//The sampled valus is then used to to weight the three float returns we get from the three density height functions that it calls
	//In other words, the weighted sum of the gradients are affected by the cloud type attribute, which is found using the current ray positon
	//P is either our current ray position or current camera position!
	float GetDensityHeightGradientForPoint(float3 p, float3 weather_data) {
		
		float gradient1 = DensityHeightFunction(p.y, _Gradient1);
		float gradient2 = DensityHeightFunction(p.y, _Gradient2);
		float gradient3 = DensityHeightFunction(p.y, _Gradient3);

		//Do the weighted sum thingy here using the three gradients floats and the b channel of weather_data.
		float weightedSum = 0;

		return weightedSum;
	}

	float4 GetDensityHeightGradientScalar(float p) {
		
		float gradient1 = DensityHeightFunction(p, _Gradient1);
		float gradient2 = DensityHeightFunction(p, _Gradient2);
		float gradient3 = DensityHeightFunction(p, _Gradient3);

		//Do the weighted sum thingy here using the three gradients floats and the b channel of weather_data.
		float4 weightedSum = float4(1,gradient1,gradient2,gradient3);

		return weightedSum;
	}
	inline float Lerp3( float v0, float v1, float v2, float a)
			{
				return a < 0.5 ? lerp( v0, v1, a * 2.0) : lerp( v1, v2, (a-0.5) * 2.0);
			}
	inline float4 Lerp3( float4 v0, float4 v1, float4 v2, float a)
		{
			return float4( Lerp3( v0.x, v1.x, v2.x, a),
							Lerp3( v0.y, v1.y, v2.y, a),
							Lerp3( v0.z, v1.z, v2.z, a),
							Lerp3( v0.w, v1.w, v2.w, a));
		}
	inline float GradientStep( float a, float4 gradient)
		{
			return smoothstep( gradient.x, gradient.y, a) - smoothstep( gradient.z, gradient.w, a);
		}

				
	inline float4 SampleCoverage( float3 ray)
	{
		float2 unit = ray.xz * _CoverageScale;
		float2 uv = unit * 0.5 + 0.5;
		uv += _CoverageOffset;

		float depth = distance( ray, _CameraPosition) / _MaxDistance;
		float4 coverage = tex2Dlod(_WeatherTexture , float4( uv, 0.0, 0.0));
		return coverage;
	}

	//P is either our current ray position or current camera position! 
	float SampleCloudDensity(float3 ray) 
	{
		////
		////PART 1
		////
		//Here we  read the first 3D texture, namely the PerlinWorleyNoise
		//As stated in the book, this texture consists of 1 Perlin-Worley noise & 3 Worley noise
		//In order, i think each of them is going to be stored in the color channels, that is Perlin-Worley in R, and GBA is Worley
		//_Base scale will increase the size of the clouds _BaseScale+_BaseOffset
		float4 test = float4(ray , 0);
		float4 low_frequency_noises = tex3Dlod(_PerlinWorleyNoise, test);


		low_frequency_noises *=  GetDensityHeightGradientScalar(ray.y);



		float noise = saturate((low_frequency_noises.r + low_frequency_noises.g + low_frequency_noises.b + low_frequency_noises.a) / 4.0);
		

		//Lets sample the coverage here 
		//float2 unit = ray.xz * _CoverageScale;
		//float2 uv = unit * 0.5 + 0.5;
		////uv += _CoverageOffset;

		//float depth = distance( ray, _CameraPosition) / _MaxDistance;
		//float4 weather_data = tex2Dlod( WeatherTexture, float4( uv, 0.0, 0.0));
		float4 weather_data = SampleCoverage(ray);

		//We not create a new gradient based on our three predefined gradients and the coverage to get our cloud type
		float4 gradient = Lerp3(_Gradient3,
										_Gradient2,
										_Gradient1,
										FLOAT4_TYPE(weather_data));


		low_frequency_noises *= GradientStep(ray.y, gradient);
											
		//Before moving on, here we quickly sample the weather texture, converting it to a float3, just to get it out of the way
		//float3 weather_data = tex2Dlod(WeatherTexture, test);
		//low_frequency_noises = saturate(low_frequency_noises - (1.0 - FLOAT4_COVERAGE(weather_data))) * FLOAT4_COVERAGE(weather_data);

		//Here we make an FBM out of the 3 worley noises found in the GBA channels of the low_frequency_noises.
		//We will be using this FBM to add detail to the low-frequency Perlin-Worley noise (the R channel)
		float low_freq_FBM = (low_frequency_noises.g * 0.625) + (low_frequency_noises.b * 0.25) + +(low_frequency_noises.a * 0.125);

		//Here we use our previously defined remap function to basically combine our "low_freq_FBM" with "low_frequency_noises"
		//We store this in what we will call our base_cloud
		float base_cloud = Remap(low_frequency_noises.r, -(1.0 - low_freq_FBM), 1.0, 0.0, 1.0);

		//We use the GetDensityHeightGradientForPoint to figure out which clouds should be drawn
		float4 density_height_gradient =GradientStep(ray.y,gradient);

		//Here we apply height function to our base_cloud, to get the correct cloud
		base_cloud *= density_height_gradient;


		////
		////PART 2
		////
		//At this point, we can stop working on base_cloud, however, it is really low-detailed and stuff (basically, you are not done with it)
		//We need to apply the cloud coverage attribute from the weather texture to ensure that we can control how much clouds cover the sky
		//The cloud coverage is stored in the weather_data's R channel
		float cloud_coverage = weather_data.r;

		//Funny enough, we use the remap function to combine the cloud coverage with our base_cloud
		float base_cloud_with_coverage = Remap(base_cloud, cloud_coverage, 1.0, 0.0, 1.0);

		//We then multipy our newly mapped base_cloud with the coverage so that we get the correct coverage of different cloud types
		//An example of this, is that smaller clouds should look lighter now. Stuff like that.
		base_cloud_with_coverage *= cloud_coverage;

		//Here is return the cloud. Duh. 
		return base_cloud;


		//Final steps, namely Part 3 (There is also a super short part 4 afterwards, no biggie.) 
		//Incomplete as I cant figure out the damn mix function they use! It is also here that the curl noise comes into play!
		/*

		//Next, we finish off the cloud by adding realistic detail ranging from small billows to wispy distortions
		//We use the curl noise to distort the sample coordinate at the bottom of the clouds
		//We do this to simulate turbulence.
		
		//We get the height fraction (the position of the current sample) to use it when blending the different noises over height
		//We use this together with the FBM we'll make in a momement to transition between cloud shapes
		float inCloudMinMax = 1;
		float height_fraction = GetHeightFractionForPoint(p, inCloudMinMax);
		
		//Then we sample the curl noise...:
		float2 curl_noise = tex2Dlod(_CurlNoise, test);
		//and...  apply it to the current position
		float2 currentPosition;
		currentPosition.xy = p.xy;
		currentPosition.xy += curl_noise.xy * (1.0 - height_fraction);

		//We  build an FBM out of our high-frequency Worley noises in order to add detail to the edges of the cloud
		//First we need to sample the noise before using it to make FBM
		float3 high_frequency_noises = tex3Dlod(_WorleyNoise, test);
		//Then we make the FBM
		float high_freq_FBM = (high_frequency_noises.r * 0.625) + (high_frequency_noises.r * 0.25) + (high_frequency_noises.r * 0.125);

		//The transition magic over height happens here:
		float hight_freq_noise_modifier = mix(high_freq_FBM, 1.0 - high_freq_FBM, saturate(height_fraction * 90.0));

		*/

	}

	//Fragment shader
	fixed4 frag(v2f i) : SV_Target
	{
		fixed4 color = half4( 0.0, 0.0, 0.0, 0.0);
		float3 rayDirection = normalize( i.cameraRay);


		float2 uv = (i.uv - 0.5) * _FieldOfView;
		uv.x *= _AspectRatio;

		if( rayDirection.y > _RayMinimumY)
		{
		// So now we have a position, and a ray defined for our current fragment, that matches the field of view and aspect ratio of the camera. 
		// We can now start iterating and creating our clouds. 
		// We will not be ray-marching twoards any distance field at this point in time.
		// pos is our original position, and p is our current position which we are going to be using later on.
		// For each iteration, we read from our SampleCloudDensity function the density of our current position, and add it to this density variable.
		float cosAngle = dot( rayDirection, -_LightDirection);
		float density = SampleCloudDensity(rayDirection);
		float3 rayStep = rayDirection * _RayStepLength;
		float3 ray = InternalRaySphereIntersect(_EarthRadius + _StartHeight, _CamPos, rayDirection);
		float4 particle = float4(density,density,density,density);
		float rayStepScalar = 1.0;

		for (float i = 0; i < _Iterations; i++)
		{
			//float2 uv = i.uv;
			if(particle.a < 0){
			break;
			}
			// f gives a number between 0 and 1.
			// We use that to fade our clouds in and out depending on how far and close from our camera we are.
			float f = i / _Iterations;
			// And here we do just that:
			float alpha = smoothstep(0, _Iterations * 0.2, i) * (1 - f) * (1 - f);
			// Note that smoothstep here doesn't do the same as Mathf.SmoothStep() in Unity C# - which is frustrating btw. Get a grip Unity!
			// Smoothstep in shader languages interpolates between two values, given t, and returns a value between 0 and 1. 

			// At each iteration, we sample the density and add it to the density variable
			density += SampleCloudDensity(ray);
			particle = float4(density,density,density,density);

			if(density >0 ){
			//Optimization code we can look at that later
			if(rayStepScalar > 1){
			}
			
			}
			//What the fuck is this value? Oh Transmittance this is related to light
			float T = 1.0 -particle.a;
			// And then we move one step further away from the camera.
			//p = pos + ray * f * _ViewDistance;
			particle.rgb*= particle.a;
			//We multiply the negative alpha with the particle for god knows why
			color = (1.0 - color.a) * particle + color;
			ray += rayStep;
		}
		// And here i just melted all our variables together with random numbers until I had something that looked good.
		// You can try playing around with them too.
		//float lightColor = saturate(dot(_WorldSpaceLightPos0, p));
		color = _CloudColor * density + particle; 
		//color = _LightColor0 * _SkyColor * (_CloudColor.rgb - 0.5) * (density / _Iterations) * 20 * _CloudColor.a;
		}
		// If you reach this point, allelujah!
		return color;
	}

	ENDCG
	}
	}
}
