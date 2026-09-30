extends Node
## Milestone 5 checks: permadeath + corpse run (saved legacy, body placed on
## the next map, looting it), the Armoured Survivor (plate, poise, rage phase,
## leap, real attacks) and the victory / defeat screens.
##
## Run: Summer.exe --headless --path . res://tests/permadeath_boss_test.tscn

var _failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	# Tests assert English texts and must not touch the player's settings
	Settings.settings_path = "user://test_settings.cfg"
	Settings.language = "en"
	Settings.apply()
	RunState.legacy_path = "user://test_legacy.json"
	RunState.reset_legacy()
	var placeholder := Node.new()   # scene changes free this, not the runner
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder

	await _test_death_leaves_a_body()
	await _test_next_thief_finds_the_body()
	_test_only_one_body()
	await _test_boss_armour_and_poise()
	await _test_boss_rage_and_leap()
	await _test_boss_fights_back()
	await _test_victory()
	RunState.reset_legacy()
	print("PERMADEATH/BOSS TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

# ── Helpers ──────────────────────────────────────────────────────────────────
func _check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		_failures += 1

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _wait_scene(scene_name: String, max_frames: int = 400) -> Node:
	for i in max_frames:
		var s := get_tree().current_scene
		if s != null and s != self and s.name == scene_name and s.is_node_ready():
			return s
		await get_tree().physics_frame
	return null

func _item(id: StringName) -> ItemData:
	return RunState.get_item(id)

func _enter_boss_room() -> CombatRoom:
	RunState.new_run(4321)
	RunState.inventory.add(_item(&"rusty_gladius"))
	for n in RunState.map:
		for nid in n["next"]:
			if RunState.map_node(nid)["type"] == CatacombMapGen.BOSS:
				RunState.current_node_id = n["id"]
				RunState.room_cleared = true
	var boss_id: int = RunState.map[-1]["id"]
	get_tree().change_scene_to_file(RunState.enter_node(boss_id))
	return await _wait_scene("CombatRoom")

# ── Permadeath & corpse run ──────────────────────────────────────────────────
func _test_death_leaves_a_body() -> void:
	print("death leaves a body")
	RunState.new_run(100)
	_check(RunState.thief_name == "Escapee #1" and RunState.corpse_node_id == -1, "first thief, no body yet")
	RunState.inventory.add(_item(&"iron_axe"))
	RunState.inventory.add(_item(&"stale_bread"), 2)
	var first: Dictionary = RunState.available_nodes()[0]
	get_tree().change_scene_to_file(RunState.enter_node(first["id"]))
	var room: CombatRoom = await _wait_scene("CombatRoom")
	room.player.global_position.x = 333.0
	room.player.receive_hit(999.0, "HEAD", Vector2.LEFT, 0.0, room.opponent, [])
	var c := RunState.corpse()
	_check(c.get("layer") == 1 and c.get("room_type") == "combat", "body saved where he fell: depth 1, a fight")
	_check(c.get("items", []).size() == 3 and int(c.get("runner", 0)) == 1, "the body keeps the axe and 2 breads")
	RunState.legacy = {}
	RunState.load_legacy()
	_check(RunState.corpse().get("items", []).size() == 3 and int(RunState.legacy.get("deaths", 0)) == 1,
		"the body survives a restart of the game (saved to disk)")
	var end: RunEndScreen = await _wait_scene("RunEndScreen")
	_check(end != null and not end.result["victory"] and end.result["corpse_items"].size() == 3,
		"defeat screen lists what stays on the body")
	end.continue_game()
	await _wait_scene("CatacombMap")

func _test_next_thief_finds_the_body() -> void:
	print("next thief finds the body")
	_check(RunState.thief_name == "Escapee #2", "a new thief: %s" % RunState.thief_name)
	_check(RunState.corpse_node_id >= 0 and RunState.map_node(RunState.corpse_node_id)["layer"] == 1,
		"the body is marked on the new map at the same depth")
	RunState.inventory.add(_item(&"rusty_gladius"))
	get_tree().change_scene_to_file(RunState.enter_node(RunState.corpse_node_id))
	var room: CombatRoom = await _wait_scene("CombatRoom")
	_check(room.corpse_pile != null and is_equal_approx(room.corpse_pile.position.x, 333.0),
		"the body lies where the last thief fell (x 333)")
	if room.corpse_pile == null:
		return
	room.corpse_pile.search()
	var inv := RunState.inventory
	_check(inv.weapons.has(_item(&"iron_axe")) and inv.count_of(_item(&"stale_bread")) == 2,
		"searching it returns the axe and both breads")
	_check(RunState.corpse().is_empty() and RunState.corpse_node_id == -1, "the searched body is gone for good")
	RunState.load_legacy()
	_check(RunState.corpse().is_empty(), "…also in the save file")

func _test_only_one_body() -> void:
	print("only one body")
	RunState.new_run(200)
	RunState.inventory.add(_item(&"rusty_spear"))
	RunState.record_death(500.0)
	RunState.new_run(201)
	RunState.inventory.add(_item(&"bone_club"))
	var second: Dictionary = RunState.available_nodes()[0]
	RunState.enter_node(second["id"])
	RunState.record_death(700.0)
	var c := RunState.corpse()
	_check(c["items"] == ["bone_club"] and is_equal_approx(float(c["x"]), 700.0),
		"dying before reaching the old body replaces it (the spear is lost)")

# ── Boss ─────────────────────────────────────────────────────────────────────
func _test_boss_armour_and_poise() -> void:
	print("boss armour and poise")
	var room := await _enter_boss_room()
	var boss := room.opponent
	_check(room.boss_brain != null and boss.brain == room.boss_brain, "the boss runs on BossBrain")
	boss.ai_enabled = false
	var hp := boss.current_health
	boss.receive_hit(20.0, "TORSO", Vector2.RIGHT, 0.0, room.player, [])
	var torso := hp - boss.current_health
	hp = boss.current_health
	boss.receive_hit(20.0, "HEAD", Vector2.RIGHT, 0.0, room.player, [])
	var head := hp - boss.current_health
	_check(is_equal_approx(torso, 11.0) and is_equal_approx(head, 20.0),
		"plate: torso takes %.0f of 20, the head all %.0f" % [torso, head])
	boss.receive_hit(1.0, "LEGS", Vector2.RIGHT, 0.0, room.player, [])
	boss.receive_hit(1.0, "LEGS", Vector2.RIGHT, 0.0, room.player, [])
	var tripped_early := boss.is_tripped
	boss.receive_hit(1.0, "LEGS", Vector2.RIGHT, 0.0, room.player, [])
	_check(not tripped_early and boss.is_tripped and boss.trip_time_left > 1.0,
		"poise: 2 leg hits do nothing, the 3rd floors him for 1.2 s")

func _test_boss_rage_and_leap() -> void:
	print("boss rage and leap")
	var room := await _enter_boss_room()
	var boss := room.opponent
	var brain := room.boss_brain
	room.player.input_enabled = false
	_check(brain.phase == 1, "starts in the defensive phase")
	boss.receive_hit(boss.max_health * 0.55, "HEAD", Vector2.RIGHT, 0.0, room.player, [])
	await _frames(2)
	_check(brain.phase == 2 and room.hud.enemy_name_label.text.contains("ENRAGED"), "at half health: rage, the HUD says so")
	# Keep the thief far away: the boss should leap at him
	room.player.global_position.x = 250.0
	boss.global_position.x = 600.0
	var saw_leap := false
	var start_gap := absf(boss.global_position.x - room.player.global_position.x)
	for i in 420:
		if brain.move == BossBrain.Move.LEAP_AIR:
			saw_leap = true
		if saw_leap and brain.move == BossBrain.Move.RECOVER:
			break
		room.player.global_position.x = 250.0
		await get_tree().physics_frame
	var end_gap := absf(boss.global_position.x - room.player.global_position.x)
	_check(saw_leap, "in rage he leaps at a distant thief")
	_check(end_gap < start_gap - 150.0, "the leap closes the gap (%.0f -> %.0f px)" % [start_gap, end_gap])
	_check(not is_nan(boss.shoulder_pivot.rotation), "his weapon arm is sane after the leap")

func _test_boss_fights_back() -> void:
	print("boss fights back")
	var room := await _enter_boss_room()
	var boss := room.opponent
	room.player.input_enabled = false   # a thief who just stands there
	room.player.global_position.x = 500.0
	boss.global_position.x = 700.0
	var guarded := false
	for i in 600:
		if boss.weapon.is_guarding():
			guarded = true
		if room.player.current_health < 100.0:
			break
		await get_tree().physics_frame
	_check(guarded, "phase 1: he advances behind a raised guard")
	_check(room.player.current_health < 100.0, "…and swings at an idle thief (hp %.0f)" % room.player.current_health)

func _test_victory() -> void:
	print("victory")
	var room := await _enter_boss_room()
	room.opponent.receive_hit(9999.0, "HEAD", Vector2.RIGHT, 0.0, room.player, [])
	await _frames(70)
	_check(room.door.is_open and RunState.boss_defeated, "the gate opens after the boss")
	room.door.used.emit()
	var end: RunEndScreen = await _wait_scene("RunEndScreen")
	_check(end != null and end.result["victory"], "walking out is the victory screen")
	_check(int(RunState.legacy.get("victories", 0)) == 1, "victory counted in the legacy")
	if end:
		end.continue_game()
		_check(await _wait_scene("MainMenu") != null, "after freedom: back to the main menu")
