extends MeshInstance2D

# chain.png import: FileSystem → chain.png → Import tab → Repeat → Enabled → Reimport.
# The texture is 32×162 px: U-axis (32 px) = chain strip thickness,
# V-axis (162 px) = repeating link pattern.  The shader maps ring-UV accordingly.

# ── Wheel ring ───────────────────────────────────────────────────────────────

## Radius of the chain ring in world pixels.  Tune to sit on the visual wheel rim.
## Collision polygon extends ~70–75 px from centre; start around 75.
@export var chain_radius: float = 75.0

## Thickness of the rendered chain strip in pixels.
## Set this equal to chain.png's width (32 px) for a 1:1 pixel display.
## Larger values stretch the strip; smaller values crop it.
@export var ring_thickness: float = 32.0

## Ring polygon resolution — 64 segments is smooth at any normal wheel size.
@export var segments: int = 64

## The chain texture.  Assign chain.png in the Inspector.
@export var chain_texture: Texture2D

# ── Chain extension to a target node ─────────────────────────────────────────

## When set, a straight chain segment is drawn from the wheel rim to this node.
## Leave empty to show only the wrapped ring.
@export var chain_target: Node2D

## World-space exit angle in degrees.
## 0 = right (+X), 90 = down (+Y), 180 = left, 270 = up.
## The exit point is always fixed in world space regardless of wheel rotation.
@export_range(0.0, 360.0, 1.0) var exit_angle_degrees: float = 90.0

# ── Internals ─────────────────────────────────────────────────────────────────

const _RING_SHADER  := "res://Level 1/Level 1 Art Assets/Shaders/chain_ring.gdshader"
const _BELT_SHADER  := "res://Level 1/Level 1 Art Assets/Shaders/chain_belt.gdshader"

# Tile count is auto-computed from the texture height and circumference so every
# chain link is exactly one tex_h (162 px) arc long.  Rounded to the nearest
# integer so the ring closes cleanly with no partial link at the seam.
var _tile_count:    float = 1.0
var _ring_uv_offset: float = 0.0  # shared scroll position, updated each frame

var _ext_sprite: Sprite2D           # straight extension segment, created in _ready


func _ready() -> void:
	# Make the node's own texture-sampler use repeat mode as a safety net
	# (the shader sampler hint is the primary mechanism, but this covers edge cases).
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	_compute_tile_count()
	mesh     = _build_ring_mesh()
	material = _build_material()
	_build_extension_sprite()


# ── Tile-count calculation ────────────────────────────────────────────────────

func _compute_tile_count() -> void:
	if not chain_texture:
		_tile_count = 3.0
		return
	# chain.png link pattern runs along the V-axis (texture height = 162 px).
	# tile_count = how many full link-patterns fit around the circumference.
	# Rounding to an integer guarantees the ring seam (angle 0 ↔ TAU) is seamless:
	#   fract(1.0 * tile_count) = 0.0  →  same texture column on both seam edges.
	var tex_h       := float(chain_texture.get_height())   # 162 px
	var circumference := TAU * chain_radius                # ≈ 471 px at r=75
	_tile_count = max(1.0, round(circumference / tex_h))   # ≈ round(2.91) = 3


# ── Ring mesh ─────────────────────────────────────────────────────────────────

func _build_ring_mesh() -> ArrayMesh:
	# Build a ring (annulus) as a triangle strip around the origin.
	# Each loop iteration produces one inner + one outer vertex.
	# UV.x = normalised angle (0→1 around ring) — used as the scroll axis.
	# UV.y = 0 at inner edge, 1 at outer edge   — used for chain thickness.
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var verts := PackedVector2Array()
	var uvs   := PackedVector2Array()
	var idx   := PackedInt32Array()

	var r_in  := chain_radius - ring_thickness * 0.5
	var r_out := chain_radius + ring_thickness * 0.5

	for i: int in range(segments + 1):
		var t     := float(i) / float(segments)  # 0→1 around the ring
		var angle := t * TAU
		verts.append(Vector2(cos(angle) * r_in,  sin(angle) * r_in))
		uvs.append(Vector2(t, 0.0))
		verts.append(Vector2(cos(angle) * r_out, sin(angle) * r_out))
		uvs.append(Vector2(t, 1.0))

	for i: int in range(segments):
		var b := i * 2
		# Two CCW triangles per quad strip segment
		idx.append_array([b, b + 1, b + 2,  b + 1, b + 3, b + 2])

	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX]  = idx

	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# ── Ring material ─────────────────────────────────────────────────────────────

func _build_material() -> ShaderMaterial:
	var shader := load(_RING_SHADER) as Shader
	if not shader:
		push_error("ChainRing: ring shader not found at " + _RING_SHADER)
		return null

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tile_count", _tile_count)
	if chain_texture:
		mat.set_shader_parameter("chain_texture", chain_texture)
	return mat


# ── Extension sprite ──────────────────────────────────────────────────────────

func _build_extension_sprite() -> void:
	_ext_sprite = Sprite2D.new()
	_ext_sprite.centered         = false   # origin at left edge; sprite extends right
	_ext_sprite.texture          = chain_texture
	_ext_sprite.texture_repeat   = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ext_sprite.visible          = false

	var belt_shader := load(_BELT_SHADER) as Shader
	if not belt_shader:
		push_error("ChainRing: belt shader not found at " + _BELT_SHADER)
	else:
		var mat := ShaderMaterial.new()
		mat.shader = belt_shader
		_ext_sprite.material = mat

	add_child(_ext_sprite)


# ── Per-frame update ──────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var parent := get_parent() as Node2D
	if not parent:
		return

	# Counter-rotate so the ring stays fixed in world space.
	# A circle rotating is visually identical to a still circle, so this is
	# invisible — but it keeps the UV-origin anchored to world-space right (+X),
	# which makes the scroll-offset maths below straightforward.
	global_rotation = 0.0

	if not material:
		return

	# ── FIX: scroll speed was missing the tile_count factor ──────────────────
	# One wheel revolution moves every chain link one full circumference
	# = tile_count link-widths (tex_h = 162 px each).  The UV offset therefore
	# needs to advance by tile_count units per revolution so the links appear to
	# move the correct physical distance.
	# Old code used:  -parent.rotation / TAU          (too slow by ×tile_count)
	# Fixed:          -parent.rotation / TAU * _tile_count
	_ring_uv_offset = fposmod(-parent.rotation / TAU * _tile_count, 1.0)
	(material as ShaderMaterial).set_shader_parameter("uv_offset", _ring_uv_offset)

	_update_extension()


# ── Extension update (called every frame) ─────────────────────────────────────

func _update_extension() -> void:
	if not is_instance_valid(chain_target) or not chain_texture:
		_ext_sprite.visible = false
		return

	# ── Geometry ──────────────────────────────────────────────────────────────
	# exit_angle_degrees is in world space (0=right, 90=down, 180=left, 270=up).
	# Because global_rotation = 0, our node's local space == world space directions.
	var exit_dir   := Vector2.from_angle(deg_to_rad(exit_angle_degrees))
	var exit_world := global_position + exit_dir * chain_radius
	var to_target  := chain_target.global_position - exit_world
	var dist       := to_target.length()

	if dist < 1.0:
		_ext_sprite.visible = false
		return

	_ext_sprite.visible = true

	# Position the sprite so its left edge sits exactly on the wheel rim.
	_ext_sprite.global_position = exit_world
	# Rotate so local +X points toward the target.
	_ext_sprite.global_rotation = to_target.angle()

	# ── Scale ─────────────────────────────────────────────────────────────────
	# chain.png:  tex_w = 32 px (chain thickness, U axis)
	#             tex_h = 162 px (link pattern, V axis — the scroll direction)
	#
	# The belt shader maps UV.x → texture V and UV.y → texture U.
	# UV.x spans the sprite's local-X width;  UV.y spans its local-Y height.
	#
	# We want the sprite to be  dist × ring_thickness  pixels in world space:
	#   scale.x = dist      / tex_w  →  physical width  = tex_w × scale.x = dist
	#   scale.y = ring_thickness / tex_h  →  physical height = tex_h × scale.y = ring_thickness
	#
	# And the number of link-pattern tiles along that dist:
	#   ext_tile_count = dist / tex_h
	# (fractional tiles just show a partial link at the far end — physically correct)
	var tex_w := float(chain_texture.get_width())   # 32
	var tex_h := float(chain_texture.get_height())  # 162
	_ext_sprite.scale = Vector2(dist / tex_w, ring_thickness / tex_h)

	# ── UV sync with ring ──────────────────────────────────────────────────────
	# To make the ring and extension look like one continuous chain, the texture
	# at UV.x=0 on the extension must equal the ring's texture at the exit angle.
	#
	# exit_t = fraction of the ring at the exit angle (0=right, 0.25=bottom, …)
	# ring texture at exit:  fract(exit_t × tile_count + _ring_uv_offset)
	# extension at UV.x=0:   fract(0 × ext_tile + ext_uv_offset) = fract(ext_uv_offset)
	# Setting ext_uv_offset = ring_sample_at_exit makes them match exactly.
	var exit_t         := exit_angle_degrees / 360.0
	var ext_uv_start   := fposmod(exit_t * _tile_count + _ring_uv_offset, 1.0)
	var ext_tile_count := dist / tex_h

	var ext_mat := _ext_sprite.material as ShaderMaterial
	if ext_mat:
		ext_mat.set_shader_parameter("tile_count", ext_tile_count)
		ext_mat.set_shader_parameter("uv_offset", ext_uv_start)
