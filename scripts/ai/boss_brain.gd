class_name BossBrain
extends Node
## The Armoured Survivor. Added as a child of a Combatant, it replaces the
## standard AI (Combatant.brain).
##
## Phase 1 — "Stance": advances behind a raised guard, punishes the player's
##   recovery with a thrust, drops the guard only to swing when in range.
##   A fully charged slash breaks the stance; the head is the weak point
##   (the plate covers torso and legs).
## Phase 2 — "Rage" (at half health): hops in aggressively, chains 2–3
##   swings, and every few seconds does a telegraphed LEAP: crouch and roar,
##   jump at the player, land with a guard-breaking overhead. A dodged leap
##   leaves him open for almost a second.

signal phase_changed(phase: int)

enum Move { STANCE, ATTACK, COMBO, LEAP_WINDUP, LEAP_AIR, RECOVER }

@export var rage_at: float = 0.5            # share of health that triggers phase 2
@export var leap_windup: float = 0.45       # telegraph before the jump
@export var leap_cooldown_range := Vector2(4.0, 6.0)
@export var leap_recovery: float = 0.9      # opening after landing

var phase: int = 1
var move: Move = Move.STANCE
var body: Combatant

var _t: float = 0.6
var _leap_cd: float = 3.0
var _combo_left: int = 0
var _last_lane: float = Weapon.LANE_MID_ANGLE
var _left_ground: bool = false

func _ready() -> void:
	body = get_parent() as Combatant
	body.brain = self
	body.health_changed.connect(_on_health_changed)

func _on_health_changed(hp: float, max_hp: float) -> void:
	if phase == 1 and body.is_alive and hp <= max_hp * rage_at:
		_enter_rage()

func _enter_rage() -> void:
	phase = 2
	body.ai_aggression = 1.8
	body.hop_force_x *= 1.3
	body.say(tr("ENRAGED!"), Color(1.0, 0.25, 0.15))
	body._trigger_camera_shake(0.6)
	body.weapon.ai_guard(false)
	move = Move.RECOVER
	_t = 0.4
	_leap_cd = 0.0   # the first leap comes right after the roar
	phase_changed.emit(phase)

## Called by Combatant._process_ai every physics frame.
func tick(delta: float) -> void:
	var target := body._find_opponent() as Combatant
	var w := body.weapon
	if target == null or not target.is_alive:
		w.ai_guard(false)
		return
	var tw := target.weapon
	var dx: float = target.global_position.x - body.global_position.x
	var dist: float = absf(dx)
	var toward: float = signf(dx) if dx != 0.0 else 1.0
	if move != Move.LEAP_AIR:
		body.facing_direction = int(toward)

	_t -= delta
	_leap_cd -= delta

	# Knocked down or staggered: the opening the player worked for
	if body.is_tripped or body.is_staggered():
		if move == Move.LEAP_WINDUP or move == Move.ATTACK or move == Move.COMBO:
			move = Move.RECOVER
			_t = 0.3
		return

	match move:
		Move.STANCE:
			_tick_stance(target, tw, dist, toward)
		Move.ATTACK, Move.COMBO:
			if w.state == Weapon.SwingState.CHARGING:
				if _t <= 0.0:
					w.ai_release(body.shoulder_pivot, _last_lane)
			elif w.state == Weapon.SwingState.STRIKING:
				pass
			elif _combo_left > 0:
				# Wait out the swing's recovery, then chain the next one
				if w.is_idle():
					if dist <= w.slash_range() + 20.0:
						_combo_left -= 1
						_start_swing(target, tw, 0.12, true)   # quick follow-up
					else:
						_combo_left = 0
			else:
				move = Move.RECOVER
				_t = 0.6 if phase == 1 else 0.3
		Move.LEAP_WINDUP:
			body._squash_scale = Vector2(1.25, 0.75)   # crouch
			if _t <= 0.0:
				# Jump so the arc lands on the player
				var jump_speed := 520.0
				body.velocity.y = -jump_speed
				var air_time: float = 2.0 * jump_speed / body.gravity
				body.velocity.x = clampf(dx / air_time, -560.0, 560.0)
				_left_ground = false
				move = Move.LEAP_AIR
				_t = 2.0   # safety: never hang in this state
		Move.LEAP_AIR:
			if not body.is_on_floor():
				_left_ground = true
			elif _left_ground or _t <= 0.0:
				# Landing: the overhead comes down, fully charged (breaks a guard)
				body._trigger_camera_shake(0.8)
				VFXSpawner.spawn_sparks(body.get_tree(), body.global_position + Vector2(0, 48), Vector2.UP,
					Color(0.55, 0.47, 0.38), 26)
				w.ai_release(body.shoulder_pivot, Weapon.LANE_MID_ANGLE)
				move = Move.RECOVER
				_t = leap_recovery
		Move.RECOVER:
			if w.is_guarding():
				w.ai_guard(false)
			if _t <= 0.0 and (w.is_idle() or w.is_guarding()):
				move = Move.STANCE
				_t = randf_range(1.0, 1.8) if phase == 1 else randf_range(0.2, 0.5)

func _tick_stance(target: Combatant, tw: Weapon, dist: float, toward: float) -> void:
	var w := body.weapon
	var reach := w.slash_range()

	# Phase 2: leap across the room when the player keeps distance
	if phase == 2 and _leap_cd <= 0.0 and dist > 150.0 and dist < 480.0 and body.is_on_floor() and w.is_idle():
		_leap_cd = randf_range(leap_cooldown_range.x, leap_cooldown_range.y)
		move = Move.LEAP_WINDUP
		_t = leap_windup
		body.say(tr("Rrraagh!"), Color(1.0, 0.35, 0.2))
		w.ai_start_charge()   # the axe goes up during the crouch and the flight
		return

	# Punish: the player whiffed or got blocked and is stuck in recovery
	if tw and tw.is_in_recovery() and dist <= w.thrust_range() and (w.is_idle() or w.is_guarding()):
		w.ai_guard(false)
		w.ai_start_thrust(target.global_position + Vector2(0, -4))
		move = Move.RECOVER
		_t = 0.45
		return

	if phase == 1:
		# Advance behind the guard with short, heavy steps
		if w.is_idle():
			w.raise_guard()
		if body.is_on_floor() and body.hop_cooldown <= 0.0 and dist > reach - 10.0:
			body._perform_hop(toward)
			body.velocity.x *= 0.55
			body.hop_cooldown = 0.7
	else:
		# Rage: close in fast, guard only on reflex
		if tw and tw.state == Weapon.SwingState.STRIKING and dist < reach and w.is_idle() and randf() < 0.2:
			w.raise_guard()
		# A leap is about ready: hold position and let the thief keep his distance
		var leap_soon: bool = _leap_cd < 0.8 and dist > 150.0
		if body.is_on_floor() and body.hop_cooldown <= 0.0 and dist > reach - 15.0 and not leap_soon:
			body._perform_hop(toward)
			body.hop_cooldown = 0.3

	if _t <= 0.0 and dist <= reach:
		_combo_left = 0 if phase == 1 else randi_range(1, 2)
		_start_swing(target, tw, -1.0, false)

## Drop the guard and wind up a slash. charge < 0 = pick by situation.
func _start_swing(target: Combatant, tw: Weapon, charge: float, is_combo: bool) -> void:
	var w := body.weapon
	w.ai_guard(false)
	if charge < 0.0:
		if tw and tw.is_guarding():
			charge = w.max_charge_time * w.heavy_threshold + 0.08   # break that guard
		else:
			charge = randf_range(0.3, 0.55) if phase == 1 else randf_range(0.18, 0.35)
	# Tripped player: go for the head; combos alternate lanes
	var lanes: Array[float] = [Weapon.LANE_HIGH_ANGLE, Weapon.LANE_MID_ANGLE, Weapon.LANE_LOW_ANGLE]
	if target.is_tripped:
		_last_lane = Weapon.LANE_HIGH_ANGLE
	elif is_combo:
		lanes.erase(_last_lane)
		_last_lane = lanes[randi_range(0, lanes.size() - 1)]
	else:
		_last_lane = lanes[randi_range(0, lanes.size() - 1)]
	w.ai_start_charge()
	move = Move.COMBO if is_combo else Move.ATTACK
	_t = charge
