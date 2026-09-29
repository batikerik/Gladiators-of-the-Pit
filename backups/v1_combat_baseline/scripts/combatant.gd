class_name Combatant
extends CharacterBody2D

signal took_damage(amount: float, zone: String, current_hp: float, max_hp: float)
signal landed_hit(target: Node2D, zone: String, damage: float, pos: Vector2, normal: Vector2)
signal defeated

@export var is_player: bool = true
@export var character_name: String = "Gladiator"
@export var max_health: float = 100.0
@export var hop_force_y: float = 320.0
@export var hop_force_x: float = 240.0
@export var gravity: float = 980.0
@export var balance_spring: float = 12.0 # Speed of returning to upright posture
@export var arm_rotation_speed: float = 26.0 # Radians/sec arm follows target
@export var ai_aggression: float = 1.0
@export var is_zombie: bool = false
@export var armor_tier: int = 1

var current_health: float = 100.0
var is_alive: bool = true
var is_tripped: bool = false
var trip_time_left: float = 0.0
var hop_cooldown: float = 0.0
var facing_direction: int = 1 # 1 = right, -1 = left

# Nodes
@onready var visual_root: Node2D = $VisualRoot
@onready var torso: Node2D = $VisualRoot/Torso
@onready var head: Node2D = $VisualRoot/Head
@onready var legs: Node2D = $VisualRoot/Legs
@onready var shoulder_pivot: Node2D = $VisualRoot/ShoulderPivot
@onready var weapon: Area2D = $VisualRoot/ShoulderPivot/Weapon
@onready var flash_timer: Timer = get_node_or_null("FlashTimer")

# Visual procedural squashing & bobbing
var _squash_scale: Vector2 = Vector2.ONE
var _hop_phase: float = 0.0
var _original_modulate: Color = Color.WHITE

func _ready() -> void:
	current_health = max_health
	if visual_root and visual_root.has_node("Puppet"):
		var puppet: Node2D = visual_root.get_node("Puppet")
		puppet.set("is_zombie", is_zombie)
		puppet.set("armor_tier", armor_tier)
	
	if weapon:
		weapon.owner_combatant = self
		weapon.hit_connected.connect(_on_weapon_hit_connected)
	
	if flash_timer:
		flash_timer.timeout.connect(_on_flash_timeout)

func _physics_process(delta: float) -> void:
	if not is_alive:
		# Apply ragdoll-like collapse physics
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 150.0 * delta)
		move_and_slide()
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	
	# Handle trip recovery
	if is_tripped:
		trip_time_left -= delta
		if trip_time_left <= 0.0:
			is_tripped = false
	
	hop_cooldown = maxf(0.0, hop_cooldown - delta)
	
	# Input & Locomotion
	if is_player:
		_process_player_input(delta)
		_process_player_weapon(delta)
	else:
		_process_ai(delta)
	
	# Balance & tilt stabilization
	var target_rotation: float = 0.0
	if is_tripped:
		target_rotation = deg_to_rad(35.0 * facing_direction)
	elif not is_on_floor():
		# Tilt slightly based on horizontal movement
		target_rotation = clampf(velocity.x * 0.001, -0.4, 0.4)
	
	rotation = lerpf(rotation, target_rotation, balance_spring * delta)
	
	# Squash & stretch interpolation
	if visual_root:
		_squash_scale = _squash_scale.lerp(Vector2.ONE, 10.0 * delta)
		visual_root.scale = Vector2(facing_direction * absf(_squash_scale.x), _squash_scale.y)
	
	move_and_slide()

func _process_player_input(_delta: float) -> void:
	if is_tripped:
		return
	
	var input_x: float = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_x += 1.0
	
	# Mouse determines facing direction
	var mouse_pos: Vector2 = get_global_mouse_position()
	var new_facing: int = 1 if mouse_pos.x >= global_position.x else -1
	if new_facing != facing_direction:
		facing_direction = new_facing
	
	# Hopping execution
	if input_x != 0.0 and is_on_floor() and hop_cooldown <= 0.0:
		_perform_hop(input_x)

func _process_player_weapon(delta: float) -> void:
	if not shoulder_pivot:
		return
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_pos - shoulder_pivot.global_position
	var target_angle: float = to_mouse.angle()
	
	# Adjust angle if flipped
	if facing_direction == -1:
		target_angle = PI - target_angle
	
	# Smoothly sweep arm to target mouse direction
	shoulder_pivot.rotation = rotate_toward(shoulder_pivot.rotation, target_angle, arm_rotation_speed * delta)

func _process_ai(delta: float) -> void:
	var target_combatant: Combatant = _find_opponent()
	if not target_combatant or not target_combatant.is_alive:
		return
	
	var to_target: Vector2 = target_combatant.global_position - global_position
	var dist: float = absf(to_target.x)
	
	# Face opponent
	facing_direction = 1 if to_target.x > 0.0 else -1
	
	# Hopping spacing logic
	if is_on_floor() and hop_cooldown <= 0.0 and not is_tripped:
		var desired_dir: float = 0.0
		if dist > 140.0:
			desired_dir = 1.0 if to_target.x > 0.0 else -1.0
		elif dist < 70.0:
			desired_dir = -1.0 if to_target.x > 0.0 else 1.0
		else:
			# In combat range, occasional unpredictable feint hop
			if randf() < 0.2:
				desired_dir = -1.0 if randf() < 0.5 else 1.0
		
		if desired_dir != 0.0:
			_perform_hop(desired_dir)
	
	# AI weapon swing towards opponent
	if shoulder_pivot:
		var aim_target: Vector2 = target_combatant.global_position
		# Aim randomly between head and torso
		aim_target.y += sin(Time.get_ticks_msec() * 0.005) * 30.0
		var to_aim: Vector2 = aim_target - shoulder_pivot.global_position
		var target_angle: float = to_aim.angle()
		if facing_direction == -1:
			target_angle = PI - target_angle
		shoulder_pivot.rotation = rotate_toward(shoulder_pivot.rotation, target_angle, arm_rotation_speed * 0.8 * delta)

func _perform_hop(dir_x: float) -> void:
	velocity.y = -hop_force_y
	velocity.x = dir_x * hop_force_x
	hop_cooldown = 0.28 # Rhythmic hop cadence
	
	# Squash visual anticipation
	_squash_scale = Vector2(0.85, 1.25)
	
	# Slight forward lurch rotation
	rotation = deg_to_rad(dir_x * 8.0)

func receive_hit(amount: float, zone_name: String, hit_dir: Vector2, swing_speed: float, attacker: Node2D) -> void:
	if not is_alive:
		return
	
	current_health = maxf(0.0, current_health - amount)
	
	# Directional knockback
	var knockback_strength: float = 120.0 + minf(swing_speed * 0.25, 250.0)
	velocity += hit_dir * knockback_strength
	velocity.y = -150.0 # Small pop up
	
	# Zone-specific impact reactions
	match zone_name:
		"HEAD":
			# Severe head snap & critical stagger
			rotation = deg_to_rad(-hit_dir.x * 25.0)
			_squash_scale = Vector2(1.3, 0.7)
			_trigger_camera_shake(0.65)
		"TORSO":
			# Push back
			rotation = deg_to_rad(-hit_dir.x * 15.0)
			_squash_scale = Vector2(1.15, 0.85)
			_trigger_camera_shake(0.35)
		"LEGS":
			# Trip! Disrupts hopping
			is_tripped = true
			trip_time_left = 0.55
			rotation = deg_to_rad(-hit_dir.x * 35.0)
			_squash_scale = Vector2(0.7, 1.3)
			_trigger_camera_shake(0.25)
	
	# Hit flash visual
	_flash_white()
	
	# Spawn damage numbers and hit sparks
	_spawn_damage_indicator(amount, zone_name)
	VFXSpawner.spawn_hit_impact(get_tree(), global_position, hit_dir, zone_name)
	
	took_damage.emit(amount, zone_name, current_health, max_health)
	
	if current_health <= 0.0:
		_die()

func _on_weapon_hit_connected(target: Node2D, zone: String, damage: float, pos: Vector2, normal: Vector2 = Vector2.ZERO) -> void:
	landed_hit.emit(target, zone, damage, pos, normal)

func _flash_white() -> void:
	if visual_root:
		visual_root.modulate = Color(2.5, 2.5, 2.5, 1.0)
		var tween := create_tween()
		tween.tween_property(visual_root, "modulate", Color.WHITE, 0.1)

func _on_flash_timeout() -> void:
	if visual_root:
		visual_root.modulate = Color.WHITE

func _trigger_camera_shake(trauma: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(trauma)

func _spawn_damage_indicator(amount: float, zone_name: String) -> void:
	var label := Label.new()
	label.text = "%d %s" % [int(amount), zone_name]
	label.position = global_position + Vector2(randf_range(-20, 20), -60)
	label.z_index = 50
	
	# Style label
	var color := Color.WHITE
	if zone_name == "HEAD":
		color = Color(1.0, 0.8, 0.2) # Gold crit
		label.text = "CRIT! " + label.text
	elif zone_name == "LEGS":
		color = Color(0.4, 0.9, 1.0) # Blue trip
		label.text = "TRIP! " + label.text
	else:
		color = Color(1.0, 0.3, 0.3) # Red standard
	
	label.modulate = color
	get_parent().add_child(label)
	
	# Floating animation & destroy
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 45.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

func _die() -> void:
	is_alive = false
	rotation = deg_to_rad(85.0 * facing_direction)
	if visual_root:
		visual_root.modulate = Color(0.6, 0.6, 0.6, 0.8)
	defeated.emit()

func _find_opponent() -> CharacterBody2D:
	for node in get_tree().get_nodes_in_group(&"combatants"):
		if node is CharacterBody2D and node != self and node.get("is_alive") == true:
			return node
	return null
