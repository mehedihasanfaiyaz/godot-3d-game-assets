extends RigidBody3D

# Simple trailer script - just handles wheel physics, no driving
@export var wheels: Array[RayCast3D]
@export var spring_strength := 100000.0
@export var spring_damping := 2500.0
@export var suspension_travel := 0.5
@export var wheel_radius := 0.4
@export var tire_grip := 2.5
@export var rolling_resistance := 0.5

func _ready():
	for wheel in wheels:
		wheel.target_position.y = -(suspension_travel + wheel_radius)

func _physics_process(delta: float):
	for wheel in wheels:
		_process_wheel(wheel, delta)

func _process_wheel(ray: RayCast3D, delta: float):
	var wheel_mesh = ray.get_node("wheel")
	
	if not ray.is_colliding():
		wheel_mesh.position.y = lerp(wheel_mesh.position.y, -suspension_travel, 0.1)
		return
	
	var contact_point = ray.get_collision_point()
	var tire_vel = linear_velocity + angular_velocity.cross(contact_point - global_position)
	
	# Suspension
	var current_spring_len = ray.global_position.distance_to(contact_point) - wheel_radius
	var compression = (suspension_travel * 0.5) - current_spring_len
	var spring_force_mag = spring_strength * compression
	var damping_force = spring_damping * ray.global_basis.y.dot(tire_vel)
	var total_sus_force = max(0.0, spring_force_mag - damping_force) * ray.global_basis.y
	
	# Forward rolling resistance
	var tire_fwd_dir = -ray.global_basis.z
	var fwd_speed = tire_fwd_dir.dot(tire_vel)
	var resistance_force = -sign(fwd_speed) * rolling_resistance * (mass / wheels.size()) * tire_fwd_dir
	
	# Lateral friction (keeps trailer from sliding sideways)
	var tire_right_dir = ray.global_basis.x
	var lateral_vel = tire_right_dir.dot(tire_vel)
	var desired_friction = -lateral_vel * (mass / wheels.size()) * 10.0
	var max_lat_grip = max(0.0, spring_force_mag) * tire_grip
	var friction_force = tire_right_dir * clamp(desired_friction, -max_lat_grip, max_lat_grip)
	
	# Apply forces
	apply_force(total_sus_force + friction_force + resistance_force, contact_point - global_position)
	
	# Visual wheel rotation
	wheel_mesh.rotate_x(-(fwd_speed / wheel_radius) * delta)
	wheel_mesh.position.y = -current_spring_len
