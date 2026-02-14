extends Resource
class_name BuildBlueprint

@export var name: String = "Structure"
@export var category: String = "Structures"
@export var sub_category: String = "Foundations"
@export var icon: Texture2D
@export var scene: PackedScene
@export var cost: Dictionary = {} # { "Wood": 5, "Stone": 10 }
@export var description: String = ""
@export var snap_size: float = 4.0
