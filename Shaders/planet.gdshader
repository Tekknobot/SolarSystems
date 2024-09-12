shader_type canvas_item;

uniform vec4 color1 : hint_color;
uniform vec4 color2 : hint_color;
uniform float gradient_strength;

void fragment() {
    vec2 uv = FRAGCOORD.xy / SCREEN_SIZE;
    float dist = length(uv - vec2(0.5, 0.5));  // Distance from the center
    vec4 grad_color = mix(color1, color2, smoothstep(0.4, 0.5, dist));
    COLOR = grad_color * gradient_strength;
}
