class_name SettingsPanel
extends PanelContainer
## Options screen shared by the main menu and the pause menu:
## language, fullscreen, screen shake, and erasing saved progress.
## Emits `closed` on Back / Esc. Rebuilds its texts when the language changes.

signal closed

var _confirm_reset: bool = false
var _box: VBoxContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_box())
	custom_minimum_size = Vector2(620, 0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	add_child(_box)
	Settings.changed.connect(_build)
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()

func focus_first() -> void:
	var first := _box.find_child("Language", true, false) as Control
	if first:
		first.grab_focus()

func _build() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()

	_box.add_child(UiStyle.make_label(tr("SETTINGS"), 28, UiStyle.GOLD))

	# Language
	var lang := OptionButton.new()
	lang.name = "Language"
	var codes: Array = Settings.LANGUAGES.keys()
	for i in codes.size():
		lang.add_item(Settings.LANGUAGES[codes[i]], i)
		if codes[i] == Settings.language:
			lang.select(i)
	lang.item_selected.connect(func(i: int) -> void: Settings.set_language(codes[i]))
	_box.add_child(_row(tr("Language"), lang))

	# Fullscreen
	var full := CheckButton.new()
	full.button_pressed = Settings.fullscreen
	full.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	_box.add_child(_row(tr("Fullscreen"), full))

	# Screen shake
	var shake_row := HBoxContainer.new()
	shake_row.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 10
	slider.value = Settings.screen_shake * 100.0
	slider.custom_minimum_size = Vector2(220, 24)
	var value_label := UiStyle.make_label("%d%%" % int(slider.value), 18)
	value_label.custom_minimum_size = Vector2(56, 0)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d%%" % int(v)
		Settings.screen_shake = v / 100.0)
	slider.drag_ended.connect(func(_changed: bool) -> void: Settings.set_screen_shake(slider.value / 100.0))
	shake_row.add_child(slider)
	shake_row.add_child(value_label)
	_box.add_child(_row(tr("Screen shake"), shake_row))

	# Erase progress (two presses)
	var lg := RunState.legacy
	var reset_text := tr("Erase progress")
	if _confirm_reset:
		reset_text = tr("Press again: erase the body and all records")
	var reset := UiStyle.make_button(reset_text, _on_reset, 16, 420)
	_box.add_child(reset)
	_box.add_child(UiStyle.make_label(
		tr("Escapees: %d     Fallen: %d     Escaped: %d") % [lg.get("runs", 0), lg.get("deaths", 0), lg.get("victories", 0)],
		14, UiStyle.TEXT_DIM))

	var back := UiStyle.make_button(tr("Back"), func() -> void: closed.emit(), 20, 200)
	back.name = "Back"
	_box.add_child(back)

func _row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := UiStyle.make_label(caption, 20)
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	row.add_child(control)
	return row

func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_build()
		return
	_confirm_reset = false
	RunState.reset_legacy()
	_build()
