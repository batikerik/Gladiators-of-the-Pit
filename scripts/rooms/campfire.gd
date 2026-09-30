class_name Campfire
extends Node2D
## The safe room's fire. Walk up and press E to rest once (see RunState.rest()).

signal rest_requested

@export var use_range: float = 90.0

var rest_available: bool = true
var _t: float = 0.0
var _label: Label
var _prev_e: bool = true

func _ready() -> void:
	_label = Label.new()
	_label.top_level = true
	_label.z_index = 60
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.05))
	_label.add_theme_constant_override("outline_size", 4)
	_label.visible = false
	add_child(_label)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var player: Combatant = null
	for c in get_tree().get_nodes_in_group(&"combatants"):
		if c is Combatant and c.is_player:
			player = c
	var near: bool = rest_available and player != null and player.input_enabled and player.is_alive \
		and absf(player.global_position.x - global_position.x) <= use_range
	_label.visible = near
	if near:
		var fed: bool = RunState.inventory.total_satiety() >= RunState.REST_SATIETY_COST
		_label.text = "[E] Отдохнуть у костра — съесть еду (%d сытости)" % RunState.REST_SATIETY_COST if fed \
			else "[E] Отдохнуть голодным — еды мало, голод отнимет %d%% HP" % int(RunState.HUNGER_PENALTY * 100)
		_label.global_position = global_position + Vector2(-_label.size.x * 0.5, -140)
	var e := Input.is_key_pressed(KEY_E)
	if near and e and not _prev_e:
		rest_available = false
		_label.visible = false
		rest_requested.emit()
	_prev_e = e

func _draw() -> void:
	var f: float = 1.0 if rest_available else 0.55   # embers after the rest
	var flick: float = 0.85 + 0.15 * sin(_t * 9.0) * sin(_t * 5.3)
	# Warm glow on the floor and walls
	draw_circle(Vector2(0, -20), 220.0 * f * flick, Color(1.0, 0.5, 0.15, 0.06))
	draw_circle(Vector2(0, -20), 120.0 * f * flick, Color(1.0, 0.55, 0.2, 0.08))
	# Stone ring and logs
	for i in 7:
		var x: float = -30.0 + i * 10.0
		draw_circle(Vector2(x, 2), 6.0, Color(0.3, 0.27, 0.26))
	draw_line(Vector2(-24, -2), Vector2(22, -12), Color(0.35, 0.22, 0.12), 7.0)
	draw_line(Vector2(-22, -12), Vector2(24, -2), Color(0.4, 0.26, 0.14), 7.0)
	# Flames: three layered tongues that sway
	var colors := [Color(1.0, 0.35, 0.1), Color(1.0, 0.65, 0.15), Color(1.0, 0.95, 0.6)]
	var heights := [46.0, 32.0, 18.0]
	for layer in 3:
		# Keep the tongue taller than its base, or the polygon folds over itself
		var h: float = maxf(heights[layer] * f * (0.85 + 0.2 * sin(_t * (7.0 + layer * 3.0))), 10.0)
		var w: float = maxf((18.0 - layer * 5.0) * f, 3.0)
		var sway: float = sin(_t * 4.0 + layer) * minf(4.0, h * 0.15)
		var base_y := -4.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w, base_y), Vector2(-w * 0.4 + sway * 0.5, base_y - h * 0.5),
			Vector2(sway, base_y - h), Vector2(w * 0.4 + sway * 0.5, base_y - h * 0.5), Vector2(w, base_y)
		]), colors[layer])
	# Sparks rising
	for i in 4:
		var p: float = fmod(_t * 0.6 + i * 0.25, 1.0)
		draw_rect(Rect2(Vector2(sin(i * 2.1 + _t) * 14.0, -20.0 - p * 90.0 * f), Vector2(2, 2)),
			Color(1.0, 0.8, 0.3, 1.0 - p))
