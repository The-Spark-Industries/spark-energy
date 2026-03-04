shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.008;
uniform vec2 u_mouse;
uniform vec2 u_resolution = vec2(1280.0, 720.0);
uniform float background_alpha : hint_range(0.0, 1.0) = 0.;
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

// Smooth noise for organic water warping
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep curve
    float a = random_vec2(i);
    float b = random_vec2(i + vec2(1.0, 0.0));
    float c = random_vec2(i + vec2(0.0, 1.0));
    float d = random_vec2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 screen_uv = SCREEN_UV;

    // --- Water distortion ---
    // Two layers of noise scrolling at different speeds/directions = ripple feel
    float wave1 = noise(screen_uv * 6.0 + vec2(TIME * 0.3,  TIME * 0.15));
    float wave2 = noise(screen_uv * 6.0 + vec2(-TIME * 0.2, TIME * 0.25));

    // Combine into a 2D offset, centered around 0
    vec2 distort = vec2(
        (wave1 - 0.5) * distortion_strength,
        (wave2 - 0.5) * distortion_strength
    );

    // Sample background with distorted UV
    vec3 background = texture(SCREEN_TEXTURE, screen_uv + distort).rgb;

    // --- Data stream pattern (unchanged) ---
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
    color.g = pattern(st,          vel, threshold);
    color.b = pattern(st - offset, vel, threshold);
    color *= step(0.4, 1.0);

    float mask = smoothstep(0.0, 1.0, 1.0 - color.r);
    vec3 tint   = tint_color * mask;
    float final_alpha = mix(background_alpha, opacity, mask);

    // --- Blend: distorted background + data stream tint on top ---
    vec3 final_color = mix(background, tint, mask * opacity);

    COLOR = vec4(final_color, final_alpha);
}