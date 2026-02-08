extends RigidBody3D

@export_group("Suspension")
@export var wheels: Array[RayCast3D]
@export var spring_strength := 100000.0
@export var spring_damping := 2500.0
@export var suspension_travel := 0.5
@export var wheel_radius := 0.4

@export_group("Engine & Handling")
@export var engine_power := 80000.0
@export var boost_power := 150000.0
@export var max_speed := 30.0
@export var max_reverse_speed := 15.0
@export var brake_power := 50.0
@export var steer_angle := 30.0
@export var tire_grip := 40.0
@export var jump_impulse := 20000.0

@export_group("Air Control & Stability")
@export var air_rotation_speed := 8.0
@export var auto_stabilization := 15.0
@export var max_air_roll_angle := 45.0
@export var max_air_pitch_angle := 45.0
@export var jump_pitch_compensation := 0.4
@export var air_brake_strength := 0.9

@export_group("Air Control")
@export var enable_air_control := true
@export var air_pitch_sensitivity := 0.5
@export var air_roll_sensitivity := 0.7

@export_group("Camera System")
@export var cameras: Array[Camera3D]
@export var start_camera_index := 0

var current_steer_angle := 0.0
var is_airborne := false
var time_airborne := 0.0
var grounded_wheels := 0
var last_grounded_rotation := Vector3.ZERO
var current_camera_index := 0

func _ready() -> void:
	# Initialize wheels
	for wheel in wheels:
		wheel.target_position.y = -(suspension_travel + wheel_radius)
	
	# Initialize camera system
	current_camera_index = start_camera_index
	_update_camera()

func _physics_process(delta: float) -> void:
	# 1. Capture Inputs
	var throttle = Input.get_action_strength("veh_accelerate")
	var reverse = Input.get_action_strength("veh_back")
	var brake = Input.get_action_strength("veh_brake")
	var steer_input = Input.get_axis("veh_right", "veh_left") 
	var is_boosting = Input.is_action_pressed("veh_boost")
	
	# 2. Camera switching
	if Input.is_action_just_pressed("veh_cam"):
		switch_camera()
	
	# 3. Update grounded state
	grounded_wheels = 0
	for wheel in wheels:
		if wheel.is_colliding():
			grounded_wheels += 1
	
	is_airborne = grounded_wheels == 0
	
	if is_airborne:
		time_airborne += delta
	else:
		time_airborne = 0.0
		last_grounded_rotation = global_transform.basis.get_euler()
	
	# 4. Steering Angle Calculation
	if not is_airborne:
		current_steer_angle = lerp(current_steer_angle, steer_input * deg_to_rad(steer_angle), 15.0 * delta)
	else:
		current_steer_angle = lerp(current_steer_angle, 0.0, 5.0 * delta)
	
	# 5. Process each wheel individually
	for wheel in wheels:
		_process_wheel(wheel, throttle, reverse, brake, is_boosting, wheels.size())

	# 6. Jump Logic
	if Input.is_action_just_pressed("veh_jump") and grounded_wheels >= 2:
		_jump()
	
	# 7. Air Control & Stability
	if is_airborne:
		if enable_air_control:
			_air_control(delta, steer_input, throttle, reverse)
		_stabilize_in_air(delta)
	else:
		_ground_stabilization(delta)

func _jump():
	# Apply jump impulse with pitch compensation
	var jump_direction = Vector3.UP
	var forward_dir = -global_transform.basis.z.normalized()
	jump_direction += forward_dir * jump_pitch_compensation
	
	apply_central_impulse(jump_direction.normalized() * jump_impulse)
	
	# Store rotation at jump time
	last_grounded_rotation = global_transform.basis.get_euler()
	
	# Stronger angular velocity reduction to prevent flipping
	angular_velocity *= 0.6
	
	# Apply a small upward torque to help keep car level
	var current_rotation = global_transform.basis.get_euler()
	if current_rotation.x > 0.1:  # If already tilted forward
		apply_torque(global_transform.basis.x * 1000.0)

func _air_control(delta: float, steer_input: float, throttle: float, reverse: float):
	# Simple air control using existing inputs
	var rotation_input = Vector3.ZERO
	
	if time_airborne > 0.05:
		# PITCH CONTROL: Use throttle/reverse to pitch
		var pitch_input = reverse - throttle  # Reverse pitches up, throttle pitches down
		rotation_input.x = -pitch_input * air_rotation_speed * air_pitch_sensitivity
		
		# ROLL CONTROL: Use steering to roll
		rotation_input.z = -steer_input * air_rotation_speed * air_roll_sensitivity
	
	# Apply rotation
	if rotation_input.length_squared() > 0:
		apply_torque(global_transform.basis * rotation_input * mass)
	else:
		# Air brake when no input
		angular_velocity *= (1.0 - air_brake_strength * delta)

func _stabilize_in_air(delta: float):
	# Strong auto-stabilization to prevent flipping
	var current_rotation = global_transform.basis.get_euler()
	
	# Calculate how much we're tilted
	var tilt_angle_x = abs(current_rotation.x)
	var tilt_angle_z = abs(current_rotation.z)
	
	# Determine stabilization strength based on tilt
	var stabilization_strength = auto_stabilization
	
	# Increase stabilization if we're tilted a lot
	if tilt_angle_x > deg_to_rad(30) or tilt_angle_z > deg_to_rad(30):
		stabilization_strength *= 2.0
	
	# Target: upright rotation
	var target_rotation = Vector3(0, current_rotation.y, 0)
	var error = target_rotation - current_rotation
	
	# Apply stabilization torque
	var stabilization_torque = error * stabilization_strength * mass
	apply_torque(global_transform.basis * stabilization_torque)
	
	# Strong air resistance to dampen rotation
	angular_velocity *= 0.93

func _ground_stabilization(delta: float):
	# Prevention of tipping while on ground
	var current_rotation = global_transform.basis.get_euler()
	
	# Check if we're starting to tip
	if abs(current_rotation.x) > deg_to_rad(15) or abs(current_rotation.z) > deg_to_rad(15):
		# Calculate speed - less stabilization at high speeds
		var speed = linear_velocity.length()
		var speed_factor = clamp(1.0 - (speed / 10.0), 0.3, 1.0)
		
		var target_rotation = Vector3(0, current_rotation.y, 0)
		var error = target_rotation - current_rotation
		
		# Apply correction stronger when tilted more
		var tilt_amount = max(abs(current_rotation.x), abs(current_rotation.z))
		var correction_strength = clamp(tilt_amount * 20.0, 5.0, 30.0) * speed_factor
		
		var correction = error * correction_strength * mass * delta
		apply_torque(global_transform.basis * correction)

func _process_wheel(ray: RayCast3D, throttle: float, reverse: float, brake: float, is_boosting: bool, wheel_count: int) -> void:
	var wheel_mesh = ray.get_node("wheel")
	
	if ray.is_colliding():
		# --- GROUNDED STATE ---
		
		# 1. Update Steering
		if ray.position.z < 0: # Front wheels
			ray.rotation.y = current_steer_angle
		else: # Rear wheels
			ray.rotation.y = 0

		var contact_point = ray.get_collision_point()
		var dist_to_hit = ray.global_position.distance_to(contact_point)
		var tire_vel = _get_point_velocity(contact_point)
		
		# 2. Suspension Physics
		var current_spring_len = dist_to_hit - wheel_radius
		var compression = (suspension_travel * 0.5) - current_spring_len
		var spring_force = spring_strength * compression
		
		var suspension_dir = ray.global_basis.y 
		var vertical_vel = suspension_dir.dot(tire_vel)
		var damping_force = spring_damping * vertical_vel
		var total_sus_force = (spring_force - damping_force) * suspension_dir
		
		# 3. Acceleration & Reversing & Braking
		var tire_forward_dir = -ray.global_basis.z
		var current_forward_speed = tire_forward_dir.dot(tire_vel)
		var accel_force = Vector3.ZERO
		
		if throttle > 0:
			# Forward acceleration
			var torque_curve = 1.0 - (abs(current_forward_speed) / max_speed)
			torque_curve = clamp(torque_curve, 0.0, 1.0)
			var current_power = boost_power if is_boosting else engine_power
			accel_force = tire_forward_dir * throttle * (current_power / wheel_count) * torque_curve
		
		elif reverse > 0:
			# Reverse acceleration
			var reverse_speed_limit = 1.0 - (abs(current_forward_speed) / max_reverse_speed)
			reverse_speed_limit = clamp(reverse_speed_limit, 0.0, 1.0)
			accel_force = -tire_forward_dir * reverse * (engine_power * 0.5 / wheel_count) * reverse_speed_limit
		
		if brake > 0:
			var brake_direction: Vector3
			if abs(current_forward_speed) > 0.5:
				brake_direction = tire_forward_dir * sign(current_forward_speed)
			else:
				brake_direction = tire_forward_dir
			
			# Apply the force in the opposite direction of movement
			accel_force -= brake_direction * brake * brake_power * (mass / wheel_count)
			
		# 4. Lateral Friction
		var tire_right_dir = ray.global_basis.x
		var lateral_vel = tire_right_dir.dot(tire_vel)
		var friction_force = -tire_right_dir * lateral_vel * tire_grip * (mass / wheel_count)
		
		# 5. Apply Final Forces
		var force_offset = contact_point - global_position
		apply_force(total_sus_force + friction_force + accel_force, force_offset)
		
		# Visual Position
		wheel_mesh.position.y = -current_spring_len
		
	else:
		# --- AIRBORNE STATE ---
		wheel_mesh.position.y = lerp(wheel_mesh.position.y, -suspension_travel, 0.1)
		ray.rotation.y = lerp(ray.rotation.y, 0.0, 0.1)

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)

# ===== CAMERA FUNCTIONS =====
func switch_camera():
	# If the array is empty, we can't switch
	if cameras.is_empty():
		push_warning("Camera array is empty! Drag cameras into the Inspector.")
		return

	# Cycle index
	current_camera_index = (current_camera_index + 1) % cameras.size()
	_update_camera()

func _update_camera():
	# Double-check the camera exists at that index
	var target_cam = cameras[current_camera_index]

	if is_instance_valid(target_cam):
		target_cam.make_current()
	else:
		push_error("Camera at index %d is null or invalid!" % current_camera_index)
