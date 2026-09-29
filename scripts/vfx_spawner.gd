class_name VFXSpawner
extends Node

static func spawn_hit_impact(tree: SceneTree, pos: Vector2, hit_dir: Vector2, zone: String) -> void:
	if not tree or not tree.current_scene:
		return
	
	var parent: Node = tree.current_scene
	
	# 1. Sparks / Impact particles
	var sparks := CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = 14
	sparks.lifetime = 0.35
	sparks.position = pos
	sparks.spread = 45.0
	sparks.gravity = Vector2(0, 450)
	sparks.initial_velocity_min = 120.0
	sparks.initial_velocity_max = 240.0
	sparks.direction = hit_dir
	
	# Color based on zone
	if zone == "HEAD":
		sparks.color = Color(1.0, 0.85, 0.2) # Bright gold/fire sparks
		sparks.scale_amount_min = 2.0
		sparks.scale_amount_max = 4.5
	elif zone == "LEGS":
		sparks.color = Color(0.6, 0.5, 0.4) # Dust/dirt
		sparks.scale_amount_min = 2.0
		sparks.scale_amount_max = 3.5
	else:
		sparks.color = Color(0.85, 0.15, 0.15) # Blood / flesh
		sparks.scale_amount_min = 2.0
		sparks.scale_amount_max = 4.0
	
	parent.add_child(sparks)
	sparks.restart()
	
	# Auto free sparks after lifetime
	var timer := tree.create_timer(0.4)
	timer.timeout.connect(sparks.queue_free)
	
	# 2. Hitstop for critical head impacts
	if zone == "HEAD":
		_apply_hitstop(tree, 0.04)

static func _apply_hitstop(tree: SceneTree, duration: float) -> void:
	Engine.time_scale = 0.1
	var timer := tree.create_timer(duration, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)
