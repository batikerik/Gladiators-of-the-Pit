class_name FoodData
extends ItemData
## Something to eat: heals right away, and its satiety pays for safe rest.

## Drawing style for ItemArt: bread, meat, mushroom
@export var style: StringName = &"bread"
@export var heal_amount: float = 15.0
## Rest costs RunState.REST_SATIETY_COST satiety points
@export var satiety: int = 1
## Seconds of chewing; a hit in that window interrupts the meal
@export var eat_time: float = 0.8
