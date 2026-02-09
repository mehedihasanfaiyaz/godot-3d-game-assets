extends RayCast3D

class_name RaycastWheel

@export var spring_strength := 100000.0
@export var spring_damping := 2500.0
@export var rest_dis := 0.5
@export var over_extend := 0.0
@export var wheel_radis := 0.4
@export var is_motor := false

@onready var wheel: Node3D = get_child(0)
