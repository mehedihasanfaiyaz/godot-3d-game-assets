extends "res://raycast_car.gd"

# --- Flying Mode Settings ---
@export_group("Flying Mode")
@export var can_fly: bool = true
@export var takeoff_speed: float = 15.0
@export var landing_speed: float = 8.0

@export_subgroup("Flight Forces")
@export var engine_thrust: float = 120000.0
@export var max_lift: float = 3000.0
@export var aoa_effect: float = 50.0  # Angle of attack strength
@export var drag_coeff: float = 0.04

@export_subgroup("Flight Rotation")
@export var pitch_torque: float = 3.5
@export var yaw_torque: float = 2.5
@export var roll_stability: float = 0.8
@export var angular_damping: float = 0.94

@export_group("Wing Nodes")
@export var left_wing: Node3D
@export var right_wing: Node3D

# --- Internal State ---
var is_flying: bool = false
var wings_deployed: bool = false
var target_wing_rotation: float = 0.0
var wing_rotation: float = 0.0

const WING_OPEN_ANGLE: float = 90.0

func _ready() -> void:
	super._ready()
	print("✈ Flight controller initialized. Press 'veh_fly' to deploy wings.")

func _physics_process(delta: float) -> void:
	var speed: float = linear_velocity.length()

	# Toggle Wings
	if Input.is_action_just_pressed("veh_fly") and can_fly:
		_toggle_wings()

	_animate_wings(delta)

	# Auto takeoff
	if wings_deployed and not is_flying and speed >= takeoff_speed:
		_start_flight()

	# Flight vs Ground processing
	if is_flying:
		_handle_flight(delta)
		_update_lights(0, 0, 0, delta)
		_update_damage_particles()
		_process_camera_smoothness(delta)

		if speed < landing_speed and grounded_wheels >= 2:
			_land()
	else:
		super._physics_process(delta)

# --- Wing Toggle ---
func _toggle_wings() -> void:
	wings_deployed = not wings_deployed
	if wings_deployed:
		print("🪽 Wings deployed!")
		target_wing_rotation = 1.0
	else:
		print("🪽 Wings retracted!")
		target_wing_rotation = 0.0

func _animate_wings(delta: float) -> void:
	wing_rotation = lerp(wing_rotation, target_wing_rotation, 3.0 * delta)
	if left_wing:
		left_wing.rotation.z = deg_to_rad(WING_OPEN_ANGLE * wing_rotation)
	if right_wing:
		right_wing.rotation.z = deg_to_rad(-WING_OPEN_ANGLE * wing_rotation)

# --- Takeoff / Landing ---
func _start_flight() -> void:
	print("🛫 Taking off!")
	is_flying = true
	gravity_scale = 1.0
	angular_velocity = Vector3.ZERO

func _land() -> void:
	print("🛬 Landing")
	is_flying = false
	wings_deployed = false
	target_wing_rotation = 0.0
	gravity_scale = 2.0

# --- Flight Physics ---
func _handle_flight(delta: float) -> void:
	if current_health <= 0:
		return

	# --- INPUTS ---
	var throttle: float = Input.get_action_strength("veh_accelerate")
	var pitch_input: float = Input.get_action_strength("fly_up") - Input.get_action_strength("fly_down")
	var yaw_input: float = Input.get_action_strength("fly_right") - Input.get_action_strength("fly_left")
	var boost: bool = Input.is_action_pressed("veh_boost") and current_boost_fuel > 0

	# Disable car controls in air
	var brake: float = 0.0
	var roll_left: float = 0.0
	var roll_right: float = 0.0

	_update_resources(throttle, 0, boost, delta)
	if current_fuel <= 0:
		throttle = 0.0
		boost = false

	# --- LOCAL AXES ---
	var forward: Vector3 = -global_basis.z
	var up: Vector3 = global_basis.y
	var right: Vector3 = global_basis.x
	var speed: float = linear_velocity.length()

	# --- ENGINE THRUST ---
	var thrust_force: float = engine_thrust * (2.0 if boost else 1.0)
	apply_central_force(forward * throttle * thrust_force)

	# --- AERODYNAMIC LIFT ---
	if wing_rotation > 0.1:
		var vel_dir: Vector3 = linear_velocity.normalized() if speed > 0.1 else forward
		var aoa: float = clamp(forward.dot(vel_dir), -1.0, 1.0)
		var lift_strength: float = max_lift * (aoa + 1.0) * wing_rotation
		apply_central_force(up * lift_strength)

	# --- DRAG ---
	apply_central_force(-linear_velocity * speed * drag_coeff)

	# --- TORQUE BASED ROTATION ---
	var torque: Vector3 = Vector3.ZERO

	# Pitch
	if abs(pitch_input) > 0.01:
		torque.x += -pitch_input * pitch_torque

	# Yaw
	if abs(yaw_input) > 0.01:
		torque.y += yaw_input * yaw_torque

	# Roll stabilization
	var roll_error: float = global_basis.get_euler().z
	torque.z += -roll_error * roll_stability * mass

	apply_torque(torque * mass)

	# Angular damping
	angular_velocity *= angular_damping

	# Gravity
	apply_central_force(Vector3.DOWN * mass * gravity_scale)

	# Speed limit
	if speed > 100.0:
		linear_velocity = linear_velocity.normalized() * 100.0

	# Camera switch
	if Input.is_action_just_pressed("veh_cam"):
		switch_camera()
