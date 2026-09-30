class_name ExitDoor
extends Node2D
## Iron portcullis out of a room. Closed while the room is not cleared; once
## open the thief walks up and presses E to go back to the map.

signal used

@export var use_range: float = 80.0
@export var prompt_text: String = "[E] Вернуться к карте"

var is_open: bool = false
var _lift: float = 0.0       # 0 = bars down, 1 = bars up
var _glow: float = 0.0
var _label: Label
var _prev_e: bool = true
var _used: bool = false

func _ready() -> void:
	z_index = -1   # behind the fighters
	_label = Label.new()
	_label.top_level = true
	_label.z_index = 60
	_label.text = prompt_text
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.05))
	_label.add_theme_constant_override("outline_size", 4)
	_label.visible = false
	add_child(_label)

func open() -> void:
	if is_open:
		return
	is_open = true
	create_tween().tween_property(self, "_lift", 1.0, 0.8).set_trans(Tween.TRANS_QUAD)

func _process(delta: float) -> void:
	_glow += delta * 3.0
	queue_redraw()
	var player := _player()
	var near: bool = is_open and not _used and player != null and player.is_alive \
		and player.input_enabled and absf(player.global_position.x - global_position.x) <= use_range
	_label.visible = near
	if near:
		_label.global_position = global_position + Vector2(-_label.size.x * 0.5, -150)
	var e := Input.is_key_pressed(KEY_E)
	if near and e and not _prev_e:
		_used = true
		_label.visible = false
		used.emit()
	_prev_e = e

func _player() -> Combatant:
	for c in get_tree().get_nodes_in_group(&"combatants"):
		if c is Combatant and c.is_player:
			return c
	return null

func _draw() -> void:
	# Origin = bottom centre of the doorway (floor level)
	var w := 70.0
	var h := 120.0
	var stone := Color(0.22, 0.19, 0.25)
	# Frame and arch
	draw_rect(Rect2(-w * 0.5 - 14, -h - 10, 14, h + 10), stone)
	draw_rect(Rect2(w * 0.5, -h - 10, 14, h + 10), stone)
	draw_rect(Rect2(-w * 0.5 - 14, -h - 26, w + 28, 18), stone.lightened(0.1))
	# Opening: dark, warm light when open
	var inside := Color(0.03, 0.02, 0.04)
	if is_open:
		inside = inside.lerp(Color(0.5, 0.35, 0.15), 0.25 + 0.05 * sin(_glow))
	draw_rect(Rect2(-w * 0.5, -h - 8, w, h + 8), inside)
	# Portcullis bars, lifted by _lift
	var bars_bottom: float = lerpf(0.0, -h + 6.0, _lift)
	var iron := Color(0.32, 0.33, 0.37)
	for i in 6:
		var x: float = -w * 0.5 + 6.0 + i * (w - 12.0) / 5.0
		draw_line(Vector2(x, -h - 8), Vector2(x, bars_bottom), iron, 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 3, bars_bottom), Vector2(x + 3, bars_bottom), Vector2(x, bars_bottom + 6)
		]), iron)
	for j in 3:
		var y: float = lerpf(-h * 0.25 * (j + 1), -h + 6.0, _lift)
		draw_line(Vector2(-w * 0.5, y), Vector2(w * 0.5, y), iron, 3.0)
