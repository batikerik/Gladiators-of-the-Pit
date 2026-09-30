class_name SafeRoom
extends RoomDirector
## Campfire nook: rest once by the fire (food buys a full heal, no food costs
## health — RunState.rest()), sort the inventory with [Tab], leave any time.

@onready var campfire: Campfire = $Campfire

func room_type() -> StringName:
	return CatacombMapGen.SAFE

func _setup_room() -> void:
	campfire.rest_requested.connect(_on_rest)
	if RunState.room_cleared:
		campfire.rest_available = false
	open_exit()
	flash_message(tr("Safe room\nRest by the fire — [E], inventory — [Tab]"), 3.0)

func _on_rest() -> void:
	player.input_enabled = false
	var dim := create_tween()
	dim.tween_property(_fade, "modulate:a", 0.75, 0.6)
	await dim.finished

	var result: Dictionary = RunState.rest()
	player.set_health(RunState.player_health)
	var text: String
	if result["fed"]:
		var names := PackedStringArray()
		for food in result["eaten"]:
			names.append(tr(food.display_name))
		text = tr("You ate: %s\nHealth fully restored") % ", ".join(names)
	else:
		text = tr("Not enough food. Sleeping on an empty stomach\ncost %d%% of your health") % int(RunState.HUNGER_PENALTY * 100)

	await get_tree().create_timer(0.8).timeout
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.6)
	player.input_enabled = true
	flash_message(text, 3.5, Color(0.6, 1.0, 0.6) if result["fed"] else Color(1.0, 0.55, 0.4))
