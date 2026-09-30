class_name TutorialDirector
extends Node2D
## Tutorial flow: fall onto the corpse pile -> pick up the gladius -> hit the
## harmless, immortal zombie in the head, torso and legs -> it becomes mortal,
## finish it -> fade into the first real fight.

@export var next_scene_path: String = "res://main.tscn"

enum Step { FALLING, LANDED, PICKUP, ZONES, FINISH, DONE }
var _step: Step = Step.FALLING

@onready var player: Combatant = $Player
@onready var zombie: Combatant = $Zombie
@onready var pickup: WeaponPickup = $WeaponPickup
@onready var hud: CanvasLayer = $HUD
@onready var hint_label: Label = $HUD/MarginContainerBottom/RestartHint
@onready var message_label: Label = $HUD/CenterContainer/MessageLabel

const OBJECTIVES: Array = [
	["weapon", "Подбери оружие на горе трупов"],
	["HEAD",   "Удар в голову  (курсор выше плеча)"],
	["TORSO",  "Удар в торс  (курсор на уровне груди)"],
	["LEGS",   "Удар по ногам  (курсор ниже пояса) — подсекает"],
	["finish", "Добей зомби"],
]
const COLOR_TODO := Color(0.85, 0.82, 0.75)
const COLOR_DONE := Color(0.45, 0.95, 0.45)

var _objective_labels: Dictionary = {}   # id -> Label
var _zones_hit: Dictionary = {"HEAD": false, "TORSO": false, "LEGS": false}
var _panel: PanelContainer = null
var _fade: ColorRect = null
var _message_serial: int = 0

func _ready() -> void:
	player.input_enabled = false
	zombie.ai_enabled = false
	pickup.picked_up.connect(_on_weapon_picked)
	zombie.took_damage.connect(_on_zombie_hit)
	zombie.defeated.connect(_on_zombie_defeated)

	hint_label.text = ""
	message_label.text = ""
	_build_objective_panel()
	_build_fade()
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.8)

func _physics_process(_delta: float) -> void:
	if _step == Step.FALLING and player.is_on_floor():
		_on_landed()

# ── Flow ─────────────────────────────────────────────────────────────────────
func _on_landed() -> void:
	_step = Step.LANDED
	player.land_heavy(1.0)
	await get_tree().create_timer(0.9).timeout
	player.say("...живой?")
	await get_tree().create_timer(1.3).timeout
	player.say("Там что-то блестит.")
	player.input_enabled = true
	_step = Step.PICKUP
	_show_panel()
	hint_label.text = "[A / D] Прыжок   |   [E] Подобрать"

func _on_weapon_picked() -> void:
	player.equip_weapon()
	_complete("weapon")
	player.say("Гладиус. Сойдёт.")
	_step = Step.ZONES
	hint_label.text = "[Зажми и отпусти ЛКМ] Удар — высота курсора выбирает зону   |   [ПКМ] Укол   |   [S / Shift] Блок   |   [R] Заново"
	await get_tree().create_timer(0.8).timeout
	zombie.ai_enabled = true
	zombie.say("Гххррр...", Color(0.6, 0.85, 0.5))
	_flash_message("Зомби не умрёт, пока ты не отработаешь удары\nпо голове, торсу и ногам", 3.5)

func _on_zombie_hit(_amount: float, zone: String, _hp: float, _max_hp: float) -> void:
	if _step != Step.ZONES or not _zones_hit.has(zone) or _zones_hit[zone]:
		return
	_zones_hit[zone] = true
	_complete(zone)
	if _zones_hit.values().all(func(done: bool) -> bool: return done):
		_step = Step.FINISH
		zombie.immortal = false
		zombie.say("Ррр?!", Color(0.6, 0.85, 0.5))
		_flash_message("Зомби стал уязвим — добей его!", 2.5)

func _on_zombie_defeated() -> void:
	_complete("finish")
	_step = Step.DONE
	_flash_message("ОБУЧЕНИЕ ПРОЙДЕНО", 3.0)
	player.say("Дальше — глубже в катакомбы.")
	await get_tree().create_timer(2.5).timeout
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 1.0)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(next_scene_path))

# ── UI ───────────────────────────────────────────────────────────────────────
func _build_objective_panel() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.85)
	style.border_color = Color(0.55, 0.42, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(40, 100)
	_panel.visible = false

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "ЗАДАНИЯ"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	vbox.add_child(title)

	for entry in OBJECTIVES:
		var label := Label.new()
		label.text = "[  ]  " + entry[1]
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", COLOR_TODO)
		vbox.add_child(label)
		_objective_labels[entry[0]] = label
	hud.add_child(_panel)

func _show_panel() -> void:
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.4)

func _complete(id: String) -> void:
	var label: Label = _objective_labels.get(id)
	if label == null or label.text.begins_with("[x]"):
		return
	label.text = "[x]" + label.text.substr(4)
	label.add_theme_color_override("font_color", COLOR_DONE)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(1.15, 1.15)
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.25)

func _flash_message(text: String, duration: float) -> void:
	_message_serial += 1
	var serial := _message_serial
	message_label.text = text
	message_label.modulate = Color(1.0, 0.9, 0.6)
	await get_tree().create_timer(duration).timeout
	if serial == _message_serial:   # skip if a newer message replaced this one
		message_label.text = ""

func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(_fade)
