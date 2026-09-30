class_name MainMenu
extends Node2D
## Title screen: the catacomb arena as a living backdrop (torches, drifting
## dust), the game title and Play / Settings / Exit.
## Play runs the intro (which can be skipped with Esc).

const PLAY_SCENE := "res://scenes/intro_cutscene.tscn"

var _t: float = 0.0
var _ui: CanvasLayer
var _menu: VBoxContainer
var _settings: SettingsPanel
var _name_panel: PanelContainer
var _name_edit: LineEdit
var _fade: ColorRect
var _leaving: bool = false
var _dust: Array[Vector3] = []   # x, y, speed

func _ready() -> void:
	get_tree().paused = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 40:
		_dust.append(Vector3(rng.randf_range(0, 1280), rng.randf_range(0, 720), rng.randf_range(6, 22)))
	Settings.changed.connect(_rebuild_texts)
	_build_ui()
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.8)

func _process(delta: float) -> void:
	_t += delta
	for i in _dust.size():
		var d := _dust[i]
		d.y += d.z * delta
		d.x += sin(_t * 0.5 + i) * 4.0 * delta
		if d.y > 720:
			d.y = -5
		_dust[i] = d
	queue_redraw()

func _draw() -> void:
	# Darken the arena behind the title, keep the torches glowing through
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.01, 0.03, 0.55))
	for i in 6:
		draw_rect(Rect2(0, 720 - (i + 1) * 40, 1280, 40), Color(0, 0, 0, 0.06 * (6 - i)))
	for d in _dust:
		draw_rect(Rect2(d.x, d.y, 2, 2), Color(0.9, 0.8, 0.6, 0.35))
	# A lone corpse on the arena floor, the Pit's welcome
	draw_rect(Rect2(930, 568, 34, 12), Color(0.45, 0.4, 0.36))
	draw_rect(Rect2(962, 564, 30, 16), Color(0.35, 0.18, 0.16))
	draw_circle(Vector2(1000, 572), 8.0, Color(0.45, 0.4, 0.36))
	draw_line(Vector2(970, 566), Vector2(1030, 548), Color(0.7, 0.72, 0.78), 3.0)   # his sword

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)

	var title := UiStyle.make_label("THE PIT", 96, UiStyle.GOLD)
	title.name = "Title"
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	title.add_theme_constant_override("outline_size", 12)
	title.position = Vector2(120, 90)
	_ui.add_child(title)
	var subtitle := UiStyle.make_label("", 24, UiStyle.TEXT)
	subtitle.name = "Subtitle"
	subtitle.position = Vector2(126, 210)
	_ui.add_child(subtitle)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 14)
	_menu.position = Vector2(120, 300)
	_ui.add_child(_menu)
	for entry in [["Play", _on_play], ["Settings", _on_settings], ["Exit", _on_exit]]:
		var b := UiStyle.make_button("", entry[1], 26, 320)
		b.name = entry[0]
		_menu.add_child(b)

	var stats := UiStyle.make_label("", 15, UiStyle.TEXT_DIM)
	stats.name = "Stats"
	stats.position = Vector2(122, 560)
	_ui.add_child(stats)
	var hint := UiStyle.make_label("", 13, UiStyle.TEXT_DIM)
	hint.name = "Hint"
	hint.position = Vector2(122, 660)
	_ui.add_child(hint)

	_settings = SettingsPanel.new()
	_settings.position = Vector2(560, 150)
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	_ui.add_child(_settings)

	_build_name_panel()

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_fade)

	_rebuild_texts()
	(_menu.get_node("Play") as Button).grab_focus()

func _rebuild_texts() -> void:
	(_ui.get_node("Subtitle") as Label).text = tr("Gladiators of the Catacombs")
	(_menu.get_node("Play") as Button).text = tr("Play")
	(_menu.get_node("Settings") as Button).text = tr("Settings")
	(_menu.get_node("Exit") as Button).text = tr("Exit")
	var lg := RunState.legacy
	var stats := _ui.get_node("Stats") as Label
	if int(lg.get("runs", 0)) > 0:
		stats.text = tr("Escapees: %d     Fallen: %d     Escaped: %d") % [lg.get("runs", 0), lg.get("deaths", 0), lg.get("victories", 0)]
		if not RunState.corpse().is_empty():
			stats.text += "\n" + tr("A body with belongings waits at depth %d.") % int(RunState.corpse().get("layer", 1))
	else:
		stats.text = ""
	(_ui.get_node("Hint") as Label).text = tr("A vertical slice made with Summer Engine")
	if _name_panel:
		(_name_panel.find_child("NameTitle", true, false) as Label).text = tr("What is your name, thief?")
		(_name_panel.find_child("NameHint", true, false) as Label).text = tr("Shown above your health bar. Leave it empty to stay a nameless escapee.")
		(_name_panel.find_child("Begin", true, false) as Button).text = tr("Begin")
		(_name_panel.find_child("NameBack", true, false) as Button).text = tr("Back")
		_name_edit.placeholder_text = tr("Escapee")

## Play first asks for the thief's name (remembered in Settings).
func _on_play() -> void:
	if _leaving:
		return
	_menu.visible = false
	_name_panel.visible = true
	_name_edit.text = Settings.nickname
	_name_edit.grab_focus()
	_name_edit.select_all()

func _build_name_panel() -> void:
	_name_panel = PanelContainer.new()
	_name_panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	_name_panel.position = Vector2(120, 290)
	_name_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_name_panel.add_child(box)
	var title := UiStyle.make_label("", 26, UiStyle.GOLD)
	title.name = "NameTitle"
	box.add_child(title)
	_name_edit = LineEdit.new()
	_name_edit.max_length = Settings.NICKNAME_MAX
	_name_edit.custom_minimum_size = Vector2(420, 48)
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _begin())
	box.add_child(_name_edit)
	var hint := UiStyle.make_label("", 14, UiStyle.TEXT_DIM)
	hint.name = "NameHint"
	box.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var begin := UiStyle.make_button("", _begin, 22, 200)
	begin.name = "Begin"
	row.add_child(begin)
	var back := UiStyle.make_button("", _cancel_name, 22, 200)
	back.name = "NameBack"
	row.add_child(back)
	box.add_child(row)
	_ui.add_child(_name_panel)

func _cancel_name() -> void:
	_name_panel.visible = false
	_menu.visible = true
	(_menu.get_node("Play") as Button).grab_focus()

## Save the name and start the descent.
func _begin() -> void:
	if _leaving:
		return
	Settings.set_nickname(_name_edit.text)
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(PLAY_SCENE))

func _on_settings() -> void:
	_menu.visible = false
	_settings.visible = true
	_settings.focus_first()

func _close_settings() -> void:
	_settings.visible = false
	_menu.visible = true
	_rebuild_texts()
	(_menu.get_node("Settings") as Button).grab_focus()

func _on_exit() -> void:
	get_tree().quit()
