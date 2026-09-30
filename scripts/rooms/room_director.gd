class_name RoomDirector
extends Node2D
## Shared flow of a map room: fade in, open the exit when the room is cleared,
## go back to the map through the door, and start a new descent after death.
## Subclasses: CombatRoom, LootRoom, SafeRoom.

@onready var player: Combatant = $Player
@onready var door: ExitDoor = $ExitDoor
@onready var hud: CombatHUD = $HUD

var _fade: ColorRect
var _message_serial: int = 0
var _leaving: bool = false

func _enter_tree() -> void:
	# Launched straight from the editor (F6): make up a descent and stand on the
	# first map node of this room's type, so the room works on its own
	if not RunState.run_active or RunState.map.is_empty():
		RunState.new_run()
		for n in RunState.map:
			if n["type"] == room_type():
				RunState.current_node_id = n["id"]
				RunState.room_cleared = false
				break

## Map node type this scene serves when launched directly. Override.
func room_type() -> StringName:
	return CatacombMapGen.COMBAT

func _ready() -> void:
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(_fade)
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.5)

	door.used.connect(_leave)
	player.defeated.connect(_on_player_defeated)
	if RunState.room_cleared:
		door.open()   # coming back to an already cleared room
	_setup_room()

## Room-specific setup (enemy, loot, campfire). Override.
func _setup_room() -> void:
	pass

## Mark the room done in RunState and lift the portcullis.
func open_exit() -> void:
	RunState.clear_current_room()
	door.open()

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(RunState.MAP_SCENE))

func _on_player_defeated() -> void:
	flash_message("ТЫ ПАЛ В ЯМЕ\n[R] — начать новый спуск", 0.0, Color(1.0, 0.25, 0.2))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and event.keycode == KEY_R and not player.is_alive and not _leaving:
		_leaving = true
		RunState.new_run()
		get_tree().change_scene_to_file(RunState.MAP_SCENE)

## Centre-screen message; duration 0 keeps it until replaced.
func flash_message(text: String, duration: float, color: Color = Color(1.0, 0.9, 0.6)) -> void:
	_message_serial += 1
	var serial := _message_serial
	hud.message_label.text = text
	hud.message_label.modulate = color
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration).timeout
	if serial == _message_serial:   # skip if a newer message replaced this one
		hud.message_label.text = ""
