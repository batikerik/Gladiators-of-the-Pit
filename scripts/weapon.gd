class_name Weapon
extends Area2D

signal hit_connected(target: Node2D, zone: String, damage: float, hit_pos: Vector2, hit_normal: Vector2)
signal clash_occurred(other_weapon: Area2D, pos: Vector2)
signal strike_started(charge_ratio: float, strike_angle: float)
signal strike_whiffed()
signal recovery_ended()

# ── Tunables ────────────────────────────────────────────────────────────────
@export var weapon_name: String = "Rusty Gladius"
@export var base_damage: float = 18.0

@export_group("Slash (hold LMB)")
@export var max_charge_time: float = 0.9     # Seconds to reach full charge
@export var full_charge_damage_mult: float = 2.4  # Damage multiplier at max charge
@export var heavy_threshold: float = 0.85    # Charge ratio at which a slash breaks guard
@export var strike_duration: float = 0.18    # How long the strike arc lasts
@export var whiff_recovery: float = 0.32     # Open/vulnerable frames after a miss
@export var hit_recovery: float = 0.12       # Brief pause after landing a hit
## A slash sweeps down from the wind-up, passing the head first. Contacts count
## only once the blade is within this angle (radians) of its lane, so the aimed
## zone is the one hit.
@export var slash_active_angle: float = 0.2

@export_group("Thrust (RMB)")
@export var thrust_windup_time: float = 0.12 # Fixed short pull-back before the stab
@export var thrust_duration: float = 0.12
@export var thrust_reach: float = 26.0       # How far the blade extends forward
@export var thrust_pullback: float = 10.0
@export var thrust_damage_mult: float = 1.1
@export var thrust_whiff_recovery: float = 0.4
@export var thrust_hit_recovery: float = 0.15

@export_group("Guard (S / Shift)")
@export var parry_window: float = 0.15       # First seconds of a raised guard count as a parry
@export var guard_rearm_time: float = 0.3    # Lowering the guard locks it briefly (no parry spam)
@export var block_damage_mult: float = 0.2
@export var guard_break_damage_mult: float = 0.35
@export var block_recoil: float = 0.35       # Attacker recovery after hitting a guard
@export var parried_stun: float = 0.6        # Attacker recovery + stagger after being parried

@export_group("Misc")
@export var counter_hit_mult: float = 1.5    # Hitting a charging or staggered opponent
@export var clash_knockback: float = 320.0   # How hard blades bounce apart on clash

# ── State ────────────────────────────────────────────────────────────────────
enum SwingState { IDLE, CHARGING, STRIKING, RECOVERY, GUARD }
enum StrikeKind { SLASH, THRUST }
enum Defense { NONE, BLOCKED, PARRIED, GUARD_BROKEN }

var state: SwingState = SwingState.IDLE
var strike_kind: StrikeKind = StrikeKind.SLASH

var _charge_timer: float = 0.0
var _strike_timer: float = 0.0
var _recovery_timer: float = 0.0
var _charge_ratio: float = 0.0          # 0..1, how charged is the swing
var _strike_start_angle: float = 0.0   # Shoulder angle when swing began
var _strike_target_angle: float = 0.0  # Angle to swing toward
var _hit_this_strike: bool = false      # Did we land a hit during this swing arc?
var _victims_this_strike: Array = []    # Each target can be hit once per strike
var _clashed_this_strike: bool = false
var _guard_time: float = 0.0            # How long the guard has been up
var _guard_lock: float = 0.0            # Time until the guard can be raised again
var current_tip_speed: float = 0.0     # Readable by AI

# Strike lane: angle (local shoulder-pivot) determining HIGH/MID/LOW
const LANE_HIGH_ANGLE: float = -0.52   # ≈ -30° (head level)
const LANE_MID_ANGLE:  float =  0.10   # ≈   6° (torso level)
const LANE_LOW_ANGLE:  float =  0.55   # ≈ +32° (legs level)
const GUARD_ANGLE: float = -1.15       # Blade raised up-forward across the body
const THRUST_MAX_ANGLE: float = 0.9    # Thrusts aim freely inside ±52°

# Visual
@onready var tip_marker: Marker2D = $TipMarker
@onready var trail_line: Line2D = get_node_or_null("TrailLine")

var owner_combatant: Node2D = null
var _prev_tip_pos: Vector2 = Vector2.ZERO
var _facing: int = 1   # synced from combatant each frame

func _ready() -> void:
	if tip_marker:
		_prev_tip_pos = tip_marker.global_position

func _physics_process(delta: float) -> void:
	_update_tip_speed(delta)
	_guard_lock = maxf(0.0, _guard_lock - delta)
	# AI-controlled weapons tick their own state machine; the player's weapon
	# is ticked by Combatant through weapon_physics_update().
	if owner_combatant and not owner_combatant.get("is_player"):
		_facing = int(owner_combatant.get("facing_direction"))
		match state:
			SwingState.CHARGING:
				_tick_charging(delta)
				if strike_kind == StrikeKind.THRUST and _charge_timer >= thrust_windup_time:
					_release_thrust()
			SwingState.STRIKING:
				_tick_striking(delta)
			SwingState.RECOVERY:
				_tick_recovery(delta)
			SwingState.GUARD:
				_tick_guard(delta)
	_update_trail()

# ── Called by Combatant every physics frame (player only) ────────────────────
func weapon_physics_update(delta: float, facing: int, _shoulder: Node2D,
		mouse_world_pos: Vector2, hold_down: bool,
		thrust_pressed: bool = false, guard_held: bool = false) -> void:
	_facing = facing

	match state:
		SwingState.IDLE:
			if guard_held:
				raise_guard()
			elif thrust_pressed:
				_begin_thrust(mouse_world_pos)
			elif hold_down:
				_begin_charge(mouse_world_pos)

		SwingState.GUARD:
			_tick_guard(delta)
			if not guard_held:
				lower_guard()

		SwingState.CHARGING:
			_tick_charging(delta)
			if strike_kind == StrikeKind.THRUST:
				if _charge_timer >= thrust_windup_time:
					_release_thrust()
			elif not hold_down:
				_release_slash(_angle_to_lane(mouse_world_pos))

		SwingState.STRIKING:
			_tick_striking(delta)

		SwingState.RECOVERY:
			_tick_recovery(delta)

# ── AI interface ─────────────────────────────────────────────────────────────
func ai_start_charge() -> void:
	if state == SwingState.IDLE:
		strike_kind = StrikeKind.SLASH
		_charge_timer = 0.0
		_charge_ratio = 0.0
		state = SwingState.CHARGING

func ai_release(_shoulder: Node2D, target_angle: float) -> void:
	if state != SwingState.CHARGING or strike_kind != StrikeKind.SLASH:
		return
	_release_slash(target_angle)

func ai_start_thrust(target_world_pos: Vector2) -> void:
	if state == SwingState.IDLE:
		_begin_thrust(target_world_pos)

func ai_cancel(_shoulder: Node2D = null) -> void:
	interrupt()

func ai_guard(up: bool) -> void:
	if up and state == SwingState.IDLE:
		raise_guard()
	elif not up and state == SwingState.GUARD:
		lower_guard()

# ── Queries ──────────────────────────────────────────────────────────────────
func is_idle() -> bool:
	return state == SwingState.IDLE

func is_in_recovery() -> bool:
	return state == SwingState.RECOVERY

func is_guarding() -> bool:
	return state == SwingState.GUARD

func is_parry_window() -> bool:
	return state == SwingState.GUARD and _guard_time <= parry_window

func is_heavy() -> bool:
	return strike_kind == StrikeKind.SLASH and _charge_ratio >= heavy_threshold

func get_charge_ratio() -> float:
	return _charge_ratio

# ── External state changes (from Combatant / other weapons) ─────────────────
func raise_guard() -> bool:
	if _guard_lock > 0.0 or state != SwingState.IDLE:
		return false
	state = SwingState.GUARD
	_guard_time = 0.0
	return true

func lower_guard() -> void:
	if state == SwingState.GUARD:
		state = SwingState.IDLE
		_guard_lock = guard_rearm_time

func break_guard(lock_time: float) -> void:
	state = SwingState.IDLE
	_guard_lock = lock_time

## Cancel whatever the weapon is doing (stagger, counter-hit, death).
func interrupt() -> void:
	state = SwingState.IDLE
	_charge_timer = 0.0
	_charge_ratio = 0.0
	position.x = 0.0

func force_recovery(duration: float) -> void:
	_charge_ratio = 0.0
	_recovery_timer = duration
	state = SwingState.RECOVERY

# ── Private: state entry ─────────────────────────────────────────────────────
func _shoulder() -> Node2D:
	return get_parent() as Node2D

func _begin_charge(aim_world_pos: Vector2) -> void:
	strike_kind = StrikeKind.SLASH
	_charge_timer = 0.0
	_charge_ratio = 0.0
	state = SwingState.CHARGING
	# Snap arm toward the aim point at charge start so the player "picks" a lane
	_shoulder().rotation = _local_aim_angle(aim_world_pos)

func _begin_thrust(aim_world_pos: Vector2) -> void:
	strike_kind = StrikeKind.THRUST
	_charge_timer = 0.0
	_charge_ratio = 0.0
	_strike_target_angle = clampf(_local_aim_angle(aim_world_pos), -THRUST_MAX_ANGLE, THRUST_MAX_ANGLE)
	state = SwingState.CHARGING

func _release_slash(target_angle: float) -> void:
	_charge_ratio = clampf(_charge_timer / max_charge_time, 0.0, 1.0)
	_strike_target_angle = target_angle
	_strike_start_angle = _shoulder().rotation
	_start_strike(strike_duration)

func _release_thrust() -> void:
	_strike_start_angle = _strike_target_angle
	_start_strike(thrust_duration)

func _start_strike(duration: float) -> void:
	_hit_this_strike = false
	_clashed_this_strike = false
	_victims_this_strike.clear()
	_strike_timer = duration
	state = SwingState.STRIKING
	strike_started.emit(_charge_ratio, _strike_target_angle)

func _enter_recovery(duration: float) -> void:
	_recovery_timer = duration
	state = SwingState.RECOVERY

# ── Private: per-state ticks ────────────────────────────────────────────────
func _tick_charging(delta: float) -> void:
	_charge_timer += delta
	var sp := _shoulder()
	if strike_kind == StrikeKind.THRUST:
		# Short, readable pull-back along the aim line
		sp.rotation = rotate_toward(sp.rotation, _strike_target_angle, 30.0 * delta)
		position.x = move_toward(position.x, -thrust_pullback, 200.0 * delta)
		return
	_charge_ratio = clampf(_charge_timer / max_charge_time, 0.0, 1.0)
	# Pull weapon behind the body as a clear telegraph
	var windup_angle: float = -PI * 0.55 if _facing == 1 else -PI * 0.45
	var pull_speed: float = 22.0 + _charge_ratio * 12.0
	sp.rotation = rotate_toward(sp.rotation, windup_angle, pull_speed * delta)

func _tick_striking(delta: float) -> void:
	_strike_timer -= delta
	var duration: float = thrust_duration if strike_kind == StrikeKind.THRUST else strike_duration
	# Clamp: on the last frame _strike_timer goes negative, and pow() of a
	# negative base returns NaN, which permanently hides the weapon.
	var t: float = clampf(1.0 - (_strike_timer / duration), 0.0, 1.0)
	var ease_t: float = 1.0 - pow(1.0 - t, 2.5)   # fast start, settles at target
	if strike_kind == StrikeKind.THRUST:
		_shoulder().rotation = _strike_target_angle
		position.x = lerpf(-thrust_pullback, thrust_reach, ease_t)
	else:
		_shoulder().rotation = lerpf(_strike_start_angle, _strike_target_angle, ease_t)

	if strike_kind == StrikeKind.THRUST \
			or absf(_shoulder().rotation - _strike_target_angle) <= slash_active_angle:
		_scan_contacts()
	if state != SwingState.STRIKING:
		return   # a clash / parry already moved us out of the strike

	if _strike_timer <= 0.0:
		var thrust := strike_kind == StrikeKind.THRUST
		if not _hit_this_strike:
			_enter_recovery(thrust_whiff_recovery if thrust else whiff_recovery)
			strike_whiffed.emit()
		else:
			_enter_recovery(thrust_hit_recovery if thrust else hit_recovery)

func _tick_recovery(delta: float) -> void:
	_recovery_timer -= delta
	var sp := _shoulder()
	sp.rotation = rotate_toward(sp.rotation, LANE_MID_ANGLE, 14.0 * delta)
	position.x = move_toward(position.x, 0.0, 160.0 * delta)
	if _recovery_timer <= 0.0:
		interrupt()
		recovery_ended.emit()

func _tick_guard(delta: float) -> void:
	_guard_time += delta
	var sp := _shoulder()
	sp.rotation = rotate_toward(sp.rotation, GUARD_ANGLE, 28.0 * delta)
	position.x = move_toward(position.x, 0.0, 200.0 * delta)

# ── Private: aiming ──────────────────────────────────────────────────────────
## Angle from the shoulder to a world point, in the shoulder's local
## (facing-mirrored) space, wrapped to -PI..PI.
func _local_aim_angle(world_pos: Vector2) -> float:
	var angle: float = (world_pos - _shoulder().global_position).angle()
	if _facing == -1:
		angle = PI - angle
	return wrapf(angle, -PI, PI)

func _angle_to_lane(world_pos: Vector2) -> float:
	var local_angle := _local_aim_angle(world_pos)
	var high_dist := absf(local_angle - LANE_HIGH_ANGLE)
	var mid_dist  := absf(local_angle - LANE_MID_ANGLE)
	var low_dist  := absf(local_angle - LANE_LOW_ANGLE)
	if high_dist < mid_dist and high_dist < low_dist:
		return LANE_HIGH_ANGLE
	elif low_dist < mid_dist:
		return LANE_LOW_ANGLE
	return LANE_MID_ANGLE

# ── Private: contacts ────────────────────────────────────────────────────────
## Checked every strike frame (not only on area_entered), so a blade that is
## already touching the target when the strike starts still connects.
func _scan_contacts() -> void:
	# The blade can overlap several zones of one body at once (head + torso).
	# A slash prefers the zone of its lane; otherwise the zone nearest the tip wins.
	var tip: Vector2 = tip_marker.global_position if tip_marker else global_position
	var aimed_zone: String = _lane_zone() if strike_kind == StrikeKind.SLASH else ""
	var best_per_victim: Dictionary = {}   # victim -> hurtbox
	for area in get_overlapping_areas():
		if area is Weapon and area != self:
			var other := area as Weapon
			if other.state == SwingState.STRIKING and not _clashed_this_strike:
				_handle_clash(other)
				return
		elif area.is_in_group(&"hurtbox"):
			var victim: Variant = area.get("parent_combatant")
			var current: Area2D = best_per_victim.get(victim)
			if current == null:
				best_per_victim[victim] = area
				continue
			var area_aimed: bool = str(area.get_meta("zone", "")) == aimed_zone
			var current_aimed: bool = str(current.get_meta("zone", "")) == aimed_zone
			if area_aimed != current_aimed:
				if area_aimed:
					best_per_victim[victim] = area
			elif area.global_position.distance_to(tip) < current.global_position.distance_to(tip):
				best_per_victim[victim] = area
	for hurtbox in best_per_victim.values():
		if state != SwingState.STRIKING:
			return
		_try_hit(hurtbox)

func _lane_zone() -> String:
	if is_equal_approx(_strike_target_angle, LANE_HIGH_ANGLE):
		return "HEAD"
	if is_equal_approx(_strike_target_angle, LANE_LOW_ANGLE):
		return "LEGS"
	return "TORSO"

func _try_hit(hurtbox: Area2D) -> void:
	var victim: Node2D = hurtbox.get("parent_combatant")
	if victim == null:
		victim = hurtbox.owner if hurtbox.owner else hurtbox.get_parent()
	if victim == owner_combatant or victim in _victims_this_strike:
		return
	if victim.get("is_alive") == false:
		return
	_victims_this_strike.append(victim)

	var zone_name: String = str(hurtbox.get_meta("zone", "TORSO"))
	var zone_mult: float = float(hurtbox.get_meta("multiplier", 1.0))
	var kind_mult: float = thrust_damage_mult if strike_kind == StrikeKind.THRUST \
		else lerpf(0.4, full_charge_damage_mult, _charge_ratio)
	var damage: float = base_damage * kind_mult * zone_mult
	if owner_combatant and owner_combatant.has_method("get_combo_multiplier"):
		damage *= owner_combatant.get_combo_multiplier()

	var hit_pos: Vector2 = tip_marker.global_position if tip_marker else global_position
	var hit_normal: Vector2 = (victim.global_position - owner_combatant.global_position).normalized()
	if hit_normal.is_zero_approx():
		hit_normal = Vector2.RIGHT * _facing

	var tags: Array[String] = []

	# Sample the victim's state before defense: a guard break staggers the
	# victim, and that same hit must not also count as a counter.
	var victim_weapon := victim.get("weapon") as Weapon
	var victim_charging: bool = victim_weapon != null and victim_weapon.state == SwingState.CHARGING
	var victim_staggered: bool = victim.has_method("is_staggered") and bool(victim.call("is_staggered"))

	# Defense first: a guard facing us can block, parry or be broken
	var defense: int = Defense.NONE
	if victim.has_method("try_defend"):
		defense = victim.try_defend(owner_combatant, is_heavy())
	match defense:
		Defense.PARRIED:
			VFXSpawner.spawn_sparks(get_tree(), hit_pos, -hit_normal, Color(1.0, 0.95, 0.6), 22)
			if owner_combatant and owner_combatant.has_method("stagger"):
				owner_combatant.stagger(parried_stun)
			force_recovery(parried_stun)
			return
		Defense.BLOCKED:
			damage *= block_damage_mult
			tags.append("BLOCK")
			VFXSpawner.spawn_sparks(get_tree(), hit_pos, -hit_normal, Color(0.8, 0.85, 0.9), 12)
			_hit_this_strike = true
			if victim.has_method("receive_hit"):
				victim.receive_hit(damage, zone_name, hit_normal, current_tip_speed * 0.3, owner_combatant, tags)
			force_recovery(block_recoil)
			return
		Defense.GUARD_BROKEN:
			damage *= guard_break_damage_mult
			tags.append("GUARD BREAK")

	# Counter-hit: catching the opponent mid wind-up or while staggered
	if victim_charging or victim_staggered:
		damage *= counter_hit_mult
		tags.append("COUNTER")
		if victim_weapon:
			victim_weapon.interrupt()

	_hit_this_strike = true
	hit_connected.emit(victim, zone_name, damage, hit_pos, hit_normal)
	if victim.has_method("receive_hit"):
		victim.receive_hit(damage, zone_name, hit_normal, current_tip_speed, owner_combatant, tags)

func _handle_clash(other_weapon: Weapon) -> void:
	var pos: Vector2 = tip_marker.global_position if tip_marker else global_position
	clash_occurred.emit(other_weapon, pos)
	_bounce_off_clash()
	# Both blades bounce: the other weapon would no longer see us as STRIKING
	if other_weapon.state == SwingState.STRIKING and not other_weapon._clashed_this_strike:
		other_weapon._bounce_off_clash()

func _bounce_off_clash() -> void:
	_clashed_this_strike = true
	if owner_combatant and owner_combatant.has_method("receive_clash"):
		owner_combatant.receive_clash(clash_knockback)
	force_recovery(0.28)

# ── Private: misc ────────────────────────────────────────────────────────────
func _update_tip_speed(delta: float) -> void:
	if tip_marker and delta > 0.0:
		var cur := tip_marker.global_position
		current_tip_speed = _prev_tip_pos.distance_to(cur) / delta
		_prev_tip_pos = cur
	else:
		current_tip_speed = 0.0

func _update_trail() -> void:
	if not trail_line or not tip_marker:
		return
	if state == SwingState.STRIKING and current_tip_speed > 200.0:
		trail_line.add_point(tip_marker.global_position)
		if trail_line.get_point_count() > 10:
			trail_line.remove_point(0)
	elif trail_line.get_point_count() > 0:
		trail_line.remove_point(0)
