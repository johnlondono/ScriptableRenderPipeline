Shader "Hidden/VFX_0"
{
	SubShader
	{
		Pass
		{
			Tags { "LightMode" = "Deferred" }
			ZTest LEqual
			ZWrite On
			Cull Off
			
			CGPROGRAM
			#pragma target 5.0
			
			#pragma vertex vert
			#pragma fragment frag
			
			#define VFX_LOCAL_SPACE
			
			#include "UnityCG.cginc"
			#include "UnityStandardUtils.cginc"
			#include "HLSLSupport.cginc"
			#include "..\VFXCommon.cginc"
			
			CBUFFER_START(outputUniforms)
				float3 outputUniform0;
				float outputUniform1;
				float outputUniform2;
			CBUFFER_END
			
			struct Attribute1
			{
				float3 position;
				float _PADDING_;
			};
			
			struct Attribute2
			{
				float2 size;
			};
			
			StructuredBuffer<Attribute1> attribBuffer1;
			StructuredBuffer<Attribute2> attribBuffer2;
			StructuredBuffer<int> flags;
			
			struct ps_input
			{
				linear noperspective centroid float4 pos : SV_POSITION;
				nointerpolation float4 col : SV_Target0;
				float2 offsets : TEXCOORD0;
				nointerpolation float size : TEXCORRD1;
			};
			
			void VFXBlockSetColorConstant( inout float3 color,float3 Color)
			{
				color = Color;
			}
			
			ps_input vert (uint id : SV_VertexID, uint instanceID : SV_InstanceID)
			{
				ps_input o;
				uint index = (id >> 2) + instanceID * 16384;
				if (flags[index] == 1)
				{
					Attribute1 attrib1 = attribBuffer1[index];
					Attribute2 attrib2 = attribBuffer2[index];
					
					float3 local_color = (float3)0;
					
					VFXBlockSetColorConstant( local_color,outputUniform0);
					
					float2 size = attrib2.size * 0.5f;
					o.offsets.x = 2.0 * float(id & 1) - 1.0;
					o.offsets.y = 2.0 * float((id & 2) >> 1) - 1.0;
					
					float3 position = attrib1.position;
					
					float4x4 cameraMat = VFXCameraMatrix();
					float camDist = dot(cameraMat[2].xyz,position - VFXCameraPos());
					float scale = 1.0f - size.x / camDist;
					position += cameraMat[0].xyz * (o.offsets.x * size.x) * scale;
					position += cameraMat[1].xyz * (o.offsets.y * size.y) * scale;
					position += -cameraMat[2].xyz * size.x;
					
					o.size = size;
					o.pos = mul (UNITY_MATRIX_MVP, float4(position,1.0f));
					o.col = float4(local_color.xyz,0.5);
				}
				else
				{
					o.pos = -1.0;
					o.col = 0;
				}
				
				return o;
			}
			
			struct ps_output
			{
				float4 col : SV_Target0;
				float4 spec_smoothness : SV_Target1;
				float4 normal : SV_Target2;
				float4 emission : SV_Target3;
				float depth : SV_DepthLessEqual;
			};
			
			ps_output frag (ps_input i)
			{
				ps_output o = (ps_output)0;
				
				float4 color = i.col;
				float lsqr = dot(i.offsets, i.offsets);
				if (lsqr > 1.0)
					discard;
				
				float nDepthOffset = 1.0f - sqrt(1.0f - lsqr); // normalized depth offset
				float depth = DECODE_EYEDEPTH(i.pos.z) + nDepthOffset * i.size;
				o.depth = (1.0f - depth * _ZBufferParams.w) / (depth * _ZBufferParams.z);
				float3 specColor = (float3)0;
				float oneMinusReflectivity = 0;
				float metalness = saturate(outputUniform1);
				color.rgb = DiffuseAndSpecularFromMetallic(color.rgb,metalness,specColor,oneMinusReflectivity);
				color.a = 0.0f;
				float3 normal = float3(i.offsets.x,i.offsets.y,nDepthOffset - 1.0f);
				o.spec_smoothness = float4(specColor,outputUniform2);
				o.normal = mul(unity_CameraToWorld, float4(normal,0.0f)) * 0.5f + 0.5f;
				half3 ambient = color.xyz * 0.0f;//ShadeSHPerPixel(normal, float4(color.xyz, 1) * 0.1, float3(0, 0, 0));
				o.emission = float4(ambient, 0);
				
				o.col = color;
				return o;
			}
			
			ENDCG
		}
	}
	FallBack Off
}
