class_name ItemPickup
extends Node2D
## An item lying in the world. The player walks up and presses E to take it.
## A weapon with a full weapon belt swaps places with the one in hand.

signal picked_up(item: ItemData)

@export var item: ItemData
@export var pickup_range: float = 90.0
## Drawn stuck point-down into the ground (tutorial sword in the corpse pile)
@export var stuck: bool = false
## Spawned by a dying fighter: bounces out instead of just appearing
@export var pop_in: bool = false

## Only one pickup reacts to a single E press
static var _last_take_frame: int = -1

var _player: Combatant = null
var _label: Label = null
var _taken: bool = false
var _pulse: float = 0.0
var _prev_e: bool = true   # ignore an E that is already held when we appear

func _ready() -> void:
	add_to_group(&"item_pickups")
	z_index = 5
	if stuck:
		rotation = 1.8
	elif item is WeaponData:
		rotation = -0.08
	_label = Label.new()
	_label.top_level = true   # not rotated with the item
	_label.z_index = 60
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.05))
	_label.add_theme_constant_override("outline_size", 4)
	_label.visible = false
	add_child(_label)
	if pop_in:
		var land_y := position.y
		position.y -= 40.0
		var tw := create_tween()
		tw.tween_property(self, "position:y", land_y, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	if item is WeaponData:
		# Centre the weapon on the node (stuck: the blade sinks in below it)
		var length: float = 18.0 + item.reach
		var origin_x: float = -length * (0.35 if stuck else 0.5)
		ItemArt.draw_weapon(self, item.style, item.reach, Vector2(origin_x, 0.0))
	elif item is FoodData:
		ItemArt.draw_food(self, item.style, Vector2(0, -6), 1.0)

func _process(delta: float) -> void:
	if _taken or item == null:
		return
	# Glint so the player notices it
	_pulse += delta * 4.0
	var glow: float = 1.0 + 0.35 * (0.5 + 0.5 * sin(_pulse))
	modulate = Color(glow, glow, glow)

	if _player == null or not is_instance_valid(_player):
		_player = null
		for c in get_tree().get_nodes_in_group(&"combatants"):
			if c is Combatant and c.is_player:
				_player = c
	var near: bool = _player != null and _player.input_enabled and _player.is_alive \
		and _player.global_position.distance_to(global_position) <= pickup_range \
		and _is_nearest_to_player()
	_label.visible = near
	if near:
		_label.text = _prompt_text()
		_label.global_position = global_position + Vector2(-_label.size.x * 0.5, -78)

	var e := Input.is_key_pressed(KEY_E)
	if near and e and not _prev_e and _last_take_frame != Engine.get_process_frames():
		_last_take_frame = Engine.get_process_frames()
		_take()
	_prev_e = e

func _is_nearest_to_player() -> bool:
	var my_d := _player.global_position.distance_to(global_position)
	for p in get_tree().get_nodes_in_group(&"item_pickups"):
		if p != self and not p._taken and _player.global_position.distance_to(p.global_position) < my_d:
			return false
	return true

func _prompt_text() -> String:
	var inv := RunState.inventory
	if item is FoodData:
		if not inv.can_add(item):
			return "%s — больше не унести" % item.display_name
		return "[E] Подобрать: %s (+%d HP)" % [item.display_name, int(item.heal_amount)]
	if item is WeaponData and not inv.can_add(item) and inv.equipped:
		return "[E] Сменить %s на %s" % [inv.equipped.display_name, item.display_name]
	return "[E] Подобрать: %s" % item.display_name

## Picks the item up into RunState.inventory. Returns false if it does not fit.
func _take() -> bool:
	var inv := RunState.inventory
	if item is WeaponData and not inv.can_add(item) and inv.equipped:
		# Full belt: leave the weapon in hand here, take this one
		var dropped := inv.equipped
		inv.remove(dropped)
		var swap := ItemPickup.new()
		swap.item = dropped
		swap.position = position
		get_parent().add_child.call_deferred(swap)
	if not inv.add(item):
		if _player:
			_player.say("Больше не унести.")
		return false
	if item is WeaponData:
		inv.equip(item)   # the new weapon goes straight into the hand

	_taken = true
	_label.visible = false
	modulate = Color.WHITE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 40.0, 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
	picked_up.emit(item)
	return true
