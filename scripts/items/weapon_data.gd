class_name WeaponData
extends ItemData
## Stats of one weapon type. Weight drives the timings: heavier weapons charge,
## swing and recover slower and slow down hopping; see the derived getters.

## Drawing style for WeaponRenderer / ItemArt: gladius, dagger, spear, axe, club
@export var style: StringName = &"gladius"
@export var base_damage: float = 18.0
## Length of the damaging part, in px from the guard (gladius = 60)
@export var reach: float = 60.0
## 1.0 = gladius. 0.5 = dagger, 1.6 = club
@export var weight: float = 1.0

@export_group("Damage")
@export var full_charge_damage_mult: float = 2.4
@export var thrust_damage_mult: float = 1.1
## Share of damage that goes through a guard
@export var block_chip_mult: float = 0.2
@export var knockback_mult: float = 1.0

@export_group("Behaviour")
## Charge ratio at which a slash breaks a guard (lower = breaks guards easier)
@export var heavy_threshold: float = 0.85
## Seconds the victim is staggered by every clean hit (blunt weapons)
@export var stagger_on_hit: float = 0.0
## Extra damage per chained hit (combatant default is 0.15)
@export var combo_step_bonus: float = 0.15
## How far a thrust extends the blade
@export var thrust_reach: float = 26.0

# ── Derived timings ──────────────────────────────────────────────────────────
func max_charge_time() -> float:
	return 0.9 * pow(weight, 0.7)

func strike_duration() -> float:
	return 0.18 * pow(weight, 0.5)

func whiff_recovery() -> float:
	return 0.32 * weight

func hit_recovery() -> float:
	return 0.12 * weight

func thrust_windup_time() -> float:
	return 0.12 * pow(weight, 0.8)

func thrust_whiff_recovery() -> float:
	return 0.4 * weight

## Multiplier on hop distance: light weapons hop further
func move_mult() -> float:
	return clampf(1.12 - 0.12 * weight, 0.85, 1.1)

## One-line summary for the inventory screen
func stat_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Урон: %d   Длина: %d   Вес: %.1f" % [int(base_damage), int(reach), weight])
	lines.append("Заряд: %.2f с   Удар: %.2f с" % [max_charge_time(), strike_duration()])
	var traits := PackedStringArray()
	if thrust_damage_mult >= 1.4:
		traits.append("сильный укол")
	if full_charge_damage_mult >= 2.8:
		traits.append("мощный замах")
	if heavy_threshold <= 0.65:
		traits.append("легко ломает блок")
	if block_chip_mult >= 0.35:
		traits.append("бьёт сквозь блок")
	if stagger_on_hit > 0.0:
		traits.append("оглушает")
	if combo_step_bonus >= 0.25:
		traits.append("быстрые комбо")
	if not traits.is_empty():
		lines.append("Особое: " + ", ".join(traits))
	return lines
