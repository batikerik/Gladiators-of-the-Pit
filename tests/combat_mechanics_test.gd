extends Node
## Headless check of the combat moves: thrust, slash, block, parry, guard break,
## counter-hit, combo and the NaN regression. Both combatants are frozen
## (no AI, no player input) and commanded directly through the Weapon API.
##
## Run: Summer.exe --headless --path . res://tests/combat_mechanics_test.tscn

const MAIN := preload("res://main.tscn")

var _failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	# Tests assert English texts and must not touch the player's settings
	Settings.settings_path = "user://test_settings.cfg"
	Settings.language = "en"
	Settings.nickname = ""   # the player's real nickname must not leak into name checks
	Settings.apply()
	# Never touch the real legacy save: runs and corpses go to a scratch file
	RunState.legacy_path = "user://test_legacy.json"
	RunState.reset_legacy()
	await _test_thrust_hits()
	await _test_light_slash_hits()
	await _test_slash_lanes_hit_aimed_zone()
	await _test_block()
	await _test_parry()
	await _test_guard_break()
	await _test_counter_hit()
	await _test_combo()
	await _test_no_nan_after_strikes()
	print("COMBAT TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

# ── Setup helpers ────────────────────────────────────────────────────────────
## Fresh arena; A (player) faces right, B (opponent) stands `gap` px to the right facing left.
func _setup(gap: float) -> Array:
	# Free the previous arena (never the runner: it starts as current_scene)
	if get_tree().current_scene and get_tree().current_scene != self:
		get_tree().current_scene.free()
	var arena := MAIN.instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	var a: Combatant = arena.get_node("Player")
	var b: Combatant = arena.get_node("Opponent")
	for c in [a, b]:
		c.is_player = false            # weapon ticks itself
		c.set_physics_process(false)   # no AI decisions, no movement
	a.position = Vector2(420, 520)
	b.position = Vector2(420 + gap, 520)
	a.facing_direction = 1
	b.facing_direction = -1
	a.visual_root.scale = Vector2(1, 1)
	b.visual_root.scale = Vector2(-1, 1)
	await _frames(3)
	return [a, b]

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		_failures += 1

func _slash(attacker: Combatant, charge_frames: int, lane: float) -> void:
	attacker.weapon.ai_start_charge()
	await _frames(charge_frames)
	attacker.weapon.ai_release(attacker.shoulder_pivot, lane)

# ── Tests ────────────────────────────────────────────────────────────────────
func _test_thrust_hits() -> void:
	print("thrust")
	var ab := await _setup(110.0)
	var a: Combatant = ab[0]
	var b: Combatant = ab[1]
	a.weapon.ai_start_thrust(b.global_position + Vector2(0, -4))
	await _frames(30)
	_check(b.current_health < 100.0, "thrust at 110px connects (hp %.1f)" % b.current_health)
	_check(a.weapon.position.x == 0.0, "blade returns after thrust")

func _test_light_slash_hits() -> void:
	print("light slash")
	var ab := await _setup(80.0)
	var b: Combatant = ab[1]
	await _slash(ab[0], 10, Weapon.LANE_MID_ANGLE)
	await _frames(20)
	_check(b.current_health < 100.0, "slash at 80px connects (hp %.1f)" % b.current_health)

func _test_slash_lanes_hit_aimed_zone() -> void:
	print("slash lanes")
	# The sweep passes the head on its way down: a torso or legs slash must
	# still register on the zone it was aimed at.
	var lanes: Dictionary = {"HEAD": Weapon.LANE_HIGH_ANGLE, "TORSO": Weapon.LANE_MID_ANGLE, "LEGS": Weapon.LANE_LOW_ANGLE}
	for zone in lanes:
		for gap in [65.0, 85.0]:
			var ab := await _setup(gap)
			var b: Combatant = ab[1]
			var hit_zones: Array = []
			b.took_damage.connect(func(_a: float, z: String, _h: float, _m: float) -> void: hit_zones.append(z))
			await _slash(ab[0], 12, lanes[zone])
			await _frames(20)
			_check(hit_zones == [zone], "%s slash at %dpx hits %s (got %s)" % [zone, gap, zone, hit_zones])

func _test_block() -> void:
	print("block")
	var ab := await _setup(80.0)
	var a: Combatant = ab[0]
	var b: Combatant = ab[1]
	b.weapon.raise_guard()
	await _frames(20)   # past the parry window
	await _slash(a, 12, Weapon.LANE_MID_ANGLE)
	await _frames(20)
	var dmg := 100.0 - b.current_health
	# Same slash unblocked deals ~28 (light slash test); guard lets 20% through
	_check(dmg > 0.0 and dmg < 8.0, "blocked slash deals chip damage only (%.1f)" % dmg)
	_check(b.weapon.is_guarding(), "guard stays up after a block")

func _test_parry() -> void:
	print("parry")
	var ab := await _setup(80.0)
	var a: Combatant = ab[0]
	var b: Combatant = ab[1]
	a.weapon.ai_start_charge()
	await _frames(12)
	b.weapon.raise_guard()   # raised right as the strike starts
	a.weapon.ai_release(a.shoulder_pivot, Weapon.LANE_MID_ANGLE)
	await _frames(8)   # contact lands inside the 0.15 s (9 frame) parry window
	_check(b.current_health == 100.0, "parried slash deals no damage")
	_check(a.is_staggered(), "attacker is staggered after being parried")
	_check(a.weapon.is_in_recovery(), "attacker weapon is locked in recovery")

func _test_guard_break() -> void:
	print("guard break")
	var ab := await _setup(80.0)
	var a: Combatant = ab[0]
	var b: Combatant = ab[1]
	b.weapon.raise_guard()
	await _frames(20)
	await _slash(a, 55, Weapon.LANE_MID_ANGLE)   # ~0.92 s: full charge
	await _frames(20)
	var dmg := 100.0 - b.current_health
	_check(not b.weapon.is_guarding(), "full-charge slash knocks the guard down")
	_check(dmg > 10.0, "guard break still deals real damage (%.1f)" % dmg)
	var full_head := a.weapon.base_damage * a.weapon.full_charge_damage_mult * 2.0
	_check(dmg <= full_head * a.weapon.guard_break_damage_mult + 0.1,
		"guard break is not also scored as a counter-hit")

func _test_counter_hit() -> void:
	print("counter-hit")
	var ab := await _setup(110.0)
	var a: Combatant = ab[0]
	var b: Combatant = ab[1]
	b.weapon.ai_start_charge()   # B is winding up
	a.weapon.ai_start_thrust(b.global_position + Vector2(0, -4))
	await _frames(20)
	var dmg := 100.0 - b.current_health
	var normal_thrust := a.weapon.base_damage * a.weapon.thrust_damage_mult
	_check(dmg > normal_thrust * 1.4, "thrust into a wind-up counts as counter (%.1f)" % dmg)
	_check(b.weapon.state != Weapon.SwingState.CHARGING, "victim's charge is interrupted")

func _test_combo() -> void:
	print("combo")
	var ab := await _setup(110.0)
	var a: Combatant = ab[0]
	var b: Combatant = ab[1]
	var hits: Array[float] = []
	for i in 3:
		var before := b.current_health
		a.weapon.ai_start_thrust(b.global_position + Vector2(0, -4))
		await _frames(40)   # windup + stab + hit recovery ≈ 24 frames
		hits.append(before - b.current_health)
	_check(hits[1] > hits[0] and hits[2] > hits[1],
		"chained hits grow: %.1f -> %.1f -> %.1f" % [hits[0], hits[1], hits[2]])

func _test_no_nan_after_strikes() -> void:
	print("NaN regression")
	var ab := await _setup(300.0)   # out of reach: every strike whiffs
	var a: Combatant = ab[0]
	for i in 4:
		await _slash(a, 8 + i * 10, Weapon.LANE_HIGH_ANGLE)
		await _frames(40)
		a.weapon.ai_start_thrust(a.global_position + Vector2(200, 0))
		await _frames(40)
	var rot: float = a.shoulder_pivot.rotation
	_check(not is_nan(rot), "shoulder rotation is a number after whiffs (%.3f)" % rot)
