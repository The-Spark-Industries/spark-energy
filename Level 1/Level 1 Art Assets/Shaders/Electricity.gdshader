shader_type canvas_item;

uniform vec4 lightning_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float size : hint_range(0.0, 1.0) = 0.1;
uniform float width : hint_range(0.0, 1.0) = 0.5;
uniform float speed : hint_range(0.0, 100.0) = 10.0;
uniform float cycle : hint_range(0.0, 50.0) = 40.0;
uniform float ratio : hint_range(0.0, 1.0) = 0.7;
uniform float time_shift : hint_range(0.0, 10.0) = 4.0;

float rand(float x) {
	return fract(sin(x) * 100000.0);
}

void fragment() {
	float bolt = abs(mod(UV.y * cycle + (rand(TIME) + time_shift) * speed * -1.0, 0.5) - 0.25) - 0.125;
	bolt *= 4.0 * width;

	// scale down at start and end
	bolt *= (0.5 - abs(UV.y - 0.5)) * 2.0;

	// turn to a line, center aligned
	float wave = abs(UV.x - 0.5 + bolt);
	// invert and adjust size
	wave = 1.0 - step(size * 0.5, wave);

	float blink = step(rand(TIME) * ratio, 0.5);
	wave *= blink;

	vec4 display = lightning_color * vec4(wave);

	COLOR = display;
}