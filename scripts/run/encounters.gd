class_name Encounters
extends RefCounted
## Who waits in a combat room and what lies in a cache, by depth (map layer).

## Enemy archetypes. min_depth gates the tougher ones; health grows with depth.
const ENEMIES: Array[Dictionary] = [
	{"name": "Катакомбный доходяга", "zombie": true, "armor": 0, "weapons": [&"prisoner_dagger", &"rusty_gladius"],
		"health": 70.0, "aggression": 0.8, "min_depth": 1},
	{"name": "Обезумевший узник", "zombie": false, "armor": 0, "weapons": [&"prisoner_dagger", &"rusty_spear"],
		"health": 80.0, "aggression": 1.0, "min_depth": 1},
	{"name": "Гладиатор-беглец", "zombie": false, "armor": 1, "weapons": [&"rusty_gladius", &"rusty_spear"],
		"health": 100.0, "aggression": 1.1, "min_depth": 2},
	{"name": "Костолом", "zombie": true, "armor": 0, "weapons": [&"bone_club"],
		"health": 110.0, "aggression": 1.0, "min_depth": 2},
	{"name": "Палач Ямы", "zombie": false, "armor": 1, "weapons": [&"iron_axe"],
		"health": 120.0, "aggression": 1.2, "min_depth": 3},
]

## Placeholder boss until Milestone 5 gives him his own AI
const BOSS: Dictionary = {"name": "Выживший в латах", "zombie": false, "armor": 2,
	"weapons": [&"iron_axe"], "health": 180.0, "aggression": 1.3, "min_depth": 0}

const FOODS: Array[StringName] = [&"stale_bread", &"stale_bread", &"cave_mushroom", &"dried_meat"]
const WEAPONS: Array[StringName] = [&"prisoner_dagger", &"rusty_gladius", &"rusty_spear", &"iron_axe", &"bone_club"]

const HEALTH_PER_DEPTH: float = 0.08   # +8% enemy health per layer

## Resolved enemy: {name, zombie, armor, weapon: WeaponData, health, aggression, loot: Array[ItemData]}
static func combat(depth: int, rng: RandomNumberGenerator, boss: bool = false) -> Dictionary:
	var base: Dictionary
	if boss:
		base = BOSS
	else:
		var pool: Array[Dictionary] = []
		for e in ENEMIES:
			if depth >= e["min_depth"]:
				pool.append(e)
		base = pool[rng.randi_range(0, pool.size() - 1)]
	var weapons: Array = base["weapons"]
	var loot: Array[ItemData] = []
	if boss or rng.randf() < 0.6:
		loot.append(RunState.get_item(FOODS[rng.randi_range(0, FOODS.size() - 1)]))
	return {
		"name": base["name"],
		"zombie": base["zombie"],
		"armor": base["armor"],
		"weapon": RunState.get_item(weapons[rng.randi_range(0, weapons.size() - 1)]),
		# The boss is tuned by hand; only the regular enemies scale with depth
		"health": base["health"] if boss else roundf(base["health"] * (1.0 + HEALTH_PER_DEPTH * maxi(depth - 1, 0))),
		"aggression": base["aggression"],
		"loot": loot,
	}

## Items lying in a cache room: 2 food, often a weapon you do not carry yet.
static func cache(depth: int, rng: RandomNumberGenerator) -> Array[ItemData]:
	var items: Array[ItemData] = []
	for i in 2:
		items.append(RunState.get_item(FOODS[rng.randi_range(0, FOODS.size() - 1)]))
	if rng.randf() < 0.55 + 0.05 * depth:
		var candidates: Array[StringName] = []
		for id in WEAPONS:
			if not RunState.inventory.weapons.has(RunState.get_item(id)):
				candidates.append(id)
		if not candidates.is_empty():
			items.append(RunState.get_item(candidates[rng.randi_range(0, candidates.size() - 1)]))
	return items
