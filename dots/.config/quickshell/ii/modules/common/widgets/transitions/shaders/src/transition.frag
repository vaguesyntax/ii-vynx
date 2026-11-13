#version 440

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
} _32;

layout(binding = 1) uniform sampler2D fromImage;
layout(binding = 2) uniform sampler2D toImage;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

void main()
{
    vec4 from = texture(fromImage, qt_TexCoord0);
    vec4 to = texture(toImage, qt_TexCoord0);
    fragColor = mix(from, to, vec4(_32.progress)) * _32.qt_Opacity;
}
