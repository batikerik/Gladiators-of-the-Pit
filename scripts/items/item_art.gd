@tool
class_name ItemArt
extends RefCounted
## Procedural pixel art for items, shared by the in-world weapon, pickups and
## the inventory UI. Call only from inside the target CanvasItem's _draw().
## Weapons are drawn along +x from the grip at `origin`; the damaging part
## starts at x = 18 and is `length` long.

const STEEL := Color(0.85, 0.88, 0.92)
const STEEL_DARK := Color(0.55, 0.58, 0.65)
const RUST := Color(0.6, 0.38, 0.25)
const GOLD := Color(0.85, 0.65, 0.2)
const WOOD := Color(0.45, 0.28, 0.15)
const BONE := Color(0.86, 0.82, 0.7)
const BONE_DARK := Color(0.62, 0.58, 0.48)

static func draw_item(ci: CanvasItem, item: ItemData, origin: Vector2, scale: float = 1.0) -> void:
	if item is WeaponData:
		draw_weapon(ci, item.style, item.reach, origin, scale)
	elif item is FoodData:
		draw_food(ci, item.style, origin, scale)

static func draw_weapon(ci: CanvasItem, style: StringName, length: float, origin: Vector2, s: float = 1.0) -> void:
	var p := func(x: float, y: float) -> Vector2: return origin + Vector2(x, y) * s
	var r := func(x: float, y: float, w: float, h: float) -> Rect2: return Rect2(origin + Vector2(x, y) * s, Vector2(w, h) * s)
	var tip_x: float = 18.0 + length
	match style:
		&"dagger":
			ci.draw_rect(r.call(0, -2.5, 14, 5), WOOD)
			ci.draw_rect(r.call(14, -6, 3, 12), STEEL_DARK)
			ci.draw_colored_polygon(PackedVector2Array([
				p.call(17, -3), p.call(tip_x - 6, -2), p.call(tip_x, 0), p.call(17, 3)
			]), RUST.lerp(STEEL, 0.5))
		&"spear":
			# Long shaft; the grip part stays behind the guard line
			ci.draw_rect(r.call(-6, -2, tip_x - 10, 4), WOOD)
			ci.draw_rect(r.call(tip_x - 30, -3, 6, 6), STEEL_DARK)   # socket
			ci.draw_colored_polygon(PackedVector2Array([
				p.call(tip_x - 24, -6), p.call(tip_x, 0), p.call(tip_x - 24, 6), p.call(tip_x - 28, 0)
			]), RUST.lerp(STEEL, 0.4))
		&"axe":
			ci.draw_rect(r.call(-4, -2.5, tip_x - 2, 5), WOOD)
			var hx: float = tip_x - 14.0
			ci.draw_colored_polygon(PackedVector2Array([
				p.call(hx - 6, -4), p.call(hx + 4, -16), p.call(hx + 14, -14),
				p.call(hx + 14, 14), p.call(hx + 4, 16), p.call(hx - 6, 4)
			]), STEEL_DARK)
			ci.draw_line(p.call(hx + 13, -13), p.call(hx + 13, 13), STEEL, 2.0 * s)   # edge
		&"club":
			ci.draw_rect(r.call(-4, -3, 20, 6), BONE_DARK)
			ci.draw_colored_polygon(PackedVector2Array([
				p.call(16, -4), p.call(tip_x - 10, -8), p.call(tip_x, -6),
				p.call(tip_x, 6), p.call(tip_x - 10, 8), p.call(16, 4)
			]), BONE)
			ci.draw_circle(p.call(tip_x - 2, 0), 8.0 * s, BONE)   # knuckle of the bone
			for sx in [tip_x - 26.0, tip_x - 16.0, tip_x - 6.0]:
				ci.draw_colored_polygon(PackedVector2Array([p.call(sx - 3, -7), p.call(sx, -14), p.call(sx + 3, -7)]), STEEL_DARK)
				ci.draw_colored_polygon(PackedVector2Array([p.call(sx - 3, 7), p.call(sx, 14), p.call(sx + 3, 7)]), STEEL_DARK)
		_:   # gladius
			ci.draw_rect(r.call(0, -3, 14, 6), WOOD)
			ci.draw_circle(p.call(-2, 0), 4.0 * s, GOLD)
			ci.draw_rect(r.call(14, -12, 4, 24), GOLD)
			ci.draw_colored_polygon(PackedVector2Array([
				p.call(18, -4), p.call(tip_x - 10, -4), p.call(tip_x, 0), p.call(tip_x - 10, 4), p.call(18, 4)
			]), STEEL)
			ci.draw_line(p.call(20, 0), p.call(tip_x - 12, 0), STEEL_DARK, 2.0 * s)
			ci.draw_line(p.call(18, -4), p.call(tip_x - 10, -4), Color.WHITE, 1.0 * s)

## Food icons are centred on `origin`, about 24 px wide at scale 1.
static func draw_food(ci: CanvasItem, style: StringName, origin: Vector2, s: float = 1.0) -> void:
	var p := func(x: float, y: float) -> Vector2: return origin + Vector2(x, y) * s
	match style:
		&"meat":
			ci.draw_circle(p.call(-2, 0), 9.0 * s, Color(0.55, 0.2, 0.15))
			ci.draw_circle(p.call(3, -2), 7.0 * s, Color(0.65, 0.28, 0.2))
			ci.draw_line(p.call(6, 3), p.call(14, 8), BONE, 3.0 * s)
			ci.draw_circle(p.call(14, 8), 2.5 * s, BONE)
		&"mushroom":
			ci.draw_rect(Rect2(p.call(-2, -1), Vector2(5, 10) * s), Color(0.85, 0.82, 0.7))
			ci.draw_colored_polygon(PackedVector2Array([
				p.call(-10, 0), p.call(-6, -8), p.call(0, -10), p.call(6, -8), p.call(10, 0)
			]), Color(0.35, 0.75, 0.7))
			ci.draw_circle(p.call(-3, -5), 1.5 * s, Color(0.8, 1.0, 0.9))
			ci.draw_circle(p.call(4, -4), 1.5 * s, Color(0.8, 1.0, 0.9))
		_:   # bread
			ci.draw_colored_polygon(PackedVector2Array([
				p.call(-12, 4), p.call(-10, -4), p.call(-4, -8), p.call(4, -8),
				p.call(10, -4), p.call(12, 4)
			]), Color(0.7, 0.5, 0.25))
			ci.draw_line(p.call(-5, -6), p.call(-3, 0), Color(0.5, 0.33, 0.15), 2.0 * s)
			ci.draw_line(p.call(2, -7), p.call(4, -1), Color(0.5, 0.33, 0.15), 2.0 * s)
