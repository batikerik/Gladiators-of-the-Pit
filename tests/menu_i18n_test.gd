extends Node
## Milestone 6 checks: the English source + Russian translation (complete
## coverage of every tr() literal and data-driven text), settings saved to
## disk, the main menu, and the pause menu.
##
## Run: Summer.exe --headless --path . res://tests/menu_i18n_test.tscn

var _failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Settings.settings_path = "user://test_settings.cfg"
	Settings.language = "en"
	Settings.apply()
	RunState.legacy_path = "user://test_legacy.json"
	RunState.reset_legacy()
	var placeholder := Node.new()   # scene changes free this, not the runner
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder

	_test_translation_coverage()
	_test_language_switch()
	_test_settings_persist()
	await _test_main_menu()
	await _test_pause_menu()
	await _test_screen_shake_setting()
	Settings.language = "en"
	Settings.apply()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	RunState.reset_legacy()
	print("MENU/I18N TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		_failures += 1

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait_scene(scene_name: String, max_frames: int = 300) -> Node:
	for i in max_frames:
		var s := get_tree().current_scene
		if s != null and s != self and s.name == scene_name and s.is_node_ready():
			return s
		await get_tree().process_frame
	return null

func _press_esc() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventKey.new()
	up.keycode = KEY_ESCAPE
	up.pressed = false
	Input.parse_input_event(up)

# ── Translation ──────────────────────────────────────────────────────────────
func _collect_scripts(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect_scripts(dir.path_join(d), out)

func _test_translation_coverage() -> void:
	print("translation coverage")
	var ru: Dictionary = LocaleRu.STRINGS
	var missing: Array[String] = []
	var found := 0
	var files: Array[String] = []
	_collect_scripts("res://scripts", files)
	var re := RegEx.create_from_string('tr\\("((?:[^"\\\\]|\\\\.)*)"\\)')
	for path in files:
		if path.contains("/i18n/"):
			continue
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var key := m.get_string(1).c_unescape()
			found += 1
			if not ru.has(key):
				missing.append("%s: %s" % [path.get_file(), key])
	_check(missing.is_empty(), "every tr() text in code has a Russian line (%d checked)%s" % [found,
		"" if missing.is_empty() else ": " + ", ".join(missing)])

	# Texts that come from data and are translated where they are shown
	var data_texts: Array[String] = []
	for id in RunState.ITEM_PATHS:
		var item := RunState.get_item(id)
		data_texts.append(item.display_name)
		data_texts.append(item.description)
	for e in Encounters.ENEMIES:
		data_texts.append(e["name"])
	data_texts.append(Encounters.BOSS["name"])
	for entry in TutorialDirector.OBJECTIVES:
		data_texts.append(entry[1])
	data_texts.append_array(["Escapee", "Training Zombie", "in a fight", "in a cache", "by a campfire", "in the boss's lair",
		"Entrance", "Fight", "Cache", "Safe room", "HEAD!", "TORSO!", "LEGS!", "[E] Back to the map"])
	var data_missing: Array[String] = []
	for t in data_texts:
		if not ru.has(t):
			data_missing.append(t)
	_check(data_missing.is_empty(), "items, enemies, objectives and rooms are translated (%d)%s" % [data_texts.size(),
		"" if data_missing.is_empty() else ": " + ", ".join(data_missing)])

	var cyrillic_in_code: Array[String] = []
	var cyr := RegEx.create_from_string("[\\x{0400}-\\x{04FF}]")
	for path in files:
		# settings.gd names each language in that language ("Русский") on purpose
		if not path.contains("/i18n/") and not path.ends_with("settings.gd") and cyr.search(FileAccess.get_file_as_string(path)) != null:
			cyrillic_in_code.append(path.get_file())
	_check(cyrillic_in_code.is_empty(), "no Russian left in game code (English is the source)%s" % [
		"" if cyrillic_in_code.is_empty() else ": " + ", ".join(cyrillic_in_code)])

func _test_language_switch() -> void:
	print("language switch")
	_check(tr("Play") == "Play" and RunState.escapee_name(3) == "Escapee #3", "English by default")
	Settings.language = "ru"
	Settings.apply()
	_check(tr("Play") == "Играть" and RunState.escapee_name(3) == "Беглец №3", "Russian: menu and escapee names")
	_check(tr(RunState.get_item(&"iron_axe").display_name) == "Топор палача", "Russian: item names")
	_check(tr("Damage: %d   Reach: %d   Weight: %.1f") % [21, 52, 1.3] == "Урон: 21   Длина: 52   Вес: 1.3",
		"Russian: formatted lines keep their numbers")
	Settings.language = "en"
	Settings.apply()
	_check(tr("Play") == "Play", "back to English")

func _test_settings_persist() -> void:
	print("settings persist")
	Settings.set_language("ru")
	Settings.set_screen_shake(0.3)
	Settings.language = "en"
	Settings.screen_shake = 1.0
	Settings.load_settings()
	_check(Settings.language == "ru" and is_equal_approx(Settings.screen_shake, 0.3), "language and shake survive a restart (saved to disk)")
	Settings.set_language("en")
	Settings.set_screen_shake(1.0)

# ── Menus ────────────────────────────────────────────────────────────────────
func _test_main_menu() -> void:
	print("main menu")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main_menu.tscn",
		"the game starts on the main menu")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	var menu: MainMenu = await _wait_scene("MainMenu")
	_check(menu != null, "main menu loads")
	if menu == null:
		return
	var play := menu._menu.get_node("Play") as Button
	var settings := menu._menu.get_node("Settings") as Button
	var exit := menu._menu.get_node("Exit") as Button
	_check(play.text == "Play" and settings.text == "Settings" and exit.text == "Exit", "Play / Settings / Exit")
	settings.pressed.emit()
	_check(menu._settings.visible and not menu._menu.visible, "Settings opens the options panel")
	Settings.set_language("ru")
	await _frames(2)
	menu._settings.closed.emit()
	_check(play.text == "Играть" and menu._menu.visible, "switching language re-labels the menu right away")
	Settings.set_language("en")
	await _frames(2)
	_press_esc()
	await _frames(3)
	_check(not PauseMenu.is_open(), "no pause menu on the title screen")
	_check(Music.current_track == &"tavern", "the menu plays Cozy Tavern Hearth")
	play.pressed.emit()
	_check(menu._name_panel.visible and not menu._menu.visible, "Play first asks for the thief's name")
	menu._name_edit.text = "Spartacus the Great Thief"
	menu._name_edit.text_submitted.emit(menu._name_edit.text)
	_check(Settings.nickname == "Spartacus the Gr", "the name is trimmed to %d letters and saved" % Settings.NICKNAME_MAX)
	_check(await _wait_scene("IntroCutscene") != null, "Begin starts the intro")
	RunState.new_run(5)
	_check(RunState.thief_name == "Spartacus the Gr" and RunState.escapee_name(3, "Spartacus") == "Spartacus (#3)",
		"the nickname is the thief's name; bodies read 'Nick (#3)'")

func _test_pause_menu() -> void:
	print("pause menu")
	RunState.new_run(77)
	get_tree().change_scene_to_file(RunState.MAP_SCENE)
	await _wait_scene("CatacombMap")
	_check(Music.current_track == &"tavern", "the map keeps the tavern music")
	_press_esc()
	await _frames(3)
	_check(PauseMenu.is_open() and get_tree().paused, "Esc on the map pauses the game")
	_press_esc()
	await _frames(3)
	_check(not PauseMenu.is_open() and not get_tree().paused, "Esc again resumes")

	get_tree().change_scene_to_file(RunState.enter_node(RunState.available_nodes()[0]["id"]))
	var fight_room: CombatRoom = await _wait_scene("CombatRoom")
	await _frames(2)
	_check(Music.current_track == &"fight", "fights play Skirmish on the Road")
	_check(fight_room.hud.player_name_label.text == "Spartacus the Gr", "the nickname sits above the health bar")
	Settings.nickname = ""
	InventoryScreen.open()
	await _frames(1)
	_press_esc()
	await _frames(3)
	_check(not PauseMenu.is_open() and not InventoryScreen.is_open(), "with the inventory open Esc only closes the inventory")
	PauseMenu.open()
	(PauseMenu._menu.get_node("MainMenu") as Button).pressed.emit()
	_check(await _wait_scene("MainMenu") != null and not get_tree().paused, "Main menu from pause: back to the title, unpaused")

func _test_screen_shake_setting() -> void:
	print("screen shake")
	var cam := CombatCamera2D.new()
	add_child(cam)
	Settings.screen_shake = 0.0
	cam.add_trauma(0.8)
	var none: float = cam._trauma
	Settings.screen_shake = 1.0
	cam.add_trauma(0.8)
	_check(none == 0.0 and cam._trauma > 0.7, "shake 0% turns camera shake off, 100% keeps it")
	cam.queue_free()
