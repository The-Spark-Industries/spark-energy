// chain_ring.gdshader
//
// FIX NOTES (what was wrong and what changed):
//
//  1. UV axes were backwards for chain.png (32×162 portrait texture).
//     chain.png layout: U-axis (width=32) is the chain-strip THICKNESS;
//     V-axis (height=162) is the repeating LINK PATTERN.
//     Old shader sampled vec2(UV.x, UV.y) which put the link pattern across
//     the ring THICKNESS and the strip thickness around the CIRCUMFERENCE —
//     the opposite of what looks right.  Fixed: UV.x (angular, circumference
//     direction) → texture V;  UV.y (radial, thickness direction) → texture U.
//
//  2. uv_offset is now driven correctly by chain_ring.gd (see that file for the
//     scroll-speed fix).
//
// IMPORT REQUIREMENT: chain.png must have Repeat Mode = Enabled in the Import
// tab, or tiling will hard-clamp at the texture edge.

shader_type canvas_item;

uniform sampler2D chain_texture : source_color, repeat_enable;

// Scroll position in [0, 1); one full unit = one full tile of the link pattern.
// Driven each frame by chain_ring.gd.
uniform float uv_offset : hint_range(0.0, 1.0) = 0.0;

// How many times the 162 px link-pattern tiles around the full circumference.
// Auto-computed in chain_ring.gd as round(2π·radius / 162).
uniform float tile_count : hint_range(1.0, 64.0) = 3.0;

void fragment() {
	// UV.x = angular position (0→1 around ring circumference)
	// UV.y = radial  position (0=inner edge, 1=outer edge)
	//
	// We map angular → texture V (the 162 px link-pattern axis) so the chain
	// links scroll around the rim, and radial → texture U (the 32 px thickness
	// axis) so the full strip width is shown across the ring's thickness.
	//
	// tile_count controls how many link-pattern repeats fit around the ring;
	// uv_offset shifts the V coordinate each frame to animate the scroll.
	vec2 chain_uv = vec2(UV.y, fract(UV.x * tile_count + uv_offset));
	COLOR = texture(chain_texture, chain_uv);
}
