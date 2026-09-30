class_name RoomDirector
extends Node2D
## Shared flow of a map room: fade in, open the exit when the room is cleared,
## go back to the map through the door (or to the victory screen after the
## boss), lay out the previous thief's body if it lies here, and on death save
## the new body and show the run end screen.
## Subclasses: CombatRoom, LootRoom, SafeRoom.

## Seconds between the killing blow and the run end screen
const DEATH_DELAY: float = 2.5

@onready var player: Combatant = $Player
@onready var door: ExitDoor = $ExitDoor
@onready var hud: CombatHUD = $HUD

## The previous thief's body in this room (null if it lies elsewhere)
var corpse_pile: CorpsePile = null
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
	_spawn_corpse()
	_setup_room()

func _spawn_corpse() -> void:
	if RunState.corpse_node_id != RunState.current_node_id or RunState.corpse().is_empty():
		return
	var c := RunState.corpse()
	corpse_pile = CorpsePile.new()
	corpse_pile.owner_name = RunState.corpse_name()
	corpse_pile.items = RunState.corpse_items()
	corpse_pile.position = Vector2(clampf(float(c["x"]), 160.0, 1060.0), 580.0)
	add_child(corpse_pile)
	corpse_pile.looted.connect(func() -> void:
		flash_message(tr("You took the belongings of %s.\nMay his death not be in vain.") % corpse_pile.owner_name, 3.0,
			Color(0.75, 0.9, 1.0)))

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
	# Past the boss the portcullis opens onto daylight: the descent is won
	var next_scene := RunState.MAP_SCENE
	if RunState.boss_defeated:
		RunState.record_victory()
		next_scene = RunState.RUN_END_SCENE
	_fade_to(next_scene, 0.5)

func _on_player_defeated() -> void:
	if _leaving:
		return
	_leaving = true
	# Permadeath: the body and everything on it stays here for the next thief
	RunState.record_death(player.global_position.x)
	flash_message(tr("YOU FELL IN THE PIT"), 0.0, Color(1.0, 0.25, 0.2))
	await get_tree().create_timer(DEATH_DELAY).timeout
	_fade_to(RunState.RUN_END_SCENE, 1.0)

func _fade_to(scene: String, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, duration)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(scene))

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
