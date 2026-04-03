// Made by PWira (modified — vertical falling water)
// MIT License
shader_type canvas_item;

// Liquid Property
uniform vec4 liquid_color : source_color = vec4(0.2, 0.4, 0.9, 0.8);

// Flow property
uniform float flow_speed : hint_range(0.0, 5.0) = 0.65;
uniform float flow_streak_scale : hint_range(2.0, 40.0) = 12.0;
uniform float flow_streak_intensity : hint_range(0.0, 0.3) = 0.12;
uniform float flow_wobble : hint_range(0.0, 0.02) = 0.005;
uniform float flow_wobble_speed : hint_range(0.0, 2.0) = 0.25;

// Visual property
uniform float shine_intensity : hint_range(0.0, 1.0) = 0.08;
uniform bool add_bubble = true;
uniform float bubble_scale : hint_range(0.0, 50.0) = 10.0;
uniform float bubble_speed : hint_range(0.0, 2.0) = 0.4;

// Speck properties
uniform float speck_pixel_size : hint_range(1.0, 8.0) = 3.0;
uniform float speck_density : hint_range(0.0, 1.0) = 0.4;
uniform float speck_brightness : hint_range(0.0, 0.5) = 0.15;
uniform float speck_dark_brightness : hint_range(-0.3, 0.0) = -0.08;
uniform float speck_drift_speed : hint_range(0.0, 1.0) = 0.025;
uniform float speck_shimmer_speed : hint_range(0.0, 3.0) = 0.12;

// Edge properties
uniform float edge_darken : hint_range(0.0, 1.0) = 0.45;
uniform float edge_width : hint_range(0.01, 0.3) = 0.12;
uniform vec4 edge_color : source_color = vec4(0.08, 0.15, 0.4, 1.0);
uniform float edge_noise_scale : hint_range(5.0, 60.0) = 25.0;
uniform float edge_noise_strength : hint_range(0.0, 0.15) = 0.06;

// Reflection properties
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.15;
uniform float reflection_distortion : hint_range(0.0, 0.05) = 0.012;
uniform float reflection_pixel_snap : hint_range(1.0, 8.0) = 4.0;

// Background distortion
uniform float bg_distortion_strength : hint_range(0.0, 1.0) = 0.58;
uniform float bg_distortion_scale : hint_range(2.0, 30.0) = 10.0;

// Simple Noise
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float pixel_speck(vec2 uv, float grid_size, float time_offset, float threshold) {
    vec2 cell = floor(uv * grid_size);
    float cell_rand = random(cell + vec2(time_offset * 0.01, time_offset * 0.007));
    return step(threshold, cell_rand);
}

void fragment() {
    vec2 uv = UV;

    // --- Vertical flow offset ---
    float flow_offset = TIME * flow_speed;
    vec2 flow_uv = vec2(uv.x, uv.y - flow_offset);

    // Horizontal wobble
    float wobble = noise(vec2(uv.x * 8.0, flow_uv.y * 4.0 + TIME * flow_wobble_speed)) - 0.5;
    flow_uv.x += wobble * flow_wobble;

    // --- Background distortion (sample what's behind, warped) ---
    vec2 screen_uv = FRAGCOORD.xy * SCREEN_PIXEL_SIZE;
    float bg_n1 = noise(vec2(flow_uv.x * bg_distortion_scale, flow_uv.y * bg_distortion_scale * 0.3)) - 0.5;
    float bg_n2 = noise(vec2(flow_uv.x * bg_distortion_scale * 1.3 + 70.0, flow_uv.y * bg_distortion_scale * 0.25)) - 0.5;
    vec2 bg_offset = vec2(bg_n1, bg_n2) * bg_distortion_strength;
    // Pixel-snap the distortion
    vec2 snap_res_bg = vec2(960.0, 540.0) / 4.0;
    vec2 bg_sample_uv = floor((screen_uv + bg_offset) * snap_res_bg) / snap_res_bg;
    vec4 bg_color = texture(screen_texture, bg_sample_uv);

    vec4 base_color = liquid_color;

    // --- Vertical streaks ---
    float streak1 = noise(vec2(flow_uv.x * flow_streak_scale, flow_uv.y * flow_streak_scale * 0.15));
    float streak2 = noise(vec2(flow_uv.x * flow_streak_scale * 1.7 + 30.0, flow_uv.y * flow_streak_scale * 0.1 + 50.0));
    float streaks = (streak1 * 0.6 + streak2 * 0.4) - 0.5;
    base_color.rgb += vec3(streaks * flow_streak_intensity);

    // --- Internal turbulence ---
    float internal_wave = noise(vec2(flow_uv.x * 3.0, flow_uv.y * 1.5)) * 0.08;
    base_color.rgb += vec3(internal_wave);

    // --- Bubbles ---
    if (add_bubble) {
        vec2 bubble_uv = flow_uv * bubble_scale;
        bubble_uv.y -= TIME * bubble_speed * 0.3;
        float bubble_noise = noise(bubble_uv);
        float bubbles = step(0.93, bubble_noise);
        base_color.rgb += vec3(bubbles * 0.3);
    }

    // --- Center shine (reduced) ---
    // Wider, flatter curve so the center isn't a bright hotspot
    float center_dist = abs(uv.x - 0.5) * 2.0;
    float shine = pow(1.0 - center_dist, 5.0) * shine_intensity;
    // Subtract a base amount in the center to darken it
    float center_darken = (1.0 - center_dist) * 0.06;
    base_color.rgb += vec3(shine - center_darken);

    // --- Pixelated specks ---
    float grid = 960.0 / (32.0 / speck_pixel_size);

    vec2 bright_uv = flow_uv + vec2(TIME * speck_drift_speed * 0.1, 0.0);
    float bright = pixel_speck(bright_uv, grid, 0.0, 1.0 - speck_density * 0.15);
    float shimmer_cell = floor(bright_uv.x * grid) + floor(bright_uv.y * grid) * 137.0;
    float shimmer = step(0.5, fract(sin(shimmer_cell * 43.17) * 0.5 + TIME * speck_shimmer_speed));
    bright *= shimmer;
    base_color.rgb += vec3(bright * speck_brightness);

    vec2 dark_uv = flow_uv + vec2(-TIME * speck_drift_speed * 0.05, 0.0);
    float dark_grid = grid * 0.7;
    float dark = pixel_speck(dark_uv, dark_grid, 100.0, 1.0 - speck_density * 0.12);
    base_color.rgb += vec3(dark * speck_dark_brightness);

    vec2 mid_uv = flow_uv + vec2(TIME * speck_drift_speed * 0.03, 0.0);
    float mid_grid = grid * 1.4;
    float mid = pixel_speck(mid_uv, mid_grid, 200.0, 1.0 - speck_density * 0.1);
    base_color.rgb += mid * vec3(-0.02, 0.04, 0.06) * speck_brightness * 2.0;

    // --- Organic edge darkening ---
    float dist_left   = uv.x;
    float dist_right  = 1.0 - uv.x;
    float dist_top    = uv.y;
    float dist_bottom = 1.0 - uv.y;

    float n_left   = noise(vec2(flow_uv.y * edge_noise_scale, 0.0)) * edge_noise_strength;
    float n_right  = noise(vec2(flow_uv.y * edge_noise_scale + 50.0, 0.0)) * edge_noise_strength;
    float n_top    = noise(vec2(uv.x * edge_noise_scale + 100.0, TIME * 0.015)) * edge_noise_strength;
    float n_bottom = noise(vec2(uv.x * edge_noise_scale + 150.0, TIME * 0.015)) * edge_noise_strength;

    float edge_left   = smoothstep(0.0, edge_width + n_left, dist_left);
    float edge_right  = smoothstep(0.0, edge_width + n_right, dist_right);
    float edge_top    = smoothstep(0.0, edge_width * 0.4 + n_top, dist_top);
    float edge_bottom = smoothstep(0.0, edge_width * 0.4 + n_bottom, dist_bottom);

    float edge_mask = edge_left * edge_right * edge_top * edge_bottom;

    base_color.rgb = mix(edge_color.rgb, base_color.rgb, mix(1.0 - edge_darken, 1.0, edge_mask));
    base_color.a = mix(base_color.a, min(base_color.a + 0.15, 1.0), 1.0 - edge_mask);

    // Edge speckle
    float edge_grid = 960.0 / (32.0 / (speck_pixel_size * 0.5));
    vec2 edge_cell = floor(vec2(uv.x, flow_uv.y) * edge_grid) / edge_grid;
    float edge_speckle = random(edge_cell + vec2(3.7, 1.3));
    float near_edge = smoothstep(0.3, 0.5, 1.0 - edge_mask) * smoothstep(0.7, 0.5, 1.0 - edge_mask);
    float edge_detail = step(0.82, edge_speckle) * near_edge;
    base_color.rgb += vec3(edge_detail * 0.12);
    float edge_dark_detail = step(edge_speckle, 0.18) * near_edge;
    base_color.rgb -= vec3(edge_dark_detail * 0.1);

    // --- Blend distorted background behind the water ---
    base_color.rgb = mix(bg_color.rgb, base_color.rgb, base_color.a);

    // --- Screen-space reflection (smeared downward) ---
    vec2 reflect_uv = screen_uv;
    reflect_uv.y -= 0.08;

    float ref_noise = noise(vec2(flow_uv.x * 15.0, flow_uv.y * 4.0)) - 0.5;
    reflect_uv.x += ref_noise * reflection_distortion;
    reflect_uv.y += ref_noise * reflection_distortion * 2.0;

    vec2 snap_res = vec2(960.0, 540.0) / reflection_pixel_snap;
    reflect_uv = floor(reflect_uv * snap_res) / snap_res;

    vec4 reflection = texture(screen_texture, reflect_uv);

    float ref_center = pow(1.0 - abs(uv.x - 0.5) * 2.0, 2.0);
    float ref_fade = ref_center * reflection_strength;

    float ref_luma = dot(reflection.rgb, vec3(0.299, 0.587, 0.114));
    reflection.rgb = mix(vec3(ref_luma), reflection.rgb, 0.5);

    base_color.rgb = mix(base_color.rgb, reflection.rgb, ref_fade * reflection.a);

    COLOR = base_color;
}
