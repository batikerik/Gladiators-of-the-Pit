class_name WeaponPickup
extends Node2D
## A weapon lying in the world. The player walks up and presses E to take it.

signal picked_up

@export var pickup_range: float = 90.0
@export var prompt_text: String = "[E] Подобрать гладиус"

var _player: Combatant = null
var _label: Label = null
var _taken: bool = false
var _pulse: float = 0.0

func _ready() -> void:
	_label = Label.new()
	_label.top_level = true   # not rotated with the stuck-in sword
	_label.text = prompt_text
	_label.z_index = 60
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_label.visible = false
	add_child(_label)

func _process(delta: float) -> void:
	if _taken:
		return
	# Glint so the player notices it
	_pulse += delta * 4.0
	var glow: float = 1.0 + 0.4 * (0.5 + 0.5 * sin(_pulse))
	modulate = Color(glow, glow, glow)

	if _player == null:
		for c in get_tree().get_nodes_in_group(&"combatants"):
			if c is Combatant and c.is_player:
				_player = c
	var near: bool = _player != null and _player.input_enabled \
		and _player.global_position.distance_to(global_position) <= pickup_range
	_label.visible = near
	_label.global_position = global_position + Vector2(-80, -70)
	if near and Input.is_key_pressed(KEY_E):
		_take()

func _take() -> void:
	_taken = true
	_label.visible = false
	modulate = Color.WHITE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 40.0, 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
	picked_up.emit()
