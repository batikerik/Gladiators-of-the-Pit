class_name Combatant
extends CharacterBody2D

signal took_damage(amount: float, zone: String, current_hp: float, max_hp: float)
signal landed_hit(target: Node2D, zone: String, damage: float, pos: Vector2, normal: Vector2)
signal defeated

# ── Inspector ────────────────────────────────────────────────────────────────
@export var is_player: bool = true
@export var character_name: String = "Gladiator"
@export var max_health: float = 100.0
@export var hop_force_y: float = 260.0
@export var hop_force_x: float = 160.0
@export var gravity: float = 1400.0
@export var balance_spring: float = 20.0
@export var ai_aggression: float = 1.0
@export var is_zombie: bool = false
@export var armor_tier: int = 1

@export_group("Combo")
@export var combo_window: float = 1.5        # Seconds between hits to keep the chain
@export var combo_step_bonus: float = 0.15   # +15% damage per chained hit
@export var combo_max_steps: int = 3

@export_group("Guard")
@export var guard_break_stagger: float = 0.5
@export var guard_break_lock: float = 0.8    # Guard cannot be raised again for this long

# ── AI State Machine ─────────────────────────────────────────────────────────
enum AIState { APPROACH, FOOTSIE, CHARGING, RETREAT, GUARDING }
var _ai_state: AIState = AIState.APPROACH
var _ai_timer: float = 0.0
var _ai_dodge_cooldown: float = 0.0
var _ai_attack_cooldown: float = 0.6
var _ai_guard_cooldown: float = 0.0
var _ai_charge_target_angle: float = 0.0

# ── Runtime ──────────────────────────────────────────────────────────────────
var current_health: float = 100.0
var is_alive: bool = true
var is_tripped: bool = false
var trip_time_left: float = 0.0
var hop_cooldown: float = 0.0
var facing_direction: int = 1   # 1 = right, -1 = left

# Stagger: clash bounce, parried, guard broken. Blocks input and opens us to counters.
var _stagger_timer: float = 0.0

# Combo chain of landed hits
var _combo_count: int = 0
var _combo_timer: float = 0.0

# ── Nodes ────────────────────────────────────────────────────────────────────
@onready var visual_root: Node2D = $VisualRoot
@onready var shoulder_pivot: Node2D = $VisualRoot/ShoulderPivot
@onready var weapon: Weapon = $VisualRoot/ShoulderPivot/Weapon

# Visual
var _squash_scale: Vector2 = Vector2.ONE

# HUD charge indicator (created dynamically)
var _charge_bar: ColorRect = null
var _charge_bar_bg: ColorRect = null

# Edge detection for keys/buttons polled without InputMap
var _prev_key_a: bool = false
var _prev_key_d: bool = false
var _prev_rmb: bool = false

func _ready() -> void:
	current_health = max_health
	add_to_group(&"combatants")

	if visual_root and visual_root.has_node("Puppet"):
		var puppet: Node2D = visual_root.get_node("Puppet")
		puppet.set("is_zombie", is_zombie)
		puppet.set("armor_tier", armor_tier)

	if weapon:
		weapon.owner_combatant = self
		weapon.hit_connected.connect(_on_weapon_hit_connected)
		weapon.clash_occurred.connect(_on_clash)
		weapon.add_to_group(&"weapon_hitbox")

	if is_player:
		_create_charge_bar()

# ── Physics ───────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Ground friction — stops quickly
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	# Trip recovery
	if is_tripped:
		trip_time_left -= delta
		if trip_time_left <= 0.0:
			is_tripped = false

	_stagger_timer = maxf(0.0, _stagger_timer - delta)
	hop_cooldown = maxf(0.0, hop_cooldown - delta)

	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo_count = 0

	if is_player:
		_process_player_input(delta)
		_process_player_weapon(delta)
	else:
		_process_ai(delta)

	# Body tilt
	var target_rot: float = 0.0
	if is_tripped:
		target_rot = deg_to_rad(38.0 * facing_direction)
	elif _stagger_timer > 0.0:
		target_rot = deg_to_rad(-10.0 * facing_direction)
	elif not is_on_floor():
		target_rot = clampf(velocity.x * 0.0008, -0.35, 0.35)
	rotation = lerpf(rotation, target_rot, balance_spring * delta)

	# Squash & stretch
	if visual_root:
		_squash_scale = _squash_scale.lerp(Vector2.ONE, 12.0 * delta)
		visual_root.scale = Vector2(facing_direction * absf(_squash_scale.x), _squash_scale.y)

	move_and_slide()

# ── Player input ──────────────────────────────────────────────────────────────
func _process_player_input(_delta: float) -> void:
	if is_tripped or _stagger_timer > 0.0:
		return

	# Facing: follow mouse
	var mouse_pos: Vector2 = get_global_mouse_position()
	facing_direction = 1 if mouse_pos.x >= global_position.x else -1

	# Guarding plants your feet
	if weapon and weapon.is_guarding():
		return

	# Hop on single press — A/D or arrow keys
	# Hopping is intentional & directional, not held
	if Input.is_action_just_pressed("ui_left") or (Input.is_key_pressed(KEY_A) and not _prev_key_a):
		if is_on_floor() and hop_cooldown <= 0.0:
			_perform_hop(-1.0)
	if Input.is_action_just_pressed("ui_right") or (Input.is_key_pressed(KEY_D) and not _prev_key_d):
		if is_on_floor() and hop_cooldown <= 0.0:
			_perform_hop(1.0)

func _process(_delta: float) -> void:
	# Track key state for just_pressed emulation without InputMap
	_prev_key_a = Input.is_key_pressed(KEY_A)
	_prev_key_d = Input.is_key_pressed(KEY_D)
	_update_charge_bar()

func _process_player_weapon(delta: float) -> void:
	if not shoulder_pivot or not weapon:
		return

	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var thrust_pressed := rmb and not _prev_rmb
	_prev_rmb = rmb

	var mouse_pos: Vector2 = get_global_mouse_position()
	var hold := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var guard := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SHIFT) \
		or Input.is_action_pressed("ui_down")
	# Still tick the weapon (recovery must run out), but accept no new commands
	if is_tripped or _stagger_timer > 0.0:
		hold = false
		thrust_pressed = false
		guard = false
	weapon.weapon_physics_update(delta, facing_direction, shoulder_pivot, mouse_pos,
		hold, thrust_pressed, guard)

# ── AI ────────────────────────────────────────────────────────────────────────
func _process_ai(delta: float) -> void:
	if not weapon:
		return

	var target: CharacterBody2D = _find_opponent()
	if not target or target.get("is_alive") != true:
		weapon.ai_guard(false)
		return

	var w: Weapon = weapon
	var tw: Weapon = target.get("weapon") as Weapon

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = absf(to_target.x)
	var toward: float = 1.0 if to_target.x > 0.0 else -1.0
	facing_direction = int(toward)

	_ai_timer -= delta
	_ai_dodge_cooldown = maxf(0.0, _ai_dodge_cooldown - delta)
	_ai_attack_cooldown = maxf(0.0, _ai_attack_cooldown - delta)
	_ai_guard_cooldown = maxf(0.0, _ai_guard_cooldown - delta)

	# Staggered or tripped: no decisions this frame
	if _stagger_timer > 0.0 or is_tripped:
		if _ai_state == AIState.GUARDING or _ai_state == AIState.CHARGING:
			_ai_state = AIState.FOOTSIE
		return

	# React to an incoming strike: snap-guard (likely parry), dodge, or eat it
	if tw and tw.state == Weapon.SwingState.STRIKING and dist < 140.0 \
			and _ai_dodge_cooldown <= 0.0 and _ai_state != AIState.GUARDING:
		_ai_dodge_cooldown = 0.7
		var roll := randf()
		if roll < 0.25 * ai_aggression:
			w.ai_cancel()
			if w.raise_guard():
				_ai_state = AIState.GUARDING
				_ai_timer = 0.45
		elif roll < 0.6 and is_on_floor() and hop_cooldown <= 0.0:
			w.ai_cancel()
			_perform_hop(-toward)
			_ai_state = AIState.RETREAT
			_ai_timer = 0.25

	# Anticipate a charging opponent by raising the guard early
	if tw and tw.state == Weapon.SwingState.CHARGING and dist < 170.0 and w.is_idle() \
			and _ai_guard_cooldown <= 0.0 \
			and (_ai_state == AIState.APPROACH or _ai_state == AIState.FOOTSIE):
		_ai_guard_cooldown = 1.2
		if randf() < 0.35 and w.raise_guard():
			_ai_state = AIState.GUARDING
			_ai_timer = randf_range(0.6, 1.0)

	# Punish a tripped or staggered opponent with a fast thrust to the head
	var target_open: bool = bool(target.get("is_tripped")) or target.is_staggered()
	if target_open and _ai_state == AIState.FOOTSIE and _ai_attack_cooldown <= 0.0 \
			and w.is_idle() and dist <= 145.0:
		w.ai_start_thrust(target.global_position + Vector2(0, -36))
		_ai_state = AIState.RETREAT
		_ai_timer = 0.45
		_ai_attack_cooldown = randf_range(0.4, 0.7)

	match _ai_state:
		AIState.APPROACH:
			if is_on_floor() and hop_cooldown <= 0.0:
				if dist > 120.0:
					_perform_hop(toward)
				else:
					_ai_state = AIState.FOOTSIE
					_ai_timer = randf_range(0.3, 0.6)
			if w.is_idle():
				shoulder_pivot.rotation = move_toward(
					shoulder_pivot.rotation, Weapon.LANE_MID_ANGLE, 12.0 * delta)

		AIState.FOOTSIE:
			# Space management — stay at ideal range
			if is_on_floor() and hop_cooldown <= 0.0:
				if dist < 65.0:
					_perform_hop(-toward)
				elif dist > 130.0:
					_perform_hop(toward)

			# Feinting guard — move weapon around to confuse
			if w.is_idle():
				var feint := sin(Time.get_ticks_msec() * 0.006) * 0.3 + Weapon.LANE_MID_ANGLE
				shoulder_pivot.rotation = lerpf(shoulder_pivot.rotation, feint, 8.0 * delta)

			if _ai_timer <= 0.0 and _ai_attack_cooldown <= 0.0 and w.is_idle():
				_ai_choose_attack(target, tw, dist, toward)

		AIState.CHARGING:
			if _ai_timer <= 0.0:
				w.ai_release(shoulder_pivot, _ai_charge_target_angle)
				_ai_state = AIState.RETREAT
				_ai_timer = randf_range(0.3, 0.55)
				_ai_attack_cooldown = randf_range(0.5, 0.9)
				if is_on_floor():
					_perform_hop(-toward)  # back off after strike

		AIState.RETREAT:
			if w.is_idle():
				shoulder_pivot.rotation = move_toward(
					shoulder_pivot.rotation, Weapon.LANE_MID_ANGLE, 18.0 * delta)
			if _ai_timer <= 0.0:
				_ai_state = AIState.FOOTSIE
				_ai_timer = randf_range(0.25, 0.5)

		AIState.GUARDING:
			var opening: bool = tw != null and tw.is_in_recovery()
			if opening and dist <= 145.0:
				# Riposte: the attacker is stuck in recovery
				w.ai_guard(false)
				w.ai_start_thrust(target.global_position + Vector2(0, -4))
				_ai_state = AIState.RETREAT
				_ai_timer = 0.4
				_ai_attack_cooldown = randf_range(0.4, 0.7)
			elif _ai_timer <= 0.0 or not w.is_guarding():
				w.ai_guard(false)
				_ai_state = AIState.FOOTSIE
				_ai_timer = randf_range(0.2, 0.4)

func _ai_choose_attack(target: Node2D, tw: Weapon, dist: float, toward: float) -> void:
	var w: Weapon = weapon
	# Thrust from mid range: fast, long reach, aimed at a random zone
	if dist >= 80.0 and dist <= 145.0 and randf() < 0.35:
		var zone_offsets: Array[Vector2] = [Vector2(0, -36), Vector2(0, -4), Vector2(0, 30)]
		w.ai_start_thrust(target.global_position + zone_offsets.pick_random())
		_ai_state = AIState.RETREAT
		_ai_timer = 0.5
		_ai_attack_cooldown = randf_range(0.5, 0.9)
		return

	if dist > 125.0:
		return

	var roll := randf()
	if roll < 0.35:
		_ai_charge_target_angle = Weapon.LANE_HIGH_ANGLE
	elif roll < 0.70:
		_ai_charge_target_angle = Weapon.LANE_MID_ANGLE
	else:
		_ai_charge_target_angle = Weapon.LANE_LOW_ANGLE

	_ai_state = AIState.CHARGING
	# A raised guard invites a fully charged, guard-breaking slash
	if tw and tw.is_guarding():
		_ai_timer = randf_range(0.8, 0.95)
	else:
		_ai_timer = randf_range(0.25, 0.55)
	w.ai_start_charge()
	if is_on_floor() and dist > 80.0:
		_perform_hop(toward)

# ── Hop ───────────────────────────────────────────────────────────────────────
func _perform_hop(dir_x: float) -> void:
	velocity.y = -hop_force_y
	velocity.x = dir_x * hop_force_x
	hop_cooldown = 0.28

	_squash_scale = Vector2(0.85, 1.22)
	rotation = deg_to_rad(dir_x * 6.0)

# ── Defense ───────────────────────────────────────────────────────────────────
## Called by the attacker's weapon before damage is applied.
func try_defend(attacker: Node2D, heavy: bool) -> int:
	if not weapon or not weapon.is_guarding() or not attacker:
		return Weapon.Defense.NONE
	# A guard only covers the side we are facing
	var from_side: int = 1 if attacker.global_position.x >= global_position.x else -1
	if from_side != facing_direction:
		return Weapon.Defense.NONE

	if weapon.is_parry_window():
		_spawn_popup("PARRY!", Color(1.0, 0.9, 0.3), 22)
		_trigger_camera_shake(0.35)
		VFXSpawner.apply_hitstop(get_tree(), 0.06)
		weapon.lower_guard()
		return Weapon.Defense.PARRIED

	if heavy:
		weapon.break_guard(guard_break_lock)
		stagger(guard_break_stagger)
		return Weapon.Defense.GUARD_BROKEN

	return Weapon.Defense.BLOCKED

func stagger(duration: float) -> void:
	_stagger_timer = maxf(_stagger_timer, duration)
	_squash_scale = Vector2(1.2, 0.8)
	if weapon:
		weapon.interrupt()

func is_staggered() -> bool:
	return _stagger_timer > 0.0

func get_combo_multiplier() -> float:
	return 1.0 + combo_step_bonus * mini(_combo_count, combo_max_steps)

# ── Hit reception ─────────────────────────────────────────────────────────────
func receive_hit(amount: float, zone_name: String, hit_dir: Vector2,
		swing_speed: float, _attacker: Node2D, tags: Array = []) -> void:
	if not is_alive:
		return

	current_health = maxf(0.0, current_health - amount)
	var blocked: bool = "BLOCK" in tags

	if blocked:
		# Guard held: slide back a little, no zone reaction
		velocity.x += hit_dir.x * 140.0
		_squash_scale = Vector2(1.1, 0.9)
		_trigger_camera_shake(0.15)
	else:
		_combo_count = 0   # getting hit breaks your own chain
		var knockback: float = 100.0 + minf(swing_speed * 0.2, 220.0)
		velocity += hit_dir * knockback
		velocity.y = -130.0

		match zone_name:
			"HEAD":
				rotation = deg_to_rad(-hit_dir.x * 28.0)
				_squash_scale = Vector2(1.35, 0.65)
				_trigger_camera_shake(0.7)
			"TORSO":
				rotation = deg_to_rad(-hit_dir.x * 15.0)
				_squash_scale = Vector2(1.18, 0.82)
				_trigger_camera_shake(0.38)
			"LEGS":
				is_tripped = true
				trip_time_left = 0.6
				rotation = deg_to_rad(-hit_dir.x * 38.0)
				_squash_scale = Vector2(0.7, 1.32)
				_trigger_camera_shake(0.28)
		if "COUNTER" in tags:
			_trigger_camera_shake(0.3)
		VFXSpawner.spawn_hit_impact(get_tree(), global_position, hit_dir, zone_name)

	_flash_white()
	_spawn_damage_indicator(amount, zone_name, tags)

	took_damage.emit(amount, zone_name, current_health, max_health)

	if current_health <= 0.0:
		_die()

func receive_clash(knockback_strength: float) -> void:
	_stagger_timer = maxf(_stagger_timer, 0.22)
	velocity.x -= facing_direction * knockback_strength * 0.5
	_squash_scale = Vector2(1.2, 0.8)
	_trigger_camera_shake(0.25)
	_flash_white()

# ── Charge bar (player only) ──────────────────────────────────────────────────
func _create_charge_bar() -> void:
	_charge_bar_bg = ColorRect.new()
	_charge_bar_bg.color = Color(0.15, 0.12, 0.1, 0.7)
	_charge_bar_bg.size = Vector2(40, 6)
	_charge_bar_bg.position = Vector2(-20, -90)
	_charge_bar_bg.z_index = 39
	add_child(_charge_bar_bg)

	_charge_bar = ColorRect.new()
	_charge_bar.color = Color(1.0, 0.75, 0.1, 0.85)
	_charge_bar.size = Vector2(0, 6)
	_charge_bar.position = Vector2(-20, -90)
	_charge_bar.z_index = 40
	add_child(_charge_bar)

func _update_charge_bar() -> void:
	if not _charge_bar or not weapon:
		return
	var charging: bool = weapon.state == Weapon.SwingState.CHARGING \
		and weapon.strike_kind == Weapon.StrikeKind.SLASH
	_charge_bar.visible = charging
	_charge_bar_bg.visible = charging
	var ratio: float = weapon.get_charge_ratio()
	_charge_bar.size.x = ratio * 40.0
	if weapon.is_heavy():
		# Full charge: this slash will break a guard
		_charge_bar.color = Color(1.0, 0.15, 0.1, 1.0)
	else:
		_charge_bar.color = Color(lerpf(0.4, 1.0, ratio), lerpf(0.8, 0.5, ratio), 0.1, 0.9)

# ── Signals & helpers ─────────────────────────────────────────────────────────
func _on_weapon_hit_connected(target: Node2D, zone: String, damage: float,
		pos: Vector2, normal: Vector2 = Vector2.ZERO) -> void:
	_combo_count += 1
	_combo_timer = combo_window
	if _combo_count >= 2:
		_spawn_popup("COMBO x%d" % _combo_count, Color(1.0, 0.6, 0.2), 16, Vector2(0, -95))
	landed_hit.emit(target, zone, damage, pos, normal)

func _on_clash(_other_weapon: Area2D, pos: Vector2) -> void:
	VFXSpawner.spawn_sparks(get_tree(), pos, Vector2.UP, Color(1.0, 0.85, 0.5), 18)
	_trigger_camera_shake(0.2)

func _flash_white() -> void:
	if visual_root:
		visual_root.modulate = Color(2.5, 2.5, 2.5, 1.0)
		create_tween().tween_property(visual_root, "modulate", Color.WHITE, 0.1)

func _trigger_camera_shake(trauma: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(trauma)

func _spawn_damage_indicator(amount: float, zone_name: String, tags: Array = []) -> void:
	var text := "%d" % int(amount)
	var color := Color(1.0, 0.4, 0.4)
	if "BLOCK" in tags:
		text = "BLOCK %d" % int(amount)
		color = Color(0.75, 0.8, 0.9)
	elif zone_name == "HEAD":
		text = "CRIT! %d" % int(amount)
		color = Color(1.0, 0.85, 0.2)
	elif zone_name == "LEGS":
		text = "TRIP! %d" % int(amount)
		color = Color(0.4, 0.9, 1.0)
	if "GUARD BREAK" in tags:
		text = "GUARD BREAK! " + text
		color = Color(1.0, 0.3, 0.1)
	if "COUNTER" in tags:
		text = "COUNTER! " + text
	_spawn_popup(text, color, 18)

func _spawn_popup(text: String, color: Color, font_size: int,
		offset: Vector2 = Vector2(0, -65)) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.position = global_position + offset + Vector2(randf_range(-18, 18), 0)
	label.z_index = 50
	label.add_theme_font_size_override("font_size", font_size)
	get_parent().add_child(label)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 48.0, 0.75)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.2)
	tw.chain().tween_callback(label.queue_free)

func _die() -> void:
	is_alive = false
	if weapon:
		weapon.interrupt()
	rotation = deg_to_rad(85.0 * facing_direction)
	if visual_root:
		visual_root.modulate = Color(0.6, 0.6, 0.6, 0.8)
	defeated.emit()

func _find_opponent() -> CharacterBody2D:
	for node in get_tree().get_nodes_in_group(&"combatants"):
		if node is CharacterBody2D and node != self and node.get("is_alive") == true:
			return node
	return null
