extends Area2D

signal puzzle_solved(terminal: Node)

@export var minigame_scene: PackedScene = preload("res://Master Scenes/PipeMinigame.tscn")
@export var puzzle_definition: Dictionary = {}  # Serializable puzzle; auto-populate with default if empty.
@export_enum("Default 3x3", "3x3", "4x4", "5x5", "6x6", "7x7", "9x8", "9x9", "Wire Tree 9x8", "Wire Full 6x6") var puzzle_layout: int = 0
@export_enum("Normal", "Move Only", "Rotate Only") var control_mode: int = 0
@export_group("Solved Platform Motion")
@export var moving_platform_path: NodePath
@export var platform_move_distance: float = 140.0
@export var platform_move_duration: float = 1.4
@export_group("Solved Water Flow")
@export var water_stream_path: NodePath
@export var water_wheel_path: NodePath
@export var water_to_wheel_delay: float = 0.25
@export var wheel_spin_time_per_turn: float = 0.6
@export_group("Solved Rise Motion")
@export var solved_rise_target_path: NodePath
@export var solved_rise_distance: float = 0.0
@export var solved_rise_duration: float = 1.0
@export_enum("Rise", "Ellipse Conveyor") var solved_motion_type: int = 0
@export_group("Solved Ellipse Motion")
@export var solved_ellipse_target_path: NodePath
@export var solved_ellipse_partner_target_path: NodePath
@export var solved_ellipse_radius_x: float = 150.0
@export var solved_ellipse_radius_y: float = 80.0
@export var solved_ellipse_cycle_duration: float = 4.0
@export var solved_ellipse_clockwise: bool = true
@export var solved_ellipse_rotate_with_path: bool = true
@export_group("Embedded Puzzle Board")
@export var embedded_minigame_path: NodePath
@export var debug_embedded_sync: bool = false
@export_group("Solved Linked Object")
@export var linked_object_path: NodePath
@export var linked_object_method: StringName = &"on_terminal_solved"

var _bodies_inside: Array[Node] = []
var _ui_layer: CanvasLayer = null
var _minigame: Control = null
var _solved: bool = false
var _puzzle: PipePuzzleDefinition = null
var _randomized_once: bool = false
var _platform_motion_started: bool = false
var _wheel_spin_started: bool = false
var _solved_rise_started: bool = false
var _rise_tween: Tween = null
var _ellipse_motion_started: bool = false
var _ellipse_target: Node2D = null
var _ellipse_partner_target: Node2D = null
var _ellipse_center: Vector2 = Vector2.ZERO
var _ellipse_angle: float = 0.0
var _ellipse_riders: Dictionary = {}
var _embedded_sync_attempts: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if has_node("Prompt"):
		$Prompt.visible = false
	# Initialize puzzle from export data or use default.
	if puzzle_definition.is_empty():
		match puzzle_layout:
			1:
				_puzzle = PipePuzzleDefinition.create_puzzle_3x3()
			2:
				_puzzle = PipePuzzleDefinition.create_puzzle_4x4()
			3:
				_puzzle = PipePuzzleDefinition.create_puzzle_5x5()
			4:
				_puzzle = PipePuzzleDefinition.create_puzzle_6x6()
			5:
				_puzzle = PipePuzzleDefinition.create_puzzle_7x7()
			6:
				_puzzle = PipePuzzleDefinition.create_puzzle_9x8()
			7:
				_puzzle = PipePuzzleDefinition.create_puzzle_9x9()
			8:
				_puzzle = PipePuzzleDefinition.create_wire_tree_9x8()
			9:
				_puzzle = PipePuzzleDefinition.create_wire_full_6x6()
			_:
				_puzzle = PipePuzzleDefinition.create_default()
		puzzle_definition = _puzzle.to_dict()
	else:
		_puzzle = PipePuzzleDefinition.from_dict(puzzle_definition)

	# Randomize at level load so puzzle state is ready before any interaction.
	_randomize_puzzle_first_open()

	# For in-world puzzle boxes, preload the board so the full layout is visible before interaction.
	if not String(embedded_minigame_path).is_empty():
		if debug_embedded_sync:
			push_warning("[PipePuzzleTerminal] debug active for %s path=%s" % [name, String(embedded_minigame_path)])
		_setup_embedded_preview()
		call_deferred("_setup_embedded_preview")
		call_deferred("_sync_embedded_preview_with_retries", 0)

func _setup_embedded_preview() -> void:
	var embedded := get_node_or_null(embedded_minigame_path) as Control
	if embedded == null:
		# The sibling minigame can still be instancing during scene boot.
		call_deferred("_setup_embedded_preview")
		return
	if not embedded.is_node_ready():
		call_deferred("_setup_embedded_preview")
		return

	_minigame = embedded
	if _minigame.has_method("set_puzzle"):
		_minigame.call("set_puzzle", _puzzle)
	if _minigame.has_method("refresh_embedded_preview"):
		_minigame.call("refresh_embedded_preview")
		_minigame.call_deferred("refresh_embedded_preview")
	if _minigame.has_method("set_control_mode"):
		_minigame.call("set_control_mode", control_mode)
	if _minigame.has_method("set_debug_preview"):
		_minigame.call("set_debug_preview", debug_embedded_sync)
	if _minigame.has_signal("completed") and not _minigame.is_connected("completed", _on_minigame_completed):
		_minigame.connect("completed", _on_minigame_completed)

func _sync_embedded_preview_with_retries(attempt: int) -> void:
	if String(embedded_minigame_path).is_empty():
		return
	if attempt > 30:
		if debug_embedded_sync:
			print("[PipePuzzleTerminal] sync gave up after retries: ", name)
		return
	if attempt > 0:
		await get_tree().process_frame

	var embedded := get_node_or_null(embedded_minigame_path) as Control
	if embedded == null or not embedded.is_node_ready():
		if debug_embedded_sync:
			print("[PipePuzzleTerminal] embedded not ready attempt=", attempt, " terminal=", name)
		call_deferred("_sync_embedded_preview_with_retries", attempt + 1)
		return

	_minigame = embedded
	_embedded_sync_attempts = attempt

	if _minigame.has_method("set_puzzle"):
		_minigame.call("set_puzzle", _puzzle)
	if _minigame.has_method("set_control_mode"):
		_minigame.call("set_control_mode", control_mode)
	if _minigame.has_method("set_debug_preview"):
		_minigame.call("set_debug_preview", debug_embedded_sync)
	if _minigame.has_method("refresh_embedded_preview"):
		_minigame.call("refresh_embedded_preview")

	if _minigame.has_method("get_puzzle_signature") and _minigame.has_method("get_render_signature"):
		var puzzle_signature := String(_minigame.call("get_puzzle_signature"))
		var render_signature := String(_minigame.call("get_render_signature"))
		if debug_embedded_sync:
			print("[PipePuzzleTerminal] attempt=", attempt, " terminal=", name, " puzzle_sig=", puzzle_signature.left(120), " render_sig=", render_signature.left(120))
		if not puzzle_signature.is_empty() and puzzle_signature == render_signature:
			if debug_embedded_sync:
				print("[PipePuzzleTerminal] sync matched for ", name, " at attempt ", attempt)
			return

	call_deferred("_sync_embedded_preview_with_retries", attempt + 1)

func interact(player: CharacterBody2D) -> bool:
	if _solved:
		if has_node("Prompt"):
			$Prompt.text = "Solved"
			$Prompt.visible = true
		return false

	if _minigame == null:
		if not String(embedded_minigame_path).is_empty():
			_minigame = get_node_or_null(embedded_minigame_path) as Control
			if _minigame == null:
				push_warning("PipePuzzleTerminal: embedded_minigame_path not found. Overlay fallback disabled for this terminal.")
				return false
		if _minigame == null:
			if _ui_layer == null:
				_ui_layer = CanvasLayer.new()
				_ui_layer.layer = 100
				get_tree().current_scene.add_child(_ui_layer)

			_minigame = minigame_scene.instantiate() as Control
			if _minigame == null:
				push_error("PipePuzzleTerminal: failed to instantiate PipeMinigame scene.")
				return false

			_ui_layer.add_child(_minigame)
			_ui_layer.move_child(_minigame, _ui_layer.get_child_count() - 1)
	elif _ui_layer:
		_ui_layer.move_child(_minigame, _ui_layer.get_child_count() - 1)

	if _minigame.has_signal("completed") and not _minigame.is_connected("completed", _on_minigame_completed):
		_minigame.connect("completed", _on_minigame_completed)

	if _minigame.has_method("set_puzzle"):
		_minigame.call("set_puzzle", _puzzle)
	if _minigame.has_method("refresh_embedded_preview"):
		_minigame.call("refresh_embedded_preview")
	if _minigame.has_method("set_control_mode"):
		_minigame.call("set_control_mode", control_mode)

	if _minigame.has_method("open_for_player"):
		_minigame.call("open_for_player", player)
		return true

	return false

func _on_minigame_completed(success: bool) -> void:
	if success:
		_solved = true
		if has_node("Prompt"):
			$Prompt.text = "Solved"
		_notify_linked_object_on_solve()
		await _start_connected_water_flow()
		if solved_motion_type == 1:
			_start_solved_ellipse_if_needed()
		else:
			_start_solved_rise_if_needed()
		_start_platform_motion_if_needed()

func _physics_process(delta: float) -> void:
	if (Global.fontChoice==0):
		$Prompt.theme=load("res://Assets/Visual/Lingua.tres")
	if (Global.fontChoice==1):
		$Prompt.theme=load("res://Assets/Visual/lingualight.tres")
	if (Global.fontChoice==2):
		$Prompt.theme=load("res://Assets/Visual/Receipt.tres")

	
	if not _ellipse_motion_started:
		return
	if _ellipse_target == null or not is_instance_valid(_ellipse_target):
		var fallback_path := solved_ellipse_target_path
		if String(fallback_path).is_empty():
			fallback_path = solved_rise_target_path
		if String(fallback_path).is_empty():
			_ellipse_motion_started = false
			set_physics_process(false)
			return
		_ellipse_target = get_node_or_null(fallback_path) as Node2D
		if _ellipse_target == null:
			_ellipse_motion_started = false
			set_physics_process(false)
			return

	var cycle := maxf(solved_ellipse_cycle_duration, 0.01)
	var direction := -1.0 if solved_ellipse_clockwise else 1.0
	_ellipse_angle += direction * (TAU / cycle) * delta
	_ellipse_angle = wrapf(_ellipse_angle, -TAU, TAU)
	var target_prev := _ellipse_target.global_position
	var partner_prev := Vector2.ZERO
	if _ellipse_partner_target != null and is_instance_valid(_ellipse_partner_target):
		partner_prev = _ellipse_partner_target.global_position

	var radius_x := absf(solved_ellipse_radius_x)
	var radius_y := absf(solved_ellipse_radius_y)
	var offset := Vector2(cos(_ellipse_angle) * radius_x, sin(_ellipse_angle) * radius_y)
	_ellipse_target.position = _ellipse_center + offset
	if _ellipse_partner_target != null and is_instance_valid(_ellipse_partner_target):
		var partner_angle := _ellipse_angle + PI
		var partner_offset := Vector2(cos(partner_angle) * radius_x, sin(partner_angle) * radius_y)
		_ellipse_partner_target.position = _ellipse_center + partner_offset

	_apply_platform_friction(_ellipse_target, _ellipse_target.global_position - target_prev)
	if _ellipse_partner_target != null and is_instance_valid(_ellipse_partner_target):
		_apply_platform_friction(_ellipse_partner_target, _ellipse_partner_target.global_position - partner_prev)

	if solved_ellipse_rotate_with_path:
		var tangent := Vector2(-sin(_ellipse_angle) * radius_x, cos(_ellipse_angle) * radius_y)
		if tangent.length() > 0.0001:
			_ellipse_target.rotation = tangent.angle()
		if _ellipse_partner_target != null and is_instance_valid(_ellipse_partner_target):
			var partner_tangent := Vector2(-sin(_ellipse_angle + PI) * radius_x, cos(_ellipse_angle + PI) * radius_y)
			if partner_tangent.length() > 0.0001:
				_ellipse_partner_target.rotation = partner_tangent.angle()
	else:
		_ellipse_target.rotation = 0.0
		if _ellipse_partner_target != null and is_instance_valid(_ellipse_partner_target):
			_ellipse_partner_target.rotation = 0.0

func _notify_linked_object_on_solve() -> void:
	puzzle_solved.emit(self)

	if String(linked_object_path).is_empty():
		return

	var linked := get_node_or_null(linked_object_path)
	if linked == null:
		push_warning("PipePuzzleTerminal: linked_object_path not found.")
		return

	if not String(linked_object_method).is_empty() and linked.has_method(String(linked_object_method)):
		linked.call(String(linked_object_method), self)
		return

	# Fallback names for convenience.
	if linked.has_method("start_water_dispense"):
		linked.call("start_water_dispense", self)
	elif linked.has_method("activate"):
		linked.call("activate", self)
	elif linked.has_method("trigger"):
		linked.call("trigger", self)

func _start_connected_water_flow() -> void:
	if not String(water_stream_path).is_empty():
		var stream_node := get_node_or_null(water_stream_path)
		_set_flow_visual_active(stream_node, true)

	if not String(water_wheel_path).is_empty():
		if water_to_wheel_delay > 0.0:
			await get_tree().create_timer(water_to_wheel_delay).timeout
		_start_wheel_spin(get_node_or_null(water_wheel_path))

func _start_solved_rise_if_needed() -> void:
	if _solved_rise_started:
		return
	if String(solved_rise_target_path).is_empty():
		return
	if is_zero_approx(solved_rise_distance):
		return

	var target := get_node_or_null(solved_rise_target_path) as Node2D
	if target == null:
		push_warning("PipePuzzleTerminal: solved_rise_target_path not found.")
		return

	_solved_rise_started = true
	
	# Wait for player to be on the platform before rising
	if target.has_method("is_player_on_platform"):
		# Check if player is currently on platform
		if target.is_player_on_platform():
			print("Player already on platform, raising immediately")
			_raise_platform(target)
		else:
			print("Player not on platform, waiting for arrival")
			# If player not yet on platform, wait for signal
			if not target.is_connected("player_landed", Callable(self, "_on_player_landed_on_platform")):
				target.connect("player_landed", Callable(self, "_on_player_landed_on_platform").bind(target))
			if not target.is_connected("player_left", Callable(self, "_on_player_left_platform")):
				target.connect("player_left", Callable(self, "_on_player_left_platform").bind(target))
	else:
		print("Platform doesn't have is_player_on_platform method, raising immediately")
		_raise_platform(target)

func _start_solved_ellipse_if_needed() -> void:
	if _ellipse_motion_started:
		return

	var path := solved_ellipse_target_path
	if String(path).is_empty():
		path = solved_rise_target_path
	if String(path).is_empty():
		return

	var target := get_node_or_null(path) as Node2D
	if target == null:
		push_warning("PipePuzzleTerminal: solved ellipse target path not found.")
		return

	var partner_path := solved_ellipse_partner_target_path
	if not String(partner_path).is_empty():
		_ellipse_partner_target = get_node_or_null(partner_path) as Node2D
		if _ellipse_partner_target == null:
			push_warning("PipePuzzleTerminal: solved ellipse partner target path not found.")
	else:
		_ellipse_partner_target = null

	if is_zero_approx(solved_ellipse_radius_x) and is_zero_approx(solved_ellipse_radius_y):
		return

	_ellipse_target = target
	_ellipse_motion_started = true
	_ellipse_angle = -PI * 0.5
	_ellipse_center = target.position - Vector2(cos(_ellipse_angle) * solved_ellipse_radius_x, sin(_ellipse_angle) * solved_ellipse_radius_y)
	set_physics_process(true)

func _apply_platform_friction(platform: Node2D, delta_motion: Vector2) -> void:
	if platform == null:
		return
	if platform.has_method("get_player_on_platform"):
		return
	if is_zero_approx(delta_motion.x) and is_zero_approx(delta_motion.y):
		return

	var key := platform.get_instance_id()
	var rider := _find_platform_rider(platform)
	if rider == null and _ellipse_riders.has(key):
		var cached = _ellipse_riders[key]
		if cached is CharacterBody2D and is_instance_valid(cached) and _is_player_on_platform_top(cached, platform):
			rider = cached
	if rider == null:
		_ellipse_riders.erase(key)
		return

	_ellipse_riders[key] = rider
	rider.global_position += delta_motion

func _find_platform_rider(platform: Node2D) -> CharacterBody2D:
	if platform == null:
		return null

	if platform.has_method("get_player_on_platform"):
		var player = platform.call("get_player_on_platform")
		if player is CharacterBody2D and is_instance_valid(player):
			return player as CharacterBody2D

	var area := platform.get_node_or_null("Area2D") as Area2D
	if area:
		for body in area.get_overlapping_bodies():
			if body is CharacterBody2D and is_instance_valid(body):
				return body as CharacterBody2D

	var fallback_player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if fallback_player != null and is_instance_valid(fallback_player) and _is_player_on_platform_top(fallback_player, platform):
		return fallback_player

	var named_player := get_tree().current_scene.find_child("Player", true, false) as CharacterBody2D
	if named_player != null and is_instance_valid(named_player) and _is_player_on_platform_top(named_player, platform):
		return named_player

	return null

func _is_player_on_platform_top(player: CharacterBody2D, platform: Node2D) -> bool:
	if player == null or platform == null:
		return false

	var shape := platform.get_node_or_null("PlatformBody/CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = platform.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if shape == null:
		return false
	var rect := shape.shape as RectangleShape2D
	if rect == null:
		return false

	var half := rect.size * 0.5
	var center := shape.global_position
	var top_y := center.y - half.y
	var left_x := center.x - half.x
	var right_x := center.x + half.x

	var x_ok := player.global_position.x >= (left_x - 12.0) and player.global_position.x <= (right_x + 12.0)
	var y_ok := absf(player.global_position.y - top_y) <= 42.0
	return x_ok and y_ok

func _on_player_landed_on_platform(target: Node2D) -> void:
	print("Signal received: player landed on platform")
	_raise_platform(target)

func _on_player_left_platform(target: Node2D) -> void:
	print("Player left platform - stopping rise")
	# Cancel the rise tween if it's active
	if _rise_tween and _rise_tween.is_valid():
		_rise_tween.kill()
		_rise_tween = null

func _raise_platform(target: Node2D) -> void:
	print("Raising platform: ", target.name)
	# Kill any existing tween
	if _rise_tween and _rise_tween.is_valid():
		_rise_tween.kill()
	var start_y := target.position.y
	_rise_tween = create_tween()
	_rise_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_rise_tween.tween_property(target, "position:y", start_y - solved_rise_distance, solved_rise_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_flow_visual_active(node: Node, active: bool) -> void:
	if node == null:
		return

	if node is CanvasItem:
		(node as CanvasItem).visible = active

	# Supports GPUParticles2D/CPUParticles2D if a particle stream node is used.
	if node is GPUParticles2D:
		(node as GPUParticles2D).emitting = active
	elif node is CPUParticles2D:
		(node as CPUParticles2D).emitting = active

	# Supports an AnimationPlayer child named FlowAnimation for custom visuals.
	if node.has_node("FlowAnimation"):
		var flow_anim := node.get_node("FlowAnimation") as AnimationPlayer
		if flow_anim:
			if active:
				if flow_anim.has_animation("default"):
					flow_anim.play("default")
			else:
				flow_anim.stop()

func _start_wheel_spin(node: Node) -> void:
	if _wheel_spin_started:
		return
	var wheel := node as Node2D
	if wheel == null:
		return

	_wheel_spin_started = true
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(wheel, "rotation", TAU, wheel_spin_time_per_turn).as_relative().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	if body in _bodies_inside:
		return

	_bodies_inside.append(body)
	if has_node("Prompt"):
		$Prompt.visible = true

	if body.has_method("_on_interactable_entered"):
		body._on_interactable_entered(self)

func _on_body_exited(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return

	_bodies_inside.erase(body)
	if _bodies_inside.is_empty() and has_node("Prompt"):
		$Prompt.visible = false

	if body.has_method("_on_interactable_exited"):
		body._on_interactable_exited(self)

func _randomize_puzzle_first_open() -> void:
	if _randomized_once or _puzzle == null:
		return

	var movable_indices: Array[int] = []
	var movable_pieces: Array[Dictionary] = []
	var original_movable_pieces: Array[Dictionary] = []
	for i in range(_puzzle.pieces.size()):
		var piece: Dictionary = _puzzle.pieces[i]
		if piece.get("locked", false):
			continue
		movable_indices.append(i)
		var copied_piece := piece.duplicate()
		movable_pieces.append(copied_piece)
		original_movable_pieces.append(copied_piece.duplicate())

	if movable_indices.is_empty():
		_randomized_once = true
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	if control_mode == 2:
		var changed := false
		for piece in movable_pieces:
			var kind := String(piece.get("kind", "empty"))
			if kind == "straight" or kind == "corner" or kind == "tee":
				var next_rot := rng.randi_range(0, 3)
				if next_rot != int(piece.get("rot", 0)):
					changed = true
				piece["rot"] = next_rot

		if not changed:
			for piece in movable_pieces:
				var kind := String(piece.get("kind", "empty"))
				if kind == "straight" or kind == "corner" or kind == "tee":
					piece["rot"] = posmod(int(piece.get("rot", 0)) + 1, 4)
					changed = true
					break

		for i in range(movable_indices.size()):
			_puzzle.pieces[movable_indices[i]] = movable_pieces[i]

		puzzle_definition = _puzzle.to_dict()
		_randomized_once = true
		if debug_embedded_sync:
			print("[PipePuzzleTerminal] rotate randomize for ", name, " layout=", puzzle_layout, " pieces=", _puzzle.pieces.size())
		return

	for piece in movable_pieces:
		var kind := String(piece.get("kind", "empty"))
		if kind == "straight" or kind == "corner" or kind == "tee":
			piece["dirt_level"] = rng.randi_range(0, 2)

	# Shuffle all movable slots (including empties) so each terminal starts unique.
	for i in range(movable_pieces.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Dictionary = movable_pieces[i]
		movable_pieces[i] = movable_pieces[j]
		movable_pieces[j] = temp

	# If shuffled layout still looks identical by value, force one visible swap.
	var looks_identical := true
	for i in range(movable_pieces.size()):
		if movable_pieces[i] != original_movable_pieces[i]:
			looks_identical = false
			break

	if looks_identical and movable_pieces.size() > 1:
		for i in range(movable_pieces.size() - 1):
			for j in range(i + 1, movable_pieces.size()):
				var a_kind := String(movable_pieces[i].get("kind", "empty"))
				var b_kind := String(movable_pieces[j].get("kind", "empty"))
				var a_rot := int(movable_pieces[i].get("rot", 0))
				var b_rot := int(movable_pieces[j].get("rot", 0))
				if a_kind != b_kind or a_rot != b_rot:
					var forced_swap := movable_pieces[i]
					movable_pieces[i] = movable_pieces[j]
					movable_pieces[j] = forced_swap
					looks_identical = false
					break
			if not looks_identical:
				break

	for i in range(movable_indices.size()):
		_puzzle.pieces[movable_indices[i]] = movable_pieces[i]

	puzzle_definition = _puzzle.to_dict()
	_randomized_once = true
	if debug_embedded_sync:
		print("[PipePuzzleTerminal] randomized once for ", name, " layout=", puzzle_layout, " pieces=", _puzzle.pieces.size())




func _start_platform_motion_if_needed() -> void:
	if _platform_motion_started:
		return
	if solved_motion_type == 1:
		return
	if puzzle_layout != 2:
		return
	if String(moving_platform_path).is_empty():
		return

	var platform := get_node_or_null(moving_platform_path) as Node2D
	if platform == null:
		return

	var start_x := platform.position.x
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_loops()
	tween.tween_property(platform, "position:x", start_x + platform_move_distance, platform_move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(platform, "position:x", start_x - platform_move_distance, platform_move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_platform_motion_started = true
