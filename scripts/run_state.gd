extends Node
## Autoload "RunState": everything about the current descent that must survive
## scene changes — the inventory and the thief's health — plus the rest rule
## the Safe Room (Milestone 4) will call.

signal inventory_replaced

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

func new_run() -> void:
	inventory = Inventory.new()
	player_health = player_max_health
	run_active = true
	inventory_replaced.emit()

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
