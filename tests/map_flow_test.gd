extends Node
## Milestone 4 checks: map generation rules over many seeds, encounter rolls,
## and the real scene flow map -> combat -> map -> cache -> campfire -> boss,
## plus death starting a new descent.
##
## Run: Summer.exe --headless --path . res://tests/map_flow_test.tscn

const SEEDS: int = 40
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
	# Scene changes free the current scene. Hand that role to a placeholder so
	# this runner (also a child of root) survives map/room switches.
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	_test_map_rules()
	_test_encounters()
	await _test_combat_flow()
	await _test_cache_room()
	await _test_safe_room()
	await _test_boss_room()
	await _test_death_restarts()
	print("MAP TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

# ── Helpers ──────────────────────────────────────────────────────────────────
func _check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		_failures += 1

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _wait_scene(scene_name: String, max_frames: int = 300) -> Node:
	for i in max_frames:
		var s := get_tree().current_scene
		if s != null and s != self and s.name == scene_name and s.is_node_ready():
			return s
		await get_tree().physics_frame
	return null

func _go(path: String) -> void:
	get_tree().change_scene_to_file(path)

## Stand the thief right before a node of `type` (cleared) and return that node.
func _stand_before(type: StringName) -> Dictionary:
	for n in RunState.map:
		for nid in n["next"]:
			if RunState.map_node(nid)["type"] == type:
				RunState.current_node_id = n["id"]
				RunState.room_cleared = true
				return RunState.map_node(nid)
	return {}

func _layers(map: Array[Dictionary]) -> Array:
	var layers: Array = []
	for n in map:
		while layers.size() <= n["layer"]:
			layers.append([])
		layers[n["layer"]].append(n)
	return layers

# ── Pure generation ──────────────────────────────────────────────────────────
func _test_map_rules() -> void:
	print("map rules over %d seeds" % SEEDS)
	var ok_shape := true
	var ok_types := true
	var ok_reach := true
	var ok_cross := true
	var ok_exits := true
	var ok_cache := true
	for s in SEEDS:
		var map := CatacombMapGen.generate(1000 + s)
		var layers := _layers(map)
		var last := layers.size() - 1
		if layers.size() != CatacombMapGen.LAYERS_BETWEEN + 2 or layers[0].size() != 1 or layers[last].size() != 1:
			ok_shape = false
		if layers[0][0]["type"] != CatacombMapGen.START or layers[last][0]["type"] != CatacombMapGen.BOSS:
			ok_types = false
		for n in layers[1]:
			if n["type"] != CatacombMapGen.COMBAT:
				ok_types = false
		for n in layers[last - 1]:
			if n["type"] != CatacombMapGen.SAFE:
				ok_types = false
		for l in range(2, last - 1):
			var has_combat := false
			for i in layers[l].size():
				if layers[l][i]["type"] == CatacombMapGen.COMBAT:
					has_combat = true
				if i > 0 and layers[l][i]["type"] == CatacombMapGen.SAFE and layers[l][i - 1]["type"] == CatacombMapGen.SAFE:
					ok_types = false
			if not has_combat:
				ok_types = false
		var caches := 0
		for n in map:
			if n["type"] == CatacombMapGen.LOOT:
				caches += 1
		if caches == 0:
			ok_cache = false
		# Reachability from the entrance
		var seen := {map[0]["id"]: true}
		var queue: Array = [map[0]]
		while not queue.is_empty():
			var n: Dictionary = queue.pop_front()
			for nid in n["next"]:
				if not seen.has(nid):
					seen[nid] = true
					for m in map:
						if m["id"] == nid:
							queue.append(m)
		if seen.size() != map.size():
			ok_reach = false
		# Every non-boss room leads somewhere, only upward by one layer
		for n in map:
			if n["type"] != CatacombMapGen.BOSS and n["next"].is_empty():
				ok_exits = false
		# Non-crossing: edges between two layers keep left-to-right order
		for l in last:
			var edges: Array = []
			for n in layers[l]:
				for nid in n["next"]:
					for m in layers[l + 1]:
						if m["id"] == nid:
							edges.append([n["pos"].x, m["pos"].x])
			for e1 in edges:
				for e2 in edges:
					if e1[0] < e2[0] and e1[1] > e2[1]:
						ok_cross = false
	_check(ok_shape, "7 layers: one entrance, 5 layers of choices, one boss")
	_check(ok_types, "layer 1 all fights, pre-boss layer all campfires, a fight in every middle layer, no double campfire")
	_check(ok_cache, "every map has at least one cache")
	_check(ok_reach, "every room is reachable from the entrance")
	_check(ok_exits, "every room except the boss leads further")
	_check(ok_cross, "paths never cross")
	var a := CatacombMapGen.generate(77)
	var b := CatacombMapGen.generate(77)
	_check(str(a) == str(b), "same seed gives the same map")

func _test_encounters() -> void:
	print("encounters")
	RunState.new_run(5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var shallow_ok := true
	for i in 60:
		var e := Encounters.combat(1, rng)
		if e["name"] in ["Runaway Gladiator", "Bonebreaker", "Executioner of the Pit"]:
			shallow_ok = false
	_check(shallow_ok, "depth 1 only rolls the weakest enemies")
	var deep_names := {}
	for i in 200:
		deep_names[Encounters.combat(5, rng)["name"]] = true
	_check(deep_names.has("Executioner of the Pit"), "deep layers can roll the executioner")
	rng.seed = 1
	var h1: float = Encounters.combat(1, rng)["health"]
	rng.seed = 1
	var h5: float = Encounters.combat(5, rng)["health"]
	_check(h5 > h1, "enemies get tougher with depth (%.0f -> %.0f)" % [h1, h5])
	var boss := Encounters.combat(6, rng, true)
	_check(boss["name"] == "The Armoured Survivor" and boss["armor"] == 2, "boss profile: armoured survivor")
	_check(Encounters.cache(3, rng).size() >= 2, "a cache holds at least two items")
	var invalid := RunState.enter_node(RunState.map[-1]["id"])
	_check(invalid == "", "cannot jump to a room that is not next on the path")

# ── Scene flow ───────────────────────────────────────────────────────────────
func _test_combat_flow() -> void:
	print("combat flow")
	RunState.new_run(1234)
	RunState.inventory.add(RunState.get_item(&"rusty_gladius"))
	_go(RunState.MAP_SCENE)
	var map_screen: CatacombMapScreen = await _wait_scene("CatacombMap")
	_check(map_screen != null, "map scene opens")
	var options := RunState.available_nodes()
	_check(options.size() >= 2 and options[0]["type"] == CatacombMapGen.COMBAT, "first choice: %d fights" % options.size())
	var target: Dictionary = options[0]
	map_screen.travel_to(target["id"])
	var room: CombatRoom = await _wait_scene("CombatRoom")
	_check(room != null, "clicking a fight loads the combat room")
	if room == null:
		return
	_check(room.opponent.character_name == room.encounter["name"] and room.opponent.weapon.data == room.encounter["weapon"],
		"opponent built from the encounter: %s with %s" % [room.encounter["name"], room.encounter["weapon"].display_name])
	_check(not room.door.is_open and not RunState.room_cleared, "exit is shut while the enemy lives")
	room.opponent.receive_hit(999.0, "TORSO", Vector2.RIGHT, 0.0, room.player, [])
	await _frames(70)
	_check(room.door.is_open and RunState.room_cleared, "victory opens the exit")
	room.door.used.emit()
	map_screen = await _wait_scene("CatacombMap")
	_check(map_screen != null and RunState.current_node_id == target["id"], "the door leads back to the map, thief on the cleared room")
	var next_ids: Array = []
	for n in RunState.available_nodes():
		next_ids.append(n["id"])
	_check(next_ids == target["next"], "now only the rooms above it are open")

func _test_cache_room() -> void:
	print("cache room")
	RunState.new_run(1234)
	var loot := _stand_before(CatacombMapGen.LOOT)
	if loot.is_empty():
		for s in 50:   # find a seed with a cache room
			RunState.new_run(2000 + s)
			loot = _stand_before(CatacombMapGen.LOOT)
			if not loot.is_empty():
				break
	_go(RunState.enter_node(loot["id"]))
	var room: LootRoom = await _wait_scene("LootRoom")
	_check(room != null, "cache room loads")
	await _frames(5)
	var pickups := 0
	for c in room.get_children():
		if c is ItemPickup:
			pickups += 1
	_check(pickups >= 2, "%d items lie in the cache" % pickups)
	_check(room.door.is_open, "a cache's exit is open from the start")

func _test_safe_room() -> void:
	print("safe room")
	RunState.new_run(1234)
	var safe := _stand_before(CatacombMapGen.SAFE)
	RunState.inventory.add(RunState.get_item(&"stale_bread"), 2)
	RunState.player_health = 40.0
	_go(RunState.enter_node(safe["id"]))
	var room: SafeRoom = await _wait_scene("SafeRoom")
	_check(room != null, "campfire room loads")
	if room == null:
		return
	_check(room.door.is_open, "you can leave a campfire any time")
	room.campfire.rest_requested.emit()
	room.campfire.rest_available = false
	await _frames(150)
	_check(is_equal_approx(room.player.current_health, room.player.max_health), "resting with food heals fully")
	_check(RunState.inventory.count_of(RunState.get_item(&"stale_bread")) == 0, "the rest ate both breads")
	_check(room.player.input_enabled, "control returns after resting")

func _test_boss_room() -> void:
	print("boss room")
	RunState.new_run(1234)
	RunState.inventory.add(RunState.get_item(&"rusty_gladius"))
	var boss := _stand_before(CatacombMapGen.BOSS)
	_go(RunState.enter_node(boss["id"]))
	var room: CombatRoom = await _wait_scene("CombatRoom")
	_check(room != null and room.opponent.character_name == "The Armoured Survivor", "the boss node brings the armoured survivor")
	if room == null:
		return
	_check(room.opponent.max_health >= 180.0 and room.opponent.armor_tier == 2, "boss: %d HP, plate armour" % int(room.opponent.max_health))
	room.opponent.receive_hit(9999.0, "HEAD", Vector2.RIGHT, 0.0, room.player, [])
	await _frames(70)
	_check(RunState.boss_defeated, "killing him marks the catacombs as beaten")

func _test_death_restarts() -> void:
	print("death")
	RunState.new_run(1234)
	RunState.inventory.add(RunState.get_item(&"iron_axe"))
	var first: Dictionary = RunState.available_nodes()[0]
	_go(RunState.enter_node(first["id"]))
	var room: CombatRoom = await _wait_scene("CombatRoom")
	room.player.receive_hit(999.0, "HEAD", Vector2.LEFT, 0.0, room.opponent, [])
	var end_screen: RunEndScreen = await _wait_scene("RunEndScreen", 400)
	_check(end_screen != null and not end_screen.result["victory"], "death leads to the run end screen")
	if end_screen == null:
		return
	end_screen.continue_game()   # what [Enter] does
	var map_screen := await _wait_scene("CatacombMap")
	_check(map_screen != null, "the next thief starts on a fresh map")
	_check(RunState.current_node()["type"] == CatacombMapGen.START and RunState.inventory.weapons.is_empty(),
		"a new descent: back at the entrance, pockets empty")
