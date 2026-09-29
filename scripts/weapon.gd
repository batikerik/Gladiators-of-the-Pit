class_name Weapon
extends Area2D

signal hit_connected(target: Node2D, zone: String, damage: float, hit_pos: Vector2, hit_normal: Vector2)

@export var weapon_name: String = "Rusty Gladius"
@export var base_damage: float = 15.0
@export var min_swing_speed: float = 160.0 # Minimum px/s to register as a valid strike
@export var speed_damage_scale: float = 0.02 # Extra damage per unit of speed
@export var hit_cooldown: float = 0.22 # Seconds between hits on the same target

@onready var tip_marker: Marker2D = $TipMarker
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var trail_line: Line2D = get_node_or_null("TrailLine")

var current_tip_speed: float = 0.0
var _prev_tip_pos: Vector2 = Vector2.ZERO
var _hit_timers: Dictionary = {} # target -> float remaining cooldown
var owner_combatant: Node2D = null

func _ready() -> void:
	if tip_marker:
		_prev_tip_pos = tip_marker.global_position
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# Calculate instantaneous weapon tip speed
	if tip_marker and delta > 0.0:
		var current_pos: Vector2 = tip_marker.global_position
		current_tip_speed = (_prev_tip_pos.distance_to(current_pos)) / delta
		_prev_tip_pos = current_pos
	else:
		current_tip_speed = 0.0
	
	# Update hit cooldowns
	var to_erase: Array = []
	for target in _hit_timers.keys():
		_hit_timers[target] -= delta
		if _hit_timers[target] <= 0.0:
			to_erase.append(target)
	for t in to_erase:
		_hit_timers.erase(t)
	
	# Update visual weapon trail if present
	if trail_line and tip_marker:
		if current_tip_speed > min_swing_speed * 1.5:
			trail_line.add_point(tip_marker.global_position)
			if trail_line.get_point_count() > 8:
				trail_line.remove_point(0)
		else:
			if trail_line.get_point_count() > 0:
				trail_line.remove_point(0)

func _on_area_entered(other_area: Area2D) -> void:
	if not other_area.is_in_group(&"hurtbox"):
		return
	
	# Ignore self hits
	var victim: Node2D = other_area.owner if other_area.owner else other_area.get_parent()
	if victim == owner_combatant:
		return
	
	# Check cooldown
	if _hit_timers.has(victim):
		return
	
	# Require minimum swing velocity for damage
	if current_tip_speed < min_swing_speed:
		return
	
	var zone_name: String = "TORSO"
	var zone_mult: float = 1.0
	if other_area.has_meta("zone"):
		zone_name = str(other_area.get_meta("zone"))
	if other_area.has_meta("multiplier"):
		zone_mult = float(other_area.get_meta("multiplier"))
	
	# Momentum damage calculation: Base * (1 + speed_bonus) * zone_multiplier
	var speed_bonus: float = maxf(0.0, (current_tip_speed - min_swing_speed) * speed_damage_scale)
	var final_damage: float = (base_damage + speed_bonus) * zone_mult
	
	var hit_pos: Vector2 = tip_marker.global_position if tip_marker else global_position
	var hit_normal: Vector2 = (victim.global_position - global_position).normalized()
	if hit_normal.is_zero_approx():
		hit_normal = Vector2.RIGHT
	
	# Put on cooldown against this victim
	_hit_timers[victim] = hit_cooldown
	
	hit_connected.emit(victim, zone_name, final_damage, hit_pos, hit_normal)
	
	# Deliver damage to the hurtbox/combatant
	if other_area.has_method("receive_hit"):
		other_area.receive_hit(final_damage, zone_name, hit_normal, current_tip_speed, owner_combatant)
	elif victim.has_method("receive_hit"):
		victim.receive_hit(final_damage, zone_name, hit_normal, current_tip_speed, owner_combatant)
