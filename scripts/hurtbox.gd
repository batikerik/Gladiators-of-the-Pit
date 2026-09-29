class_name Hurtbox
extends Area2D

enum Zone { HEAD, TORSO, LEGS }

@export var zone: Zone = Zone.TORSO
@export var damage_multiplier: float = 1.0

var parent_combatant: Node2D = null

func _ready() -> void:
	add_to_group(&"hurtbox")
	parent_combatant = owner if owner else get_parent()
	
	var zone_str: String = "TORSO"
	match zone:
		Zone.HEAD:
			zone_str = "HEAD"
			if damage_multiplier == 1.0:
				damage_multiplier = 2.0
		Zone.TORSO:
			zone_str = "TORSO"
			damage_multiplier = 1.0
		Zone.LEGS:
			zone_str = "LEGS"
			if damage_multiplier == 1.0:
				damage_multiplier = 0.75
	
	set_meta("zone", zone_str)
	set_meta("multiplier", damage_multiplier)

func receive_hit(amount: float, zone_name: String, hit_dir: Vector2, swing_speed: float, attacker: Node2D) -> void:
	if parent_combatant and parent_combatant.has_method("receive_hit"):
		parent_combatant.receive_hit(amount, zone_name, hit_dir, swing_speed, attacker)
