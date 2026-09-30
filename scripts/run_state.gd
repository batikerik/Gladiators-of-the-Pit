extends Node
## Autoload "RunState": everything about the current descent that must survive
## scene changes — the inventory, the thief's health and the room map with the
## thief's position on it — plus the rest rule used by the safe room.

signal inventory_replaced

const MAP_SCENE := "res://scenes/catacomb_map.tscn"
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
	inventory_replaced.emit()

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
	return ROOM_SCENES[target["type"]]

## The room's director calls this when its exit opens.
func clear_current_room() -> void:
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
