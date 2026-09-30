@tool
class_name GladiatorPuppet
extends Node2D

@export var is_zombie: bool = false:
	set(val):
		is_zombie = val
		queue_redraw()

@export var armor_tier: int = 1: # 0 = ragged, 1 = gladiator leather/iron, 2 = boss plate
	set(val):
		armor_tier = val
		queue_redraw()

@export var skin_color: Color = Color(0.85, 0.65, 0.5):
	set(val):
		skin_color = val
		queue_redraw()

@export var cloth_color: Color = Color(0.65, 0.2, 0.2):
	set(val):
		cloth_color = val
		queue_redraw()

## false when a separate KickLeg node animates the right leg (intro cutscene)
@export var draw_right_leg: bool = true:
	set(val):
		draw_right_leg = val
		queue_redraw()

func _draw() -> void:
	var skin: Color = Color(0.45, 0.55, 0.4) if is_zombie else skin_color
	var cloth: Color = Color(0.3, 0.35, 0.25) if is_zombie else cloth_color
	var iron: Color = Color(0.35, 0.38, 0.42)
	var bronze: Color = Color(0.75, 0.55, 0.25)
	
	# === 1. LEGS (Bottom: y = 20 to 50) ===
	# Left Leg
	draw_rect(Rect2(-12, 18, 8, 30), skin)
	draw_rect(Rect2(-13, 34, 10, 14), bronze if armor_tier >= 2 else Color(0.4, 0.25, 0.15))
	# Right Leg
	if draw_right_leg:
		draw_rect(Rect2(4, 18, 8, 30), skin)
		draw_rect(Rect2(3, 34, 10, 14), bronze if armor_tier >= 2 else Color(0.4, 0.25, 0.15))
	
	# === 2. TORSO & TUNIC (Middle: y = -25 to 20) ===
	# Waist / Loincloth
	draw_rect(Rect2(-16, 12, 32, 10), cloth)
	# Main Torso
	draw_rect(Rect2(-15, -20, 30, 34), skin)
	
	# Armor Plate
	if armor_tier == 1:
		# Leather / Bronze harness
		draw_rect(Rect2(-13, -18, 26, 26), bronze)
		draw_line(Vector2(-13, -18), Vector2(13, 8), Color(0.2, 0.15, 0.1), 3.0)
	elif armor_tier >= 2:
		# Heavy Iron Breastplate
		draw_rect(Rect2(-15, -20, 30, 32), iron)
		draw_rect(Rect2(-11, -16, 22, 24), iron.lightened(0.2))
		draw_line(Vector2(0, -18), Vector2(0, 8), iron.darkened(0.3), 2.0)
	else:
		# Ragged prisoner chest
		draw_line(Vector2(-10, -5), Vector2(8, 2), Color(0.3, 0.1, 0.1), 2.0) # Scar / dirt
	
	# === 3. HEAD & HELMET (Top: y = -52 to -22) ===
	# Neck
	draw_rect(Rect2(-6, -24, 12, 8), skin)
	# Head base
	draw_rect(Rect2(-13, -50, 26, 26), skin)
	
	# Eyes / Features
	if is_zombie:
		# Glowing hollow zombie eyes
		draw_rect(Rect2(1, -43, 5, 5), Color(0.9, 0.95, 0.5))
		draw_rect(Rect2(3, -42, 2, 2), Color(0.1, 0.2, 0.1))
	else:
		# Gladiator eyes
		draw_rect(Rect2(2, -42, 4, 3), Color(0.1, 0.1, 0.1))
	
	# Helmet / Headgear
	if armor_tier >= 1:
		# Gladiator Helm
		var helm_col: Color = iron if armor_tier >= 2 else bronze
		draw_rect(Rect2(-15, -52, 30, 14), helm_col) # Top crest
		draw_rect(Rect2(-15, -52, 8, 26), helm_col)  # Back neck-guard
		draw_rect(Rect2(8, -52, 6, 20), helm_col)   # Cheek guard
		# Red crest plum
		draw_line(Vector2(-6, -53), Vector2(8, -53), Color(0.85, 0.15, 0.15), 4.0)
	else:
		# Rough hair / bandage
		draw_rect(Rect2(-14, -51, 28, 8), Color(0.2, 0.15, 0.1))
