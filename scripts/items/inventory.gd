class_name Inventory
extends RefCounted
## What the thief carries: up to MAX_WEAPONS weapons (one equipped) and
## stacks of food.

signal changed
signal equipped_changed(weapon: WeaponData)

const MAX_WEAPONS: int = 3

var weapons: Array[WeaponData] = []
var equipped: WeaponData = null
var _food_counts: Dictionary = {}          # FoodData -> int
var _food_order: Array[FoodData] = []      # pickup order, for the UI and the Q key

# ── Adding / removing ────────────────────────────────────────────────────────
func can_add(item: ItemData, count: int = 1) -> bool:
	if item is WeaponData:
		return weapons.size() < MAX_WEAPONS
	if item is FoodData:
		return count_of(item) + count <= item.max_stack
	return false

func add(item: ItemData, count: int = 1) -> bool:
	if not can_add(item, count):
		return false
	if item is WeaponData:
		weapons.append(item)
		if equipped == null:
			equip(item)
	elif item is FoodData:
		if not _food_counts.has(item):
			_food_order.append(item)
		_food_counts[item] = count_of(item) + count
	changed.emit()
	return true

func remove(item: ItemData, count: int = 1) -> bool:
	if item is WeaponData:
		var idx := weapons.find(item)
		if idx == -1:
			return false
		weapons.remove_at(idx)
		if equipped == item:
			equip(weapons[0] if not weapons.is_empty() else null)
	elif item is FoodData:
		var have := count_of(item)
		if have < count:
			return false
		if have == count:
			_food_counts.erase(item)
			_food_order.erase(item)
		else:
			_food_counts[item] = have - count
	else:
		return false
	changed.emit()
	return true

func equip(weapon: WeaponData) -> void:
	if weapon != null and not weapons.has(weapon):
		return
	if equipped == weapon:
		return
	equipped = weapon
	equipped_changed.emit(weapon)
	changed.emit()

# ── Queries ──────────────────────────────────────────────────────────────────
func count_of(item: ItemData) -> int:
	return int(_food_counts.get(item, 0))

func foods() -> Array[FoodData]:
	return _food_order.duplicate()

func food_count() -> int:
	var total := 0
	for f in _food_order:
		total += count_of(f)
	return total

func total_satiety() -> int:
	var total := 0
	for f in _food_order:
		total += f.satiety * count_of(f)
	return total
