class_name CorpsePile
extends Node2D
## The previous thief's body, lying where he fell, with everything he carried.
## E takes it all; what does not fit (a 4th weapon, a full food stack) spills
## onto the floor. Once searched the body is gone from the legacy save.

signal looted

@export var use_range: float = 80.0

var owner_name: String = ""
var items: Array[ItemData] = []
var _label: Label
var _prev_e: bool = true
var _searched: bool = false
var _t: float = 0.0

func _ready() -> void:
	z_index = -1
	_label = Label.new()
	_label.top_level = true
	_label.z_index = 60
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.05))
	_label.add_theme_constant_override("outline_size", 4)
	_label.visible = false
	add_child(_label)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _searched:
		return
	var player: Combatant = null
	for c in get_tree().get_nodes_in_group(&"combatants"):
		if c is Combatant and c.is_player:
			player = c
	var near: bool = player != null and player.is_alive and player.input_enabled \
		and absf(player.global_position.x - global_position.x) <= use_range
	_label.visible = near
	if near:
		_label.text = tr("[E] Search the body: %s (%d items)") % [owner_name, items.size()]
		_label.global_position = global_position + Vector2(-_label.size.x * 0.5, -90)
	var e := Input.is_key_pressed(KEY_E)
	if near and e and not _prev_e:
		search()
	_prev_e = e

## Take everything that fits; the rest drops next to the body.
func search() -> Array[ItemData]:
	if _searched:
		return []
	_searched = true
	_label.visible = false
	var taken: Array[ItemData] = []
	var spilled := 0
	for item in items:
		if RunState.inventory.add(item):
			taken.append(item)
		else:
			var pickup := ItemPickup.new()
			pickup.item = item
			pickup.position = position + Vector2(-40.0 + 30.0 * spilled, -12.0)
			pickup.pop_in = true
			get_parent().add_child.call_deferred(pickup)
			spilled += 1
	RunState.consume_corpse()
	looted.emit()
	return taken

func _draw() -> void:
	# A body in a torn tunic lying on its back, a sack beside it
	var skin := Color(0.62, 0.55, 0.48)
	var cloth := Color(0.3, 0.28, 0.3) if _searched else Color(0.45, 0.3, 0.28)
	draw_rect(Rect2(-34, -12, 30, 12), skin)           # legs
	draw_rect(Rect2(-6, -16, 32, 16), cloth)           # torso
	draw_circle(Vector2(34, -9), 9.0, skin)            # head
	draw_rect(Rect2(28, -20, 12, 5), Color(0.2, 0.15, 0.1))   # hair
	draw_line(Vector2(6, -14), Vector2(18, -30), skin, 4.0)   # arm raised stiff
	if not _searched:
		draw_circle(Vector2(-48, -12), 13.0, Color(0.42, 0.36, 0.26))   # sack
		draw_rect(Rect2(-52, -28, 8, 6), Color(0.3, 0.25, 0.17))
		# Pale glow so the player notices it from across the room
		var pulse: float = 0.5 + 0.5 * sin(_t * 2.5)
		draw_circle(Vector2(0, -12), 60.0, Color(0.6, 0.8, 1.0, 0.05 + 0.04 * pulse))
