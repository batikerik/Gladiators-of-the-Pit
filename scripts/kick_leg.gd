@tool
class_name KickLeg
extends Node2D
## A single leg drawn from the hip (origin) downward, so rotating the node swings it.
## Negative rotation swings the foot forward (+x).

@export var length: float = 30.0
@export var skin: Color = Color(0.85, 0.65, 0.5)
@export var greave: Color = Color(0.75, 0.55, 0.25)

func _draw() -> void:
	draw_rect(Rect2(-4, 0, 8, length), skin)
	draw_rect(Rect2(-5, length - 14, 10, 14), greave)
	# Sandal sole sticking forward — reads as the kicking foot
	draw_rect(Rect2(-5, length - 2, 14, 4), Color(0.3, 0.2, 0.12))
