#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform float baseRadius;
uniform float endRadius;
uniform float maxY;
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
    vec2 b0 = vec2(0.5 - baseRadius, 0);
    vec2 b1 = vec2(0.5 + baseRadius, 0);
    vec2 e0 = vec2(0.5 - endRadius, maxY);
    vec2 e1 = vec2(0.5 + endRadius, maxY);

    float dist_left = line_distance(fragTexCoord, b0, e0);
    float dist_right = line_distance(fragTexCoord, b1, e1);
    
    float edge = 0.05;

    float alpha = smoothstep(-edge - borderThickness / 2.0, -borderThickness / 2.0, dist_left) *
        (1.0 - smoothstep(borderThickness / 2.0, edge + borderThickness / 2.0, dist_right)) *
        (1.0 - step(maxY, fragTexCoord.y));

    vec3 color_inner = colorInner *
        smoothstep(-edge + borderThickness / 2.0, borderThickness / 2.0, dist_left) *
        (1.0 - smoothstep(- borderThickness / 2.0, edge - borderThickness / 2.0, dist_right));

    vec3 color_border_left = colorBorder *
        (1.0 - smoothstep(-edge + borderThickness / 2.0, borderThickness / 2.0, dist_left));

    vec3 color_border_right = colorBorder *
        smoothstep(-borderThickness / 2.0, edge - borderThickness / 2.0, dist_right);

    vec3 color = color_inner + color_border_left + color_border_right;

    finalColor = vec4(color, alpha);
}
