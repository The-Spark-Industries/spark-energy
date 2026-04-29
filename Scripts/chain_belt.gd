extends Node2D

# chain.png import: FileSystem → chain.png → Import tab → Repeat → Enabled → Reimport.
# Texture layout: 32×162 px.  U-axis (32 px) = strip thickness, V-axis (162 px) = link pattern.
# The shader scrolls along V, so speed is measured in V-axis pixels per second.

## Scroll speed in pixels per second, relative to chain.png's link-pattern height (162 px).
## speed = 162 → one full chain link period passes per second.
@export var speed: float = 100.0

## Set false to freeze the belt without resetting the scroll position.
@export var moving: bool = true

## How many full link-pattern repeats (162 px each) appear across the belt's length.
## Roughly: belt_pixel_width / 162.0
@export var tile_count: float = 2.0

const _SHADER_PATH := "res://Level 1/Level 1 Art Assets/Shaders/chain_belt.gdshader"

var _uv_offset: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var mat := ShaderMaterial.new()
	mat.shader = load(_SHADER_PATH)
	mat.set_shader_parameter("tile_count", tile_count)
	_sprite.material = mat


func _process(delta: float) -> void:
	if not moving or not _sprite.texture:
		return

	# chain.png scrolls along the V-axis (link-pattern direction = tex_h = 162 px).
	# speed (px/s) / tex_h gives the UV-offset increment per second so that
	# `speed` pixels worth of link pattern scroll past per second.
	# (Old code used tex_w = 32 px, which was 5× too fast and in the wrong axis.)
	var tex_h := float(_sprite.texture.get_height())  # 162
	_uv_offset = fmod(_uv_offset + (speed / tex_h) * delta, 1.0)
	(_sprite.material as ShaderMaterial).set_shader_parameter("uv_offset", _uv_offset)
