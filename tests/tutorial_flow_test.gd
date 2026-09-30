extends Node
## Headless run of the whole tutorial: fall onto the pile -> pick up the sword ->
## hit the zombie in head, torso, legs -> it turns mortal -> kill it -> the
## scene moves on to the descent map. The player's weapon is commanded through the
## Weapon API (no mouse in headless), everything else runs as in the game.
##
## Run: Summer.exe --headless --path . res://tests/tutorial_flow_test.tscn

const TUTORIAL := preload("res://scenes/tutorial_room.tscn")
const ZONE_AIM: Dictionary = {"HEAD": Vector2(0, -36), "TORSO": Vector2(0, -2), "LEGS": Vector2(0, 30)}

var _failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	# Tests assert English texts and must not touch the player's settings
	Settings.settings_path = "user://test_settings.cfg"
	Settings.language = "en"
	Settings.apply()
	# Never touch the real legacy save: runs and corpses go to a scratch file
	RunState.legacy_path = "user://test_legacy.json"
	RunState.reset_legacy()
	var room: TutorialDirector = TUTORIAL.instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	var player: Combatant = room.player
	var zombie: Combatant = room.zombie

	print("landing")
	await _wait_until(func() -> bool: return player.input_enabled, 600)
	_check(player.input_enabled, "control returns after the landing")
	_check(player.global_position.y < 500.0, "landed on top of the corpse pile (y %.0f)" % player.global_position.y)
	_check(not player.armed and not player.weapon.visible, "starts unarmed")
	_check(not zombie.ai_enabled, "zombie waits until the sword is taken")

	print("pickup")
	player.global_position = room.pickup.global_position + Vector2(-50, -60)
	await _frames(20)
	_check(room.pickup._label.visible, "pickup prompt shows next to the sword")
	room.pickup._take()   # what pressing E does
	await _frames(70)
	_check(player.armed and player.weapon.visible, "sword equipped")
	_check(room._objective_labels["weapon"].text.begins_with("[x]"), "objective 'weapon' ticked")
	_check(zombie.ai_enabled, "zombie wakes up")

	# From here the test drives the player's sword like the AI API does
	player.is_player = false
	player.ai_enabled = false
	# Step off the pile onto the arena floor: from the top of the pile a
	# level slash passes over the zombie's head
	player.global_position = Vector2(520, 520)
	await _frames(10)

	print("zones")
	# As the on-screen hint teaches: slash, cursor height picks the lane
	var lanes: Dictionary = {"HEAD": Weapon.LANE_HIGH_ANGLE, "TORSO": Weapon.LANE_MID_ANGLE, "LEGS": Weapon.LANE_LOW_ANGLE}
	for zone in ["HEAD", "TORSO", "LEGS"]:
		for attempt in 6:
			if room._zones_hit[zone]:
				break
			await _wait_in_reach(player, zombie, 55.0, 95.0)
			player.weapon.ai_start_charge()
			await _frames(12)
			player.weapon.ai_release(player.shoulder_pivot, lanes[zone])
			await _frames(40)
		_check(room._zones_hit[zone], "zone %s registered" % zone)
	_check(zombie.current_health == zombie.max_health, "zombie took no damage while immortal")
	_check(not zombie.immortal, "zombie turns mortal after all three zones")

	print("finish")
	for attempt in 20:
		if not zombie.is_alive:
			break
		await _wait_in_reach(player, zombie)
		player.weapon.ai_start_thrust(zombie.global_position + ZONE_AIM["HEAD"])
		await _frames(40)
	_check(not zombie.is_alive, "zombie can be killed")
	_check(room._objective_labels["finish"].text.begins_with("[x]"), "objective 'finish' ticked")

	# Compare by id: the lambda must not capture the room, it gets freed on scene change
	var room_id: int = room.get_instance_id()
	await _wait_until(func() -> bool:
		return get_tree().current_scene != null and get_tree().current_scene.get_instance_id() != room_id, 600)
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "CatacombMap", "tutorial hands over to the descent map")

	print("TUTORIAL TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _wait_in_reach(player: Combatant, zombie: Combatant, near: float = 70.0, far: float = 115.0) -> void:
	await _wait_until(func() -> bool:
		var d: float = absf(zombie.global_position.x - player.global_position.x)
		return d > near and d < far and player.weapon.is_idle() and player.is_on_floor() \
			and not zombie.is_tripped, 300)
	player.facing_direction = 1 if zombie.global_position.x > player.global_position.x else -1

func _wait_until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		_failures += 1
