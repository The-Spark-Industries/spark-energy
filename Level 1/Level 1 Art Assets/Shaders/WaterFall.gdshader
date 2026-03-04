shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.02;

uniform vec2 u_mouse;
uniform vec2 u_resolution = vec2(1280.0, 720.0);

uniform float background_alpha : hint_range(0.0, 1.0) = 0.1;

uniform vec3 tint_color : source_color = vec3(0.1, 0.4, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.8;

float random_float(float x) {
    return fract(sin(x) * 1e4);
}

float random_vec2(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float pattern(vec2 st, vec2 v, float t) {
    vec2 p = floor(st + v);
    return step(t, random_float(100.0 + p.x * .000001 + p.y * .000001) 
                + random_float(p.x) * 0.5);
}

void fragment() {
    vec2 st = FRAGCOORD.xy / u_resolution.xy;
    st.x *= u_resolution.x / u_resolution.y;

    vec2 grid = vec2(40.0, 30.0);
    st *= grid;

    vec2 ipos = floor(st);
    vec2 fpos = fract(st);

    vec2 vel = vec2(TIME * 1.4 * max(grid.x, grid.y));
    vel *= vec2(0.05, -1.5) * random_float(2.0 + ipos.x);

    vec2 offset = vec2(0.1, 0.0);

    float threshold = 0.5 + u_mouse.x / u_resolution.x;

    vec3 color = vec3(0.0);
    color.r = pattern(st + offset, vel, threshold);
    color.g = pattern(st, vel, threshold);
    color.b = pattern(st - offset, vel, threshold);

    color *= step(0.4, 1);
	
	vec3 blue = vec3(0.1, 0.4, 1.0); // nice electric blue
	float alpha = 0.6;              // 0.0 = invisible, 1.0 = solid

	float mask = smoothstep(0.0, 1.0, 1.0 - color.r);

	vec3 final_color = tint_color * mask;

	float final_alpha = mix(background_alpha, opacity, mask);

	COLOR = vec4(final_color, final_alpha);
}