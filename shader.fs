#version 330

#define PI_2 1.5707963267948966192313216916397514420985846996875529104874722961

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform float x;
uniform float factor;
uniform float cutoff;
uniform float borderThickness;
uniform vec3 colorInner;
uniform vec3 colorBorder;

float line_distance(vec2 p, vec2 a, vec2 b) {
    vec2 ba = b - a;
    vec2 pa = p - a;
    
    return (pa.x * ba.y - pa.y * ba.x) / length(ba);
}

void main()
{
    uvec4 bytes = uvec4(fragColor * 255 + 0.5);
    uint packedUint = (bytes.a << 24) | (bytes.b << 16) | (bytes.g << 8) | bytes.r;
    float base = uintBitsToFloat(packedUint);

    if (base < 0) {
        base = -base;
        float end = base + cutoff * factor;

        vec2 b0 = vec2(0.5 - base, 0);
        vec2 b1 = vec2(0.5 + base, 0);
        vec2 e0 = vec2(0.5 - end, cutoff);
        vec2 e1 = vec2(0.5 + end, cutoff);

        float dist_left = line_distance(fragTexCoord, b0, e0);
        float dist_right = line_distance(fragTexCoord, b1, e1);
        
        float edge = 0.05;

        float alpha = smoothstep(-edge - borderThickness / 2.0, -borderThickness / 2.0, dist_left) *
            (1.0 - smoothstep(borderThickness / 2.0, edge + borderThickness / 2.0, dist_right)) *
            (1.0 - step(cutoff, fragTexCoord.y));

        vec3 color_inner = colorInner *
            smoothstep(-edge + borderThickness / 2.0, borderThickness / 2.0, dist_left) *
            (1.0 - smoothstep(- borderThickness / 2.0, edge - borderThickness / 2.0, dist_right));

        vec3 color_border_left = colorBorder *
            (1.0 - smoothstep(-edge + borderThickness / 2.0, borderThickness / 2.0, dist_left));

        vec3 color_border_right = colorBorder *
            smoothstep(-borderThickness / 2.0, edge - borderThickness / 2.0, dist_right);

        vec3 color = color_inner + color_border_left + color_border_right;

        finalColor = vec4(color, alpha);
    } else {
        float cutoff_angle = cutoff * PI_2;
        float factor_angle = factor / PI_2;
        vec2 center = vec2(x + 0.5, 0);
        vec2 R = fragTexCoord - center;
        float dist = length(R);
        float angle = atan(R.y, -1.0 * sign(x) * R.x);
        float r = base + factor_angle * angle;
        float minDist = abs(x) - r - borderThickness / 2.0;
        float maxDist = abs(x) + r + borderThickness / 2.0;
        float edge = 0.05;

        float alpha = smoothstep(minDist - edge, minDist, dist) *
            (1.0 - smoothstep(maxDist, maxDist + edge, dist)) *
            (1.0 - step(cutoff_angle, angle));

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
}

