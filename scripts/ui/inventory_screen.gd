extends CanvasLayer
## Autoload "InventoryScreen": the always-on quick bar (weapons 1-3, food [Q])
## and the full inventory opened with [Tab] / [I], which pauses the game.
## Shown only in scenes where the player controls the thief.

const PANEL_BG := Color(0.06, 0.05, 0.08, 0.94)
const BORDER := Color(0.55, 0.42, 0.2)
const TEXT := Color(0.88, 0.85, 0.78)
const TEXT_DIM := Color(0.6, 0.57, 0.52)
const ACCENT := Color(0.95, 0.75, 0.3)

var _quick_bar: PanelContainer
var _quick_slots: Array[PanelContainer] = []
var _quick_food: Label

var _screen: Control
var _weapon_list: VBoxContainer
var _food_list: VBoxContainer
var _details_title: Label
var _details_icon: ItemIcon
var _details_text: Label
var _status_label: Label
var _selected: ItemData = null
var _prev_toggle: bool = false
var _bound_inventory: Inventory = null

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_quick_bar()
	_build_screen()
	RunState.inventory_replaced.connect(_bind_inventory)
	_bind_inventory()

func _bind_inventory() -> void:
	if _bound_inventory and _bound_inventory.changed.is_connected(_refresh):
		_bound_inventory.changed.disconnect(_refresh)
	_bound_inventory = RunState.inventory
	_bound_inventory.changed.connect(_refresh)
	_selected = null
	_refresh()

func _player() -> Combatant:
	for c in get_tree().get_nodes_in_group(&"combatants"):
		if c is Combatant and c.is_player:
			return c
	return null

func is_open() -> bool:
	return _screen.visible

func _process(_delta: float) -> void:
	var player := _player()
	var playable: bool = player != null and player.input_enabled and player.is_alive

	var toggle := Input.is_key_pressed(KEY_TAB) or Input.is_key_pressed(KEY_I)
	if toggle and not _prev_toggle:
		if is_open():
			close()
		elif playable:
			open()
	_prev_toggle = toggle
	if is_open() and player == null:
		close()
	_quick_bar.visible = playable and not is_open()

## Esc closes the inventory (and is consumed, so the pause menu stays shut).
func _input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func open() -> void:
	_screen.visible = true
	get_tree().paused = true
	if _selected == null:
		_selected = RunState.inventory.equipped
	_refresh()

func close() -> void:
	_screen.visible = false
	get_tree().paused = false

# ── Refresh ──────────────────────────────────────────────────────────────────
func _refresh() -> void:
	var inv := RunState.inventory
	# Quick bar
	for i in _quick_slots.size():
		var slot := _quick_slots[i]
		var icon: ItemIcon = slot.get_node("Icon")
		var w: WeaponData = inv.weapons[i] if i < inv.weapons.size() else null
		icon.item = w
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel")
		style.border_color = ACCENT if w != null and w == inv.equipped else Color(0.3, 0.26, 0.2)
	_quick_food.text = tr("Food: %d  [Q] eat   [Tab] inventory") % inv.food_count()

	if not is_open():
		return
	_fill_weapon_list(inv)
	_fill_food_list(inv)
	_fill_details(inv)
	var player := _player()
	var hp: float = player.current_health if player else RunState.player_health
	_status_label.text = tr("Health: %d / %d     Satiety stored: %d  (a rest costs %d)") % [
		int(hp), int(RunState.player_max_health), inv.total_satiety(), RunState.REST_SATIETY_COST]

func _fill_weapon_list(inv: Inventory) -> void:
	_clear(_weapon_list)
	_weapon_list.add_child(_section_label(tr("WEAPONS  %d / %d") % [inv.weapons.size(), Inventory.MAX_WEAPONS]))
	for i in inv.weapons.size():
		var w := inv.weapons[i]
		var tag := tr("  — in hand") if w == inv.equipped else ""
		_weapon_list.add_child(_item_row(w, "[%d] %s%s" % [i + 1, tr(w.display_name), tag]))
	if inv.weapons.is_empty():
		_weapon_list.add_child(_dim_label(tr("Empty. Weapons lie beside the dead.")))

func _fill_food_list(inv: Inventory) -> void:
	_clear(_food_list)
	_food_list.add_child(_section_label(tr("FOOD")))
	for f in inv.foods():
		_food_list.add_child(_item_row(f, "%s  x%d" % [tr(f.display_name), inv.count_of(f)]))
	if inv.foods().is_empty():
		_food_list.add_child(_dim_label(tr("Empty. Without food a rest will cost health.")))

func _fill_details(inv: Inventory) -> void:
	for child in _details_text.get_parent().get_children():
		if child is Button:
			child.queue_free()
	if _selected == null or (not inv.weapons.has(_selected) and inv.count_of(_selected) == 0):
		_selected = null
		_details_title.text = tr("Choose an item")
		_details_icon.item = null
		_details_text.text = ""
		return
	_details_title.text = tr(_selected.display_name)
	_details_icon.item = _selected
	var lines := PackedStringArray([tr(_selected.description), ""])
	var actions := _details_text.get_parent()
	if _selected is WeaponData:
		lines.append_array(_selected.stat_lines())
		if _selected != inv.equipped:
			actions.add_child(_button(tr("Take in hand"), _on_equip_pressed))
		actions.add_child(_button(tr("Drop"), _on_drop_pressed))
	elif _selected is FoodData:
		lines.append(tr("Heals: %d HP   Satiety: %d   Eating: %.1f s") % [
			int(_selected.heal_amount), _selected.satiety, _selected.eat_time])
		lines.append(tr("Get hit while eating and the meal is lost."))
		actions.add_child(_button(tr("Eat"), _on_eat_pressed))
	_details_text.text = "\n".join(lines)

# ── Actions ──────────────────────────────────────────────────────────────────
func _on_equip_pressed() -> void:
	var player := _player()
	if player and player.weapon and not player.weapon.is_idle():
		return
	RunState.inventory.equip(_selected)

func _on_drop_pressed() -> void:
	var player := _player()
	var item := _selected
	if player == null or not RunState.inventory.remove(item):
		return
	var pickup := ItemPickup.new()
	pickup.item = item
	pickup.position = player.global_position + Vector2(player.facing_direction * 40.0, 40.0)
	player.get_parent().add_child(pickup)
	_selected = RunState.inventory.equipped

func _on_eat_pressed() -> void:
	var player := _player()
	var food := _selected as FoodData
	close()
	if player and food:
		player.start_eating(food)

# ── Building ─────────────────────────────────────────────────────────────────
func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	return s

func _build_quick_bar() -> void:
	_quick_bar = PanelContainer.new()
	_quick_bar.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.05, 0.08, 0.8), BORDER))
	_quick_bar.position = Vector2(40, 600)
	_quick_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quick_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_quick_bar.add_child(row)
	for i in Inventory.MAX_WEAPONS:
		var slot := PanelContainer.new()
		var style := _panel_style(Color(0.1, 0.08, 0.1), Color(0.3, 0.26, 0.2))
		style.set_content_margin_all(2)
		slot.add_theme_stylebox_override("panel", style)
		slot.custom_minimum_size = Vector2(84, 34)
		var icon := ItemIcon.new()
		icon.name = "Icon"
		slot.add_child(icon)
		var num := Label.new()
		num.text = str(i + 1)
		num.add_theme_font_size_override("font_size", 11)
		num.add_theme_color_override("font_color", TEXT_DIM)
		slot.add_child(num)
		row.add_child(slot)
		_quick_slots.append(slot)
	_quick_food = Label.new()
	_quick_food.add_theme_font_size_override("font_size", 14)
	_quick_food.add_theme_color_override("font_color", TEXT)
	_quick_food.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_quick_food)

func _build_screen() -> void:
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.visible = false
	add_child(_screen)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, BORDER))
	panel.position = Vector2(190, 90)
	panel.custom_minimum_size = Vector2(900, 520)
	_screen.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = tr("INVENTORY")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT)
	root.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_constant_override("separation", 14)
	columns.add_child(left)
	_weapon_list = VBoxContainer.new()
	_weapon_list.add_theme_constant_override("separation", 4)
	left.add_child(_weapon_list)
	_food_list = VBoxContainer.new()
	_food_list.add_theme_constant_override("separation", 4)
	left.add_child(_food_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	_details_title = Label.new()
	_details_title.add_theme_font_size_override("font_size", 20)
	_details_title.add_theme_color_override("font_color", ACCENT)
	right.add_child(_details_title)
	_details_icon = ItemIcon.new()
	_details_icon.custom_minimum_size = Vector2(200, 60)
	right.add_child(_details_icon)
	_details_text = Label.new()
	_details_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_text.custom_minimum_size = Vector2(420, 0)
	_details_text.add_theme_font_size_override("font_size", 15)
	_details_text.add_theme_color_override("font_color", TEXT)
	right.add_child(_details_text)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", TEXT)
	root.add_child(_status_label)
	root.add_child(_dim_label(tr("[Tab] / [I] / [Esc] — close.   Click an item for details.")))

func _item_row(item: ItemData, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(360, 40)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("icon_max_width", 0)
	var style := _panel_style(Color(0.12, 0.1, 0.13) if item != _selected else Color(0.24, 0.18, 0.1),
		ACCENT if item == _selected else Color(0.25, 0.22, 0.2))
	style.content_margin_left = 96
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, style)
	var icon := ItemIcon.new()
	icon.item = item
	icon.position = Vector2(6, 4)
	icon.size = Vector2(84, 32)
	b.add_child(icon)
	b.pressed.connect(func() -> void:
		_selected = item
		_refresh())
	return b

func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 34)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func() -> void:
		callback.call()
		_refresh())
	return b

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", ACCENT)
	return l

func _dim_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", TEXT_DIM)
	return l

func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
