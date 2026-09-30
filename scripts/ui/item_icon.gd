class_name ItemIcon
extends Control
## Draws an item's pixel art scaled to fit this control.

var item: ItemData = null:
	set(val):
		item = val
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if item == null:
		return
	if item is WeaponData:
		var length: float = 18.0 + item.reach + 8.0
		var s: float = minf(1.0, (size.x - 6.0) / length)
		var origin := Vector2((size.x - length * s) * 0.5 + 6.0 * s, size.y * 0.5)
		ItemArt.draw_weapon(self, item.style, item.reach, origin, s)
	elif item is FoodData:
		ItemArt.draw_food(self, item.style, size * 0.5 + Vector2(0, 3), minf(1.4, size.y / 26.0))
