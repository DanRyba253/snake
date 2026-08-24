#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform float x;
uniform float base;
uniform float factor;
uniform float cutoff;
uniform float borderThickness;
uniform vec3 colorInner;
uniform vec3 colorBorder;

void main()
{
    vec2 center = vec2(x + 0.5, 0);
    vec2 R = fragTexCoord - center;
    float dist = length(R);
    float angle = atan(R.y, -1.0 * sign(x) * R.x);
    float r = base + factor * angle;
    float minDist = abs(x) - r - borderThickness / 2.0;
    float maxDist = abs(x) + r + borderThickness / 2.0;
    float edge = 0.05;

    float alpha = smoothstep(minDist - edge, minDist, dist) *
        (1.0 - smoothstep(maxDist, maxDist + edge, dist)) *
        (1.0 - step(cutoff, angle));

    vec3 color_inner = colorInner *
        smoothstep(-edge + minDist + borderThickness, minDist + borderThickness, dist) *
        (1.0 - smoothstep(maxDist - borderThickness, edge + maxDist - borderThickness, dist));

    vec3 color_border_small = colorBorder *
        (1.0 - smoothstep(-edge + minDist + borderThickness, minDist + borderThickness, dist));

    vec3 color_border_big = colorBorder *
        smoothstep(maxDist - borderThickness, edge + maxDist - borderThickness, dist);

    vec3 color = color_inner + color_border_small + color_border_big;

    finalColor = vec4(color, alpha);
}
