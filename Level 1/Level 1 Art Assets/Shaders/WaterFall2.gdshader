shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.04;
uniform vec2 u_mouse;
uniform vec2 u_resolution = vec2(1280.0, 720.0);
uniform float background_alpha : hint_range(0.0, 1.0) = 0.8;
uniform vec3 tint_color : source_color = vec3(0.15, 0.45, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.95;
uniform float flow_speed : hint_range(0.0, 5.0) = 2.2;
uniform float foam_brightness : hint_range(0.0, 1.0) = 0.45;

float random_float(float x) {
    return fract(sin(x) * 1e4);
}
float random_vec2(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = random_vec2(i);
    float b = random_vec2(i + vec2(1.0, 0.0));
    float c = random_vec2(i + vec2(0.0, 1.0));
    float d = random_vec2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float val = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        val += amp * noise(p);
        p *= 2.1;
        amp *= 0.5;
    }
    return val;
}

void fragment() {
    vec2 screen_uv = SCREEN_UV;

    // --- Pixelated sine wave distortion ---
    float pixel_size = 0.008;
    vec2 pixelated_uv = floor(SCREEN_UV / pixel_size) * pixel_size;

    float wave = sin(pixelated_uv.y * 12.0 + TIME * 0.6) * 0.8
               + sin(pixelated_uv.y * 5.0  + TIME * 0.3) * 0.8;

    vec2 distort = vec2(
        wave * 0.04,
        0.0
    );

    vec3 background = texture(SCREEN_TEXTURE, pixelated_uv + distort).rgb;

    // --- Streak pattern ---
    vec2 st = FRAGCOORD.xy / u_resolution.xy;
    st.x *= u_resolution.x / u_resolution.y;

    // Denser grid — more columns, more coverage
    vec2 grid = vec2(80.0, 120.0);
    st *= grid;

    vec2 ipos = floor(st);
    vec2 fpos = fract(st);

    // Each column flows downward at its own speed
    float col_speed = 1.0;   // min speed raised so no column is too slow
    vec2 vel = vec2(0.0, -TIME * flow_speed * max(grid.x, grid.y) * 0.03);

    // Two streak layers at different scales blended together for fullness
    vec2 p1 = floor(st + vel);
    vec2 p2 = floor(st + vel);   // coarser layer

    float streak1 = step(0.35, random_float(100.0 + p1.x * 0.0001) + random_float(p1.y) * 0.5);
    float streak2 = step(0.25, random_float(200.0 + p2.x * 0.0001) + random_float(p2.y * p2.x) * 0.5);
    float streak  = clamp(streak1 + streak2 * 0.6, 0.0, 1.0);   // combine, cap at 1

    // Soft edges on each column — wider fade so streaks bleed into each other
    float h_fade = smoothstep(0.0, 0.35, fpos.x) * smoothstep(1.0, 0.65, fpos.x);
    streak *= h_fade;

    // Vertical continuity: fade less aggressively top-to-bottom so streaks feel long
    float v_fade = smoothstep(0.0, 0.08, fpos.y) * smoothstep(1.0, 0.92, fpos.y);
    streak *= mix(0.7, 1.0, v_fade);   // don't fully cut — keeps streaks connected

    // Foam on the densest parts
    float foam = noise(st * 0.6 + vec2(0.0, -TIME * flow_speed * 0.4));
    foam = smoothstep(0.65, 1.0, foam) * streak;

    // --- Color ---
    float depth_shade = mix(0.5, 1.0, col_speed / 2.3);
    vec3 deep   = tint_color * 0.55;
    vec3 mid    = tint_color * 1.0;
    vec3 bright = vec3(0.8, 0.92, 1.0);

    vec3 stream_color = mix(deep, mid, streak * depth_shade);
    stream_color = mix(stream_color, bright, foam * foam_brightness);

    // Fill gaps: even non-streak pixels get a faint tint so nothing is bare
    vec3 fill = tint_color * 0.18;
    vec3 final_color = mix(background, fill, 0.3);               // faint base tint over bg
    final_color = mix(final_color, stream_color, streak * opacity);
    final_color = mix(final_color, bright, foam * foam_brightness * 0.5);

    float blend = mix(background_alpha, opacity, clamp(streak + 0.3, 0.0, 1.0));
    COLOR = vec4(final_color, blend);
}