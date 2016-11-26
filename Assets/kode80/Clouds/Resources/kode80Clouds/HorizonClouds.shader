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

	//Our defined local properties
	int _Iterations;
	float3 _SkyColor;
	float4 _CloudColor;
	float _ViewDistance;
	float _CloudDensity;
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
		return lerp(gradient.x, gradient.y, smoothstep(0, 1, a)) - lerp(gradient.z, gradient.w, smoothstep(0, 1, a));
	}
	inline float Lerp3(float v0, float v1, float v2, float a)
	{
		return a < 0.5 ? lerp(v0, v1, a * 2.0) : lerp(v1, v2, (a - 0.5) * 2.0);
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

		//float weightedSum  = Lerp3(gradient1,gradient2,gradient3,FLOAT4_TYPE(weather_data));
		float weightedSum = length(float4(FLOAT4_TYPE(weather_data),gradient1,gradient2,gradient3));
		//float weightedSum = (gradient1 + gradient2 + gradient3) * FLOAT4_TYPE(weather_data);
		//float weightedSum = FLOAT4_TYPE(weather_data) < 0.5 ? lerp( v0, v1, FLOAT4_TYPE(weather_data) * 2.0) : lerp( v1, v2, (FLOAT4_TYPE(weather_data)-0.5) * 2.0);
		//Do the weighted sum thingy here using the three gradients floats and the b channel of weather_data.
		//float weightedSum = 1;

		return weightedSum;
	}

					
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
	
	inline float mix(float4 lowFreqNoise,float4 neglowFreqNoise, float a){
		return sum;
	}


	//P is either our current ray position or current camera position! 
	float SampleCloudDensity(float3 ray, float4 weather_data, float csRayHeight) 
	{
		//Here we  read the first 3D texture, namely the PerlinWorleyNoise. As stated in the book, this texture consists of 1 Perlin-Worley noise & 3 Worley noise
		//In order, i think each of them is going to be stored in the color channels, that is Perlin-Worley in R, and GBA is Worley
		//_Base scale will increase the size of the clouds _BaseScale+_BaseOffset
		//We have to multiply by base scale as the texture we are looking into is huge simply using the ray coordinates as a lookup
		//Will result in sampling the same area of a for all pixels, ergo we end up with one giant cloud in the sky
		

		//WIND DIRECTION START
		ray = ray * _BaseScale + _BaseOffset;
		
		float4 test = float4(ray, 0);
		float2 inCloudMinMax = float2 (10, 4);
		//float2 inCloudMinMax = ray.xy;
		float height_fraction = GetHeightFractionForPoint(test, inCloudMinMax);


		float3 wind_direction = float3 (1.0, 0.0, 0.0);
		float cloud_speed = 10.0;

		float cloud_top_offset = 500.0;
		
		ray += height_fraction * wind_direction * cloud_top_offset;
		ray += (wind_direction + float3(0.0, 0.1, 0.0)) * 30 * cloud_speed;


		test = float4(ray, 0);
		//WIND DIRECTION STOP


		float4 low_frequency_noises = tex3Dlod(_PerlinWorleyNoise, test).rgba;

		//Here we make an FBM out of the 3 worley noises found in the GBA channels of the low_frequency_noises.
		//We will be using this FBM to add detail to the low-frequency Perlin-Worley noise (the R channel)
		float low_freq_FBM = (low_frequency_noises.g * 0.625) + (low_frequency_noises.b * 0.25) + +(low_frequency_noises.a * 0.125);

		//Here we use our previously defined remap function to basically combine our "low_freq_FBM" with "low_frequency_noises"
		//We store this in what we will call our base_cloud
		float base_cloud = Remap(low_frequency_noises.r, -(1.0 - low_freq_FBM), 1.0, 0.0, 1.0);

		//We use the GetDensityHeightGradientForPoint to figure out which clouds should be drawn
		float4 density_height_gradient =  GetDensityHeightGradientForPoint(test,weather_data);  //GradientStep(csRayHeight,gradient);

		//Here we apply height function to our base_cloud, to get the correct cloud
		base_cloud *= density_height_gradient;



		//At this point, we can stop working on base_cloud, however, it is really low-detailed and stuff (basically, you are not done with it)
		//We need to apply the cloud coverage attribute from the weather texture to ensure that we can control how much clouds cover the sky
		//The cloud coverage is stored in the weather_data's R channel
		float cloud_coverage = weather_data.r;

		//Funny enough, we use the remap function to combine the cloud coverage with our base_cloud
		float base_cloud_with_coverage = Remap(base_cloud, cloud_coverage, 1.0, 0.0, 1.0);

		//We then multipy our newly mapped base_cloud with the coverage so that we get the correct coverage of different cloud types
		//An example of this, is that smaller clouds should look lighter now. Stuff like that.
		//base_cloud_with_coverage *= cloud_coverage;

		//return base_cloud_with_coverage;


		
		//Final steps, namely Part 3 (There is also a super short part 4 afterwards, no biggie.) 		

		//Next, we finish off the cloud by adding realistic detail ranging from small billows to wispy distortions
		//We use the curl noise to distort the sample coordinate at the bottom of the clouds
		//We do this to simulate turbulence.
		
		//We get the height fraction (the position of the current sample) to use it when blending the different noises over height
		//We use this together with the FBM we'll make in a momement to transition between cloud shapes
		//float2 inCloudMinMax = ray.xy;
		//float height_fraction = GetHeightFractionForPoint(test, inCloudMinMax);
		
		//Then we sample the curl noise...:
		float2 curl_noise = tex2Dlod(_CurlNoise, test);

		//coord = float4(ray * _BaseScale * _DetailScale, 0.0);
		//coord.xyz += _DetailOffset;
		//and...  apply it to the current position
		float2 currentPosition;
		currentPosition.xy = ray.xy;
		currentPosition.xy += curl_noise.xy * (1.0 - height_fraction);

		//We  build an FBM out of our high-frequency Worley noises in order to add detail to the edges of the cloud
		//First we need to sample the noise before using it to make FBM
		float3 high_frequency_noises = tex3Dlod(_WorleyNoise, test*0.5).rgb;
		
		//Then we make the FBM
		float high_freq_FBM = (high_frequency_noises.r * 0.625) + (high_frequency_noises.g * 0.25) + (high_frequency_noises.b * 0.125);

		//The transition magic over height happens here:
		float high_freq_noise_modifier = mix(high_freq_FBM, 1.0 - high_freq_FBM, saturate(height_fraction * 10));

		//float final_cloud = base_cloud_with_coverage + high_freq_FBM* high_freq_noise_modifier* 0.2;
		float final_cloud = Remap(base_cloud_with_coverage, high_freq_noise_modifier*0.2 , 1.0 , 0.0 , 1.0) ;
		
		//return base_cloud_with_coverage;
		return final_cloud;


	}


	inline float NormalizedAtmosphereY( float3 ray)
		{
			float y = length( ray) - _EarthRadius - _StartHeight;
			return y / _AtmosphereThickness;
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
			float density = 1;
			float3 rayStep = rayDirection * _RayStepLength;
			float3 ray = InternalRaySphereIntersect(_EarthRadius + _StartHeight, _CameraPosition, rayDirection);
			//float4 particle = float4(density,density,density,density);
			float atmosphereY = 0.0;
			float rayStepScalar = 1.0;
			float zeroThreshold = 4.0;
			float zeroAccumulator = 0.0;
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
						coverage = SampleWeatherTexture( ray);
						density = SampleCloudDensity( ray, coverage, atmosphereY);
						particle = float4( density, density, density, density);
					}

					
					float T = 1.0 -particle.a;
					//p = pos + ray * f * _ViewDistance;
					particle.a = 1.0- T;
					float bottomShade =  atmosphereY;
					float topShade = particle.y;//saturate(particle.y) ;
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
				// And here i just melted all our variables together with random numbers until I had something that looked good.
				// You can try playing around with them too.
				//float lightColor = saturate(dot(_WorldSpaceLightPos0, p));
				//color = _CloudColor * density + particle; 
				//color = _LightColor0 * _SkyColor * (_CloudColor.rgb - 0.5) * (density / _Iterations) * 20 * _CloudColor.a;
			}
			//color*= alpha;
		}
		// If you reach this point, allelujah!
		return color;
	}

	ENDCG
	}
	}
}
