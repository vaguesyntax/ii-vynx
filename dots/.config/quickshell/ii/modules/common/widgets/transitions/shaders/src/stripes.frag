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
    vec4 color1 = texture(fromImage, uv);
    vec4 color2 = texture(toImage, uv);
    float stripes = 12.0;
    float angleRad = 0.52359879016876220703125;
    float edgeSmooth = 0.0199999995529651641845703125;
    float cosA = cos(angleRad);
    float sinA = sin(angleRad);
    float stripeCoord = (uv.x * cosA) + (uv.y * sinA);
    float perpCoord = ((-uv.x) * sinA) + (uv.y * cosA);
    float minPerp = min(min(0.0 * cosA, (-sinA) + (0.0 * cosA)), min((0.0 * cosA) + cosA, (-sinA) + cosA));
    float maxPerp = max(max(0.0 * cosA, (-sinA) + (0.0 * cosA)), max((0.0 * cosA) + cosA, (-sinA) + cosA));
    float stripePos = stripeCoord * stripes;
    int stripeIndex = int(floor(stripePos));
    bool isOdd = mod(float(stripeIndex), 2.0) != 0.0;
    float normalizedPos = clamp(stripePos / stripes, 0.0, 1.0);
    float maxDelay = 0.100000001490116119384765625;
    float stripeDelay = normalizedPos * maxDelay;
    float stripeProgress;
    if (ubuf.progress <= stripeDelay)
    {
        stripeProgress = 0.0;
    }
    else
    {
        if (ubuf.progress >= (stripeDelay + (1.0 - maxDelay)))
        {
            stripeProgress = 1.0;
        }
        else
        {
            float activeStart = stripeDelay;
            float activeEnd = stripeDelay + (1.0 - maxDelay);
            stripeProgress = (ubuf.progress - activeStart) / (activeEnd - activeStart);
        }
    }
    float perpRange = maxPerp - minPerp;
    float margin = edgeSmooth;
    float edgePos;
    if (isOdd)
    {
        edgePos = (maxPerp + margin) - (stripeProgress * (perpRange + (margin * 2.0)));
    }
    else
    {
        edgePos = (minPerp - margin) + (stripeProgress * (perpRange + (margin * 2.0)));
    }
    float mask;
    if (isOdd)
    {
        mask = smoothstep(edgePos - edgeSmooth, edgePos + edgeSmooth, perpCoord);
    }
    else
    {
        mask = 1.0 - smoothstep(edgePos - edgeSmooth, edgePos + edgeSmooth, perpCoord);
    }
    if (ubuf.progress <= 0.0)
    {
        fragColor = color1;
    }
    else
    {
        if (ubuf.progress >= 1.0)
        {
            fragColor = color2;
        }
        else
        {
            fragColor = mix(color1, color2, vec4(mask));
            float edgeDist = abs(perpCoord - edgePos);
            float shadowStr = 1.0 - smoothstep(0.0, edgeSmooth * 2.5, edgeDist);
            shadowStr *= (0.20000000298023223876953125 * (1.0 - (abs(stripeProgress - 0.5) * 2.0)));
            vec4 _272 = fragColor;
            vec3 _274 = _272.xyz * (1.0 - shadowStr);
            fragColor.x = _274.x;
            fragColor.y = _274.y;
            fragColor.z = _274.z;
            float vignette = 1.0 - ((ubuf.progress * 0.100000001490116119384765625) * (1.0 - (abs(stripeProgress - 0.5) * 2.0)));
            vec4 _295 = fragColor;
            vec3 _297 = _295.xyz * vignette;
            fragColor.x = _297.x;
            fragColor.y = _297.y;
            fragColor.z = _297.z;
        }
    }
    fragColor *= ubuf.qt_Opacity;
}
