@tool
class_name RoomDecor
extends Node2D
## Set dressing drawn over CatacombsArena for the non-combat rooms.
##   cache: urns, a smashed chest, sacks and cobwebs — the dead's stash
##   camp:  bedrolls, a cooking pot, skull candles — a survivor's nook

@export_enum("cache", "camp") var style: String = "cache":
	set(val):
		style = val
		queue_redraw()
@export var floor_y: float = 580.0

func _draw() -> void:
	if style == "camp":
		_draw_camp()
	else:
		_draw_cache()
	_draw_cobwebs()

func _draw_cache() -> void:
	var clay := Color(0.5, 0.3, 0.2)
	for x in [200.0, 245.0, 1000.0]:
		_urn(Vector2(x, floor_y), clay)
	_urn(Vector2(1040.0, floor_y), clay.darkened(0.2), true)   # broken one
	# Smashed chest
	var wood := Color(0.35, 0.22, 0.12)
	draw_rect(Rect2(320, floor_y - 34, 60, 34), wood)
	draw_rect(Rect2(320, floor_y - 34, 60, 6), Color(0.45, 0.45, 0.5))
	draw_line(Vector2(318, floor_y - 42), Vector2(386, floor_y - 58), wood.lightened(0.1), 8.0)   # lid
	# Sacks
	for x in [900.0, 935.0]:
		draw_circle(Vector2(x, floor_y - 14), 16.0, Color(0.42, 0.36, 0.26))
		draw_rect(Rect2(x - 4, floor_y - 34, 8, 8), Color(0.3, 0.25, 0.17))

func _urn(base: Vector2, c: Color, broken: bool = false) -> void:
	var top := 44.0 if not broken else 24.0
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-10, 0), base + Vector2(-16, -top * 0.5), base + Vector2(-8, -top),
		base + Vector2(8, -top), base + Vector2(16, -top * 0.5), base + Vector2(10, 0)
	]), c)
	draw_line(base + Vector2(-14, -top * 0.5), base + Vector2(14, -top * 0.5), c.darkened(0.3), 2.0)
	if broken:
		draw_colored_polygon(PackedVector2Array([base + Vector2(20, 0), base + Vector2(30, -8), base + Vector2(36, 0)]), c)

func _draw_camp() -> void:
	# Bedrolls
	draw_rect(Rect2(330, floor_y - 12, 120, 12), Color(0.4, 0.18, 0.15))
	draw_rect(Rect2(330, floor_y - 18, 26, 8), Color(0.55, 0.5, 0.4))   # pillow sack
	draw_rect(Rect2(830, floor_y - 12, 110, 12), Color(0.25, 0.3, 0.22))
	# Cooking pot on a tripod (right of the fire)
	var iron := Color(0.25, 0.25, 0.28)
	draw_line(Vector2(700, floor_y), Vector2(720, floor_y - 70), iron, 3.0)
	draw_line(Vector2(740, floor_y), Vector2(720, floor_y - 70), iron, 3.0)
	draw_line(Vector2(720, floor_y - 70), Vector2(720, floor_y - 44), iron, 2.0)
	draw_circle(Vector2(720, floor_y - 32), 14.0, iron)
	# Skull candles on the bones
	for x in [230.0, 1060.0]:
		draw_circle(Vector2(x, floor_y - 10), 10.0, Color(0.72, 0.68, 0.58))
		draw_rect(Rect2(x - 5, floor_y - 13, 3, 3), Color.BLACK)
		draw_rect(Rect2(x + 2, floor_y - 13, 3, 3), Color.BLACK)
		draw_rect(Rect2(x - 2, floor_y - 34, 4, 14), Color(0.9, 0.87, 0.75))
		draw_circle(Vector2(x, floor_y - 38), 3.0, Color(1.0, 0.8, 0.3))
		draw_circle(Vector2(x, floor_y - 38), 26.0, Color(1.0, 0.6, 0.2, 0.06))
	# Scratched tally marks of days on the wall
	for i in 11:
		var x := 540.0 + i * 7.0 + (6.0 if i >= 5 else 0.0) + (6.0 if i >= 10 else 0.0)
		draw_line(Vector2(x, 330), Vector2(x - 2, 360), Color(0.55, 0.5, 0.55, 0.6), 2.0)

func _draw_cobwebs() -> void:
	var web := Color(0.8, 0.8, 0.85, 0.18)
	for corner in [Vector2(60, 0), Vector2(1220, 0)]:
		var dir: float = 1.0 if corner.x < 640 else -1.0
		for i in 5:
			var a: float = i * 0.35
			draw_line(corner, corner + Vector2(dir * cos(a), sin(a)) * 110.0, web, 1.0)
		for r in [40.0, 70.0, 100.0]:
			var pts := PackedVector2Array()
			for i in 5:
				var a: float = i * 0.35
				pts.append(corner + Vector2(dir * cos(a), sin(a)) * r)
			draw_polyline(pts, web, 1.0)
