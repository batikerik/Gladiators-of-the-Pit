class_name CombatHUD
extends CanvasLayer

@onready var player_bar: ProgressBar = $MarginContainer/VBoxTop/HBoxBars/PlayerBox/PlayerHP
@onready var player_name_label: Label = $MarginContainer/VBoxTop/HBoxBars/PlayerBox/PlayerName
@onready var enemy_bar: ProgressBar = $MarginContainer/VBoxTop/HBoxBars/EnemyBox/EnemyHP
@onready var enemy_name_label: Label = $MarginContainer/VBoxTop/HBoxBars/EnemyBox/EnemyName
@onready var message_label: Label = $CenterContainer/MessageLabel
@onready var tutorial_panel: PanelContainer = get_node_or_null("TutorialPanel")
@onready var restart_hint: Label = $MarginContainerBottom/RestartHint

## false = a scene director (e.g. the tutorial) owns the end-of-fight flow
@export var show_end_messages: bool = true

var player_combatant: CharacterBody2D = null
var enemy_combatant: CharacterBody2D = null

func _ready() -> void:
	if message_label:
		message_label.text = ""
	_find_and_bind_combatants()

func _find_and_bind_combatants() -> void:
	var combatants: Array = get_tree().get_nodes_in_group(&"combatants")
	for c in combatants:
		if c is CharacterBody2D:
			if c.is_player:
				player_combatant = c
				c.took_damage.connect(_on_player_took_damage)
				c.defeated.connect(_on_player_defeated)
				if player_name_label:
					player_name_label.text = c.character_name
				if player_bar:
					player_bar.max_value = c.max_health
					player_bar.value = c.current_health
			else:
				enemy_combatant = c
				c.took_damage.connect(_on_enemy_took_damage)
				c.defeated.connect(_on_enemy_defeated)
				if enemy_name_label:
					enemy_name_label.text = c.character_name
				if enemy_bar:
					enemy_bar.max_value = c.max_health
					enemy_bar.value = c.current_health

func _on_player_took_damage(_amount: float, _zone: String, current_hp: float, _max_hp: float) -> void:
	if player_bar:
		var tween := create_tween()
		tween.tween_property(player_bar, "value", current_hp, 0.15)

func _on_enemy_took_damage(_amount: float, _zone: String, current_hp: float, _max_hp: float) -> void:
	if enemy_bar:
		var tween := create_tween()
		tween.tween_property(enemy_bar, "value", current_hp, 0.15)

func _on_player_defeated() -> void:
	if message_label and show_end_messages:
		message_label.text = "YOU DIED IN THE PIT\nPress R to Try Again"
		message_label.modulate = Color(1.0, 0.2, 0.2)

func _on_enemy_defeated() -> void:
	if message_label and show_end_messages:
		message_label.text = "VICTORY!\nEnemy Defeated\nPress R to Restart"
		message_label.modulate = Color(0.3, 1.0, 0.4)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
