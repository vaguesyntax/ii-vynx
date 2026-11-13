#version 440

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
} _19;

layout(binding = 2) uniform sampler2D toImage;
layout(binding = 1) uniform sampler2D fromImage;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

void main()
{
    vec2 uv = qt_TexCoord0;
    float threshold = _19.progress;
    float diagonal = (uv.x + uv.y) / 2.0;
    if (diagonal < threshold)
    {
        fragColor = texture(toImage, uv) * _19.qt_Opacity;
    }
    else
    {
        vec2 newUv = uv - vec2(_19.progress * 0.20000000298023223876953125);
        fragColor = texture(fromImage, newUv) * _19.qt_Opacity;
    }
}
