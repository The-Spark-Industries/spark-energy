shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(0.12, 0.1, 0.18, 0.6);
uniform float speed : hint_range(0.0, 5.0, 0.1) = 0.1;
uniform float scale : hint_range(0.5, 8.0, 0.5) = 8.0;
uniform float pixel_size : hint_range(2.0, 16.0, 1.0) = 2.0;
uniform float cutoff : hint_range(0.0, 1.0, 0.05) = 0.45;
uniform float layers : hint_range(1.0, 3.0, 1.0) = 3.0;
uniform float vertical_fade : hint_range(0.0, 1.0, 0.1) = 0.3;

const vec2 screen_res = vec2(2400.0, 1400.0);

vec2 pixelate(vec2 uv) {
	vec2 grid = screen_res / pixel_size;
	return floor(uv * grid) / grid;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fog(vec2 uv, float time, vec2 drift, float s) {
	vec2 p = uv * s + drift * time;
	float n = noise(p) * 0.6 + noise(p * 2.0) * 0.3 + noise(p * 4.0) * 0.1;
	return step(cutoff, n);
}

void fragment() {
	vec2 uv = pixelate(UV);
	float time = TIME * speed * 0.1;
	float result = 0.0;

	if (layers >= 1.0) {
		result += fog(uv, time, vec2(1.0, 0.2), scale);
	}
	if (layers >= 2.0) {
		result += fog(uv, time * 0.6, vec2(-0.7, 0.1), scale * 1.4) * 0.5;
	}
	if (layers >= 3.0) {
		result += fog(uv, time * 0.3, vec2(0.4, -0.15), scale * 1.8) * 0.3;
	}

	result = clamp(result, 0.0, 1.0);
	result *= mix(1.0, uv.y, vertical_fade);

	COLOR = vec4(fog_color.rgb, result * fog_color.a);
}