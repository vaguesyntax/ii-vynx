#version 440

const int _45[256] = int[](-8, -8, -8, -9, -9, -8, -7, -8, -7, -6, -5, -5, -6, -5, -6, -6, -5, -4, -3, -3, -4, -4, -3, -2, -1, 0, -1, 0, 0, 0, -1, 0, 0, 0, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, -1, 0, 0, -1, -1, 0, 0, -1, -2, -1, -2, -3, -4, -4, -5, -6, -5, -5, -6, -7, -7, -6, -6, -5, -5, -6, -6, -5, -5, -5, -6, -7, -6, -6, -6, -5, -4, -4, -5, -4, -5, -5, -6, -5, -4, -3, -3, -2, -2, -1, 0, 0, 0, 0, -1, 0, 0, -1, 0, 0, -1, -2, -2, -3, -2, -1, -2, -1, -2, -2, -2, -1, 0, 0, 0, 0, -1, -1, -2, -1, -2, -1, -2, -1, 0, 0, 0, 0, 0, 0, 0, 0, -1, -1, -2, -3, -4, -4, -4, -3, -3, -3, -3, -3, -4, -4, -3, -4, -5, -5, -6, -6, -5, -6, -6, -7, -6, -5, -5, -4, -5, -4, -4, -5, -6, -7, -8, -9, -8, -9, -10, -9, -9, -9, -10, -9, -8, -8, -9, -9, -8, -8, -9, -8, -8, -8, -7, -6, -5, -6, -7, -8, -8, -9, -8, -8, -9, -8, -7, -8, -7, -7, -7, -8, -8, -8, -8, -7, -8, -8, -9, -10, -9, -9, -8, -7, -6, -6, -7, -7, -6, -6, -6, -7, -7, -8, -8, -8, -9, -9, -8, -9, -10);

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
} _92;

layout(binding = 1) uniform sampler2D fromImage;
layout(binding = 2) uniform sampler2D toImage;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

float getMeltTableValue(float x)
{
    float screenWidth = 360.0;
    int index = int(floor(x * screenWidth)) & 255;
    int melt_height = _45[index];
    float result_height = float(melt_height + 20) / 10.0;
    return result_height;
}
float melt_pattern(float x)
{
    float param = x;
    float height = getMeltTableValue(param) * 2.0;
    return height;
}

float inNormal(float x)
{
    return float((x >= 0.0) && (x <= 1.0));
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float t = _92.progress;
    float animationTime = clamp((t * 1.0) - 1.0, -1.0, 2.0);
    vec2 uv2 = uv;
    float acceleration = (smoothstep(0.5, 1.0, t * 1.0) * 0.5) + 1.0;
    float param = uv.x;
    float push = (melt_pattern(param) * 0.5) + ((animationTime * acceleration) * 2.0);
    float maxPush = 2.0;
    push = clamp(push, 0.0, maxPush);
    uv2.y += push;
    vec4 topColor = texture(fromImage, uv2);
    vec4 bottomColor = texture(toImage, uv);
    float param_1 = uv2.y;
    vec4 mask = vec4(inNormal(param_1));
    fragColor = vec4((mask.xyz * topColor.xyz) + (bottomColor.xyz * (vec3(1.0) - mask.xyz)), 1.0);
}
