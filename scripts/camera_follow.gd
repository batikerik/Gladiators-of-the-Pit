class_name CombatCamera2D
extends Camera2D

@export var trauma_decay: float = 3.5
@export var max_offset: Vector2 = Vector2(24.0, 18.0)
@export var max_roll_deg: float = 2.0
@export var min_zoom: float = 0.85
@export var max_zoom: float = 1.35
@export var arena_min_x: float = 100.0
@export var arena_max_x: float = 1180.0
## Drawn room edges: the view never shows past them
@export var world_left: float = 0.0
@export var world_right: float = 1280.0
## Zoom when only the thief is in the room (cache, campfire)
@export var solo_zoom: float = 1.15

var _trauma: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_roll: float = 0.0

func _ready() -> void:
	add_to_group(&"combat_camera")

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount * Settings.screen_shake, 0.0, 1.0)

func _process(delta: float) -> void:
	# 1. Clear previous frame's shake offset to avoid positional drift
	if _shake_offset != Vector2.ZERO or _shake_roll != 0.0:
		offset -= _shake_offset
		rotation -= _shake_roll
		_shake_offset = Vector2.ZERO
		_shake_roll = 0.0
	
	# 2. Track combatants
	var combatants: Array = get_tree().get_nodes_in_group(&"combatants")
	if combatants.size() >= 2:
		var pos_a: Vector2 = (combatants[0] as Node2D).global_position
		var pos_b: Vector2 = (combatants[1] as Node2D).global_position
		var mid_x: float = clampf((pos_a.x + pos_b.x) * 0.5, arena_min_x, arena_max_x)
		var mid_y: float = minf(pos_a.y, pos_b.y) - 60.0
		
		# Smoothly follow midpoint
		global_position = global_position.lerp(Vector2(mid_x, mid_y), 6.0 * delta)
		
		# Smooth zoom based on distance
		var dist_x: float = absf(pos_a.x - pos_b.x)
		var target_zoom_val: float = clampf(800.0 / maxf(dist_x + 350.0, 450.0), min_zoom, max_zoom)
		zoom = zoom.lerp(Vector2(target_zoom_val, target_zoom_val), 4.0 * delta)
	elif combatants.size() == 1:
		var target_pos: Vector2 = (combatants[0] as Node2D).global_position + Vector2(0, -60)
		global_position = global_position.lerp(target_pos, 6.0 * delta)
		zoom = zoom.lerp(Vector2(solo_zoom, solo_zoom), 4.0 * delta)

	# Keep the view inside the room: half the visible width from each edge
	if combatants.size() >= 1:
		var half_w: float = get_viewport_rect().size.x * 0.5 / zoom.x
		var lo: float = world_left + half_w
		var hi: float = world_right - half_w
		global_position.x = (lo + hi) * 0.5 if lo > hi else clampf(global_position.x, lo, hi)
	
	# 3. Apply trauma shake
	if _trauma > 0.0:
		var shake: float = _trauma * _trauma # Quadratic falloff
		_shake_offset = Vector2(
			randf_range(-max_offset.x, max_offset.x) * shake,
			randf_range(-max_offset.y, max_offset.y) * shake
		)
		_shake_roll = deg_to_rad(randf_range(-max_roll_deg, max_roll_deg) * shake)
		
		offset += _shake_offset
		rotation += _shake_roll
		
		_trauma = maxf(0.0, _trauma - trauma_decay * delta)
