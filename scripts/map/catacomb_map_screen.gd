class_name CatacombMapScreen
extends Node2D
## The descent map, Inscryption style: a parchment on a dark table, ink paths,
## room icons and the thief's figurine. Click a highlighted room to go there.

## [title, description] per room type (a var: it reads RunState)
var type_info: Dictionary = {
	&"start":  ["Entrance", "This is where they threw you in."],
	&"combat": ["Fight", "Someone blocks the way.\nWin, and his weapon is yours."],
	&"loot":   ["Cache", "Supplies of the dead: food,\nsometimes a weapon."],
	&"safe":   ["Safe room", "A campfire. Resting costs %d satiety —\nor some health if there is no food."],
	&"boss":   ["The Armoured Survivor", "Master of these catacombs.\nBeyond him — the way up."],
}
const NODE_RADIUS: float = 24.0
const INK := Color(0.28, 0.18, 0.1)
const INK_FADED := Color(0.28, 0.18, 0.1, 0.35)
const PAPER := Color(0.82, 0.72, 0.52)
const GOLD := Color(0.95, 0.7, 0.2)
const LEGEND: Array[StringName] = [&"combat", &"loot", &"safe", &"boss"]
const LEGEND_POS := Vector2(1030, 150)
const LEGEND_STEP: float = 44.0

var _t: float = 0.0
var _hover_id: int = -1
var _token_pos: Vector2 = Vector2.ZERO
var _moving: bool = false
var _fade: ColorRect
var _tooltip: Label
var _info: Label
var _banner: Label
var _paper_shape: PackedVector2Array

func _ready() -> void:
	if not RunState.run_active or RunState.map.is_empty():
		RunState.new_run()   # launched straight from the editor
	_token_pos = RunState.current_node()["pos"]
	_paper_shape = _make_paper_shape()
	_build_ui()
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.5)

func _process(delta: float) -> void:
	_t += delta
	var mouse := get_global_mouse_position()
	_hover_id = -1
	if not _moving:
		for n in RunState.available_nodes():
			if mouse.distance_to(n["pos"]) <= NODE_RADIUS + 6.0:
				_hover_id = n["id"]
	_update_tooltip(mouse)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover_id >= 0:
			travel_to(_hover_id)

## Walk the figurine to a room and load it. Public so tests can drive it.
func travel_to(id: int) -> void:
	if _moving:
		return
	var target := RunState.map_node(id)
	if target.is_empty() or not RunState.available_nodes().has(target):
		return
	_moving = true
	var tw := create_tween()
	tw.tween_property(self, "_token_pos", target["pos"], 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_fade, "modulate:a", 1.0, 0.45)
	tw.tween_callback(func() -> void:
		var scene := RunState.enter_node(id)
		get_tree().change_scene_to_file(scene))

# ── Drawing ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	# Table
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.08, 0.06))
	for i in 9:
		draw_line(Vector2(0, 40 + i * 80), Vector2(1280, 40 + i * 80), Color(0.08, 0.05, 0.04), 3.0)
	# Candle glow on the table
	var flick: float = 0.9 + 0.1 * sin(_t * 7.0) * sin(_t * 3.1)
	draw_circle(Vector2(1120, 600), 260.0 * flick, Color(1.0, 0.6, 0.2, 0.05))
	draw_rect(Rect2(1110, 560, 20, 60), Color(0.9, 0.85, 0.7))
	draw_circle(Vector2(1120, 552), 6.0 * flick, Color(1.0, 0.8, 0.3))

	# Parchment with a shadow
	var shadow := PackedVector2Array()
	for p in _paper_shape:
		shadow.append(p + Vector2(8, 10))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	draw_colored_polygon(_paper_shape, PAPER)
	for spot in [Vector2(420, 160), Vector2(860, 520), Vector2(700, 250), Vector2(380, 590)]:
		draw_circle(spot, 38.0, Color(0.7, 0.58, 0.38, 0.35))

	# Paths
	for n in RunState.map:
		for nid in n["next"]:
			var m := RunState.map_node(nid)
			var travelled: bool = n["visited"] and m["visited"]
			_dotted(n["pos"], m["pos"], INK if travelled else INK_FADED, travelled)

	# Rooms
	var available := RunState.available_nodes()
	for n in RunState.map:
		var is_avail: bool = available.has(n)
		var pulse: float = 0.5 + 0.5 * sin(_t * 4.0)
		var r: float = NODE_RADIUS * (1.15 if n["id"] == _hover_id else 1.0)
		if is_avail:
			draw_circle(n["pos"], r + 7.0 + pulse * 3.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.35 + 0.3 * pulse))
		draw_circle(n["pos"], r, PAPER.lightened(0.08))
		draw_arc(n["pos"], r, 0, TAU, 32, INK if (is_avail or n["id"] == RunState.current_node_id) else INK_FADED, 2.5)
		_draw_icon(n["type"], n["pos"], 1.0 if (is_avail or n["type"] == &"boss") else 0.45)
		if n["visited"] and n["id"] != RunState.current_node_id and n["type"] != &"start":
			# Crossed out: already been there
			draw_line(n["pos"] + Vector2(-14, -14), n["pos"] + Vector2(14, 14), Color(0.55, 0.1, 0.08, 0.8), 3.0)
			draw_line(n["pos"] + Vector2(14, -14), n["pos"] + Vector2(-14, 14), Color(0.55, 0.1, 0.08, 0.8), 3.0)

	_draw_corpse_marker()
	_draw_token(_token_pos + Vector2(0, -NODE_RADIUS - 2))

	# Legend icons on small paper discs (labels are in the UI layer)
	for i in LEGEND.size():
		var p := LEGEND_POS + Vector2(0, i * LEGEND_STEP)
		draw_circle(p, 16.0, PAPER)
		_draw_icon(LEGEND[i], p, 1.0)

## The previous thief's body: a small bag and skull beside its room
func _draw_corpse_marker() -> void:
	if RunState.corpse_node_id < 0:
		return
	var n := RunState.map_node(RunState.corpse_node_id)
	if n.is_empty():
		return
	var p: Vector2 = n["pos"] + Vector2(NODE_RADIUS + 4, -NODE_RADIUS + 2)
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.5)
	draw_circle(p, 13.0 + pulse * 2.0, Color(0.5, 0.7, 1.0, 0.25 + 0.2 * pulse))
	draw_circle(p + Vector2(-3, 3), 7.0, Color(0.42, 0.36, 0.26))     # bag
	draw_circle(p + Vector2(4, -3), 6.0, Color(0.86, 0.82, 0.7))      # skull
	draw_rect(Rect2(p + Vector2(1, -5), Vector2(2, 2)), INK)
	draw_rect(Rect2(p + Vector2(5, -5), Vector2(2, 2)), INK)

func _dotted(a: Vector2, b: Vector2, color: Color, solid: bool) -> void:
	var from := a + (b - a).normalized() * (NODE_RADIUS + 4.0)
	var to := b - (b - a).normalized() * (NODE_RADIUS + 4.0)
	if solid:
		draw_line(from, to, color, 3.0)
		return
	var length := from.distance_to(to)
	var steps := int(length / 12.0)
	for i in steps:
		var p0 := from.lerp(to, i / float(steps))
		var p1 := from.lerp(to, (i + 0.5) / float(steps))
		draw_line(p0, p1, color, 2.5)

func _draw_icon(type: StringName, c: Vector2, alpha: float) -> void:
	var ink := Color(INK.r, INK.g, INK.b, alpha)
	match type:
		&"combat":
			draw_line(c + Vector2(-11, 11), c + Vector2(11, -11), ink, 3.0)
			draw_line(c + Vector2(11, 11), c + Vector2(-11, -11), ink, 3.0)
			draw_line(c + Vector2(-13, 5), c + Vector2(-5, 13), ink, 3.0)
			draw_line(c + Vector2(13, 5), c + Vector2(5, 13), ink, 3.0)
		&"loot":
			draw_rect(Rect2(c + Vector2(-12, -6), Vector2(24, 16)), ink, false, 2.5)
			draw_line(c + Vector2(-12, -1), c + Vector2(12, -1), ink, 2.0)
			draw_arc(c + Vector2(0, -6), 12.0, PI, TAU, 12, ink, 2.5)
			draw_rect(Rect2(c + Vector2(-2, -3), Vector2(4, 5)), ink)
		&"safe":
			draw_line(c + Vector2(-11, 11), c + Vector2(11, 5), ink, 3.0)
			draw_line(c + Vector2(11, 11), c + Vector2(-11, 5), ink, 3.0)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-7, 4), c + Vector2(-3, -6), c + Vector2(0, -13), c + Vector2(3, -6), c + Vector2(7, 4)
			]), Color(0.8, 0.35, 0.1, alpha))
		&"boss":
			draw_circle(c + Vector2(0, -1), 11.0, ink)
			draw_rect(Rect2(c + Vector2(-5, -4), Vector2(4, 4)), PAPER)
			draw_rect(Rect2(c + Vector2(1, -4), Vector2(4, 4)), PAPER)
			draw_rect(Rect2(c + Vector2(-6, 8), Vector2(12, 5)), ink)
			draw_line(c + Vector2(-9, -8), c + Vector2(-16, -18), ink, 3.0)   # horns
			draw_line(c + Vector2(9, -8), c + Vector2(16, -18), ink, 3.0)
		&"start":
			draw_circle(c, 12.0, Color(0.1, 0.07, 0.05, alpha))
			draw_arc(c, 15.0, 0, TAU, 20, ink, 1.5)

func _draw_token(p: Vector2) -> void:
	# Little painted figurine of the thief on a round base
	draw_circle(p + Vector2(0, 2), 9.0, Color(0.2, 0.14, 0.1))
	draw_rect(Rect2(p + Vector2(-5, -20), Vector2(10, 20)), Color(0.8, 0.62, 0.48))
	draw_rect(Rect2(p + Vector2(-5, -8), Vector2(10, 6)), Color(0.6, 0.2, 0.18))
	draw_circle(p + Vector2(0, -25), 6.0, Color(0.8, 0.62, 0.48))
	draw_rect(Rect2(p + Vector2(-6, -31), Vector2(12, 4)), Color(0.25, 0.18, 0.12))

func _make_paper_shape() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pts := PackedVector2Array()
	var rect := Rect2(300, 28, 680, 664)
	var steps := 14
	for i in steps:
		pts.append(Vector2(rect.position.x + rect.size.x * i / steps, rect.position.y + rng.randf_range(-6, 6)))
	for i in steps:
		pts.append(Vector2(rect.end.x + rng.randf_range(-6, 6), rect.position.y + rect.size.y * i / steps))
	for i in steps:
		pts.append(Vector2(rect.end.x - rect.size.x * i / steps, rect.end.y + rng.randf_range(-6, 6)))
	for i in steps:
		pts.append(Vector2(rect.position.x + rng.randf_range(-6, 6), rect.end.y - rect.size.y * i / steps))
	return pts

# ── UI ───────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = tr("CATACOMBS")
	title.position = Vector2(40, 36)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", GOLD)
	layer.add_child(title)

	_info = Label.new()
	_info.position = Vector2(40, 90)
	_info.add_theme_font_size_override("font_size", 16)
	_info.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
	layer.add_child(_info)
	_refresh_info()

	var legend := Label.new()
	legend.position = Vector2(1010, 60)
	legend.text = tr("Choose the next room:\nclick a glowing circle.")
	legend.add_theme_font_size_override("font_size", 14)
	legend.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
	layer.add_child(legend)
	for i in LEGEND.size():
		var l := Label.new()
		l.text = tr(type_info[LEGEND[i]][0])
		l.position = Vector2(LEGEND_POS.x + 32, LEGEND_POS.y + i * LEGEND_STEP - 11)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		layer.add_child(l)

	_tooltip = Label.new()
	_tooltip.add_theme_font_size_override("font_size", 14)
	_tooltip.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_tooltip.add_theme_stylebox_override("normal", style)
	_tooltip.visible = false
	layer.add_child(_tooltip)

	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 24)
	_banner.add_theme_color_override("font_color", GOLD)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(340, 300)
	_banner.size = Vector2(600, 120)
	_banner.visible = false
	layer.add_child(_banner)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)

func _refresh_info() -> void:
	var inv := RunState.inventory
	var weapon: String = tr(inv.equipped.display_name) if inv.equipped else "—"
	_info.text = tr("Depth: %d of %d\n\nHealth: %d / %d\nWeapon: %s\nFood: %d   (satiety %d)\n\nResting at a campfire\ncosts %d satiety.%s") % [
		RunState.depth(), CatacombMapGen.LAYERS_BETWEEN + 1,
		int(RunState.player_health), int(RunState.player_max_health),
		weapon, inv.food_count(), inv.total_satiety(), RunState.REST_SATIETY_COST,
		(tr("\n\nBody: %s\nat depth %d") % [RunState.corpse_name(), RunState.map_node(RunState.corpse_node_id)["layer"]]) if RunState.corpse_node_id >= 0 else ""]

func _update_tooltip(mouse: Vector2) -> void:
	var hovered: Dictionary = {}
	for n in RunState.map:
		if mouse.distance_to(n["pos"]) <= NODE_RADIUS + 6.0:
			hovered = n
	_tooltip.visible = not hovered.is_empty()
	if hovered.is_empty():
		return
	var info: Array = type_info[hovered["type"]]
	var suffix := ""
	if hovered["visited"] and hovered["id"] != RunState.current_node_id:
		suffix = tr("\n(cleared)")
	elif hovered["id"] == RunState.current_node_id:
		suffix = tr("\n(you are here)")
	elif not RunState.available_nodes().has(hovered):
		suffix = tr("\n(not reachable yet)")
	if hovered["id"] == RunState.corpse_node_id:
		var c := RunState.corpse()
		suffix += tr("\n\nA body lies here: %s\nItems on it: %d") % [RunState.corpse_name(), c.get("items", []).size()]
	_tooltip.text = "%s\n%s%s" % [tr(info[0]), tr(info[1]).replace("%d", str(RunState.REST_SATIETY_COST)), suffix]
	_tooltip.position = mouse + Vector2(20, 12)
