class_name CombatRoom
extends RoomDirector
## A fight: the opponent is rolled by Encounters for this map node (the same
## node always gives the same enemy). Victory opens the exit; the boss node
## uses the boss profile.

@onready var opponent: Combatant = $Opponent

var encounter: Dictionary = {}

func _enter_tree() -> void:
	super._enter_tree()
	# Configure the opponent before its _ready (and the HUD's) reads the values
	var boss: bool = RunState.current_node().get("type") == CatacombMapGen.BOSS
	encounter = Encounters.combat(RunState.depth(), RunState.room_rng(), boss)
	var opp: Combatant = get_node("Opponent")
	opp.character_name = encounter["name"]
	opp.is_zombie = encounter["zombie"]
	opp.armor_tier = encounter["armor"]
	opp.weapon_data = encounter["weapon"]
	opp.max_health = encounter["health"]
	opp.ai_aggression = encounter["aggression"]
	opp.loot = encounter["loot"]

func _setup_room() -> void:
	if RunState.room_cleared:
		# Re-entered after winning: the body is gone, nothing to fight
		opponent.queue_free()
		return
	opponent.defeated.connect(_on_opponent_defeated)
	var boss: bool = RunState.current_node().get("type") == CatacombMapGen.BOSS
	flash_message(("БОСС: " if boss else "") + encounter["name"], 2.0,
		Color(1.0, 0.45, 0.35) if boss else Color(1.0, 0.9, 0.6))

func _on_opponent_defeated() -> void:
	if not player.is_alive:
		return
	await get_tree().create_timer(0.8).timeout
	open_exit()
	if RunState.boss_defeated:
		flash_message("Выживший в латах повержен!\nСвет наверху уже близко...", 4.0, Color(1.0, 0.85, 0.3))
	else:
		flash_message("Путь свободен — забери трофеи и иди к воротам", 3.0)
