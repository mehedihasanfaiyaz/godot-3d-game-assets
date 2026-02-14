@tool
extends Area3D

enum ModifierType { BOOST, REPELL, SLOW, DAMAGE }

@export var type: ModifierType = ModifierType.BOOST:
	set(val):
		type = val
		_update_visuals()

@export var strength := 150.0 # Extreme strength for testing
@export var damage_per_second := 20.0
@export var slow_factor := 0.4
@export var zone_color := Color(1,1,1,1)

var _timer := 0.0

func _ready():
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	_update_visuals()

func _update_visuals():
	var color = Color.WHITE
	match type:
		ModifierType.BOOST: color = Color(0.2, 1.0, 0.3, 0.6) # Neon Green
		ModifierType.REPELL: color = Color(0.2, 0.6, 1.0, 0.6) # Light Blue
		ModifierType.SLOW: color = Color(0.6, 0.4, 0.2, 0.6) # Mud Brown
		ModifierType.DAMAGE: color = Color(1.0, 0.2, 0.1, 0.6) # Danger Red
	
	zone_color = color
	
	if has_node("Indicator"):
		var mesh: MeshInstance3D = get_node("Indicator")
		# Force a unique material for this instance so they don't all change together
		var mat = mesh.get_active_material(0)
		if mat:
			var new_mat = mat.duplicate()
			new_mat.albedo_color = color
			mesh.set_surface_override_material(0, new_mat)
			
	if has_node("Effects"):
		var parts: GPUParticles3D = get_node("Effects")
		# 1. Duplicate process material for unique emission
		if parts.process_material is ParticleProcessMaterial:
			parts.process_material = parts.process_material.duplicate()
			parts.process_material.color = Color(color.r, color.g, color.b, 1.0)
		
		# 2. IMPORTANT: Duplicate the MESH and the MATERIAL
		# This ensures that changing the color of one pad doesn't change them all!
		if parts.draw_pass_1:
			parts.draw_pass_1 = parts.draw_pass_1.duplicate()
			var mesh_mat = parts.draw_pass_1.material
			if mesh_mat:
				var new_mesh_mat = mesh_mat.duplicate()
				new_mesh_mat.albedo_color = Color(color.r, color.g, color.b, 1.0)
				parts.draw_pass_1.material = new_mesh_mat

func _physics_process(delta):
	if Engine.is_editor_hint(): return
	
	for body in get_overlapping_bodies():
		if body is RigidBody3D or body.has_method("set_speed_modifier"):
			_apply_continuous_effect(body, delta)

func _on_body_entered(body: Node3D):
	if Engine.is_editor_hint(): return
	print("[DEBUG] Zone %s: Body ENTERED: %s (Type: %s)" % [name, body.name, body.get_class()])
	if body is RigidBody3D:
		_apply_instant_effect(body)

func _on_body_exited(body: Node3D):
	if Engine.is_editor_hint(): return
	print("[DEBUG] Zone %s: Body EXITED: %s" % [name, body.name])
	if body.has_method("set_speed_modifier"):
		body.call("set_speed_modifier", 1.0)

func _apply_instant_effect(body: Node3D):
	if body is RigidBody3D:
		body.sleeping = false # Force wake up
		match type:
			ModifierType.BOOST:
				body.apply_central_impulse(-body.global_transform.basis.z * strength * body.mass * 0.8)
			ModifierType.REPELL:
				var dir = (body.global_position - global_position).normalized()
				dir.y = 0.5 
				body.apply_central_impulse(dir.normalized() * strength * body.mass * 1.0)

func _apply_continuous_effect(body: Node3D, delta: float):
	if body is RigidBody3D:
		body.sleeping = false
		
	match type:
		ModifierType.SLOW:
			if body.has_method("set_speed_modifier"):
				body.call("set_speed_modifier", slow_factor)
			elif "linear_velocity" in body:
				body.linear_velocity *= (1.0 - (1.0 - slow_factor) * delta * 10.0)
				
		ModifierType.DAMAGE:
			if "current_health" in body:
				body.current_health -= damage_per_second * delta
				if body.has_method("_update_hud"):
					body.call("_update_hud")
