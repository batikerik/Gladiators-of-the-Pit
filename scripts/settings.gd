extends Node
## Autoload "Settings": player options, saved to user://settings.cfg.
##   language      "en" (the game's own language) or "ru" (LocaleRu table)
##   fullscreen    window mode
##   screen_shake  0..1 multiplier on every camera shake
## Registers the Russian Translation with the TranslationServer on start.

signal changed

const LANGUAGES: Dictionary = {"en": "English", "ru": "Русский"}
const DEFAULT_PATH := "user://settings.cfg"

var settings_path: String = DEFAULT_PATH
var language: String = "en"
var fullscreen: bool = false
var screen_shake: float = 1.0

func _ready() -> void:
	var ru := Translation.new()
	ru.locale = "ru"
	for key in LocaleRu.STRINGS:
		ru.add_message(key, LocaleRu.STRINGS[key])
	TranslationServer.add_translation(ru)
	load_settings()
	apply()

func apply() -> void:
	TranslationServer.set_locale(language)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)

func set_language(code: String) -> void:
	if LANGUAGES.has(code):
		language = code
		_commit()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_commit()

func set_screen_shake(value: float) -> void:
	screen_shake = clampf(value, 0.0, 1.0)
	_commit()

func _commit() -> void:
	apply()
	save_settings()
	changed.emit()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	language = str(cfg.get_value("general", "language", language))
	if not LANGUAGES.has(language):
		language = "en"
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	screen_shake = clampf(float(cfg.get_value("video", "screen_shake", screen_shake)), 0.0, 1.0)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", language)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.save(settings_path)
