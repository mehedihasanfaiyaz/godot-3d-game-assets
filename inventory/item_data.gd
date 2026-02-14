extends Resource
class_name ItemData

enum Category { TOOLS, CONSUMABLES, MATERIALS, SPECIAL, CONSTRUCTION, DEVIATIONS, WEAPON }

@export var item_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.MATERIALS
@export var icon: Texture2D
@export var stackable: bool = true
@export var max_stack: int = 99
@export var weight: float = 0.1

# For weapons
@export var damage: float = 0.0
@export var attack_speed: float = 1.0
