// Compiled shader for PC, Mac & Linux Standalone, uncompressed size: 1.0KB

// Skipping shader variants that would not be included into build of current scene.

Shader "Custom/HorizonClouds" {
Properties {
 _Iterations ("Iterations", Range(0.000000,200.000000)) = 100.000000
 _ViewDistance ("View Distance", Range(0.000000,5.000000)) = 2.000000
 _SkyColor ("Sky Color", Color) = (0.176000,0.478000,0.871000,1.000000)
 _CloudColor ("Cloud Color", Color) = (1.000000,1.000000,1.000000,1.000000)
 _CloudDensity ("Cloud Density", Range(0.000000,1.000000)) = 0.500000
 _RayMinimumY ("Horizon height", Float) = 30.000000
}
SubShader { 
 Pass {
  ZTest False
  ZWrite Off
  Cull Off
  GpuProgramID 13348
Program "vp" {
// Platform d3d9 had shader errors
//   <no keywords>
// Platform d3d11 had shader errors
//   <no keywords>
// Platform d3d11_9x had shader errors
//   <no keywords>
}
Program "fp" {
// Platform d3d9 skipped due to earlier errors
// Platform d3d11 skipped due to earlier errors
// Platform d3d11_9x skipped due to earlier errors
// Platform d3d9 had shader errors
//   <no keywords>
// Platform d3d11 had shader errors
//   <no keywords>
// Platform d3d11_9x had shader errors
//   <no keywords>
}
 }
}
}