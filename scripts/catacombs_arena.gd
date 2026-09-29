@tool
class_name CatacombsArena
extends Node2D

@export var floor_y: float = 580.0
@export var arena_width: float = 1280.0
@export var wall_thickness: float = 60.0

var _torch_flicker: float = 0.0

func _process(delta: float) -> void:
	_torch_flicker += delta * 6.0
	queue_redraw()

func _draw() -> void:
	# 1. Dark Catacombs Background
	draw_rect(Rect2(0, 0, arena_width, 720), Color(0.08, 0.06, 0.1))
	
	# 2. Brick Wall Texture
	var brick_color: Color = Color(0.14, 0.12, 0.18)
	var mortar_color: Color = Color(0.06, 0.05, 0.08)
	var brick_h: float = 24.0
	var brick_w: float = 48.0
	
	for row in range(0, int(floor_y / brick_h)):
		var y: float = row * brick_h
		var offset_x: float = (brick_w * 0.5) if (row % 2 == 1) else 0.0
		for col in range(-1, int(arena_width / brick_w) + 2):
			var x: float = col * brick_w + offset_x
			draw_rect(Rect2(x + 1, y + 1, brick_w - 2, brick_h - 2), brick_color)
			draw_line(Vector2(x, y), Vector2(x + brick_w, y), mortar_color, 2.0)
	
	# 3. Gothic Arches in Background
	var arch_color: Color = Color(0.18, 0.15, 0.22)
	for arch_x in [300.0, 640.0, 980.0]:
		# Pillar columns
		draw_rect(Rect2(arch_x - 70, 160, 20, floor_y - 160), arch_color)
		draw_rect(Rect2(arch_x + 50, 160, 20, floor_y - 160), arch_color)
		# Arch curve / beam
		draw_rect(Rect2(arch_x - 75, 140, 150, 25), arch_color.lightened(0.1))
		# Inner depth shadow
		draw_rect(Rect2(arch_x - 50, 165, 100, floor_y - 165), Color(0.04, 0.03, 0.05))
		# Skulls / bones pile in archway
		draw_circle(Vector2(arch_x, floor_y - 12), 10.0, Color(0.3, 0.28, 0.25))
		draw_circle(Vector2(arch_x - 14, floor_y - 8), 7.0, Color(0.28, 0.26, 0.22))
		draw_circle(Vector2(arch_x + 15, floor_y - 8), 8.0, Color(0.28, 0.26, 0.22))
	
	# 4. Arena Floor (Stone Slabs & Sand/Grit)
	var floor_stone: Color = Color(0.25, 0.22, 0.2)
	var sand_color: Color = Color(0.35, 0.3, 0.22)
	draw_rect(Rect2(0, floor_y, arena_width, 720 - floor_y), floor_stone)
	draw_rect(Rect2(0, floor_y, arena_width, 10), sand_color)
	
	# Floor flagstone dividers
	for fx in range(0, int(arena_width), 80):
		draw_line(Vector2(fx, floor_y), Vector2(fx, 720), Color(0.15, 0.12, 0.1), 3.0)
	
	# 5. Side Boundary Walls (Colossal Iron Bars & Stones)
	var iron_wall: Color = Color(0.2, 0.22, 0.26)
	draw_rect(Rect2(0, 0, wall_thickness, 720), iron_wall)
	draw_rect(Rect2(arena_width - wall_thickness, 0, wall_thickness, 720), iron_wall)
	# Spikes / wall embellishments
	for sy in range(100, int(floor_y), 50):
		draw_circle(Vector2(wall_thickness - 6, sy), 6.0, Color(0.4, 0.3, 0.2))
		draw_circle(Vector2(arena_width - wall_thickness + 6, sy), 6.0, Color(0.4, 0.3, 0.2))
	
	# 6. Flickering Wall Torches & Warm Sconce Lighting
	for tx in [200.0, 500.0, 780.0, 1080.0]:
		var ty: float = 280.0
		# Torch bracket
		draw_line(Vector2(tx, ty + 12), Vector2(tx, ty), Color(0.35, 0.25, 0.15), 4.0)
		# Glow halo
		var flicker_val: float = sin(_torch_flicker + tx) * 0.15 + 0.85
		var halo_color := Color(1.0, 0.5, 0.1, 0.08 * flicker_val)
		draw_circle(Vector2(tx, ty - 6), 65.0 * flicker_val, halo_color)
		# Flame core
		draw_circle(Vector2(tx, ty - 4), 6.0 * flicker_val, Color(1.0, 0.8, 0.2))
		draw_circle(Vector2(tx, ty - 6), 3.0, Color(1.0, 1.0, 0.8))
