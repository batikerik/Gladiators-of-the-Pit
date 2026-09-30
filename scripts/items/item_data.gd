class_name ItemData
extends Resource
## Base for everything that can lie on the floor and sit in the inventory.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var max_stack: int = 1
