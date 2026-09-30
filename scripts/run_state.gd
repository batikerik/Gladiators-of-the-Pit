extends Node
## Autoload "RunState": everything about the current descent that must survive
## scene changes — the inventory, the thief's health and the room map with the
## thief's position on it — plus the rest rule used by the safe room.

signal inventory_replaced

const MAP_SCENE := "res://scenes/catacomb_map.tscn"
const RUN_END_SCENE := "res://scenes/run_end_screen.tscn"

## Filled when a descent ends, read by the run end screen:
## {victory, name, depth, room_type, stats, corpse_items: Array[String]}
var last_result: Dictionary = {}
const ROOM_SCENES: Dictionary = {
	&"combat": "res://scenes/rooms/combat_room.tscn",
	&"boss": "res://scenes/rooms/combat_room.tscn",
	&"loot": "res://scenes/rooms/loot_room.tscn",
	&"safe": "res://scenes/rooms/safe_room.tscn",
}

## Satiety points a safe rest costs (bread = 1, dried meat = 2)
const REST_SATIETY_COST: int = 2
## Share of max health lost when resting hungry
const HUNGER_PENALTY: float = 0.2

const ITEM_PATHS: Dictionary = {
	&"rusty_gladius": "res://data/items/rusty_gladius.tres",
	&"prisoner_dagger": "res://data/items/prisoner_dagger.tres",
	&"rusty_spear": "res://data/items/rusty_spear.tres",
	&"iron_axe": "res://data/items/iron_axe.tres",
	&"bone_club": "res://data/items/bone_club.tres",
	&"stale_bread": "res://data/items/stale_bread.tres",
	&"dried_meat": "res://data/items/dried_meat.tres",
	&"cave_mushroom": "res://data/items/cave_mushroom.tres",
}

var inventory: Inventory = Inventory.new()
var player_max_health: float = 100.0
var player_health: float = 100.0
## false until a run starts (intro / tutorial) or a scene with the player is
## launched directly from the editor
var run_active: bool = false

## The descent's room map (see CatacombMapGen) and where the thief stands on it
var run_seed: int = 0
var map: Array[Dictionary] = []
var current_node_id: int = 0
## Set when the thief is inside a room and has not cleared it yet
var room_cleared: bool = false
var boss_defeated: bool = false

## This descent's escapee and what he achieved
## Number of this descent's escapee (1, 2, ...); the name is built in the current language
var thief_no: int = 1
var thief_name: String:
	get:
		return escapee_name(thief_no)
var thief_cloth: Color = Color(0.65, 0.2, 0.2)
var stats: Dictionary = {"kills": 0, "rooms": 0, "max_depth": 0}

## ── Legacy: what outlives a single descent (saved to disk) ──────────────────
## runs, deaths, victories, best_depth, and the corpse of the last fallen thief:
## corpse = {runner, layer, room_type, x, items: [item ids]} or {} when none.
const LEGACY_PATH_DEFAULT := "user://the_pit_legacy.json"
var legacy_path: String = LEGACY_PATH_DEFAULT
var legacy: Dictionary = {}
## Map node of this descent where the previous thief's body lies (-1 = none)
var corpse_node_id: int = -1

const CLOTH_COLORS: Array[Color] = [
	Color(0.65, 0.2, 0.2), Color(0.25, 0.4, 0.6), Color(0.55, 0.45, 0.2),
	Color(0.35, 0.5, 0.3), Color(0.5, 0.3, 0.55), Color(0.6, 0.35, 0.2),
]

func _ready() -> void:
	load_legacy()

func new_run(seed_value: int = -1) -> void:
	inventory = Inventory.new()
	player_health = player_max_health
	run_active = true
	run_seed = seed_value if seed_value >= 0 else randi()
	map = CatacombMapGen.generate(run_seed)
	current_node_id = map[0]["id"]
	map[0]["visited"] = true
	room_cleared = true
	boss_defeated = false
	stats = {"kills": 0, "rooms": 0, "max_depth": 0}
	legacy["runs"] = int(legacy.get("runs", 0)) + 1
	thief_no = int(legacy["runs"])
	thief_cloth = CLOTH_COLORS[(legacy["runs"] - 1) % CLOTH_COLORS.size()]
	_place_corpse()
	save_legacy()
	inventory_replaced.emit()

# ── Legacy / corpse run ──────────────────────────────────────────────────────
func load_legacy() -> void:
	legacy = {}
	if FileAccess.file_exists(legacy_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(legacy_path))
		if parsed is Dictionary:
			legacy = parsed

func save_legacy() -> void:
	var f := FileAccess.open(legacy_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(legacy, "\t"))

## Wipe all saved progress (tests, or a future "new game" button).
func reset_legacy() -> void:
	legacy = {}
	corpse_node_id = -1
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))

func escapee_name(n: int) -> String:
	return tr("Escapee #%d") % n

func corpse_name() -> String:
	return escapee_name(int(corpse().get("runner", 0)))

func corpse() -> Dictionary:
	return legacy.get("corpse", {})

## The last thief died: his body (with everything he carried) replaces any
## older body — Dark Souls rule, only one corpse waits in the Pit.
func record_death(x: float) -> void:
	var items: Array = []
	for w in inventory.weapons:
		items.append(String(w.id))
	for f in inventory.foods():
		for i in inventory.count_of(f):
			items.append(String(f.id))
	var node := current_node()
	stats["max_depth"] = maxi(stats["max_depth"], int(node.get("layer", 1)))
	legacy["deaths"] = int(legacy.get("deaths", 0)) + 1
	legacy["best_depth"] = maxi(int(legacy.get("best_depth", 0)), stats["max_depth"])
	legacy["corpse"] = {
		"runner": thief_no, "layer": int(node.get("layer", 1)), "room_type": String(node.get("type", "combat")),
		"x": x, "items": items,
	}
	save_legacy()
	last_result = {"victory": false, "runner": thief_no, "depth": int(node.get("layer", 1)),
		"room_type": String(node.get("type", "combat")), "stats": stats.duplicate(), "corpse_items": items}
	run_active = false

func record_victory() -> void:
	legacy["victories"] = int(legacy.get("victories", 0)) + 1
	legacy["best_depth"] = maxi(int(legacy.get("best_depth", 0)), stats["max_depth"])
	save_legacy()
	last_result = {"victory": true, "runner": thief_no, "depth": stats["max_depth"],
		"room_type": "boss", "stats": stats.duplicate(), "corpse_items": []}
	run_active = false

## The body was found and looted: it is gone for good.
func consume_corpse() -> void:
	legacy.erase("corpse")
	corpse_node_id = -1
	save_legacy()

## Put the saved body on this descent's map: same depth, a room of the same
## kind if that layer has one, otherwise the first room of the layer.
func _place_corpse() -> void:
	corpse_node_id = -1
	var c := corpse()
	if c.is_empty():
		return
	var layer: int = clampi(int(c["layer"]), 1, CatacombMapGen.LAYERS_BETWEEN + 1)
	var candidates: Array[Dictionary] = []
	for n in map:
		if n["layer"] == layer:
			candidates.append(n)
	if candidates.is_empty():
		return
	corpse_node_id = candidates[0]["id"]
	for n in candidates:
		if String(n["type"]) == String(c["room_type"]):
			corpse_node_id = n["id"]
			break

func corpse_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for id in corpse().get("items", []):
		if ITEM_PATHS.has(StringName(id)):
			result.append(get_item(StringName(id)))
	return result

# ── Map ──────────────────────────────────────────────────────────────────────
func map_node(id: int) -> Dictionary:
	for n in map:
		if n["id"] == id:
			return n
	return {}

func current_node() -> Dictionary:
	return map_node(current_node_id)

## Rooms the thief may walk into next (only after clearing the current one)
func available_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not room_cleared:
		return result
	for id in current_node()["next"]:
		result.append(map_node(id))
	return result

## Move onto a map node; returns the room scene to load ("" if not allowed).
func enter_node(id: int) -> String:
	var target := map_node(id)
	if target.is_empty() or not available_nodes().has(target):
		return ""
	current_node_id = id
	target["visited"] = true
	room_cleared = false
	stats["max_depth"] = maxi(stats["max_depth"], int(target["layer"]))
	return ROOM_SCENES[target["type"]]

## The room's director calls this when its exit opens.
func clear_current_room() -> void:
	if not room_cleared:
		stats["rooms"] += 1
	room_cleared = true
	if current_node()["type"] == CatacombMapGen.BOSS:
		boss_defeated = true

## Deterministic RNG for the room at the current node (same room, same enemy)
func room_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 1000 + current_node_id
	return rng

func depth() -> int:
	return int(current_node().get("layer", 1))

func get_item(id: StringName) -> ItemData:
	return load(ITEM_PATHS[id]) as ItemData

## Rest in a safe room. Eats the least valuable food until REST_SATIETY_COST is
## paid and heals fully; without enough food nothing is eaten and the thief
## loses HUNGER_PENALTY of max health (never below 1).
## Returns {fed: bool, eaten: Array[FoodData], health: float}.
func rest() -> Dictionary:
	var plan: Array[FoodData] = []
	var paid := 0
	var foods := inventory.foods()
	foods.sort_custom(func(a: FoodData, b: FoodData) -> bool: return a.heal_amount < b.heal_amount)
	for food in foods:
		for i in inventory.count_of(food):
			if paid >= REST_SATIETY_COST:
				break
			plan.append(food)
			paid += food.satiety

	if paid >= REST_SATIETY_COST:
		for food in plan:
			inventory.remove(food)
		player_health = player_max_health
		return {"fed": true, "eaten": plan, "health": player_health}

	player_health = maxf(1.0, player_health - player_max_health * HUNGER_PENALTY)
	var none: Array[FoodData] = []
	return {"fed": false, "eaten": none, "health": player_health}
