@tool
class_name TutorialDecor
extends Node2D
## Tutorial room dressing on top of CatacombsArena: the shaft the thief fell
## through, a pale light column from it, and the corpse pile he lands on.
## PILE_POINTS must match the CorpsePile collision polygon in tutorial_room.tscn.

const PILE_POINTS: PackedVector2Array = [
	Vector2(130, 580), Vector2(180, 548), Vector2(230, 520), Vector2(270, 512),
	Vector2(310, 522), Vector2(360, 552), Vector2(400, 580)
]

@export var shaft_left: float = 205.0
@export var shaft_right: float = 335.0

func _draw() -> void:
	# 1. Rock above the ceiling with the shaft opening (seen while falling in)
	var rock := Color(0.07, 0.06, 0.08)
	draw_rect(Rect2(-200, -900, shaft_left + 200, 900), rock)
	draw_rect(Rect2(shaft_right, -900, 1680 - shaft_right, 900), rock)
	draw_rect(Rect2(shaft_left, -900, shaft_right - shaft_left, 900), Color(0.03, 0.02, 0.04))
	draw_rect(Rect2(-200, -14, 1680, 14), Color(0.16, 0.13, 0.18))
	draw_rect(Rect2(shaft_left, -14, shaft_right - shaft_left, 14), Color(0.03, 0.02, 0.04))

	# 2. Light column from the shaft down to the pile
	draw_colored_polygon(PackedVector2Array([
		Vector2(shaft_left, -900), Vector2(shaft_right, -900),
		Vector2(430, 580), Vector2(110, 580)
	]), Color(0.75, 0.8, 1.0, 0.07))
	draw_colored_polygon(PackedVector2Array([
		Vector2(shaft_left + 30, -900), Vector2(shaft_right - 30, -900),
		Vector2(350, 580), Vector2(190, 580)
	]), Color(0.8, 0.85, 1.0, 0.06))

	# 3. Corpse pile: dark mound, then bodies, limbs, bones and skulls on it
	draw_colored_polygon(PILE_POINTS, Color(0.2, 0.15, 0.13))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7   # fixed: the pile looks the same every run
	var flesh := [Color(0.55, 0.45, 0.38), Color(0.45, 0.5, 0.38), Color(0.5, 0.38, 0.33)]
	var cloth := [Color(0.35, 0.15, 0.12), Color(0.25, 0.22, 0.18), Color(0.3, 0.3, 0.25)]
	for i in 16:
		var x: float = rng.randf_range(150, 380)
		var top: float = _pile_height_at(x)
		var y: float = rng.randf_range(top + 4, 578)
		var c: Color = flesh[i % 3]
		# Lying body: torso + head + an arm or leg
		var dir: float = 1.0 if rng.randf() < 0.5 else -1.0
		draw_rect(Rect2(x - 14, y - 5, 28, 10), cloth[i % 3])
		draw_circle(Vector2(x + dir * 20.0, y - 1), 6.0, c)
		draw_line(Vector2(x - dir * 12.0, y), Vector2(x - dir * 26.0, y - rng.randf_range(-12, 12)), c, 4.0)
	for i in 10:
		var x: float = rng.randf_range(145, 390)
		var y: float = rng.randf_range(_pile_height_at(x) + 2, 578)
		var bone := Color(0.72, 0.68, 0.58)
		if i % 3 == 0:
			draw_circle(Vector2(x, y), 6.0, bone)              # skull
			draw_rect(Rect2(x - 3, y - 2, 2, 2), Color.BLACK)
			draw_rect(Rect2(x + 1, y - 2, 2, 2), Color.BLACK)
		else:
			var a: float = rng.randf_range(0, PI)
			draw_line(Vector2(x, y), Vector2(x, y) + Vector2(cos(a), sin(a)) * 14.0, bone, 3.0)
	# An arm reaching up out of the pile
	draw_line(Vector2(210, 540), Vector2(200, 505), Color(0.45, 0.5, 0.38), 5.0)
	draw_line(Vector2(200, 505), Vector2(206, 490), Color(0.45, 0.5, 0.38), 4.0)

func _pile_height_at(x: float) -> float:
	for i in PILE_POINTS.size() - 1:
		var a: Vector2 = PILE_POINTS[i]
		var b: Vector2 = PILE_POINTS[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return 580.0
