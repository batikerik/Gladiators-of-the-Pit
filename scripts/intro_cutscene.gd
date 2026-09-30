class_name IntroCutscene
extends Node2D
## Opening: sentence on the execution ledge -> Spartan kick -> fall down the Pit.
## Click / any key advances the dialogue, Esc skips straight to the tutorial.

@export var next_scene_path: String = "res://scenes/tutorial_room.tscn"
@export var fall_duration: float = 2.6       # Seconds of falling before the fade
@export var kick_velocity: Vector2 = Vector2(560.0, -340.0)
@export var fall_gravity: float = 980.0
@export var max_fall_speed: float = 1400.0

enum Phase { DIALOGUE, KICK, FALL, DONE }
var _phase: Phase = Phase.DIALOGUE
var _camera_shake: float = 0.0
var _player_velocity: Vector2 = Vector2.ZERO
var _fall_time: float = 0.0

# Nodes
@onready var camera: Camera2D = $Camera2D
@onready var judge: Node2D = $Judge
@onready var judge_leg: Node2D = $Judge/LegRight
@onready var player: Node2D = $Player
@onready var backdrop: IntroBackdrop = $Backdrop
@onready var dialog_box: PanelContainer = $HUD/DialogContainer
@onready var speaker_label: Label = $HUD/DialogContainer/Margin/VBox/SpeakerLabel
@onready var text_label: Label = $HUD/DialogContainer/Margin/VBox/TextLabel
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var fade_rect: ColorRect = $HUD/FadeRect

var _dialogues: Array = [
	{
		"speaker": "HIGH JUDGE OF THE FORTRESS",
		"text": "Thief! You dared to touch the sacred grain stores of a city under siege!",
		"speaker_color": Color(0.9, 0.7, 0.2)
	},
	{
		"speaker": "YOU (THE CONDEMNED)",
		"text": "People in the lower streets were starving! Children begged for a crust of bread!",
		"speaker_color": Color(0.8, 0.8, 0.8)
	},
	{
		"speaker": "HIGH JUDGE OF THE FORTRESS",
		"text": "Your reasons do not matter. Only the crime does.\nYou are sentenced to the Abyss!",
		"speaker_color": Color(0.9, 0.7, 0.2)
	},
	{
		"speaker": "HIGH JUDGE OF THE FORTRESS",
		"text": "THIS... IS... THE PIT!!!",
		"speaker_color": Color(1.0, 0.2, 0.2)
	}
]
var _current_dialogue_idx: int = 0

func _ready() -> void:
	fade_rect.modulate.a = 1.0
	create_tween().tween_property(fade_rect, "modulate:a", 0.0, 1.2)
	prompt_label.text = tr("[LMB / any key — next]   [Esc — skip]")
	_show_dialogue(0)

func _process(delta: float) -> void:
	if _camera_shake > 0.0:
		camera.offset = Vector2(randf_range(-12, 12), randf_range(-12, 12)) * _camera_shake * Settings.screen_shake
		_camera_shake = maxf(0.0, _camera_shake - delta * 2.5)
	else:
		camera.offset = Vector2.ZERO

	if _phase == Phase.FALL:
		_process_fall(delta)

func _process_fall(delta: float) -> void:
	_fall_time += delta
	_player_velocity.y = minf(_player_velocity.y + fall_gravity * delta, max_fall_speed)
	# Air drag on x so the body drifts into the middle of the shaft instead of hitting the far wall
	_player_velocity.x = move_toward(_player_velocity.x, 0.0, 480.0 * delta)
	player.position += _player_velocity * delta
	player.rotation -= 7.0 * delta   # tumble backwards

	# Camera dives after the body once it drops below the ledge
	var shaft_center: float = (backdrop.pit_left + backdrop.pit_right) * 0.5
	var target := Vector2(lerpf(camera.position.x, shaft_center, 0.5), player.position.y - 80.0)
	if player.position.y > camera.position.y - 100.0:
		camera.position = camera.position.lerp(target, 5.0 * delta)

	if _fall_time >= fall_duration and _phase == Phase.FALL:
		_phase = Phase.DONE
		var fade := create_tween()
		fade.tween_property(fade_rect, "modulate:a", 1.0, 0.9)
		fade.tween_callback(_go_to_tutorial)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		if _phase != Phase.DONE:
			_phase = Phase.DONE
			_go_to_tutorial()
		return
	if _phase != Phase.DIALOGUE:
		return
	if (event is InputEventKey and event.is_pressed() and not event.is_echo()) or \
	   (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
		_advance_cutscene()

func _advance_cutscene() -> void:
	_current_dialogue_idx += 1
	if _current_dialogue_idx < _dialogues.size():
		_show_dialogue(_current_dialogue_idx)
		if _current_dialogue_idx == _dialogues.size() - 1:
			# The shout: judge steps up, screen shakes
			_camera_shake = 0.5
			create_tween().tween_property(judge, "position:x", judge.position.x + 22.0, 0.25)
			prompt_label.text = tr("[Click to carry out the sentence]")
	else:
		_execute_spartan_kick()

func _show_dialogue(idx: int) -> void:
	var d: Dictionary = _dialogues[idx]
	speaker_label.text = tr(d["speaker"])
	speaker_label.modulate = d["speaker_color"]
	text_label.text = tr(d["text"])

func _execute_spartan_kick() -> void:
	_phase = Phase.KICK
	dialog_box.visible = false
	prompt_label.visible = false

	# Wind the leg back, snap it forward; the hit lands at full extension
	var leg := create_tween()
	leg.tween_property(judge_leg, "rotation", deg_to_rad(35.0), 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	leg.tween_property(judge_leg, "rotation", deg_to_rad(-85.0), 0.07)
	leg.tween_callback(_on_kick_impact)
	leg.tween_interval(0.5)
	leg.tween_property(judge_leg, "rotation", 0.0, 0.3)

func _on_kick_impact() -> void:
	_camera_shake = 1.0
	_player_velocity = kick_velocity
	_phase = Phase.FALL
	VFXSpawner.spawn_hit_impact(get_tree(), player.global_position, Vector2(1, -0.3), "TORSO")
	VFXSpawner.apply_hitstop(get_tree(), 0.08)

func _go_to_tutorial() -> void:
	get_tree().change_scene_to_file(next_scene_path)
