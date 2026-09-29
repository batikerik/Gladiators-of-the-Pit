@tool
class_name WeaponRenderer
extends Node2D

@export var weapon_type: String = "gladius": # gladius, axe, club
	set(val):
		weapon_type = val
		queue_redraw()

@export var blade_length: float = 60.0
@export var blade_width: float = 8.0

func _draw() -> void:
	var steel: Color = Color(0.85, 0.88, 0.92)
	var steel_dark: Color = Color(0.55, 0.58, 0.65)
	var gold: Color = Color(0.85, 0.65, 0.2)
	var wood: Color = Color(0.45, 0.28, 0.15)
	
	# Handle / Grip (x: 0 to 14)
	draw_rect(Rect2(0, -3, 14, 6), wood)
	# Pommel (x: -4 to 0)
	draw_circle(Vector2(-2, 0), 4.0, gold)
	# Guard (x: 14 to 18)
	draw_rect(Rect2(14, -12, 4, 24), gold)
	
	# Blade (x: 18 to 18 + blade_length)
	var tip_x: float = 18.0 + blade_length
	var half_w: float = blade_width * 0.5
	
	var blade_pts: PackedVector2Array = [
		Vector2(18, -half_w),
		Vector2(tip_x - 10, -half_w),
		Vector2(tip_x, 0),
		Vector2(tip_x - 10, half_w),
		Vector2(18, half_w)
	]
	draw_colored_polygon(blade_pts, steel)
	# Center fuller groove
	draw_line(Vector2(20, 0), Vector2(tip_x - 12, 0), steel_dark, 2.0)
	# Edge highlight
	draw_line(Vector2(18, -half_w), Vector2(tip_x - 10, -half_w), Color.WHITE, 1.0)
