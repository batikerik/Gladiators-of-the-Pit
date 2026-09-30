class_name LootRoom
extends RoomDirector
## A quiet cache: food and sometimes a weapon lie among the urns. The exit is
## open from the start — take what fits and move on.

const SPAWN_Y: float = 568.0

func room_type() -> StringName:
	return CatacombMapGen.LOOT

func _setup_room() -> void:
	if not RunState.room_cleared:
		var items := Encounters.cache(RunState.depth(), RunState.room_rng())
		for i in items.size():
			var pickup := ItemPickup.new()
			pickup.item = items[i]
			pickup.position = Vector2(470.0 + i * 150.0, SPAWN_Y)
			add_child(pickup)
		flash_message("Тайник мертвецов", 2.0)
	open_exit()
