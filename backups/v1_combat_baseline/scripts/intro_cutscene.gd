class_name IntroCutscene
extends Node2D

@export var next_scene_path: String = "res://scenes/tutorial_room.tscn"

# State
var _phase: int = 0
var _timer: float = 0.0
var _camera_shake: float = 0.0

# Nodes
@onready var camera: Camera2D = $Camera2D
@onready var judge: Node2D = $Judge
@onready var player: Node2D = $Player
@onready var dialog_box: PanelContainer = $HUD/DialogContainer
@onready var speaker_label: Label = $HUD/DialogContainer/Margin/VBox/SpeakerLabel
@onready var text_label: Label = $HUD/DialogContainer/Margin/VBox/TextLabel
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var fade_rect: ColorRect = $HUD/FadeRect

var _dialogues: Array = [
	{
		"speaker": "ВЕРХОВНЫЙ СУДЬЯ КРЕПОСТИ",
		"text": "Вор! Ты посмел покуситься на неприкосновенные запасы зерна в осаждённом городе!",
		"speaker_color": Color(0.9, 0.7, 0.2)
	},
	{
		"speaker": "ТЫ (ОСУЖДЁННЫЙ)",
		"text": "Люди на нижних улицах умирали с голоду! Дети просили хоть корку хлеба!",
		"speaker_color": Color(0.8, 0.8, 0.8)
	},
	{
		"speaker": "ВЕРХОВНЫЙ СУДЬЯ КРЕПОСТИ",
		"text": "Причины кражи не имеют значения. Важен лишь факт преступления.\nТы приговариваешься к падению в Бездну!",
		"speaker_color": Color(0.9, 0.7, 0.2)
	},
	{
		"speaker": "ВЕРХОВНЫЙ СУДЬЯ КРЕПОСТИ",
		"text": "ЭТО... НАША... ЯМА!!!",
		"speaker_color": Color(1.0, 0.2, 0.2)
	}
]
var _current_dialogue_idx: int = 0
var _kick_in_progress: bool = false
var _player_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	fade_rect.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.2)
	_show_dialogue(0)

func _process(delta: float) -> void:
	if _camera_shake > 0.0:
		camera.offset = Vector2(randf_range(-12, 12), randf_range(-12, 12)) * _camera_shake
		_camera_shake = maxf(0.0, _camera_shake - delta * 2.5)
	else:
		camera.offset = Vector2.ZERO
	
	if _kick_in_progress:
		_player_velocity.y += 980.0 * delta
		player.position += _player_velocity * delta
		player.rotation -= 8.0 * delta # Tumble backwards

func _unhandled_input(event: InputEvent) -> void:
	if _kick_in_progress:
		return
	
	if (event is InputEventKey and event.is_pressed() and not event.is_echo()) or \
	   (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
		_advance_cutscene()

func _advance_cutscene() -> void:
	_current_dialogue_idx += 1
	if _current_dialogue_idx < _dialogues.size():
		_show_dialogue(_current_dialogue_idx)
		if _current_dialogue_idx == 3:
			# Spartan kick shout!
			_camera_shake = 0.5
			if prompt_label:
				prompt_label.text = "[Кликните, чтобы совершить казнь]"
	else:
		_execute_spartan_kick()

func _show_dialogue(idx: int) -> void:
	var d: Dictionary = _dialogues[idx]
	speaker_label.text = d["speaker"]
	speaker_label.modulate = d["speaker_color"]
	text_label.text = d["text"]

func _execute_spartan_kick() -> void:
	_kick_in_progress = true
	dialog_box.visible = false
	prompt_label.visible = false
	
	# Animate Spartan Kick
	# Judge raises leg and kicks!
	var judge_leg: Node2D = judge.get_node_or_null("LegRight")
	if judge_leg:
		var leg_tween := create_tween()
		leg_tween.tween_property(judge_leg, "rotation", deg_to_rad(-70), 0.15)
		leg_tween.tween_property(judge_leg, "rotation", deg_to_rad(65), 0.08)
	
	# Player receives colossal kick impulse
	_camera_shake = 1.0
	_player_velocity = Vector2(550.0, -320.0) # Launch into the pit abyss
	
	# Spawn impact spark
	VFXSpawner.spawn_hit_impact(get_tree(), player.global_position, Vector2(1, -0.3), "TORSO")
	
	# Fade to dark abyss and transition
	var fade_tween := create_tween()
	fade_tween.tween_interval(1.4)
	fade_tween.tween_property(fade_rect, "modulate:a", 1.0, 1.0)
	fade_tween.tween_callback(_go_to_tutorial)

func _go_to_tutorial() -> void:
	get_tree().change_scene_to_file(next_scene_path)
