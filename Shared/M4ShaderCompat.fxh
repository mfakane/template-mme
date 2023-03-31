/*
 * M4ShaderCompat.fxh: MME / MMM 互換レイヤ
 */

#ifdef MIKUMIKUMOVING

int   voffset   : VERTEXINDEXOFFSET;
float EdgeWidth : EDGEWIDTH;

#define ADDINGSPHERETEXTURE ADDINGSPHERE
#define MULTIPLYINGSPHERETEXTURE MULTIPLYINGSPHERE

#define Compat_SkinnedPosition(IN) MMM_SkinnedPosition(IN.Pos, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1)
#define Compat_SkinnedPositionNormal(IN) MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1)
#define Compat_LightAt(Array, Index) Array[Index]

float4 Compat_GetSelfShadowUV(float4 Position, float4x4 WorldMatrix, float4x4 LightWorldViewProjMatrix, float3 LightPosition, float LightZFar)
{
    float4 dPos = mul(Position, WorldMatrix);
    float4 UV = mul(dPos, LightWorldViewProjMatrix);

    UV.y = -UV.y;
    UV.z = length(LightPosition - Position.xyz) - LightZFar;

    return UV;
}

#else

// MMD のシャドウバッファ
sampler __ShadowSampler : register(s0);

struct MMM_SKINNING_INPUT
{
    float4 Pos    : POSITION;
    float2 Tex    : TEXCOORD0;
    float4 AddUV1 : TEXCOORD1;
    float4 AddUV2 : TEXCOORD2;
    float4 AddUV3 : TEXCOORD3;
    float3 Normal : NORMAL;
    int    Index  : _INDEX;
};

struct MMM_SKINNING_OUTPUT
{
    float4 Position;
    float2 __Reserved_Tex;
    float3 Normal;
};

const int   voffset = 0;
const float EdgeWidth = 1;
const bool  MMM_IsDinamicProjection = false;
bool parthf; // パースペクティブフラグ

float4x4 __LIGHTWVPMATRICES0    : WORLDVIEWPROJECTION < string Object = "Light"; >;
float3   __LIGHTDIRECTIONS0     : DIRECTION < string Object = "Light"; >;
float3   __LIGHTDIFFUSECOLORS0  : DIFFUSE < string Object = "Light"; >;
float3   __LIGHTAMBIENTCOLORS0  : AMBIENT < string Object = "Light"; >;
float3   __LIGHTSPECULARCOLORS0 : SPECULAR < string Object = "Light"; >;
float3   __LIGHTPOSITIONS0      : POSITION < string Object = "Light"; >;
static bool  __LIGHTENABLES0 = true;
static float __LIGHTZFARS0 = 1;

#define MMM_LightCount 1

// MMD に最適化するための定数
#define SKII1 1500
#define SKII2 8000
#define Toon 3

#define ADDINGSPHERE ADDINGSPHERETEXTURE
#define MULTIPLYINGSPHERE MULTIPLYINGSPHERETEXTURE

#define Compat_SkinnedPosition(IN) (IN.Pos)
#define Compat_LightArrayValue(MMMSemantic) { __##MMMSemantic##0 }
#define Compat_LightAt(Array, Index) Array[0]
#define MMM_DynamicFov(ProjMatrix, Length) (ProjMatrix)

MMM_SKINNING_OUTPUT Compat_SkinnedPositionNormal(MMM_SKINNING_INPUT IN)
{
    MMM_SKINNING_OUTPUT SkinOut = (MMM_SKINNING_OUTPUT)0;
    SkinOut.Position = IN.Pos;
    SkinOut.Normal = IN.Normal;
    return SkinOut;
}

float MMD_GetSelfShadowValue(float3 Normal, float4 ZCalcTex, uniform bool isPerspective)
{
    ZCalcTex /= ZCalcTex.w;
    float2 TransTexCoord = 0.5 + ZCalcTex.xy * float2(0.5, -0.5);

    if (any(saturate(TransTexCoord) != TransTexCoord))
    {
        // シャドウバッファ外
        return 1;
    }
    else
    {
        float comp = max(ZCalcTex.z - tex2D(__ShadowSampler, TransTexCoord).r, 0.0f);

        if (isPerspective)
        {
            // セルフシャドウ mode2
            comp *= SKII2 * TransTexCoord.y - 0.3f;
        }
        else
        {
            // セルフシャドウ mode1
            comp *= SKII1 - 0.3f;
        }

        return 1 - saturate(comp);
    }
}

float3 MMM_GetToonColor(float4 MaterialToon, float3 Normal, float3 LightDirection0, float3 LightDirection1, float3 LightDirection2)
{
    float LightNormal = dot(Normal, -LightDirection0);
    
    return lerp(MaterialToon, 1, saturate(LightNormal * Toon));
}

float3 MMM_GetSelfShadowToonColor(float4 MaterialToon, float3 Normal, float4 LightUV1, float4 LightUV2, float4 LightUV3, uniform bool useSoftShadow, uniform bool useToon)
{
    float ShadowValue = MMD_GetSelfShadowValue(Normal, LightUV1, parthf);

    return useToon ? lerp(MaterialToon, 1, ShadowValue).rgb : ShadowValue;
}

float4 Compat_GetSelfShadowUV(float4 Position, float4x4 WorldMatrix, float4x4 LightWorldViewProjMatrix, float3 LightPosition, float LightZFar)
{
    return mul(Position, LightWorldViewProjMatrix);
}

#endif
