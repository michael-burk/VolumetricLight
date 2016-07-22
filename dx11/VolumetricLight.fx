//@author: vux
//@help: standard constant shader
//@tags: color
//@credits: 
float3 camPos;
float3 lightDir;
float3 lightCamPos;
static const float G_SCATTERING = -.3;
static const float PI = 3.14159265f;
int NB_STEPS = 10;

struct vsInput
{
    float4 posObject : POSITION;
	float4 uv: TEXCOORD0;
};

struct psInput
{
    float4 posScreen : SV_Position;
    float4 uv: TEXCOORD0;
	float3 PosW: TEXCOORD1;
	float3 LightDirW: TEXCOORD2;
};

Texture2D inputTexture <string uiname="Texture";>;
Texture2D shadowMap <string uiname="shadowMap";>;
Texture2D worldPosMap <string uiname="worldPosMap";>;
Texture2D noiseTex <string uiname="noise";>;

SamplerState linearSampler <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = BORDER;
    AddressV = BORDER;
};

cbuffer cbPerDraw : register(b0)
{
	float4x4 tVP : VIEWPROJECTION;
	float4x4 shadowVP;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	float Alpha <float uimin=0.0; float uimax=1.0;> = 1; 
	float4 cAmb <bool color=true;String uiname="Color";> = { 1.0f,1.0f,1.0f,1.0f };
	float4x4 tColor <string uiname="Color Transform";>;
};

cbuffer cbTextureData : register(b2)
{
	float4x4 tTex <string uiname="Texture Transform"; bool uvspace=true; >;
};


psInput VS(vsInput input)
{
	psInput output;
	output.posScreen = mul(input.posObject,mul(tW,tVP));
	output.uv = mul(input.uv, tTex);
	output.PosW = mul(input.posObject, tW);

	//inverse light direction in view space
    output.LightDirW = normalize(lightCamPos - output.PosW);
	return output;
}

	// Mie scaterring approximated with Henyey-Greenstein phase function.
	float ComputeScattering(float lightDotView)
	{
	float result = 1.0f - G_SCATTERING;
	result *= result;
	result /= (4.0f * PI * pow(1.0f + G_SCATTERING * G_SCATTERING - (2.0f * G_SCATTERING) * lightDotView, 1.5f));
	return result;
	}
 

float4 PS(psInput input): SV_Target
{

	//float3 worldPos = getWorldPosition(input.uv);
	float3 startPosition = camPos;
	
	float3 endRayPosition = input.PosW.xyz;

	float3 rayVector = endRayPosition - startPosition;

	
	float rayLength = length(rayVector);
	float3 rayDirection = rayVector / rayLength;
	
	float stepLength = rayLength / NB_STEPS;
	 
	float3 step1 = rayDirection * stepLength;
	
	startPosition += step1 * noiseTex.Sample(linearSampler,input.uv);
	
	float3 currentPosition = startPosition;
	 
	float3 accumFog = 0.0f.xxx;
	float shadowMapValue;
	
	for (int i = 0; i < NB_STEPS; i++)
	{
	float4 worldInShadowCameraSpace = mul(float4(currentPosition, 1.0f), shadowVP);
	worldInShadowCameraSpace /= worldInShadowCameraSpace.w;
	 //input.posScreen.xy
	//worldInShadowCameraSpace.xy
	shadowMapValue = shadowMap.Sample(linearSampler,float2(worldInShadowCameraSpace.x+1,-worldInShadowCameraSpace.y+1)*.5).r;
	 
	if (shadowMapValue > worldInShadowCameraSpace.z)
	{
//	accumFog += ComputeScattering(dot(rayDirection, lightDir)).xxx*10;
	accumFog += ComputeScattering(dot(rayDirection, lightDir)).xxx* pow(rayLength,.6);	
//accumFog += 1 * cAmb * rayLength*.02;
//	accumFog += 1;

	}
	currentPosition += step1;
	}
	accumFog /= NB_STEPS;
	
	return float4(accumFog,1);
	//return input.posScreen.x*.001;

}

technique11 Constant <string noTexCdFallback="ConstantNoTexture"; >
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}





