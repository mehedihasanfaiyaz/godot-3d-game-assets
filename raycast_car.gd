extends RigidBody3D

#region --- Vehicle Setup & Physics ---

@export_group("Player Control")
@export var is_player_controlled := true
@export_group("NPC AI")
@export var is_npc := false
@export var npc_target_speed := 45.0
@export var npc_target_path: NodePath # Changed to NodePath for better compatibility
@export var debug_traffic := true
@export var npc_detect_dist := 15.0

var _npc_path_node: Path3D # The actual resolved node
@export var npc_path_is_loop := true # If false, NPC stops at end of path
@export var npc_steer_smoothing := 20.0 # Fast response (was 8.5)
var _npc_steer_target := 0.0 # Persistent for smoothing
@export var npc_brake_dist := 6.0
@export var npc_lane_width := 4.0 # How far to look for road edges

@export_group("Suspension")
@export var wheels: Array[RaycastWheel]  # Changed from Array[RayCast3D]
# Suspension settings are now on individual wheels
@export var anti_roll_strength := 1000.0
@export var center_of_mass_offset := Vector3(0, -0.3, 0)  # Lower CoM for stability
@export var can_tow := true

@export_group("Engine & Handling")
@export var engine_power := 80000.0
@export var boost_power := 800000.0
@export var max_speed := 30.0
@export var max_reverse_speed := 15.0
@export var brake_power := 50.0
@export var steer_angle := 40.0
@export var steer_speed := 5.5  # Tuned for a balance of smoothness and response
@export var jump_impulse := 10000.0
@export var acceleration_time := 3.0
@export var reverse_acceleration_time := 4.0
@export var min_speed_for_steering := 1.0

@export_group("Friction & Drifting Model")
# Tire friction settings are now on individual wheels
@export var drift_threshold := 0.9
@export var brake_boost_drift_grip := 0.3
@export var drift_grip_reduction := 0.5
@export var grip_change_speed := 8.0
@export var drift_yaw_damping := 0.1
@export var counter_steer_assist := 20.0
@export var drift_power_multiplier := 1.2

@export_group("Professional Handling")
@export var ackermann_factor := 0.15      # Inner wheel turns more than outer
@export var body_roll_strength := 0.05   # Visual chassis tilt when cornering
@export var wheel_base := 2.5            # Distance between front and rear axles
@export var wheel_track := 1.8           # Distance between left and right wheels
@export var car_visual_node: Node3D      # The mesh that will tilt (body roll)

@export_group("Aerodynamics")
@export var downforce_factor := 0.5

@export_group("Multi-Axle Steering")
@export var enable_rear_steer := false
@export var rear_steer_ratio := -0.3
@export var rear_steer_threshold := 0.3
@export var steer_speed_scaling := 1.5   # Steering gets heavier/slower at speed

@export_group("Air Control & Stability")
@export var air_rotation_speed := 8.0
@export var auto_stabilization := 200.0  # Massive stability (was 100.0)
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
@export var dynamic_fov_increase := 15.0 
@export var throttle_fov_increase := 8.0 
@export var boost_fov_multiplier := 1.15 
@export var boost_fov_snap_speed := 15.0
@export var speed_blur_rect: ColorRect   

@export_group("Particles")
@export var warp_particles: GPUParticles3D # Cinematic speed streaks for boost
@export var wheel_particles: Array[GPUParticles3D]
#endregion

#region --- State Variables ---
var current_health: float
var current_fuel: float
var current_boost_fuel: float
var current_driver: Node3D = null

func enter_vehicle(player):
	current_driver = player
	is_player_controlled = true
	
	# Initialize camera if needed
	if not is_instance_valid(_render_camera):
		_setup_smooth_camera()
	else:
		# If it exists, just make it current again
		_render_camera.make_current()
	
	# Show HUD
	if is_instance_valid(vehicle_hud):
		_setup_hud() # Refresh connections
		vehicle_hud.visible = true
	
	player.start_driving(self)

func exit_vehicle():
	current_driver = null
	is_player_controlled = false
	
	# Hide HUD
	if is_instance_valid(vehicle_hud):
		vehicle_hud.visible = false
	
	# Reset cameras if needed
	for cam in cameras:
		cam.current = false
var current_steer_angle := 0.0
var is_airborne := false
var time_airborne := 0.0
var grounded_wheels := 0
var _axle_mid_point_z := 0.0
var _is_drifting := false
var _is_actually_boosting := false
var _current_throttle := 0.0
var _lateral_grip_mod := 1.0
var _speed_modifier := 1.0 # 1.0 = Normal, 0.5 = Half Speed (Mud/Slow)

var _blink_timer := 0.0
var _blink_on := false
var speed_label: Label
var tow_prompt: Label
var boost_bar: Range
var health_bar: Range
var fuel_bar: Range
var _render_camera: Camera3D
var _shake_noise_time := 0.0
var current_camera_index := 0
var _towed_vehicle: RigidBody3D
var _tow_joint: PinJoint3D
var _path_progress := 0.0
var _towed_by: RigidBody3D = null # Reference to the vehicle pulling us
#endregion

#region --- Godot Lifecycle & Setup ---
var _debug_timer := 0.0

func _ready():
	_setup_wheels_and_com()
	
	if is_player_controlled:
		_setup_smooth_camera()
		_setup_hud()
		if is_instance_valid(vehicle_hud):
			vehicle_hud.visible = true
	else:
		# If not the player, HIDE the HUD so it doesn't overlap the screen
		if is_instance_valid(vehicle_hud):
			vehicle_hud.visible = false
	if is_npc:
		print("[%s] NPC MODE INITIALIZED - Ready to drive." % name)
		if not npc_target_path.is_empty():
			_npc_path_node = get_node_or_null(npc_target_path) as Path3D
			if _npc_path_node:
				print("    [+] Successfully linked to Path: ", _npc_path_node.name)
			else:
				push_warning("NPC %s: npc_target_path is assigned but node was not found or is not a Path3D!" % name)
		
	_setup_collision_detection()
	add_to_group("vehicles")
	
	# Set center of mass for proper balance
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = center_of_mass_offset
	
	current_health = max_health
	current_fuel = max_fuel
	current_boost_fuel = max_boost_fuel

func _physics_process(delta: float):
	# ALWAYS check for camera switching, even when destroyed
	if is_player_controlled and Input.is_action_just_pressed("veh_cam"):
		switch_camera()
	
	# If destroyed, still process wheels so they don't clip through ground
	if current_health <= 0:
		_is_actually_boosting = false
		if is_instance_valid(warp_particles): warp_particles.emitting = false
		
		var brake_val = 1.0
		if is_instance_valid(_towed_by):
			brake_val = 0.0 # Release brakes so it can be dragged!
			
		for i in range(wheels.size()):
			var particles = wheel_particles[i] if i < wheel_particles.size() else null
			_process_wheel(wheels[i], 0.0, 0.0, brake_val, false, particles, 1.0, delta)
			
		_update_damage_particles()
		if is_player_controlled:
			_process_camera_smoothness(delta)
		return

	# Normal physics processing
	var throttle := 0.0
	var reverse := 0.0
	var brake := 0.0
	var steer_input := 0.0
	var is_boosting := false
	
	if is_player_controlled and not is_instance_valid(_towed_by):
		throttle = Input.get_action_strength("veh_accelerate")
		reverse = Input.get_action_strength("veh_back")
		brake = Input.get_action_strength("veh_brake")
		steer_input = Input.get_axis("veh_right", "veh_left")
		is_boosting = Input.is_action_pressed("veh_boost") and current_boost_fuel > 0
	elif is_npc and not is_instance_valid(_towed_by):
		if debug_traffic: print("[%s] AI Heartbeat - Thinking..." % name)
		var ai_input = _process_npc_ai(delta)
		throttle = ai_input.x # Throttle (Positive) or Brake (Negative)
		steer_input = ai_input.y
		if throttle < 0: # Convert negative AI throttle to physical brake
			brake = abs(throttle)
			throttle = 0.0
	
	# If being towed, ensure neutral steering and no brakes
	if is_instance_valid(_towed_by):
		steer_input = 0.0
		throttle = 0.0
		reverse = 0.0
		brake = 0.0
		is_boosting = false

	_update_resources(throttle, reverse, is_boosting, delta)
	if current_fuel <= 0:
		throttle = 0; reverse = 0; is_boosting = false
	
	_is_actually_boosting = is_boosting
	_current_throttle = throttle - reverse
	
	if is_instance_valid(warp_particles):
		warp_particles.emitting = _is_actually_boosting and linear_velocity.length() > 5.0

	_update_drift_state(throttle, brake, delta)
	_update_airborne_state(delta)
	_update_steering(steer_input, delta)
	_update_body_roll(steer_input, delta)

	if not is_airborne:
		apply_downforce()
		_ground_stabilization(delta)
		if anti_roll_strength > 0 and grounded_wheels >= 3:
			var roll = global_transform.basis.get_euler().z
			if abs(roll) > deg_to_rad(15):
				apply_torque(global_transform.basis.z * -roll * anti_roll_strength * mass * 0.05 * delta)
	else:
		if enable_air_control and is_player_controlled: 
			_air_control(delta, steer_input, throttle, reverse)
		_stabilize_in_air(delta)
	
	if grounded_wheels > 0 and grounded_wheels < 3:
		var euler = global_transform.basis.get_euler()
		var target_rotation = Vector3(0, euler.y, 0)
		var error = target_rotation - euler
		apply_torque(global_transform.basis * error * auto_stabilization * 2.0 * mass)
		angular_velocity *= 0.50

	for i in range(wheels.size()):
		var particles = wheel_particles[i] if i < wheel_particles.size() else null
		_process_wheel(wheels[i], throttle, reverse, brake, is_boosting, particles, _lateral_grip_mod, delta)
	
	if _is_drifting and not is_airborne: 
		_apply_drift_assist(steer_input)

	if is_player_controlled and Input.is_action_just_pressed("veh_jump") and grounded_wheels >= 2: 
		_jump()

	_update_lights(brake, reverse, steer_input, delta)
	_update_damage_particles()
	
	if is_player_controlled:
		_process_camera_smoothness(delta)
		_process_towing(delta)

func _process(_delta: float):
	if is_player_controlled:
		_update_hud()
#endregion

#TODO
#1. do single wheel suspension
#2. do single weel accelaration.

#region --- Setup Functions ---
func _setup_wheels_and_com():
	# Wheels now have their own suspension settings configured in the scene
	# We rely on user settings or project defaults, but check for 0 values
	for wheel in wheels:
		if wheel.spring_strength <= 0:
			wheel.spring_strength = 20000.0
		if wheel.rest_distance <= 0:
			wheel.rest_distance = 0.5
		if wheel.wheel_radius <= 0:
			wheel.wheel_radius = 0.4
	
	# Calculate the axle midpoint for steering logic
	if wheels.size() > 0:
		var total_z = 0.0
		for wheel in wheels: 
			total_z += wheel.position.z
		_axle_mid_point_z = total_z / wheels.size()
		
	# Check if Blur Shader is correctly setup
	if is_instance_valid(speed_blur_rect):
		if not speed_blur_rect.material is ShaderMaterial:
			push_warning("RaycastCar: speed_blur_rect found but missing a ShaderMaterial! Blur effect won't show.")

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
		tow_prompt = vehicle_hud.get_node_or_null("%TowPrompt")
#endregion

#region --- Core Physics & Movement ---
func _process_wheel(wheel: RaycastWheel, throttle: float, reverse: float, brake: float, is_boosting: bool, particles: GPUParticles3D, grip_mod: float, delta: float):
	"""Process a single wheel using the new RaycastWheel system."""
	
	# Calculate Ackermann Steer for this wheel
	var steer_to_apply: float = 0.0
	if wheel.is_steerable:
		# Ackermann Logic: Inner wheel turns more than outer wheel
		# We use the wheel's local X position to determine if it's left or right
		var is_left = wheel.position.x < 0
		var ackermann_offset = (wheel_track / (2.0 * wheel_base)) * ackermann_factor
		
		# if current_steer_angle > 0 (turning left), left is inner
		# if current_steer_angle < 0 (turning right), right is inner
		if current_steer_angle > 0: # Turning Left
			steer_to_apply = current_steer_angle * (1.0 + ackermann_offset if is_left else 1.0 - ackermann_offset)
		else: # Turning Right
			steer_to_apply = current_steer_angle * (1.0 + ackermann_offset if not is_left else 1.0 - ackermann_offset)
			
	elif enable_rear_steer and wheel.position.z > _axle_mid_point_z:
		steer_to_apply = -current_steer_angle * rear_steer_ratio
	
	# Apply visual steering rotation
	wheel.rotation.y = steer_to_apply
	
	# Calculate engine force with torque curve
	var engine_force: float = 0.0
	var fwd_speed: float = abs(-wheel.global_basis.z.dot(linear_velocity))
	
	if throttle > 0:
		var torque_curve: float = clamp(1.0 - (fwd_speed / max_speed), 0.0, 1.0)
		var power_mult: float = boost_power / engine_power if is_boosting else 1.0
		engine_force = engine_power * power_mult * torque_curve * _speed_modifier / wheels.size()
		if _is_drifting:
			engine_force *= drift_power_multiplier
	elif reverse > 0:
		var torque_curve: float = clamp(1.0 - (fwd_speed / max_reverse_speed), 0.0, 1.0)
		engine_force = engine_power * torque_curve * _speed_modifier / wheels.size()
	
	# Calculate brake force - clamped to mass to prevent physics explosions
	var brake_force_val: float = brake * brake_power * (mass / wheels.size())
	
	# Delegate to wheel's physics processing
	var wheel_state := wheel.process_wheel_physics(
		delta,
		steer_to_apply,
		throttle if throttle > 0 else -reverse,
		brake,
		engine_force,
		brake_force_val,
		grip_mod
	)
	
	# Update particles based on wheel state
	if particles:
		particles.emitting = wheel_state.get("grounded", false) and wheel_state.get("slipping", false)

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
		var avg_tire_grip = 0.0
		var grip_wheel_count = 0
		
		for wheel in wheels:
			if not wheel.is_colliding(): 
				continue
			var tire_vel = linear_velocity + angular_velocity.cross(wheel.get_collision_point() - global_position)
			total_slip_ratio += abs(wheel.global_basis.x.dot(tire_vel))
			avg_tire_grip += wheel.tire_grip
			grip_wheel_count += 1
		
		if grip_wheel_count > 0:
			avg_tire_grip /= grip_wheel_count
		
		var is_brake_boosting = throttle > 0.5 and brake > 0.5 and linear_velocity.length() > 1.0
		var is_naturally_drifting = total_slip_ratio > avg_tire_grip * drift_threshold * grounded_wheels
		
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
		# Speed-sensitive steering: Balance between "too twitchy" and "too sluggish"
		var speed_val = linear_velocity.length()
		var speed_ratio = clamp(speed_val / max_speed, 0.0, 1.0)
		
		# Pro Steering: Sensitivity - give back some control at high speed (60% instead of 40%)
		var sensitivity = lerp(1.0, 0.6, speed_ratio) 
		
		# Dynamic Steering Speed: Start slower (5.5) so normal speed isn't twitchy
		# But don't slow down as much at high speed (only down to 75% of base speed)
		var dynamic_steer_speed = lerp(steer_speed, steer_speed * 0.75, speed_ratio)
		
		var target_angle = steer_input * deg_to_rad(steer_angle) * sensitivity
		current_steer_angle = lerp(current_steer_angle, target_angle, dynamic_steer_speed * delta)
	else:
		current_steer_angle = lerp(current_steer_angle, 0.0, 5.0 * delta)

func _update_body_roll(steer_input: float, delta: float):
	if not is_instance_valid(car_visual_node): 
		return
		
	var fwd_speed = -global_transform.basis.z.dot(linear_velocity)
	var speed_ratio = clamp(abs(fwd_speed) / max_speed, 0.0, 1.0)
	
	# Centripetal tilt: Tilts the body away from the turn (Visual G-Force)
	var target_roll = -steer_input * body_roll_strength * (speed_ratio * 1.5)
	
	# Add pitch from acceleration/braking
	var target_pitch = _current_throttle * body_roll_strength * 0.5
	
	var current_euler = car_visual_node.rotation
	car_visual_node.rotation.z = lerp(current_euler.z, target_roll, 10.0 * delta)
	car_visual_node.rotation.x = lerp(current_euler.x, target_pitch, 8.0 * delta)
func set_speed_modifier(modifier: float):
	_speed_modifier = modifier
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
	if not is_instance_valid(vehicle_hud) or not vehicle_hud.visible:
		return
		
	if is_instance_valid(speed_label): 
		var speed_kmh = int(linear_velocity.length() * 3.6)
		speed_label.text = str(speed_kmh) + " km/h"
		
		# Ensure scaling is centered
		speed_label.pivot_offset = speed_label.size / 2.0
		
		# Visceral HUD Scaling: Label gets bigger as you go faster
		var speed_ratio = linear_velocity.length() / max_speed
		var hud_scale = lerp(1.0, 1.3, clamp(speed_ratio, 0.0, 1.2))
		speed_label.scale = Vector2(hud_scale, hud_scale)
		
		# Color shift (White to Red at high speed)
		speed_label.modulate = Color(1.0, 1.0 - (speed_ratio * 0.3), 1.0 - (speed_ratio * 0.6))
		
	if is_instance_valid(boost_bar): 
		boost_bar.max_value = max_boost_fuel
		boost_bar.value = current_boost_fuel
		# Update percentage label if it exists in the children
		var perc_label = boost_bar.get_node_or_null("BoostPercentage")
		if perc_label:
			perc_label.text = str(int((current_boost_fuel / max_boost_fuel) * 100.0)) + "%"
			
	if is_instance_valid(health_bar): 
		health_bar.max_value = max_health
		health_bar.value = current_health
		
	if is_instance_valid(fuel_bar): 
		fuel_bar.max_value = max_fuel
		fuel_bar.value = current_fuel
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
	# NPCs only use indicators for sharp turns to avoid flickering
	var active_threshold = indicator_steer_threshold if not is_npc else 0.6
	var left_active = steer_input < -active_threshold
	var right_active = steer_input > active_threshold
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
	var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
	if not mat:
		var base_mat = mesh.get_active_material(0)
		if base_mat:
			mat = base_mat.duplicate()
			mesh.set_surface_override_material(0, mat)
	
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
		var speed_val = linear_velocity.length()
		var speed_ratio = clamp(speed_val / max_speed, 0.0, 1.2) # Allow slight over-ratio for boost
		
		# 1. Dynamic FOV (Warp effect)
		var target_fov = target_cam.fov + (dynamic_fov_increase * speed_ratio)
		
		if _current_throttle > 0:
			target_fov += throttle_fov_increase * _current_throttle
			
		if _is_actually_boosting:
			target_fov *= boost_fov_multiplier
		
		# AAA Trick: Use faster lerp for boost onset (kick) than for the return (smooth)
		var fov_lerp_speed = camera_fov_smooth_speed
		if _is_actually_boosting: fov_lerp_speed = boost_fov_snap_speed
		
		_render_camera.fov = lerp(_render_camera.fov, target_fov, fov_lerp_speed * delta)
		
		# (Removed G-Force Tilt as requested)
		
		# 2. Speed-based Shader Blur/Intensity
		if is_instance_valid(speed_blur_rect):
			var mat = speed_blur_rect.material as ShaderMaterial
			if mat:
				# ONLY show effect when boosting
				var target_intensity = 0.0
				if _is_actually_boosting: 
					target_intensity = clamp(speed_ratio + 0.2, 0.0, 1.0)
				
				# Smoothly fade the intensity in/out
				var current_val = mat.get_shader_parameter("speed_intensity")
				var new_val = lerp(float(current_val), target_intensity, 15.0 * delta)
				mat.set_shader_parameter("speed_intensity", new_val)
		
		# 4. Speed-based Shake
		if shake_noise:
			_shake_noise_time += camera_shake_speed * delta
			var shake_speed_mod = pow(speed_ratio, 2.0)
			
			# Visceral 'Rattle' when boosting
			var intensity_mult = 1.0
			var roll_mult = 1.0
			if _is_actually_boosting:
				intensity_mult = 2.0
				roll_mult = 3.0
			
			var s = shake_speed_mod * camera_shake_intensity * intensity_mult
			var n1 = shake_noise.get_noise_2d(_shake_noise_time, 0) * s
			var n2 = shake_noise.get_noise_2d(0, _shake_noise_time) * s
			new_xform.origin += new_xform.basis.x * n1 + new_xform.basis.y * n2
			
			var rs = shake_speed_mod * camera_shake_roll_intensity * roll_mult
			var rn = shake_noise.get_noise_2d(_shake_noise_time * 0.7, 123.45) * rs
			new_xform.basis = new_xform.basis.rotated(new_xform.basis.z, rn)
	else:
		_render_camera.fov = lerp(_render_camera.fov, target_cam.fov, camera_fov_smooth_speed * delta)
		if is_instance_valid(speed_blur_rect) and speed_blur_rect.material:
			speed_blur_rect.material.set_shader_parameter("speed_intensity", 0.0)
	
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
	
	# If we are NOT using smooth camera, we must manually set current
	if not is_instance_valid(_render_camera):
		cameras[current_camera_index].current = true
	
	print("Switched to camera index: ", current_camera_index, " (", cameras[current_camera_index].name, ")")

func _air_control(delta: float, steer: float, throttle: float, reverse: float):
	var rot_input = Vector3(-(reverse - throttle) * air_pitch_sensitivity, 0, -steer * air_roll_sensitivity) * air_rotation_speed
	if rot_input.length() > 0: 
		apply_torque(global_transform.basis * rot_input * mass)
	else: 
		angular_velocity *= (1.0 - air_brake_strength * delta)

func _stabilize_in_air(delta: float):
	"""Strongly stabilize pitch and roll while preserving yaw."""
	var euler = global_transform.basis.get_euler()
	
	# Target: level pitch (0) and roll (0), keep current yaw
	var target_rotation = Vector3(0, euler.y, 0)
	var error = target_rotation - euler
	
	# Apply strong correction torque
	var stabilization_torque = global_transform.basis * error * auto_stabilization * mass
	apply_torque(stabilization_torque)
	
	# Delta-aware angular velocity damping
	var airborne_damping := 5.0 # Strength of damping
	var damping_factor := exp(-airborne_damping * delta)
	angular_velocity *= damping_factor

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

func _process_towing(_delta: float):
	if not can_tow or current_health <= 0:
		_detach_tow()
		return
	
	# Fallback for the 'T' key if the action isn't mapped in Project Settings
	var tow_triggered = Input.is_action_just_pressed("veh_tow")
	if not InputMap.has_action("veh_tow") and Input.is_physical_key_pressed(KEY_T):
		# Using physical key pressed check as a toggle-safe-switch
		if _debug_timer <= 0:
			tow_triggered = true
			_debug_timer = 0.5 # Debounce manual key press
	
	if _debug_timer > 0: _debug_timer -= _delta

	if tow_triggered:
		print("[DEBUG] Tow Button Pressed! Current Towed: ", _towed_vehicle != null)
		if is_instance_valid(_towed_vehicle):
			_detach_tow()
		else:
			_attempt_tow()
			
	# Detection Logic
	if not is_instance_valid(_towed_vehicle):
		var target = _find_tow_target()
		if target:
			if tow_prompt: tow_prompt.visible = true
		else:
			if tow_prompt: tow_prompt.visible = false
	else:
		if tow_prompt: tow_prompt.visible = false
		if global_position.distance_to(_towed_vehicle.global_position) > 12.0:
			_detach_tow()

func _find_tow_target() -> RigidBody3D:
	# Look 2.5m behind us
	var back_pos = global_position + global_transform.basis.z * 2.5
	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		if vehicle == self: continue
		if vehicle is RigidBody3D:
			var dist = back_pos.distance_to(vehicle.global_position)
			# Wider search radius (6m) to make it easier to trigger
			if dist < 6.0:
				return vehicle
	return null

func _attempt_tow():
	var target = _find_tow_target()
	print("[DEBUG] Attempting tow. Target found: ", target != null)
	if target:
		# 1. SMART ALIGNMENT
		var target_local = global_transform.affine_inverse() * target.global_position
		target_local.x = 0 
		target_local.z = 4.5 
		
		target.global_position = global_transform * target_local
		target.global_rotation.y = global_rotation.y
		
		# 2. CREATE LINK
		_towed_vehicle = target
		if "_towed_by" in target:
			target._towed_by = self
			
		_tow_joint = PinJoint3D.new()
		add_child(_tow_joint)
		
		# Set node paths AFTER adding to tree
		_tow_joint.position = Vector3(0, 0.3, 2.15)
		_tow_joint.node_a = get_path()
		_tow_joint.node_b = target.get_path()
		
		print("[SUCCESS] Towing connected to: ", target.name)

func _detach_tow():
	if is_instance_valid(_towed_vehicle) and "_towed_by" in _towed_vehicle:
		_towed_vehicle._towed_by = null
		
	if is_instance_valid(_tow_joint):
		_tow_joint.queue_free()
	_tow_joint = null
	_towed_vehicle = null
#endregion

#region --- NPC AI Logic ---
func _process_npc_ai(_delta: float) -> Vector2:
	if debug_traffic:
		var state_info = "PATHING" if is_instance_valid(_npc_path_node) else "RADAR_ONLY"
		print("--- [%s AI] State: %s | Spd: %.1f ---" % [name, state_info, linear_velocity.length() * 3.6])

	var output := Vector2.ZERO # X: Throttle/Brake, Y: Steer
	
	# 1. ADAPTIVE CRUISE (Speed & Distance)
	var current_speed_kmh = linear_velocity.length() * 3.6
	var speed_error = (npc_target_speed - current_speed_kmh) / npc_target_speed
	output.x = clamp(speed_error, -1.0, 1.0) # Maintain speed
	
	# 2. WIDER RADAR (Obstacle Avoidance - 3 Rays)
	var space_state = get_world_3d().direct_space_state
	var fwd = -global_transform.basis.z
	var ray_origin = global_position + Vector3(0, 0.5, 0)
	
	var detection_offsets = [0.0, -1.5, 1.5] # Center, Left, Right
	var min_dist = npc_detect_dist
	var obstacle_hit = false
	
	for offset_x in detection_offsets:
		var local_offset = Vector3(offset_x, 0, 0)
		var start = ray_origin + global_transform.basis * local_offset
		var end = start + fwd * npc_detect_dist
		
		var query = PhysicsRayQueryParameters3D.create(start, end)
		query.exclude = [get_rid()]
		var result = space_state.intersect_ray(query)
		
		if result:
			var dist = start.distance_to(result.position)
			if dist < min_dist:
				min_dist = dist
				obstacle_hit = true

	if obstacle_hit:
		if debug_traffic: print("    [!] OBSTACLE AT %.2fm" % min_dist)
		if min_dist < npc_brake_dist:
			output.x = -1.2 # Hard Brake/Stop
		else:
			output.x *= 0.1 # Coast/Slow down
			
	# 3. PATH FOLLOWING (Precision G-Sync)
	if is_instance_valid(_npc_path_node):
		var curve = _npc_path_node.curve
		var total_len = curve.get_baked_length()
		
		# Find current location
		var my_local_on_path = _npc_path_node.global_transform.affine_inverse() * global_position
		var current_offset = curve.get_closest_offset(my_local_on_path)
		
		# 1. Predictive Look-ahead (Anti-Snaking Scaling)
		# Research shows snaking is caused by look-ahead being too short for the speed.
		var speed_val = linear_velocity.length()
		var look_ahead = clamp(speed_val * 2.5, 18.0, 60.0)
		var target_offset = current_offset + look_ahead
		
		# Path End Logic
		var approaching_end = false
		if target_offset > total_len:
			if npc_path_is_loop:
				target_offset = fmod(target_offset, total_len)
			else:
				target_offset = total_len
				approaching_end = true
				if current_offset > total_len - 1.2:
					output.x = -1.0 # Park
					output.y = 0.0 # Straighten
					return output

		var target_pos_local = curve.sample_baked(target_offset)
		var target_pos_global = _npc_path_node.global_transform * target_pos_local
		var to_target_car = global_transform.affine_inverse() * target_pos_global
		
		# 2. Steering Logic: Pure Pursuit + Tangent Blend
		# Positive Steer = Left target
		var steer_err = atan2(-to_target_car.x, -to_target_car.z)
		
		# Tangent Alignment: Helps keep the car straight when centered
		var tangent_local = curve.sample_baked_with_rotation(current_offset, true).basis.z
		var tangent_global = (_npc_path_node.global_transform.basis * tangent_local).normalized()
		var alignment_err = (-global_transform.basis.z).cross(tangent_global).y 
		
		# Removed Centering Force as it often conflicts with Pure Pursuit lookahead 
		# and causes the 'snaking' oscillations observed.
		
		# 1. Blend: Recovery (PP) + Smoothness (Tangent)
		# Lowered gain (1.4 instead of 1.8) to prevent over-corrections (The primary fix for snaking).
		var desired_steer = (steer_err * 1.4) + (alignment_err * 0.4)
		
		# 2. Dynamic Smoothing: Slow down steering at high speeds to maintain stability
		var speed_ratio = clamp(speed_val / 20.0, 0.5, 2.0)
		var adaptive_smoothing = npc_steer_smoothing / speed_ratio
		
		_npc_steer_target = lerp(_npc_steer_target, clamp(desired_steer, -1.2, 1.2), adaptive_smoothing * _delta)
		output.y = clamp(_npc_steer_target, -1.0, 1.0)
		
		# 3. Proportional Speed Control
		var curve_severity = abs(steer_err) 
		var safe_speed = npc_target_speed
		
		# Slow down for turns proportionally to steering angle
		if curve_severity > 0.08:
			safe_speed *= clamp(1.0 - (curve_severity * 0.75), 0.35, 1.0)
			
		var path_speed_error = safe_speed - current_speed_kmh
		
		# Gentle arrival OR Main driving
		if approaching_end:
			output.x = clamp(path_speed_error * 0.2, -1.0, 0.4)
		else:
			# Proportional Throttle/Brake (0.1 gain for smooth acceleration)
			output.x = clamp(path_speed_error * 0.1, -0.8, 1.0)
			
		if debug_traffic:
			var dist_off_track = to_target_car.x
			print("    [AI] Dist:%.1f | Off:%.1f | PP:%.2f | SafeV:%.1f | Thr:%.2f" % [current_offset, dist_off_track, steer_err, safe_speed, output.x])
	
	
	
	
	# 4. LANE KEEPING (Failsafe for empty paths)
	else:
		var side_left = global_transform.basis.x
		var left_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + side_left * npc_lane_width)
		left_query.exclude = [get_rid()]
		var left_hit = space_state.intersect_ray(left_query)
		
		var right_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin - side_left * npc_lane_width)
		right_query.exclude = [get_rid()]
		var right_hit = space_state.intersect_ray(right_query)
		
		if left_hit and not right_hit:
			output.y = -0.3 
		elif right_hit and not left_hit:
			output.y = 0.3 
		
	return output
#endregion
