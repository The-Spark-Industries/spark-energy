// chain_belt.gdshader
//
// FIX NOTE: UV axes swapped to match chain.png's portrait layout (32×162).
//   U-axis (width 32 px) = chain-strip THICKNESS.
//   V-axis (height 162 px) = repeating LINK PATTERN / scroll direction.
// Old version scrolled along U (width=32), which made the links scroll across
// the strip thickness instead of along its length.  Fixed below.
//
// IMPORT REQUIREMENT: chain.png must have Repeat Mode = Enabled in the Import tab.

shader_type canvas_item;

// How many full 162 px link-pattern heights tile across the belt's length.
// For a belt that is W pixels wide: tile_count = W / 162.0
// (chain_belt.gd computes this automatically from the Sprite2D's visible width.)
uniform float tile_count : hint_range(0.1, 200.0) = 2.0;

// Scroll offset in [0, 1); incremented each frame by chain_belt.gd.
uniform float uv_offset : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// UV.x = along belt length (0→1) → texture V (162 px link-pattern, scrolls)
	// UV.y = across belt width (0→1) → texture U (32 px chain thickness)
	//
	// Adding uv_offset to the V coordinate makes the links move along the belt.
	// fract() wraps seamlessly so the pattern tiles without a hard jump.
	vec2 belt_uv = vec2(UV.y, fract(UV.x * tile_count + uv_offset));
	COLOR = texture(TEXTURE, belt_uv);
}
