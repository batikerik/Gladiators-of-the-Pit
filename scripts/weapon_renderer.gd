@tool
class_name WeaponRenderer
extends Node2D
## Draws the held weapon; Weapon.apply_data() sets style and length.

@export var weapon_type: StringName = &"gladius":   # gladius, dagger, spear, axe, club
	set(val):
		weapon_type = val
		queue_redraw()

@export var blade_length: float = 60.0:
	set(val):
		blade_length = val
		queue_redraw()

func _draw() -> void:
	ItemArt.draw_weapon(self, weapon_type, blade_length, Vector2.ZERO)
