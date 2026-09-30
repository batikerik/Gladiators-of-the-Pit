extends CanvasLayer
## Autoload "PauseMenu": [Esc] in the map, rooms, tutorial and arena pauses
## the game with Resume / Settings / Main menu / Quit.
## Not available on the title screen, in the intro or on the run end screen;
## an open inventory takes Esc first.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const NO_PAUSE_SCENES: Array[String] = ["MainMenu", "IntroCutscene", "RunEndScreen"]

var _root: Control
var _menu: VBoxContainer
var _settings: SettingsPanel

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	Settings.changed.connect(_rebuild_texts)

func is_open() -> bool:
	return _root.visible

func can_pause() -> bool:
	var scene := get_tree().current_scene
	if scene == null or String(scene.name) in NO_PAUSE_SCENES:
		return false
	return not InventoryScreen.is_open()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if is_open():
		if _settings.visible:
			return   # the settings panel closes itself on Esc
		get_viewport().set_input_as_handled()
		resume()
	elif can_pause():
		get_viewport().set_input_as_handled()
		open()

func open() -> void:
	_root.visible = true
	_menu.visible = true
	_settings.visible = false
	get_tree().paused = true
	_rebuild_texts()
	(_menu.get_node("Resume") as Button).grab_focus()

func resume() -> void:
	_root.visible = false
	get_tree().paused = false

func _to_main_menu() -> void:
	resume()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _quit() -> void:
	get_tree().quit()

func _open_settings() -> void:
	_menu.visible = false
	_settings.visible = true
	_settings.focus_first()

func _close_settings() -> void:
	_settings.visible = false
	_menu.visible = true
	_rebuild_texts()
	(_menu.get_node("Settings") as Button).grab_focus()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.position = Vector2(470, 190)
	_root.add_child(panel)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	panel.add_child(_menu)
	var title := UiStyle.make_label("", 28, UiStyle.GOLD)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(title)
	for entry in [["Resume", resume], ["Settings", _open_settings], ["MainMenu", _to_main_menu], ["Quit", _quit]]:
		var b := UiStyle.make_button("", entry[1], 22, 300)
		b.name = entry[0]
		_menu.add_child(b)

	_settings = SettingsPanel.new()
	_settings.position = Vector2(330, 150)
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	_root.add_child(_settings)
	_rebuild_texts()

func _rebuild_texts() -> void:
	(_menu.get_node("Title") as Label).text = tr("PAUSED")
	(_menu.get_node("Resume") as Button).text = tr("Resume")
	(_menu.get_node("Settings") as Button).text = tr("Settings")
	(_menu.get_node("MainMenu") as Button).text = tr("Main menu")
	(_menu.get_node("Quit") as Button).text = tr("Quit game")
