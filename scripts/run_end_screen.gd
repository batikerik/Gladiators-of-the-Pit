class_name RunEndScreen
extends Node2D
## End of a descent. Defeat: where the thief fell, what he achieved, and what
## now lies on his body for the next thief. Victory: freedom.
## [Enter] / [Space] / click continues: next thief (defeat) or the main menu
## (victory).

const ROOM_NAMES: Dictionary = {"combat": "in a fight", "loot": "in a cache", "safe": "by a campfire", "boss": "in the boss's lair"}

var result: Dictionary = {}
var _t: float = 0.0
var _ready_for_input: bool = false
var _leaving: bool = false

func _ready() -> void:
	result = RunState.last_result
	if result.is_empty():
		# Launched straight from the editor: show a sample defeat
		result = {"victory": false, "runner": 1, "depth": 3, "room_type": "combat",
			"stats": {"kills": 2, "rooms": 3, "max_depth": 3}, "corpse_items": ["rusty_gladius", "stale_bread"]}
	_build_text()
	# Ignore keys still held from the fight for a moment
	get_tree().create_timer(1.0).timeout.connect(func() -> void: _ready_for_input = true)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_input or _leaving:
		return
	var go: bool = (event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if go:
		continue_game()

## Defeat: the next thief starts a new descent on the map. Victory: back to
## the main menu.
func continue_game() -> void:
	_leaving = true
	if result.get("victory", false):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		RunState.new_run()
		get_tree().change_scene_to_file(RunState.MAP_SCENE)

func _build_text() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var victory: bool = result.get("victory", false)
	var st: Dictionary = result.get("stats", {})
	var lg: Dictionary = RunState.legacy

	var title := _label(layer, tr("FREEDOM") if victory else tr("YOU FELL IN THE PIT"), 46,
		Color(1.0, 0.82, 0.35) if victory else Color(0.95, 0.25, 0.2))
	title.position = Vector2(0, 120)

	var sub_text: String
	if victory:
		sub_text = tr("%s defeated the Armoured Survivor and climbed out of the Pit.") % RunState.escapee_name(int(result.get("runner", 1)), str(result.get("nick", "")))
	else:
		sub_text = tr("%s died at depth %d — %s.") % [RunState.escapee_name(int(result.get("runner", 1)), str(result.get("nick", ""))), result["depth"],
			tr(ROOM_NAMES.get(result.get("room_type", "combat"), "in the catacombs"))]
	_label(layer, sub_text, 20, Color(0.9, 0.86, 0.78)).position = Vector2(0, 200)

	var lines := PackedStringArray([
		tr("Rooms cleared: %d     Enemies slain: %d     Depth: %d") % [
			st.get("rooms", 0), st.get("kills", 0), st.get("max_depth", 0)],
		"",
		tr("Escapees: %d     Fallen: %d     Escaped: %d     Best depth: %d") % [
			lg.get("runs", 0), lg.get("deaths", 0), lg.get("victories", 0), lg.get("best_depth", 0)],
	])
	if not victory:
		var names := PackedStringArray()
		for id in result.get("corpse_items", []):
			if RunState.ITEM_PATHS.has(StringName(id)):
				names.append(tr(RunState.get_item(StringName(id)).display_name))
		lines.append("")
		if names.is_empty():
			lines.append(tr("He carried nothing. The next escapee will find nothing to take."))
		else:
			lines.append(tr("His body awaits the next escapee at depth %d. On it:") % result["depth"])
			lines.append(", ".join(names))
			lines.append(tr("Reach the body and it is all yours. Die before that — and it is lost."))
	_label(layer, "\n".join(lines), 17, Color(0.8, 0.76, 0.7)).position = Vector2(0, 270)

	var prompt := _label(layer, tr("[Enter] — main menu") if victory else tr("[Enter] — next escapee"), 20,
		Color(1.0, 0.9, 0.55))
	prompt.position = Vector2(0, 520)
	prompt.name = "Prompt"

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.size = Vector2(1280, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _draw() -> void:
	var victory: bool = result.get("victory", false)
	if victory:
		# Dawn light pouring down a shaft, a small figure climbing out
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.08, 0.12))
		draw_colored_polygon(PackedVector2Array([Vector2(560, 0), Vector2(720, 0), Vector2(900, 720), Vector2(380, 720)]),
			Color(1.0, 0.85, 0.5, 0.12 + 0.03 * sin(_t * 1.5)))
		draw_colored_polygon(PackedVector2Array([Vector2(600, 0), Vector2(680, 0), Vector2(780, 720), Vector2(500, 720)]),
			Color(1.0, 0.9, 0.6, 0.1))
		var y: float = 560.0 - fmod(_t * 12.0, 40.0) * 0.2
		draw_rect(Rect2(634, y, 12, 28), Color(0.1, 0.08, 0.1))
		draw_circle(Vector2(640, y - 8), 7.0, Color(0.1, 0.08, 0.1))
	else:
		# Darkness, a body on the bones, a slowly pulsing pale glow
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.03, 0.05))
		var pulse: float = 0.5 + 0.5 * sin(_t * 1.2)
		draw_circle(Vector2(640, 640), 180.0, Color(0.5, 0.6, 0.8, 0.04 + 0.03 * pulse))
		for i in 9:
			var x: float = 520.0 + i * 30.0
			draw_circle(Vector2(x, 660.0 + (i % 2) * 6.0), 9.0, Color(0.35, 0.32, 0.28))
		draw_rect(Rect2(600, 630, 34, 12), Color(0.55, 0.48, 0.42))
		draw_rect(Rect2(632, 626, 34, 16), Color(0.35, 0.22, 0.2))
		draw_circle(Vector2(674, 634), 9.0, Color(0.55, 0.48, 0.42))
