// Made by PWira (modified with pixelated specks)
// MIT License
shader_type canvas_item;

// Liquid Property
uniform float liquid_level : hint_range(0.0, 1.0) = 0.5;
uniform vec4 liquid_color : source_color = vec4(0.2, 0.4, 0.9, 0.8);

// Wave property
uniform float wave_amplitude : hint_range(0.0, 0.4) = 0.02;
uniform float wave_frequency : hint_range(0.0, 10.0) = 1.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 0.3;

// Gravity property
uniform float gravity_angle : hint_range(-3.14159, 3.14159) = 0.0;
uniform vec2 gravity_direction = vec2(0.0, 1.0);

// Visual property
uniform float shine_intensity : hint_range(0.0, 1.0) = 0.3;
uniform bool add_bubble = true;
uniform float bubble_scale : hint_range(0.0, 50.0) = 10.0;
uniform float bubble_speed : hint_range(0.0, 2.0) = 0.07;

// Speck properties
uniform float speck_pixel_size : hint_range(1.0, 8.0) = 3.0;
uniform float speck_density : hint_range(0.0, 1.0) = 0.4;
uniform float speck_brightness : hint_range(0.0, 0.5) = 0.15;
uniform float speck_dark_brightness : hint_range(-0.3, 0.0) = -0.08;
uniform float speck_drift_speed : hint_range(0.0, 1.0) = 0.03;
uniform float speck_shimmer_speed : hint_range(0.0, 3.0) = 0.15;

// Edge properties
uniform float edge_darken : hint_range(0.0, 1.0) = 0.45;
uniform float edge_width : hint_range(0.01, 0.3) = 0.12;
uniform vec4 edge_color : source_color = vec4(0.08, 0.15, 0.4, 1.0);
uniform float edge_noise_scale : hint_range(5.0, 60.0) = 25.0;
uniform float edge_noise_strength : hint_range(0.0, 0.15) = 0.06;

// Reflection properties
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.4;
uniform float reflection_distortion : hint_range(0.0, 0.05) = 0.012;
uniform float reflection_fade : hint_range(0.0, 2.0) = 1.0;
uniform float reflection_pixel_snap : hint_range(1.0, 8.0) = 4.0;

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

vec2 rotate(vec2 v, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

float pixel_speck(vec2 uv, float grid_size, float time_offset, float threshold) {
    vec2 cell = floor(uv * grid_size);
    float cell_rand = random(cell + vec2(time_offset * 0.01, time_offset * 0.007));
    return step(threshold, cell_rand);
}

void fragment() {
    vec2 uv = UV;
    vec2 centered_uv = uv - 0.5;
    vec2 rotated_uv = rotate(centered_uv, -gravity_angle);
    rotated_uv += 0.5;

    float wave = sin(rotated_uv.x * wave_frequency + TIME * wave_speed) * wave_amplitude;
    float surface_y = (1.0 - liquid_level) + wave;

    if (rotated_uv.y > surface_y) {
        vec4 base_color = liquid_color;

        float internal_wave = noise(vec2(rotated_uv.x * 3.0, rotated_uv.y * 3.0 + TIME * 0.07)) * 0.1;
        base_color.rgb += vec3(internal_wave);

        if (add_bubble) {
            vec2 bubble_uv = rotated_uv * bubble_scale;
            bubble_uv.y += TIME * bubble_speed;
            float bubble_noise = noise(bubble_uv);
            float bubbles = step(0.95, bubble_noise);
            base_color.rgb += vec3(bubbles * 0.3);
        }

        float shine = pow(1.0 - abs(uv.x - 0.5) * 2.0, 3.0) * shine_intensity;
        base_color.rgb += vec3(shine);

        float depth_factor = 1.0 - (rotated_uv.y - surface_y) / (1.0 - surface_y);
        base_color.rgb *= 0.7 + depth_factor * 0.3;

        // --- Pixelated specks ---
        float grid = 960.0 / (32.0 / speck_pixel_size);

        vec2 bright_uv = rotated_uv + vec2(TIME * speck_drift_speed * 0.3, TIME * speck_drift_speed * 0.1);
        float bright = pixel_speck(bright_uv, grid, 0.0, 1.0 - speck_density * 0.15);
        float shimmer_cell = floor(bright_uv.x * grid) + floor(bright_uv.y * grid) * 137.0;
        float shimmer = step(0.5, fract(sin(shimmer_cell * 43.17) * 0.5 + TIME * speck_shimmer_speed));
        bright *= shimmer;
        base_color.rgb += vec3(bright * speck_brightness);

        vec2 dark_uv = rotated_uv + vec2(-TIME * speck_drift_speed * 0.15, TIME * speck_drift_speed * 0.2);
        float dark_grid = grid * 0.7;
        float dark = pixel_speck(dark_uv, dark_grid, 100.0, 1.0 - speck_density * 0.12);
        base_color.rgb += vec3(dark * speck_dark_brightness);

        vec2 mid_uv = rotated_uv + vec2(TIME * speck_drift_speed * 0.08, -TIME * speck_drift_speed * 0.12);
        float mid_grid = grid * 1.4;
        float mid = pixel_speck(mid_uv, mid_grid, 200.0, 1.0 - speck_density * 0.1);
        base_color.rgb += mid * vec3(-0.02, 0.04, 0.06) * speck_brightness * 2.0;

        // --- Organic edge darkening ---
        float dist_left   = rotated_uv.x;
        float dist_right  = 1.0 - rotated_uv.x;
        float dist_top    = rotated_uv.y - surface_y;
        float dist_bottom = 1.0 - rotated_uv.y;

        float n_left   = noise(vec2(rotated_uv.y * edge_noise_scale, TIME * 0.04)) * edge_noise_strength;
        float n_right  = noise(vec2(rotated_uv.y * edge_noise_scale + 50.0, TIME * 0.035)) * edge_noise_strength;
        float n_top    = noise(vec2(rotated_uv.x * edge_noise_scale + 100.0, TIME * 0.045)) * edge_noise_strength;
        float n_bottom = noise(vec2(rotated_uv.x * edge_noise_scale + 150.0, TIME * 0.03)) * edge_noise_strength;

        float edge_left   = smoothstep(0.0, edge_width + n_left, dist_left);
        float edge_right  = smoothstep(0.0, edge_width + n_right, dist_right);
        float edge_top    = smoothstep(0.0, edge_width * 0.6 + n_top, dist_top);
        float edge_bottom = smoothstep(0.0, edge_width + n_bottom, dist_bottom);

        float edge_mask = edge_left * edge_right * edge_top * edge_bottom;

        base_color.rgb = mix(edge_color.rgb, base_color.rgb, mix(1.0 - edge_darken, 1.0, edge_mask));
        base_color.a = mix(base_color.a, min(base_color.a + 0.15, 1.0), 1.0 - edge_mask);

        float edge_grid = 960.0 / (32.0 / (speck_pixel_size * 0.5));
        vec2 edge_cell = floor(rotated_uv * edge_grid) / edge_grid;
        float edge_speckle = random(edge_cell + vec2(3.7, 1.3));
        float near_edge = smoothstep(0.3, 0.5, 1.0 - edge_mask) * smoothstep(0.7, 0.5, 1.0 - edge_mask);
        float edge_detail = step(0.82, edge_speckle) * near_edge;
        base_color.rgb += vec3(edge_detail * 0.12);
        float edge_dark_detail = step(edge_speckle, 0.18) * near_edge;
        base_color.rgb -= vec3(edge_dark_detail * 0.1);

        // --- Screen-space reflection ---
        vec2 screen_uv = FRAGCOORD.xy * SCREEN_PIXEL_SIZE;

        // Flip Y to sample above the current pixel and pixel-snap
        vec2 reflect_uv = screen_uv;
        float dist_below_surface = rotated_uv.y - surface_y;
        reflect_uv.y = screen_uv.y - dist_below_surface * 2.0;

        // Add subtle wavy distortion to the reflection
        float ref_noise = noise(vec2(rotated_uv.x * 15.0 + TIME * 0.05, rotated_uv.y * 8.0)) - 0.5;
        reflect_uv.x += ref_noise * reflection_distortion;
        reflect_uv.y += ref_noise * reflection_distortion * 0.5;

        // Pixel-snap the reflection UV to keep it chunky
        vec2 snap_res = vec2(960.0, 540.0) / reflection_pixel_snap;
        reflect_uv = floor(reflect_uv * snap_res) / snap_res;

        // Sample the screen above
        vec4 reflection = texture(screen_texture, reflect_uv);

        // Fade reflection with depth — stronger near surface, fades deeper
        float ref_fade = exp(-dist_below_surface * reflection_fade * 8.0);
        ref_fade *= reflection_strength;

        // Desaturate the reflection slightly for a watery look
        float ref_luma = dot(reflection.rgb, vec3(0.299, 0.587, 0.114));
        reflection.rgb = mix(vec3(ref_luma), reflection.rgb, 0.6);

        // Blend reflection into water
        base_color.rgb = mix(base_color.rgb, reflection.rgb, ref_fade * reflection.a);

        COLOR = base_color;

    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}
