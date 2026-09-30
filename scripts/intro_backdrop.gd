@tool
class_name IntroBackdrop
extends Node2D
## Fortress execution ledge at night and the shaft of the Pit below it.
## World layout: ledge floor at y = 500 for x < pit_left, the pit mouth spans
## pit_left..pit_right and the shaft falls to shaft_depth.

@export var floor_y: float = 500.0
@export var pit_left: float = 740.0
@export var pit_right: float = 1200.0
@export var shaft_depth: float = 4200.0

var _flicker: float = 0.0

func _process(delta: float) -> void:
	_flicker += delta * 6.0
	queue_redraw()

func _draw() -> void:
	var left: float = -600.0
	var right: float = 2200.0

	# 1. Night sky in bands (darker toward the top)
	var sky_top := Color(0.05, 0.04, 0.09)
	var sky_low := Color(0.2, 0.12, 0.2)
	for i in 8:
		var t: float = i / 7.0
		draw_rect(Rect2(left, -700 + i * 150, right - left, 151), sky_top.lerp(sky_low, t))
	# Moon and a few stars
	draw_circle(Vector2(1080, 110), 38.0, Color(0.95, 0.9, 0.75))
	draw_circle(Vector2(1094, 100), 34.0, sky_top.lerp(sky_low, 0.35))
	for s in [Vector2(120, 60), Vector2(340, 130), Vector2(610, 40), Vector2(860, 170), Vector2(1260, 70), Vector2(1450, 150)]:
		draw_rect(Rect2(s, Vector2(2, 2)), Color(0.9, 0.9, 1.0, 0.7))

	# 2. Fortress wall behind the ledge, with crenellations and lit windows
	var wall := Color(0.13, 0.1, 0.14)
	draw_rect(Rect2(left, 230, pit_left + 40 - left, floor_y - 230), wall)
	var cx: float = left
	while cx < pit_left + 40:
		draw_rect(Rect2(cx, 206, 30, 24), wall)
		cx += 56.0
	for wx in [60.0, 300.0, 540.0]:
		draw_rect(Rect2(wx, 300, 18, 30), Color(0.95, 0.6, 0.2, 0.85))
		draw_rect(Rect2(wx + 7, 300, 4, 30), wall)
	# Far bank of the pit
	draw_rect(Rect2(pit_right, 380, right - pit_right, floor_y - 380), Color(0.1, 0.08, 0.11))

	# 3. Guards watching the execution (silhouettes with spears)
	for gx in [330.0, 400.0]:
		var g := Color(0.06, 0.05, 0.07)
		draw_rect(Rect2(gx - 9, floor_y - 70, 18, 70), g)
		draw_circle(Vector2(gx, floor_y - 80), 10.0, g)
		draw_line(Vector2(gx + 14, floor_y), Vector2(gx + 14, floor_y - 120), g, 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(gx + 10, floor_y - 120), Vector2(gx + 18, floor_y - 120), Vector2(gx + 14, floor_y - 134)
		]), Color(0.4, 0.4, 0.45))

	# 4. Torches on the wall
	for tx in [180.0, 470.0]:
		var ty: float = 380.0
		var f: float = sin(_flicker + tx) * 0.15 + 0.85
		draw_circle(Vector2(tx, ty - 6), 70.0 * f, Color(1.0, 0.5, 0.1, 0.08 * f))
		draw_line(Vector2(tx, ty + 12), Vector2(tx, ty), Color(0.35, 0.25, 0.15), 4.0)
		draw_circle(Vector2(tx, ty - 4), 6.0 * f, Color(1.0, 0.8, 0.2))
		draw_circle(Vector2(tx, ty - 6), 3.0, Color(1.0, 1.0, 0.8))

	# 5. Rock around the shaft
	var rock := Color(0.12, 0.1, 0.11)
	var rock_dark := Color(0.07, 0.06, 0.07)
	draw_rect(Rect2(left, floor_y, pit_left - left, shaft_depth - floor_y), rock)
	draw_rect(Rect2(pit_right, floor_y, right - pit_right, shaft_depth - floor_y), rock)
	# Ledge stone slabs
	draw_rect(Rect2(left, floor_y, pit_left - left, 12), Color(0.3, 0.26, 0.24))
	var sx: float = left
	while sx < pit_left:
		draw_line(Vector2(sx, floor_y), Vector2(sx, floor_y + 60), rock_dark, 2.0)
		sx += 90.0

	# 6. The shaft: black, getting darker with depth, bones stuck in the walls
	var depth := shaft_depth - floor_y
	for i in 12:
		var t: float = i / 11.0
		draw_rect(Rect2(pit_left, floor_y + depth * t, pit_right - pit_left, depth / 11.0 + 1.0),
			Color(0.06, 0.04, 0.07).lerp(Color(0.0, 0.0, 0.0), t))
	for i in 18:
		var by: float = floor_y + 160.0 + i * 205.0
		var on_left: bool = i % 2 == 0
		var bx: float = pit_left if on_left else pit_right
		var dir: float = 1.0 if on_left else -1.0
		var bone := Color(0.42, 0.38, 0.32).darkened(clampf(i / 18.0, 0.0, 0.7))
		draw_line(Vector2(bx, by), Vector2(bx + dir * 26.0, by + 8.0), bone, 4.0)
		draw_circle(Vector2(bx + dir * 28.0, by + 9.0), 4.0, bone)
		if i % 3 == 1:
			draw_circle(Vector2(bx + dir * 10.0, by + 60.0), 9.0, bone)   # skull
			draw_rect(Rect2(bx + dir * 10.0 - 4, by + 57.0, 3, 3), Color.BLACK)
	# Wall edge streaks
	for i in 40:
		var y: float = floor_y + i * 92.0
		draw_line(Vector2(pit_left, y), Vector2(pit_left - 12, y + 40), rock_dark, 2.0)
		draw_line(Vector2(pit_right, y + 30), Vector2(pit_right + 12, y + 70), rock_dark, 2.0)
