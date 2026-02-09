extends RigidBody3D

#region --- Vehicle Setup & Physics ---

@export_group("Suspension")
@export var wheels: Array[RayCast3D]
# TODO @export var wheels: Array[RaycastWheel]
@export var spring_strength := 100000.0
@export var spring_damping := 2500.0
@export var suspension_travel := 0.5
@export var wheel_radius := 0.4
@export var anti_roll_strength := 1000.0

@export_group("Engine & Handling")
@export var engine_power := 80000.0
@export var boost_power := 800000.0
@export var max_speed := 30.0
@export var max_reverse_speed := 15.0
@export var brake_power := 50.0
@export var steer_angle := 30.0
@export var jump_impulse := 10000.0
@export var acceleration_time := 3.0
@export var reverse_acceleration_time := 4.0
@export var rolling_resistance := 0.5
@export var min_speed_for_steering := 1.0

@export_group("Friction & Drifting Model")
@export var tire_grip := 2.5
@export var longitudinal_grip := 4.0
@export var drift_threshold := 0.9
@export var brake_boost_drift_grip := 0.3
@export var drift_grip_reduction := 0.5
@export var grip_change_speed := 8.0
@export var drift_yaw_damping := 0.1
@export var counter_steer_assist := 20.0
@export var drift_power_multiplier := 1.2

@export_group("Aerodynamics")
@export var downforce_factor := 0.5

@export_group("Multi-Axle Steering")
@export var enable_rear_steer := false
@export var rear_steer_ratio := -0.3
@export var rear_steer_threshold := 0.3

@export_group("Air Control & Stability")
@export var air_rotation_speed := 8.0
@export var auto_stabilization := 15.0
@export var jump_pitch_compensation := 0.4
@export var air_brake_strength := 0.9
@export var enable_air_control := false
@export var air_pitch_sensitivity := 0.5
@export var air_roll_sensitivity := 0.7
#endregion

#region --- Gameplay Systems (Health, Fuel, Boost) ---
@export_group("Boost System")
@export var max_boost_fuel := 100.0
@export var boost_consumption := 25.0
@export var boost_recharge := 15.0

@export_group("Vehicle Health & Fuel")
@export var max_health := 100.0
@export var max_fuel := 100.0
@export var fuel_consumption_rate := 5.0
@export var fuel_boost_multiplier := 3.0
@export var damage_threshold := 10.0
@export var damage_multiplier := 2.0
@export var fuel_regeneration := 0.0
@export var health_regeneration := 0.0
#endregion

#region --- Visuals & Effects ---
@export_group("Damage Particles")
@export var damage_smoke_threshold := 30.0
@export var damage_smoke_particles: GPUParticles3D
@export var destruction_fire_particles: GPUParticles3D
@export var destruction_smoke_particles: GPUParticles3D

@export_group("UI")
@export var vehicle_hud: CanvasLayer

@export_group("Vehicle Lights")
@export var front_lights: Array[MeshInstance3D]
@export var rear_lights: Array[MeshInstance3D]
@export var left_indicators: Array[MeshInstance3D]
@export var right_indicators: Array[MeshInstance3D]
@export var front_light_color := Color(1.0, 1.0, 0.9, 1.0)
@export var rear_light_normal := Color(0.3, 0.0, 0.0, 1.0)
@export var rear_light_brake := Color(1.0, 0.0, 0.0, 1.0)
@export var rear_light_reverse := Color(1.0, 1.0, 1.0, 1.0)
@export var indicator_color := Color(1.0, 0.6, 0.0, 1.0)
@export var indicator_blink_rate := 2.0
@export var indicator_steer_threshold := 0.3

@export_group("Camera Shake")
@export var shake_noise: Noise
@export var camera_shake_intensity := 0.01
@export var camera_shake_roll_intensity := 0.015
@export var camera_shake_speed := 20.0

@export_group("Camera System")
@export var cameras: Array[Camera3D]
@export var start_camera_index := 0
@export var camera_smooth_speed := 5.0
@export var camera_fov_smooth_speed := 5.0
@export var dynamic_fov_increase := 10.0

@export_group("Wheel Visuals")
@export var wheel_particles: Array[GPUParticles3D]
#endregion

#region --- State Variables ---
var current_health: float
var current_fuel: float
var current_boost_fuel: float

var current_steer_angle := 0.0
var is_airborne := false
var time_airborne := 0.0
var grounded_wheels := 0
var _axle_mid_point_z := 0.0
var _is_drifting := false
var _lateral_grip_mod := 1.0

var _blink_timer := 0.0
var _blink_on := false
var speed_label: Label
var boost_bar: Range
var health_bar: Range
var fuel_bar: Range
var _render_camera: Camera3D
var _shake_noise_time := 0.0
var current_camera_index := 0
#endregion

#region --- Godot Lifecycle & Setup ---
func _ready():
	_setup_wheels_and_com()
	_setup_smooth_camera()
	_setup_collision_detection()
	_setup_hud()
	
	current_health = max_health
	current_fuel = max_fuel
	current_boost_fuel = max_boost_fuel

func _physics_process(delta: float):
	# ALWAYS check for camera switching, even when destroyed
	if Input.is_action_just_pressed("veh_cam"):
		switch_camera()
	
	# If destroyed, only update visual effects and camera
	if current_health <= 0:
		_update_damage_particles()
		_process_camera_smoothness(delta)
		return

	# Normal physics processing when alive
	var throttle = Input.get_action_strength("veh_accelerate")
	var reverse = Input.get_action_strength("veh_back")
	var brake = Input.get_action_strength("veh_brake")
	var steer_input = Input.get_axis("veh_right", "veh_left")
	var is_boosting = Input.is_action_pressed("veh_boost") and current_boost_fuel > 0

	_update_resources(throttle, reverse, is_boosting, delta)
	if current_fuel <= 0:
		throttle = 0
		reverse = 0
		is_boosting = false

	_update_drift_state(throttle, brake, delta)
	_update_airborne_state(delta)
	_update_steering(steer_input, delta)

	if not is_airborne:
		apply_downforce()
		_ground_stabilization(delta)
		if anti_roll_strength > 0 and grounded_wheels >= 3:
			var roll = global_transform.basis.get_euler().z
			if abs(roll) > deg_to_rad(5):
				apply_torque(global_transform.basis.z * -roll * anti_roll_strength * mass * 0.1 * delta)
	else:
		if enable_air_control: 
			_air_control(delta, steer_input, throttle, reverse)
		_stabilize_in_air(delta)

	for i in range(wheels.size()):
		var particles = wheel_particles[i] if i < wheel_particles.size() else null
		_process_wheel(wheels[i], throttle, reverse, brake, is_boosting, particles, delta)
	
	if _is_drifting and not is_airborne: 
		_apply_drift_assist(steer_input)

	if Input.is_action_just_pressed("veh_jump") and grounded_wheels >= 2: 
		_jump()

	_update_lights(brake, reverse, steer_input, delta)
	_update_damage_particles()
	_process_camera_smoothness(delta)

func _process(_delta: float):
	_update_hud()
#endregion

#TODO
#1. do single wheel suspension
#2. do single weel accelaration.

#region --- Setup Functions ---
func _setup_wheels_and_com():
	for wheel in wheels:
		wheel.target_position.y = -(suspension_travel + wheel_radius)
	if wheels.size() > 0:
		var total_z = 0.0
		for wheel in wheels: 
			total_z += wheel.position.z
		_axle_mid_point_z = total_z / wheels.size()

func _setup_smooth_camera():
	if cameras.is_empty(): 
		return
	current_camera_index = start_camera_index
	var start_cam = cameras[start_camera_index]
	_render_camera = start_cam.duplicate()
	add_child(_render_camera)
	_render_camera.make_current()
	_render_camera.global_transform = start_cam.global_transform

func _setup_collision_detection():
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _setup_hud():
	if is_instance_valid(vehicle_hud):
		speed_label = vehicle_hud.get_node_or_null("%SpeedLabel")
		boost_bar = vehicle_hud.get_node_or_null("%BoostBar")
		health_bar = vehicle_hud.get_node_or_null("%HealthBar")
		fuel_bar = vehicle_hud.get_node_or_null("%FuelBar")
#endregion

#region --- Core Physics & Movement ---
func _process_wheel(ray: RayCast3D, throttle: float, reverse: float, brake: float, is_boosting: bool, particles: GPUParticles3D, delta: float):
	if ray.position.z < _axle_mid_point_z: 
		ray.rotation.y = current_steer_angle
	elif enable_rear_steer: 
		ray.rotation.y = -current_steer_angle * rear_steer_ratio
	else: 
		ray.rotation.y = 0

	var wheel_mesh = ray.get_node("wheel")
	if not ray.is_colliding():
		if particles: 
			particles.emitting = false
		wheel_mesh.position.y = lerp(wheel_mesh.position.y, -suspension_travel, 0.1)
		return

	if particles: 
		particles.emitting = _is_drifting
	var contact_point = ray.get_collision_point()
	#TODO var contact_point = ray.wheels.global_position
	var tire_vel = linear_velocity + angular_velocity.cross(contact_point - global_position)

	var current_spring_len = ray.global_position.distance_to(contact_point) - wheel_radius
	var compression = (suspension_travel * 0.5) - current_spring_len
	var spring_force_mag = spring_strength * compression
	var damping_force = spring_damping * ray.global_basis.y.dot(tire_vel)
	var total_sus_force = max(0.0, spring_force_mag - damping_force) * ray.global_basis.y

	var tire_fwd_dir = -ray.global_basis.z
	var fwd_speed = tire_fwd_dir.dot(tire_vel)
	var desired_force_mag = 0.0
	if throttle > 0:
		var torque_curve = 1.0 - pow(abs(fwd_speed) / max_speed, 2.0)
		var power_mult = boost_power / engine_power if is_boosting else 1.0
		desired_force_mag = throttle * mass * (max_speed / acceleration_time) * power_mult / wheels.size() * torque_curve
	elif reverse > 0:
		var torque_curve = 1.0 - pow(abs(fwd_speed) / max_reverse_speed, 2.0)
		desired_force_mag = -reverse * mass * (max_reverse_speed / reverse_acceleration_time) / wheels.size() * torque_curve
	if _is_drifting: 
		desired_force_mag *= drift_power_multiplier
	if brake > 0:
		if abs(fwd_speed) > 0.5:
			desired_force_mag -= sign(fwd_speed) * brake * brake_power * (mass / wheels.size())
		else:
			desired_force_mag = 0.0
	var max_long_grip = max(0.0, spring_force_mag) * longitudinal_grip
	var final_accel_mag = clamp(desired_force_mag, -max_long_grip, max_long_grip)
	if abs(final_accel_mag) < 0.01 and abs(fwd_speed) > 0.1:
		final_accel_mag = -sign(fwd_speed) * rolling_resistance * (mass / wheels.size())
	var accel_force = tire_fwd_dir * final_accel_mag

	var tire_right_dir = ray.global_basis.x
	var lateral_vel = tire_right_dir.dot(tire_vel)
	var desired_friction = -lateral_vel * (mass / wheels.size()) * 10.0
	var max_lat_grip = max(0.0, spring_force_mag) * tire_grip * _lateral_grip_mod
	var friction_force = tire_right_dir * clamp(desired_friction, -max_lat_grip, max_lat_grip)

	apply_force(total_sus_force + friction_force + accel_force, contact_point - global_position)
	wheel_mesh.rotate_x(-(fwd_speed / wheel_radius) * delta)
	wheel_mesh.position.y = -current_spring_len

func apply_downforce():
	if downforce_factor <= 0: 
		return
	var fwd_speed_sq = pow(linear_velocity.dot(-global_transform.basis.z), 2)
	apply_central_force(global_transform.basis.y * -downforce_factor * fwd_speed_sq)
#endregion

#region --- State Update Functions ---
func _update_resources(throttle: float, reverse: float, is_boosting: bool, delta: float):
	if is_boosting: 
		current_boost_fuel = max(0.0, current_boost_fuel - boost_consumption * delta)
	else: 
		current_boost_fuel = min(max_boost_fuel, current_boost_fuel + boost_recharge * delta)
	
	var is_driving = (throttle > 0.1 or reverse > 0.1) and current_fuel > 0
	if is_driving:
		var consumption = fuel_consumption_rate * delta * (fuel_boost_multiplier if is_boosting else 1.0)
		current_fuel = max(0.0, current_fuel - consumption)
	elif fuel_regeneration > 0:
		current_fuel = min(max_fuel, current_fuel + fuel_regeneration * delta)
	
	if health_regeneration > 0:
		current_health = min(max_health, current_health + health_regeneration * delta)

func _update_drift_state(throttle: float, brake: float, delta: float):
	var target_grip_mod = 1.0
	if not is_airborne:
		var total_slip_ratio = 0.0
		for wheel in wheels:
			if not wheel.is_colliding(): 
				continue
			var tire_vel = linear_velocity + angular_velocity.cross(wheel.get_collision_point() - global_position)
			total_slip_ratio += abs(wheel.global_basis.x.dot(tire_vel))
		var is_brake_boosting = throttle > 0.5 and brake > 0.5 and linear_velocity.length() > 1.0
		var is_naturally_drifting = total_slip_ratio > tire_grip * drift_threshold * grounded_wheels
		
		_is_drifting = is_brake_boosting or is_naturally_drifting
		
		if is_brake_boosting: 
			target_grip_mod = brake_boost_drift_grip
		elif is_naturally_drifting: 
			target_grip_mod = drift_grip_reduction
	
	_lateral_grip_mod = lerp(_lateral_grip_mod, target_grip_mod, grip_change_speed * delta)

func _update_airborne_state(delta: float):
	grounded_wheels = 0
	for wheel in wheels:
		if wheel.is_colliding(): 
			grounded_wheels += 1
	is_airborne = grounded_wheels == 0
	if is_airborne: 
		time_airborne += delta
	else: 
		time_airborne = 0.0

func _update_steering(steer_input: float, delta: float):
	if not is_airborne:
		current_steer_angle = lerp(current_steer_angle, steer_input * deg_to_rad(steer_angle), 12.0 * delta)
	else:
		current_steer_angle = lerp(current_steer_angle, 0.0, 5.0 * delta)
#endregion

#region --- Health & Damage ---
func _on_body_entered(body: Node):
	var impact_velocity = linear_velocity.length()
	if impact_velocity > damage_threshold:
		var damage = (impact_velocity - damage_threshold) * damage_multiplier
		current_health = max(0.0, current_health - damage)
		print("COLLISION! Damage: %.1f | Health: %.1f" % [damage, current_health])
		if current_health <= 0:
			_on_vehicle_destroyed()

func _on_vehicle_destroyed():
	print("--- VEHICLE DESTROYED ---")
	if is_instance_valid(damage_smoke_particles): 
		damage_smoke_particles.emitting = false
	if is_instance_valid(destruction_fire_particles): 
		destruction_fire_particles.emitting = true
	if is_instance_valid(destruction_smoke_particles): 
		destruction_smoke_particles.emitting = true
	# Don't disable physics process completely - just let the normal flow handle it

func _update_damage_particles():
	if not is_instance_valid(damage_smoke_particles): 
		return
	var health_percent = (current_health / max_health) * 100.0
	if health_percent <= damage_smoke_threshold and current_health > 0:
		if not damage_smoke_particles.emitting: 
			damage_smoke_particles.emitting = true
		var smoke_intensity = 1.0 - (health_percent / damage_smoke_threshold)
		damage_smoke_particles.amount_ratio = clamp(smoke_intensity, 0.3, 1.0)
	elif current_health <= 0:
		# Show destruction effects when completely destroyed
		damage_smoke_particles.emitting = false
		if is_instance_valid(destruction_fire_particles) and not destruction_fire_particles.emitting:
			destruction_fire_particles.emitting = true
		if is_instance_valid(destruction_smoke_particles) and not destruction_smoke_particles.emitting:
			destruction_smoke_particles.emitting = true
	else:
		if damage_smoke_particles.emitting: 
			damage_smoke_particles.emitting = false
#endregion

#region --- Visuals & UI ---
func _update_hud():
	if is_instance_valid(speed_label): 
		speed_label.text = str(int(linear_velocity.length() * 3.6))
	if is_instance_valid(boost_bar): 
		boost_bar.max_value = max_boost_fuel
		boost_bar.value = current_boost_fuel
	if is_instance_valid(health_bar): 
		health_bar.max_value = max_health
		health_bar.value = current_health
	if is_instance_valid(fuel_bar): 
		fuel_bar.max_value = max_fuel
		fuel_bar.value = current_fuel

func _update_lights(brake: float, reverse: float, steer_input: float, delta: float):
	# Don't update lights when destroyed
	if current_health <= 0:
		return
	
	_blink_timer += delta
	if _blink_timer >= (1.0 / indicator_blink_rate) / 2.0:
		_blink_on = not _blink_on
		_blink_timer = 0.0
	var left_active = steer_input < -indicator_steer_threshold
	var right_active = steer_input > indicator_steer_threshold
	var rear_color = rear_light_normal
	if brake > 0.1: 
		rear_color = rear_light_brake
	elif reverse > 0.1: 
		rear_color = rear_light_reverse
	for light in front_lights: 
		_set_light_material(light, front_light_color, true, 2.0)
	for light in rear_lights: 
		_set_light_material(light, rear_color, true, 3.0)
	for light in left_indicators: 
		_set_light_material(light, indicator_color, left_active and _blink_on, 4.0)
	for light in right_indicators: 
		_set_light_material(light, indicator_color, right_active and _blink_on, 4.0)

func _set_light_material(mesh: MeshInstance3D, color: Color, is_active: bool, energy: float):
	if not is_instance_valid(mesh): 
		return
	var mat = mesh.get_active_material(0) as StandardMaterial3D
	if mat:
		mat.emission_enabled = is_active
		if is_active: 
			mat.emission = color * energy

func _process_camera_smoothness(delta):
	if not is_instance_valid(_render_camera) or cameras.is_empty(): 
		return
	var target_cam = cameras[current_camera_index]
	var new_xform = _render_camera.global_transform.interpolate_with(target_cam.global_transform, camera_smooth_speed * delta)
	
	# Only apply speed-based effects when alive
	if current_health > 0:
		var speed_ratio = clamp(linear_velocity.length() / max_speed, 0.0, 1.0)
		_render_camera.fov = lerp(_render_camera.fov, target_cam.fov + (dynamic_fov_increase * speed_ratio), camera_fov_smooth_speed * delta)
		
		if shake_noise:
			_shake_noise_time += camera_shake_speed * delta
			var shake_speed_mod = pow(speed_ratio, 2.0)
			var s = shake_speed_mod * camera_shake_intensity
			var n1 = shake_noise.get_noise_2d(_shake_noise_time, 0) * s
			var n2 = shake_noise.get_noise_2d(0, _shake_noise_time) * s
			new_xform.origin += new_xform.basis.x * n1 + new_xform.basis.y * n2
			var rs = shake_speed_mod * camera_shake_roll_intensity
			var rn = shake_noise.get_noise_2d(_shake_noise_time * 0.7, 123.45) * rs
			new_xform.basis = new_xform.basis.rotated(new_xform.basis.z, rn)
	else:
		# When destroyed, use normal FOV without speed effects
		_render_camera.fov = lerp(_render_camera.fov, target_cam.fov, camera_fov_smooth_speed * delta)
	
	_render_camera.global_transform = new_xform
#endregion

#region --- Helper & Action Functions ---
func _jump():
	if current_health <= 0:
		return
	apply_central_impulse((Vector3.UP + -global_transform.basis.z.normalized() * jump_pitch_compensation).normalized() * jump_impulse)

func switch_camera():
	if cameras.is_empty(): 
		return
	current_camera_index = (current_camera_index + 1) % cameras.size()
	print("Switched to camera ", current_camera_index + 1, " of ", cameras.size())

func _air_control(delta: float, steer: float, throttle: float, reverse: float):
	var rot_input = Vector3(-(reverse - throttle) * air_pitch_sensitivity, 0, -steer * air_roll_sensitivity) * air_rotation_speed
	if rot_input.length() > 0: 
		apply_torque(global_transform.basis * rot_input * mass)
	else: 
		angular_velocity *= (1.0 - air_brake_strength * delta)

func _stabilize_in_air(delta: float):
	var err = Vector3(0, global_transform.basis.get_euler().y, 0) - global_transform.basis.get_euler()
	apply_torque(global_transform.basis * err * auto_stabilization * mass)
	angular_velocity *= 0.93

func _ground_stabilization(delta: float):
	var rot = global_transform.basis.get_euler()
	if abs(rot.x) > deg_to_rad(25) or abs(rot.z) > deg_to_rad(25):
		var sf = clamp(1.0 - (linear_velocity.length() / 5.0), 0.1, 1.0)
		var err = Vector3(0, rot.y, 0) - rot
		apply_torque(global_transform.basis * err * 15.0 * sf * mass * delta)

func _apply_drift_assist(steer_input: float):
	angular_velocity.y *= (1.0 - drift_yaw_damping)
	var car_yaw_rate = angular_velocity.y
	if sign(car_yaw_rate) == sign(steer_input) and abs(steer_input) > 0.1:
		apply_torque(Vector3(0, -car_yaw_rate * counter_steer_assist * mass, 0))
#endregion
