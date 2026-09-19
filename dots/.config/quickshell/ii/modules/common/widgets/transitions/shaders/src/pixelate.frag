#version 440

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspectX;
    float aspectY;
    vec2 aspectRatio;
    vec2 origin;
} ubuf;

layout(binding = 1) uniform sampler2D fromImage;
layout(binding = 2) uniform sampler2D toImage;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

void main()
{
    vec2 uv = qt_TexCoord0;
    float pixelIntensity = 1.0 - abs((2.0 * ubuf.progress) - 1.0);
    vec2 sampleUV = uv;
    if (pixelIntensity > 0.001000000047497451305389404296875)
    {
        float blockSize = 0.0500000007450580596923828125 * pixelIntensity;
        sampleUV = (floor(uv / vec2(blockSize)) * blockSize) + vec2(blockSize * 0.5);
    }
    vec4 color1 = texture(fromImage, sampleUV);
    vec4 color2 = texture(toImage, sampleUV);
    float blend = smoothstep(0.4000000059604644775390625, 0.60000002384185791015625, ubuf.progress);
    fragColor = mix(color1, color2, vec4(blend)) * ubuf.qt_Opacity;
}
