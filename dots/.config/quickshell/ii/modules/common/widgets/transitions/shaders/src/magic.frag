#version 440

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 aspectRatio;
    vec2 origin;
} _33;

layout(binding = 1) uniform sampler2D fromImage;
layout(binding = 2) uniform sampler2D toImage;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

float getDistance(vec2 uv)
{
    vec2 scaled = (uv - _33.origin) * _33.aspectRatio;
    return length(scaled);
}

float random(vec2 co)
{
    return fract(sin(dot(co, vec2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float p = clamp(_33.progress, 0.0, 1.0);
    if (p <= 0.0)
    {
        fragColor = texture(fromImage, uv) * _33.qt_Opacity;
        return;
    }
    if (p >= 1.0)
    {
        fragColor = texture(toImage, uv) * _33.qt_Opacity;
        return;
    }
    vec2 distortedUV = clamp(uv, vec2(0.0), vec2(1.0));
    vec4 fromColor = texture(toImage, distortedUV);
    vec4 toColor = texture(fromImage, distortedUV);
    vec2 param = uv;
    float dist = getDistance(param);
    vec2 maxVec = max(_33.origin, vec2(1.0) - _33.origin) * _33.aspectRatio;
    float maxDistance = length(maxVec);
    float threshold = p * maxDistance;
    vec2 param_1 = uv * 150.0;
    float edgeNoise = smoothstep(0.0, 1.0, random(param_1)) * 0.119999997317790985107421875;
    float blend = smoothstep(threshold - 0.0500000007450580596923828125, threshold + edgeNoise, dist);
    fragColor = mix(toColor, fromColor, vec4(1.0 - blend)) * _33.qt_Opacity;
}
