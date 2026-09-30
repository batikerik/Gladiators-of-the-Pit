class_name CombatRoom
extends RoomDirector
## A fight: the opponent is rolled by Encounters for this map node (the same
## node always gives the same enemy). Victory opens the exit. The boss node
## brings the Armoured Survivor with his own BossBrain; beating him and
## walking out of the gate wins the descent.

@onready var opponent: Combatant = $Opponent

var encounter: Dictionary = {}
var boss_brain: BossBrain = null

func _enter_tree() -> void:
	super._enter_tree()
	# Configure the opponent before its _ready (and the HUD's) reads the values
	encounter = Encounters.combat(RunState.depth(), RunState.room_rng(), is_boss())
	var opp: Combatant = get_node("Opponent")
	opp.character_name = encounter["name"]
	opp.is_zombie = encounter["zombie"]
	opp.armor_tier = encounter["armor"]
	opp.weapon_data = encounter["weapon"]
	opp.max_health = encounter["health"]
	opp.ai_aggression = encounter["aggression"]
	opp.loot = encounter["loot"]
	opp.armor_zones = encounter["armor_zones"]
	opp.poise = encounter["poise"]
	if encounter["brain"] and opp.get_node_or_null("BossBrain") == null:
		boss_brain = BossBrain.new()
		boss_brain.name = "BossBrain"
		opp.add_child(boss_brain)

func is_boss() -> bool:
	return RunState.current_node().get("type") == CatacombMapGen.BOSS

func _setup_room() -> void:
	if RunState.room_cleared:
		# Re-entered after winning: the body is gone, nothing to fight
		opponent.queue_free()
		return
	opponent.defeated.connect(_on_opponent_defeated)
	if boss_brain:
		boss_brain.phase_changed.connect(_on_boss_phase)
		flash_message(tr("BOSS: %s\nHis plate stops blows to the body and legs — aim for the head") % tr(encounter["name"]),
			3.5, Color(1.0, 0.45, 0.35))
	else:
		flash_message(tr(encounter["name"]), 2.0)

func _on_boss_phase(phase: int) -> void:
	if phase == 2:
		hud.enemy_name_label.text = tr("%s — ENRAGED") % tr(encounter["name"])
		hud.enemy_name_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
		flash_message(tr("He is enraged! Beware the leap from above"), 2.5, Color(1.0, 0.4, 0.3))

func _on_opponent_defeated() -> void:
	if not player.is_alive:
		return
	RunState.stats["kills"] += 1
	await get_tree().create_timer(0.8).timeout
	open_exit()
	if RunState.boss_defeated:
		flash_message(tr("The Armoured Survivor has fallen!\nBeyond the gate — light. Walk towards it."), 4.0, Color(1.0, 0.85, 0.3))
	else:
		flash_message(tr("The way is clear — take the spoils and head for the gate"), 3.0)
