﻿	//***************************************************
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
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}

	SubShader{ 
	Tags { "RenderType"="Opaque" }
	Pass{

	ZTest off Cull Off ZWrite Off

	CGPROGRAM
	#pragma vertex vert
	#pragma fragment frag
	#pragma target 3.0
	#pragma exclude_renderers d3d9
	#include "UnityCG.cginc"
	#include "VolumeCloudsCommon.cginc"

	uniform fixed4 _LightColor0;

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
	float _BaseFBMScale;
	float _DetailFBMScale;

	float4 _Gradient1;
	float4 _Gradient2;
	float4 _Gradient3;

	//Our defined local properties
	int _Iterations;
	float _RayMinimumY;

	//Cloud80DefinedVariables
	float _CloudBottomFade;
	float3 _BaseOffset;
	float3 _DetailOffset;
	float2 _CoverageOffset;
	float _BaseScale;
	float _CoverageScale;
	float _HorizonFadeStartAlpha;
	float _OneMinusHorizonFadeStartAlpha;
	float _HorizonFadeScalar;					// Fades clouds on horizon, 1.0 -> 10.0 (1.0 = smooth fade, 10 = no fade)
	float3 _LightDirection;
	float3 _LightColor;
	float _LightScalar;
	float _AmbientScalar;
	float3 _CloudBaseColor;
	float3 _CloudTopColor;
	float4 _CloudHeightGradient1;				// x,y,z,w = 4 positions of a black,white,white,black gradient
	float4 _CloudHeightGradient2;				// x,y,z,w = 4 positions of a black,white,white,black gradient
	float4 _CloudHeightGradient3;				// x,y,z,w = 4 positions of a black,white,white,black gradient
	float _SunRayLength;
	float _ConeRadius;
	float _MaxIterations;
	float _MaxRayDistance;
	float _RayStepLength;
	float _SampleScalar;
	float _SampleThreshold;
	float _DetailScale;
	float _ErosionEdgeSize;
	float _CloudDistortion;
	float _CloudDistortionScale;
	float _Density;
	float _ForwardScatteringG;
	float _BackwardScatteringG;
	float _DarkOutlineScalar;
	float _HorizonCoverageStart;
	float _HorizonCoverageEnd;

	float3 _Random0;
	float3 _Random1;
	float3 _Random2;
	float3 _Random3;
	float3 _Random4;
	float3 _Random5;

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


	//A remapping function, that maps values from one range to another, to be used when combining noises to make our clouds
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
		return lerp(gradient.x, gradient.y, smoothstep(0, 1, a)) - lerp(gradient.z, gradient.w, smoothstep(0, 1, a));
	}
	
	
	inline float Lerp3(float v0, float v1, float v2, float a)
	{
		return a < 0.5 ? lerp(v0, v1, a * 2.0) : lerp(v1, v2, (a - 0.5) * 2.0);
	}

	inline float NormalizedAtmosphereY(float3 ray)
	{
		float y = length(ray) - _EarthRadius - _StartHeight;
		return y / _AtmosphereThickness;
	}


	//This function is used to figure out which clouds should be drawn and so forth
	//Weather data is our weather texture channels. R is the Cloud Coverage, G is our Precipitation and B is our Cloud Type
	//This function samples the B channel (Cloud type) using the ray position. 
	//The sampled valus is then used to to weight the three float returns we get from the three density height functions that it calls
	//In other words, the weighted sum of the gradients are affected by the cloud type attribute, which is found using the current ray positon
	//P is either our current ray position or current camera position!
	float GetDensityHeightGradientForPoint(float3 p, float3 weather_data) {
		float height = NormalizedAtmosphereY(p);
		float gradient1 = DensityHeightFunction(p.y, _Gradient1);
		float gradient2 = DensityHeightFunction(p.y, _Gradient2);
		float gradient3 = DensityHeightFunction(p.y, _Gradient3);

		//float density1 = p.y
		//float weightedSum  = FLOAT4_TYPE(weather_data) * FLOAT4_TYPE(weather_data);
		float weightedSum = length(float4(FLOAT4_TYPE(weather_data), gradient3, gradient2, gradient1));// *1 - height;
		//float weightedSum = (gradient1 + gradient2 + gradient3) * FLOAT4_TYPE(weather_data);
		//float weightedSum = FLOAT4_TYPE(weather_data) < 0.5 ? lerp( v0, v1, FLOAT4_TYPE(weather_data) * 2.0) : lerp( v1, v2, (FLOAT4_TYPE(weather_data)-0.5) * 2.0);
		//Do the weighted sum thingy here using the three gradients floats and the b channel of weather_data.
		//float weightedSum = weightedSum;

		float a = gradient1 + 1.0f - saturate(FLOAT4_TYPE(weather_data) / 0.5f);
		float b = gradient2 + 1.0f - abs(FLOAT4_TYPE(weather_data) - 0.5f) * 2.0f;
		float c = gradient3 + saturate(FLOAT4_TYPE(weather_data) - 0.5f) * 2.0f;
		
		//return Lerp3(a,b,c ,FLOAT4_TYPE(weather_data));
		return saturate(weightedSum);

	}

	//This function is used to sample the weather texture based on the ray position				
	inline float4 SampleWeatherTexture( float3 ray)
	{
		float2 unit = ray.xz * _CoverageScale;
		float2 uv = unit * 0.5 + 0.5;
		uv += _CoverageOffset;
		float depth = distance( ray, _CameraPosition) / _MaxDistance;

		float4 coverageB = float4( 1.0, 0.0, 0.0, 0.0);
		//coverageB.b = saturate( smoothstep( _HorizonCoverageEnd, _HorizonCoverageStart, depth) * 2.0);
		float alpha = smoothstep( _HorizonCoverageStart, _HorizonCoverageEnd, depth);
		float4 coverage = tex2Dlod( _WeatherTexture, float4( uv, 0.0, 0.0));
		//return coverage;

		coverageB = float4( smoothstep( _HorizonCoverageStart, _HorizonCoverageEnd, depth),
						0.0,
						smoothstep( _HorizonCoverageEnd, _HorizonCoverageStart + (_HorizonCoverageEnd - _HorizonCoverageStart) * 0.5, depth),
						0.0);

		return lerp( coverage, coverageB, alpha);
	}
	
	//We use this function to transtiion between different cloud shapes by lerping all over the place!
	inline float mix(float4 lowFreqNoise,float4 neglowFreqNoise, float a){
		float mixValueR =  lerp(lowFreqNoise.r,neglowFreqNoise.r, smoothstep(0,1,a));
		float mixValueG =  lerp(lowFreqNoise.g,neglowFreqNoise.g, smoothstep(0,1,a));
		float mixValueB =  lerp(lowFreqNoise.b,neglowFreqNoise.b, smoothstep(0,1,a));
		float mixValueA =  lerp(lowFreqNoise.a,neglowFreqNoise.a, smoothstep(0,1,a));
		float sum = mixValueR +mixValueG+mixValueB+mixValueA/4;
		return sum;
	}

	//The main cloud moddeling function, where many of the above mentioned functions come into play
	float SampleCloudDensity(float3 ray, float4 weather_data, float csRayHeight) 
	{
		//Here we  read the first 3D texture, namely the PerlinWorleyNoise. As stated in the articel, this texture consists of 1 Perlin-Worley noise & 3 Worley noise
		//In order, each of them is going to be stored in the color channels, that is Perlin-Worley in R, and GBA is Worley
		//_Base scale will increase the size of the clouds _BaseScale+_BaseOffset
		//We have to multiply by base scale as the texture we are looking into is huge simply using the ray coordinates as a lookup
		//Will result in sampling the same area of all pixels, ergo we end up with one giant cloud in the sky
		float4 samplingPos = float4(ray  * _BaseScale + _BaseOffset, 0);
		float2 inCloudMinMax = float2(_StartHeight, _EndHeight);
		float4 low_frequency_noises = tex3Dlod(_PerlinWorleyNoise, samplingPos).rgba;

		//Here we make an FBM out of the 3 worley noises found in the GBA channels of the low_frequency_noises.
		//We will be using this FBM to add detail to the low-frequency Perlin-Worley noise (the R channel)
		float low_freq_FBM = (low_frequency_noises.g * 0.625) + (low_frequency_noises.b * 0.25) + +(low_frequency_noises.a * 0.125);

		//Here we use our previously defined remap function to basically combine our "low_freq_FBM" with "low_frequency_noises"
		//We store this in what we will call our base_cloud
		float base_cloud = Remap(low_frequency_noises.r, -low_freq_FBM*_BaseFBMScale, 1.0, 0.0, 1.0);

		//We use the GetDensityHeightGradientForPoint to figure out which clouds should be drawn
		float4 density_height_gradient = GetDensityHeightGradientForPoint(ray,weather_data);

		//Here we apply height function to our base_cloud, to get the correct cloud
		base_cloud *= density_height_gradient;

		//At this point, we can stop working on base_cloud, however, it is really low-detailed and stuff (basically, you are not done with it!)
		//We need to apply the cloud coverage attribute from the weather texture to ensure that we can control how much clouds cover the sky
		//The cloud coverage is stored in the weather_data's R channel
		float cloud_coverage = weather_data.r;

		//Funny enough, we use the remap function to combine the cloud coverage with our base_cloud
		float coverageModifier = cloud_coverage;
		float base_cloud_with_coverage = Remap(base_cloud, coverageModifier, 1.0, 0.0, 1.0);


		//We then multipy our newly mapped base_cloud with the coverage so that we get the correct coverage of different cloud types
		//An example of this, is that smaller clouds should look lighter now. Stuff like that.
		//base_cloud_with_coverage *= cloud_coverage;
		//return base_cloud_with_coverage;


		//Next, we finish off the cloud by adding realistic detail ranging from small billows to wispy distortions
		//We use the curl noise to distort the sample coordinate at the bottom of the clouds. We do this to simulate turbulence.	
		//We will then use our mix function to transition between cloud shapes
		//First, sample the curl noise and apply it to the current position
		float2 curl_noise = tex2Dlod(_CurlNoise, samplingPos);
		ray.xy += curl_noise.xy * (1.0 - smoothstep(0,1,csRayHeight));

		//We then build an FBM out of our high-frequency Worley noises in order to add detail to the edges of the cloud
		//First we need to sample our noise before using it to make FBM
		float3 high_frequency_noises = tex3Dlod(_WorleyNoise, float4(ray*_BaseScale *_DetailScale + _DetailOffset, 0)).rgb;
		float high_freq_FBM = (high_frequency_noises.r * 0.625) + (high_frequency_noises.g * 0.25) + (high_frequency_noises.b * 0.125);

		//The transition magic over height happens here using our predifined mix function
		float high_freq_noise_modifier = mix(high_freq_FBM, 1.0 - high_freq_FBM,saturate(csRayHeight * 10));

		//Here we remap our cloud with the high_freq_noise_modifier
		float final_cloud = Remap(base_cloud_with_coverage, high_freq_noise_modifier*_DetailFBMScale, 1.0 , 0.0 , 1.0) ;
		
		//return the final cloud!
		return final_cloud * _SampleScalar * smoothstep(0.0, _CloudBottomFade * 1.0, csRayHeight);

	}



	//Ligthing magic - courtesy of our lord and saviour, K80

	//Beer’s law models the attenuation of light as it passes through a material. In our case, the clouds.
	inline float BeerTerm(float densityAtSample)
	{
		return exp(-_Density * densityAtSample);
	}

	//Used to increase probability of light scattering forward, to create the silver lining seen in clouds
	float HenyeyGreensteinPhase(float cosAngle, float g)
	{
		float g2 = g * g;
		return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosAngle, 1.5);
	}

	//In-Scattering Probability Function (Powdered Sugar Effect)
	inline float PowderTerm(float densityAtSample, float cosTheta)
	{
		float powder = 1.0 - exp(-_Density * densityAtSample * 2.0);
		float beers = 0.5;//exp(densityAtSample);
		
		//powder = saturate(powder * _DarkOutlineScalar * 2.0);
		
		//return lerp(1.0, powder, smoothstep(0.5, -0.5, cosTheta));

		float sunlight = 2.0 * powder * beers;
		
		return sunlight;
		//return lerp(1.0, sunlight, smoothstep(0.5, -0.5, cosTheta));
	}

	//Were all the magic happens. This is ommited from the book. Genious. Again, K80 to the rescue
	inline float3 SampleLight(float3 origin, float originDensity, float pixelAlpha, float3 cosAngle, float2 debugUV, float rayDistance, float3 RandomUnitSphere[6])
	{
		const float iterations = 5.0;

		float3 rayStep = -_LightDirection * (_SunRayLength / iterations);
		float3 ray = origin + rayStep;

		float atmosphereY = 0.0;

		float lod = step(0.3, originDensity) * 3.0;
		lod = 0.0;

		float value = 0.0;

		float4 coverage;

		float3 randomOffset = float3(0.0, 0.0, 0.0);
		float coneRadius = 0.0;
		const float coneStep = _ConeRadius / iterations;
		float energy = 0.0;

		float thickness = 0.0;

		for (float i = 0.0; i<iterations; i++)
		{
			randomOffset = RandomUnitSphere[i] * coneRadius;
			ray += rayStep;
			atmosphereY = NormalizedAtmosphereY(ray);

			coverage = SampleWeatherTexture(ray + randomOffset);
			value = SampleCloudDensity(ray + randomOffset, coverage, atmosphereY);
			value *= float(atmosphereY <= 1.0);

			thickness += value;

			coneRadius += coneStep;
		}

		float far = 8.0;
		ray += rayStep * far;
		atmosphereY = NormalizedAtmosphereY(ray);
		coverage = SampleWeatherTexture(ray);
		value = SampleCloudDensity(ray, coverage, atmosphereY);
		value *= float(atmosphereY <= 1.0);
		thickness += value;


		float forwardP = HenyeyGreensteinPhase(cosAngle, _ForwardScatteringG);
		float backwardsP = HenyeyGreensteinPhase(cosAngle, _BackwardScatteringG);
		float P = (forwardP + backwardsP) / 2.0;

		return _LightColor * BeerTerm(thickness) * PowderTerm(originDensity, cosAngle) * P;
	}

	//Function used to sample the ambient light - which we sort of fake by using two color variables (representing the color of our cloud) over height (our atmosphere)
	inline float3 SampleAmbientLight(float atmosphereY, float depth)
	{
		return lerp(_CloudBaseColor, _CloudTopColor, atmosphereY);
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

			float transmittance = 1.0;

			float3 ray = InternalRaySphereIntersect(_EarthRadius + _StartHeight, _CameraPosition, rayDirection);
			float3 rayStep = rayDirection * _RayStepLength;

			float atmosphereY = 0.0;
			float rayStepScalar = 1.0;

			float cosAngle = dot(rayDirection, -_LightDirection);

			float zeroThreshold = 4.0;
			float zeroAccumulator = 0.0;

			const float3 RandomUnitSphere[6] = { _Random0, _Random1, _Random2, _Random3, _Random4, _Random5 }; ///

			float density = 1;

			for (float i = 0; i < _MaxIterations; i++)
			{
				//float2 uv = i.uv;
				if(color.a >= 1){
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
				float4 coverage = SampleWeatherTexture(ray);
				density = SampleCloudDensity(ray, coverage, atmosphereY);
				float4 particle = float4(density,density,density,density);

				if(density >0.0 )
				{
					zeroAccumulator = 0;
					//Optimization code we can look at that later
					if( rayStepScalar > 1.0)
					{
						ray -= rayStep * rayStepScalar;
						i -= rayStepScalar;

						float atmosphereY = NormalizedAtmosphereY( ray);
						coverage = SampleWeatherTexture(ray);
						density = SampleCloudDensity( ray, coverage, atmosphereY);
						particle = float4( density, density, density, density);
					}

					float T = 1.0 - particle.a;
					transmittance *= T;


					float dummy = 0;
					float3 ambientLight = SampleAmbientLight(atmosphereY, dummy);
					float3 sunLight = SampleLight(ray, particle.a, color.a, cosAngle, uv, dummy, RandomUnitSphere);

					sunLight *= _LightScalar;
					ambientLight *= _AmbientScalar;
					
					particle.rgb = sunLight + ambientLight;
					particle.a = 1.0 - T * transmittance;

		
					//float ambientLight =  lerp(_CloudBaseColor, _CloudTopColor, atmosphereY);
					
					float bottomShade = atmosphereY;
					float topShade = saturate(particle.y) ;
					
					particle.rgb*= particle.a;
					

					//We multiply the negative alpha with the particle for god knows why
					//color.rgb
					color = (1.0 - color.a) * particle + color ;
					// And then we move one step further away from the camera.
				}

				zeroAccumulator += float( density <= 0.0);
				rayStepScalar = 1.0 + step( zeroThreshold, zeroAccumulator) * 0.0;
				i += rayStepScalar;
				ray += rayStep* rayStepScalar;
				atmosphereY = NormalizedAtmosphereY( ray);

			}
			//color*= alpha;
			float fade = smoothstep(_RayMinimumY,
				_RayMinimumY + (1.0 - _RayMinimumY) * _HorizonFadeScalar,
				rayDirection.y);
			color *= _HorizonFadeStartAlpha + fade * _OneMinusHorizonFadeStartAlpha;
		}
		// If you reach this point, allelujah!

		return color;
	}

	ENDCG
	}
	}
}
