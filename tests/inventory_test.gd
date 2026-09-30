extends Node
## Milestone 3 checks: inventory rules, rest/food economy, weapon data driving
## the real weapon (reach, timings, behaviours), eating, loot drops and the
## weapon swap on a full belt.
##
## Run: Summer.exe --headless --path . res://tests/inventory_test.tscn

const MAIN := preload("res://main.tscn")

var _failures: int = 0
var _arena: Node = null

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_inventory_rules()
	_test_food_stacks()
	_test_rest()
	_test_derived_stats()
	await _test_weapon_applies_to_blade()
	await _test_spear_outreaches_gladius()
	await _test_club_staggers()
	await _test_axe_chips_through_guard()
	await _test_dagger_combo()
	await _test_eating()
	await _test_loot_drop()
	await _test_full_belt_swap()
	print("INVENTORY TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

# ── Helpers ──────────────────────────────────────────────────────────────────
func _item(id: StringName) -> ItemData:
	return RunState.get_item(id)

func _check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		_failures += 1

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Fresh arena with a new run; both fighters frozen and commanded directly.
## Loose pickups from the scene are removed so they do not interfere.
func _setup(gap: float, a_weapon: StringName = &"rusty_gladius", b_weapon: StringName = &"rusty_gladius") -> Array:
	if _arena:
		_arena.free()
	RunState.new_run()
	RunState.inventory.add(_item(a_weapon))
	_arena = MAIN.instantiate()
	get_tree().root.add_child(_arena)
	for p in _arena.get_children():
		if p is ItemPickup:
			p.free()
	var a: Combatant = _arena.get_node("Player")
	var b: Combatant = _arena.get_node("Opponent")
	b.weapon_data = _item(b_weapon)
	b.weapon.apply_data(b.weapon_data)
	b.loot.clear()
	for c in [a, b]:
		c.is_player = false
		c.set_physics_process(false)
	a.position = Vector2(420, 520)
	b.position = Vector2(420 + gap, 520)
	a.facing_direction = 1
	b.facing_direction = -1
	a.visual_root.scale = Vector2(1, 1)
	b.visual_root.scale = Vector2(-1, 1)
	await _frames(3)
	return [a, b]

func _slash(attacker: Combatant, charge_frames: int, lane: float) -> void:
	attacker.weapon.ai_start_charge()
	await _frames(charge_frames)
	attacker.weapon.ai_release(attacker.shoulder_pivot, lane)

# ── Pure data ────────────────────────────────────────────────────────────────
func _test_inventory_rules() -> void:
	print("inventory rules")
	var inv := Inventory.new()
	var gladius := _item(&"rusty_gladius")
	var spear := _item(&"rusty_spear")
	var axe := _item(&"iron_axe")
	var club := _item(&"bone_club")
	_check(inv.add(gladius) and inv.equipped == gladius, "first weapon is equipped automatically")
	inv.add(spear)
	inv.add(axe)
	_check(not inv.add(club) and inv.weapons.size() == 3, "a 4th weapon does not fit")
	inv.equip(axe)
	_check(inv.equipped == axe, "equip switches the weapon in hand")
	inv.remove(axe)
	_check(inv.equipped == gladius, "dropping the weapon in hand equips the next one")
	inv.equip(club)
	_check(inv.equipped == gladius, "cannot equip a weapon you do not carry")

func _test_food_stacks() -> void:
	print("food stacks")
	var inv := Inventory.new()
	var bread: FoodData = _item(&"stale_bread")
	var meat: FoodData = _item(&"dried_meat")
	inv.add(bread, 3)
	inv.add(meat)
	_check(inv.count_of(bread) == 3 and inv.food_count() == 4, "bread stacks (3) + meat (1)")
	_check(inv.total_satiety() == 5, "satiety adds up: 3x1 + 1x2 = 5")
	_check(not inv.add(bread, 3), "stack limit %d holds" % bread.max_stack)
	inv.remove(bread, 3)
	_check(inv.count_of(bread) == 0 and inv.foods() == [meat], "empty stack disappears from the list")

func _test_rest() -> void:
	print("rest")
	var bread: FoodData = _item(&"stale_bread")
	var meat: FoodData = _item(&"dried_meat")

	RunState.new_run()
	RunState.player_health = 40.0
	RunState.inventory.add(bread, 3)
	var r: Dictionary = RunState.rest()
	_check(r.fed and r.eaten.size() == 2 and RunState.inventory.count_of(bread) == 1,
		"rest eats 2 bread (2 satiety)")
	_check(RunState.player_health == RunState.player_max_health, "fed rest heals fully")

	RunState.new_run()
	RunState.inventory.add(meat)
	r = RunState.rest()
	_check(r.fed and RunState.inventory.food_count() == 0, "one dried meat pays for a rest")

	RunState.new_run()
	RunState.player_health = 50.0
	RunState.inventory.add(bread)   # 1 satiety: not enough
	r = RunState.rest()
	_check(not r.fed and RunState.inventory.count_of(bread) == 1, "not enough food: nothing is eaten")
	_check(is_equal_approx(RunState.player_health, 30.0), "hungry rest costs 20%% max HP (50 -> %.0f)" % RunState.player_health)
	RunState.player_health = 10.0
	RunState.rest()
	_check(RunState.player_health == 1.0, "hunger never kills (stays at 1)")

func _test_derived_stats() -> void:
	print("derived stats")
	var dagger: WeaponData = _item(&"prisoner_dagger")
	var gladius: WeaponData = _item(&"rusty_gladius")
	var club: WeaponData = _item(&"bone_club")
	_check(dagger.max_charge_time() < gladius.max_charge_time() and gladius.max_charge_time() < club.max_charge_time(),
		"charge time grows with weight (%.2f < %.2f < %.2f)" % [dagger.max_charge_time(), gladius.max_charge_time(), club.max_charge_time()])
	_check(dagger.move_mult() > gladius.move_mult() and club.move_mult() < gladius.move_mult(),
		"light weapons hop further, heavy ones shorter")
	_check(is_equal_approx(gladius.max_charge_time(), 0.9) and is_equal_approx(gladius.strike_duration(), 0.18),
		"gladius keeps the original tuning")

# ── Weapon data on the real weapon ───────────────────────────────────────────
func _test_weapon_applies_to_blade() -> void:
	print("weapon data -> blade")
	var ab := await _setup(300.0, &"rusty_spear")
	var a: Combatant = ab[0]
	var spear: WeaponData = _item(&"rusty_spear")
	_check(a.weapon.data == spear, "player spawns with the equipped inventory weapon")
	_check(is_equal_approx(a.weapon.tip_marker.position.x, 18.0 + spear.reach - 3.0), "tip moves to the spear's reach")
	var shape := a.weapon.blade_collision.shape as RectangleShape2D
	_check(is_equal_approx(shape.size.x, spear.reach - 4.0), "hit area matches the reach")
	var b: Combatant = ab[1]
	_check((b.weapon.blade_collision.shape as RectangleShape2D).size.x != shape.size.x,
		"each fighter has its own hit shape")
	_check(a.weapon.renderer.weapon_type == &"spear", "renderer draws a spear")
	RunState.inventory.add(_item(&"bone_club"))
	RunState.inventory.equip(_item(&"bone_club"))
	await _frames(1)
	_check(a.weapon.data == _item(&"bone_club"), "equipping from the inventory rebuilds the weapon")

func _test_spear_outreaches_gladius() -> void:
	print("reach")
	var ab := await _setup(150.0, &"rusty_spear")
	ab[0].weapon.ai_start_thrust(ab[1].global_position + Vector2(0, -4))
	await _frames(40)
	_check(ab[1].current_health < 100.0, "spear thrust connects at 150px")
	ab = await _setup(150.0, &"rusty_gladius")
	ab[0].weapon.ai_start_thrust(ab[1].global_position + Vector2(0, -4))
	await _frames(40)
	_check(ab[1].current_health == 100.0, "gladius thrust falls short at 150px")

func _test_club_staggers() -> void:
	print("club")
	var ab := await _setup(75.0, &"bone_club")
	await _slash(ab[0], 12, Weapon.LANE_MID_ANGLE)
	await _frames(10)
	_check(ab[1].current_health < 100.0 and ab[1].is_staggered(), "a clean club hit staggers")

func _test_axe_chips_through_guard() -> void:
	print("axe vs guard")
	var chip: Dictionary = {}
	for id in [&"rusty_gladius", &"iron_axe"]:
		var ab := await _setup(75.0, id)
		ab[1].weapon.raise_guard()
		await _frames(20)
		await _slash(ab[0], 12, Weapon.LANE_MID_ANGLE)
		await _frames(25)
		chip[id] = 100.0 - ab[1].current_health
	_check(chip[&"iron_axe"] > chip[&"rusty_gladius"] * 2.0,
		"axe chips through a guard far harder (%.1f vs %.1f)" % [chip[&"iron_axe"], chip[&"rusty_gladius"]])

func _test_dagger_combo() -> void:
	print("dagger combo")
	var ab := await _setup(60.0, &"prisoner_dagger")
	var a: Combatant = ab[0]
	a._combo_count = 2
	var dagger_mult := a.get_combo_multiplier()
	ab = await _setup(60.0, &"rusty_gladius")
	ab[0]._combo_count = 2
	_check(dagger_mult > ab[0].get_combo_multiplier(),
		"dagger combo grows faster (x%.2f vs x%.2f at 2 hits)" % [dagger_mult, ab[0].get_combo_multiplier()])

# ── Eating, loot, pickups ────────────────────────────────────────────────────
func _test_eating() -> void:
	print("eating")
	var ab := await _setup(400.0)
	var a: Combatant = ab[0]
	a.is_player = true   # eating consumes from RunState only for the player
	a.set_physics_process(true)
	a.input_enabled = false
	var bread: FoodData = _item(&"stale_bread")
	RunState.inventory.add(bread, 2)
	a.current_health = 50.0
	_check(a.start_eating(bread), "eating starts")
	await _frames(int(bread.eat_time * 60.0) + 5)
	_check(is_equal_approx(a.current_health, 65.0), "bread heals +15 (hp %.0f)" % a.current_health)
	_check(RunState.inventory.count_of(bread) == 1, "one bread consumed")
	_check(is_equal_approx(RunState.player_health, 65.0), "health is saved to RunState")

	a.start_eating(bread)
	await _frames(10)
	a.receive_hit(5.0, "TORSO", Vector2.RIGHT, 0.0, ab[1], [])
	await _frames(int(bread.eat_time * 60.0))
	_check(RunState.inventory.count_of(bread) == 1 and not a.is_eating(), "a hit interrupts the meal, bread is kept")
	_check(is_equal_approx(a.current_health, 60.0), "no heal from an interrupted meal")

func _test_loot_drop() -> void:
	print("loot")
	var ab := await _setup(400.0, &"rusty_gladius", &"bone_club")
	var b: Combatant = ab[1]
	b.loot = [_item(&"dried_meat")] as Array[ItemData]
	b.receive_hit(500.0, "TORSO", Vector2.RIGHT, 0.0, ab[0], [])
	await _frames(3)
	var dropped: Array = []
	for n in _arena.get_children():
		if n is ItemPickup:
			dropped.append(n.item)
	_check(dropped.has(_item(&"bone_club")) and dropped.has(_item(&"dried_meat")),
		"the fallen husk drops its club and dried meat")
	_check(not b.weapon.visible, "the dropped weapon leaves the corpse's hand")

func _test_full_belt_swap() -> void:
	print("full belt swap")
	var ab := await _setup(400.0)
	var a: Combatant = ab[0]
	var inv := RunState.inventory
	inv.add(_item(&"iron_axe"))
	inv.add(_item(&"prisoner_dagger"))
	_check(inv.weapons.size() == 3 and inv.equipped == _item(&"rusty_gladius"), "belt full, gladius in hand")
	var pickup := ItemPickup.new()
	pickup.item = _item(&"rusty_spear")
	pickup.position = a.position
	_arena.add_child(pickup)
	await _frames(2)
	_check(pickup._take(), "spear is taken despite the full belt")
	await _frames(2)
	_check(inv.equipped == _item(&"rusty_spear") and not inv.weapons.has(_item(&"rusty_gladius")),
		"spear in hand, gladius left behind")
	var left_behind := false
	for n in _arena.get_children():
		if n is ItemPickup and n.item == _item(&"rusty_gladius"):
			left_behind = true
	_check(left_behind, "the gladius lies on the floor where the spear was")
	_check(a.weapon.data == _item(&"rusty_spear"), "the fighter now holds the spear")
