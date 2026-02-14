extends Node3D

const BuildBlueprint = preload("res://building/blueprint.gd")
const GHOST_SHADER = preload("res://building/building_ghost.gdshader")

@export var territory_scene: PackedScene = load("res://building/territory.tscn")

# Member Variables
var is_active: bool = false
var player_ref: CharacterBody3D = null
var current_blueprint: BuildBlueprint = null
var grid_size: float = 4.0 
var manual_rotation_offset: float = 0.0
var can_place: bool = true
var is_menu_open: bool = false

var last_snapped_socket: Marker3D = null
var hovered_structure: Node3D = null
var hovered_original_materials: Dictionary = {}

var smoothed_pos: Vector3 = Vector3.ZERO
var smoothed_rot: float = 0.0
var last_logged_grid_pos: Vector3 = Vector3.ZERO
var last_raw_hit_pos: Vector3 = Vector3.ZERO

# Prediction & Ghost State
var last_calculated_snap_pos: Vector3 = Vector3.ZERO
var last_calculated_final_pos: Vector3 = Vector3.ZERO
var last_socket_id: int = 0
var aim_marker: MeshInstance3D = null
var ghost_target_color: Color = Color(0, 0.6, 1, 0.4)
var ghost_current_color: Color = Color(0, 0.6, 1, 0.4)
var ghost_pulse_timer: float = 0.0
var ghost_spawn_scale: float = 0.0
var hit_pos_history: Array[Vector3] = []
var smoothing_frames: int = 3
var current_target_collider: Node3D = null

# Debug State
var debug_ui: CanvasLayer = null
var debug_label: Label = null

const LAYER_WORLD = 1
const LAYER_ITEMS = 2
const LAYER_STRUCTURES = 4 
const LAYER_GHOST = 512 # Layer 10
const MASK_PLACEMENT = 5 # Layer 1 + Layer 4
const MASK_INSPECTION = 4

# STATIC GHOST TRACKING
static var global_ghost: Node3D = null

# --- HELPERS ---
func _perform_raycast(origin: Vector3, end: Vector3, mask: int, exclude: Array = []):
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = mask
	query.collide_with_areas = false
	
	# TOTAL EXCLUSION: Gather RIDs into a Dictionary to avoid duplicates
	var unique_rids = {} 
	for item in exclude:
		if is_instance_valid(item) and item is CollisionObject3D: unique_rids[item.get_rid()] = true
		
	# Clear every part of every active ghost from physics visibility
	for ghost in get_tree().get_nodes_in_group("building_ghost_active"):
		_gather_unique_rids_recursive(ghost, unique_rids)
		
	if is_instance_valid(global_ghost):
		_gather_unique_rids_recursive(global_ghost, unique_rids)
		
	query.exclude = unique_rids.keys()
	return get_world_3d().direct_space_state.intersect_ray(query)

func _gather_unique_rids_recursive(node: Node, dict: Dictionary):
	if node is CollisionObject3D:
		dict[node.get_rid()] = true
	elif node.has_method("get_rid") and node is CollisionShape3D:
		# Some shapes might have RIDs or debug bodies
		pass
	for child in node.get_children():
		_gather_unique_rids_recursive(child, dict)

func _get_snapped_pos(hit_pos: Vector3, snap: float) -> Vector3:
	if snap < 0.6: # Fine-grained grid (0.25m / 0.5m)
		var gx = round(hit_pos.x / snap) * snap
		var gz = round(hit_pos.z / snap) * snap
		var gy = round(hit_pos.y / 0.5) * 0.5
		return Vector3(gx, gy, gz)
		
	# Standard Cell Snapping (4m/2m)
	var half = snap / 2.0
	var gx = round((hit_pos.x - half) / snap) * snap + half
	var gz = round((hit_pos.z - half) / snap) * snap + half
	var gy = round(hit_pos.y / 0.5) * 0.5
	return Vector3(gx, gy, gz)

func _is_wall(blueprint: BuildBlueprint = null, node: Node3D = null) -> bool:
	if blueprint:
		return blueprint.sub_category in ["Walls", "Doors/Windows"]
	if node:
		var n = node.name.to_lower()
		return n.contains("wall") or n.contains("door") or n.contains("window") or n.contains("frame")
	return false

func _get_snap_size(blueprint: BuildBlueprint = null, node: Node3D = null) -> float:
	if blueprint: return blueprint.snap_size
	if node and node.has_meta("snap_size"): return node.get_meta("snap_size")
	if node and node.name.to_lower().contains("small"): return 2.0
	return 4.0

func _ready():
	# SINGLETON PROTECTION
	var systems = get_tree().get_nodes_in_group("building_system_core")
	for s in systems:
		if is_instance_valid(s) and s != self:
			s.queue_free()
	add_to_group("building_system_core")
	
	if is_instance_valid(global_ghost):
		global_ghost.queue_free()
		global_ghost = null
	
	_setup_aim_marker()
	_setup_debug_ui()

func _setup_debug_ui():
	debug_ui = CanvasLayer.new()
	add_child(debug_ui)
	
	debug_label = Label.new()
	debug_label.position = Vector2(20, 20)
	debug_label.add_theme_color_override("font_color", Color.CYAN)
	debug_label.add_theme_font_size_override("font_size", 14)
	debug_ui.add_child(debug_label)
	debug_ui.visible = false

func _setup_aim_marker():
	aim_marker = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	aim_marker.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0, 0.8, 1, 0.8)
	mat.no_depth_test = true
	aim_marker.material_override = mat
	add_child(aim_marker)
	aim_marker.visible = false

func select_blueprint(blueprint: BuildBlueprint):
	if not is_active: return
	current_blueprint = blueprint
	last_snapped_socket = null 
	ghost_spawn_scale = 0.0
	last_calculated_snap_pos = Vector3.ZERO # RESET SNAP POSITION
	if blueprint:
		_update_territory_visuals()
		if blueprint.scene:
			_spawn_ghost(blueprint.scene)

func _update_territory_visuals():
	var territories = get_tree().get_nodes_in_group("territory")
	for t in territories:
		if is_instance_valid(t) and t.area_indicator:
			var mat = t.area_indicator.mesh.material
			if mat is ShaderMaterial:
				mat.set_shader_parameter("grid_size", grid_size)

func _process(delta):
	if not is_active: return
	var is_initial_setup = is_instance_valid(player_ref) and not player_ref.has_territory
	if current_blueprint or is_initial_setup:
		_update_ghost_juice(delta)
		# Position update is handled in _physics_process for raycast accuracy
		if is_instance_valid(global_ghost) and smoothed_pos != Vector3.ZERO:
			global_ghost.global_position = smoothed_pos
			global_ghost.global_rotation.y = smoothed_rot
	else:
		_process_inspection_mode(delta)

func _physics_process(_delta):
	if not is_active: return
	var is_initial_setup = is_instance_valid(player_ref) and not player_ref.has_territory
	if current_blueprint or is_initial_setup:
		_update_ghost_position(is_initial_setup)

func _process_inspection_mode(delta: float):
	if is_instance_valid(aim_marker): aim_marker.visible = false
	if is_instance_valid(debug_ui): debug_ui.visible = false
	if is_instance_valid(global_ghost):
		global_ghost.visible = false
	_update_structure_highlighter()
	
	if is_instance_valid(hovered_structure):
		ghost_pulse_timer += delta * 4.0
		var pulse = 1.0 + (sin(ghost_pulse_timer) * 0.5)
		_set_highlight_pulse_energy(hovered_structure, pulse * 3.0)

func _set_highlight_pulse_energy(node: Node, energy: float):
	if node is MeshInstance3D:
		if is_instance_valid(node.material_overlay) and node.material_overlay is StandardMaterial3D:
			node.material_overlay.emission_energy_multiplier = energy
	for child in node.get_children():
		_set_highlight_pulse_energy(child, energy)

func activate(player):
	_clear_all_ghosts_internal()
	player_ref = player
	is_active = true
	last_snapped_socket = null
	ghost_spawn_scale = 0.0
	last_calculated_snap_pos = Vector3.ZERO
	last_calculated_final_pos = Vector3.ZERO
	
	if not player.has_territory and territory_scene:
		current_blueprint = null
		_spawn_ghost(territory_scene)
	else:
		current_blueprint = null

func _clear_all_ghosts_internal():
	if is_instance_valid(global_ghost):
		global_ghost.queue_free()
	global_ghost = null
	
	var ghosts = get_tree().get_nodes_in_group("building_ghost_active")
	for g in ghosts:
		if is_instance_valid(g):
			g.queue_free()

func deactivate():
	is_active = false
	_clear_all_ghosts()
	_clear_hover()
	if is_instance_valid(aim_marker): aim_marker.visible = false
	if is_instance_valid(debug_ui): debug_ui.visible = false

func _clear_hover():
	if is_instance_valid(hovered_structure):
		_set_structure_highlight(hovered_structure, false)
	hovered_structure = null
	hovered_original_materials.clear()

func _update_structure_highlighter():
	if is_menu_open: return
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = viewport_size / 2
	var origin = camera.project_ray_origin(mouse_pos)
	var end = origin + camera.project_ray_normal(mouse_pos) * 12.0 # Good reach
	
	# Hit both world and structures, filter manually for the group
	var result = _perform_raycast(origin, end, LAYER_WORLD | LAYER_STRUCTURES, [player_ref])
	var new_hover = null
	
	if result:
		var node = result.collider
		# Walk up hierarchy to find the root with the "structure" group
		var temp = node
		while temp:
			if temp.is_in_group("structure"):
				new_hover = temp
				break
			temp = temp.get_parent()
	
	if new_hover != hovered_structure:
		if is_instance_valid(hovered_structure):
			_set_structure_highlight(hovered_structure, false)
		hovered_structure = new_hover
		if is_instance_valid(hovered_structure):
			_set_structure_highlight(hovered_structure, true)

func _set_structure_highlight(node: Node, enabled: bool):
	if not node: return
	if node is VisualInstance3D:
		if enabled:
			var mat = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1, 0.5, 0, 0.25)
			mat.emission_enabled = true
			mat.emission = Color(1, 0.4, 0)
			mat.emission_energy_multiplier = 4.0
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			node.material_overlay = mat
		else:
			node.material_overlay = null
			node.material_overlay = null
	for child in node.get_children():
		_set_structure_highlight(child, enabled)

func _clear_all_ghosts():
	_clear_all_ghosts_internal()

func _spawn_ghost(scene: PackedScene):
	if not scene: return
	_clear_all_ghosts()
	var new_ghost = scene.instantiate()
	if not new_ghost: return
	
	new_ghost.add_to_group("building_ghost_active")
	_apply_ghost_settings(new_ghost)
	new_ghost.visible = true # Start visible, _update will hide if needed
	new_ghost.scale = Vector3(0.001, 0.001, 0.001)
	add_child(new_ghost)
	global_ghost = new_ghost
	smoothed_pos = Vector3.ZERO 
	manual_rotation_offset = 0.0

func _apply_ghost_settings(node: Node):
	if node is CollisionObject3D:
		node.collision_layer = LAYER_GHOST # Put on Layer 10
		node.collision_mask = 0
		if node is Area3D:
			node.monitoring = false
			node.monitorable = false
		node.input_ray_pickable = false
	if node is CollisionShape3D:
		node.disabled = true
	if node is CSGPrimitive3D or node is CSGCombiner3D:
		node.use_collision = false
	if node is VisualInstance3D:
		# Apply ghost material to everything including AreaIndicators
		var ghost_mat = ShaderMaterial.new()
		ghost_mat.shader = GHOST_SHADER
		ghost_mat.set_shader_parameter("base_color", ghost_current_color)
		node.material_override = ghost_mat
		if node.name == "AreaIndicator" and node is MeshInstance3D:
			node.transparency = 0.5 # Extra transparency for the big territory box
	for child in node.get_children():
		_apply_ghost_settings(child)

func _update_ghost_color(valid: bool):
	# Using high-vibrancy colors for the hollow shader look
	ghost_target_color = Color(0.0, 0.8, 1.0, 0.5) if valid else Color(1.0, 0.1, 0.1, 0.5)

func _set_node_color(node: Node, color: Color):
	if not node: return
	if node is VisualInstance3D:
		if node.name != "AreaIndicator":
			if is_instance_valid(node.material_override) and node.material_override is ShaderMaterial:
				node.material_override.set_shader_parameter("base_color", color)
	for child in node.get_children():
		_set_node_color(child, color)

func _update_ghost_juice(delta: float):
	if not is_instance_valid(global_ghost): return
	ghost_spawn_scale = lerp(ghost_spawn_scale, 1.0, delta * 10.0)
	global_ghost.scale = Vector3.ONE * ghost_spawn_scale
	ghost_current_color = ghost_current_color.lerp(ghost_target_color, delta * 8.0)
	_set_node_color(global_ghost, ghost_current_color)

func _is_spot_occupied(p: Vector3, blueprint: BuildBlueprint = null, rot: float = 0.0) -> bool:
	var snap = _get_snap_size(blueprint)
	var is_edge = _is_wall(blueprint)
	for item in get_tree().get_nodes_in_group("structure"):
		if not is_instance_valid(item) or item.is_in_group("territory"): continue
		var dist = item.global_position.distance_to(p)
		var item_is_edge = _is_wall(null, item)
		if is_edge:
			if item_is_edge and dist < 0.2:
				var rot_diff = abs(item.global_rotation.y - rot)
				while rot_diff > PI: rot_diff -= PI * 2.0
				if abs(rot_diff) < 0.1 or abs(abs(rot_diff) - PI) < 0.1: return true
		else:
			if not item_is_edge and abs(p.y - item.global_position.y) < 0.6:
				var dx = abs(p.x - item.global_position.x)
				var dz = abs(p.z - item.global_position.z)
				var limit = (snap + _get_snap_size(null, item)) / 2.0 - 0.5
				if dx < limit and dz < limit:
					# COMPLEMENTARY SHAPE LOGIC (Once Human Style)
					# Allow Curve and Inward-Curve to coexist in the same spot
					var n1 = blueprint.name.to_lower() if blueprint else ""
					var n2 = item.name.to_lower()
					var is_curve1 = "curve" in n1 and not "inward" in n1
					var is_inward1 = "inward" in n1
					var is_curve2 = "curve" in n2 and not "inward" in n2
					var is_inward2 = "inward" in n2
					
					if (is_curve1 and is_inward2) or (is_inward1 and is_curve2):
						continue # They fit together!
						
					return true
	return false

func _check_structural_support(pos: Vector3, blueprint: BuildBlueprint) -> bool:
	if not blueprint: return true
	var sub = blueprint.sub_category.to_lower()
	
	# Foundation check (Robust Multi-Point)
	if "foundation" in sub:
		var check_points = [pos] # Always check center
		var snap = blueprint.snap_size / 2.0
		# Also check 4 corners relative to rotation if it's a large foundation
		if snap > 0.6:
			check_points.append(pos + Vector3(snap, 0.1, snap))
			check_points.append(pos + Vector3(-snap, 0.1, snap))
			check_points.append(pos + Vector3(snap, 0.1, -snap))
			check_points.append(pos + Vector3(-snap, 0.1, -snap))
			
		for p in check_points:
			# Check for overlapping structures (Occupancy)
			var s_hit = _perform_raycast(p + Vector3(0, 1.5, 0), p + Vector3(0, 0.6, 0), LAYER_STRUCTURES)
			if not s_hit.is_empty() and not s_hit.collider.name.to_lower().contains("territory"): return false 
			
			# Check for ground or snap support (Support)
			var hit = _perform_raycast(p + Vector3(0, 0.5, 0), p + Vector3(0, -1.2, 0), LAYER_WORLD | LAYER_STRUCTURES)
			if not hit.is_empty(): return true 
		return false
	if sub == "Walls" or sub == "Doors/Windows":
		for item in get_tree().get_nodes_in_group("structure"):
			var d_v = pos.y - item.global_position.y
			var d_xz = Vector2(pos.x, pos.z).distance_to(Vector2(item.global_position.x, item.global_position.z))
			if d_v >= 0.2 and d_v <= 4.0 and d_xz < 2.5: return true
		return false
	if sub == "Floor/Roof":
		var h_ground = _perform_raycast(pos + Vector3(0, 0.5, 0), pos + Vector3(0, -0.3, 0), LAYER_WORLD)
		if not h_ground.is_empty(): return false 
		for item in get_tree().get_nodes_in_group("structure"):
			var dist_xz = Vector2(pos.x, pos.z).distance_to(Vector2(item.global_position.x, item.global_position.z))
			var dist_y = pos.y - item.global_position.y
			if dist_xz < 4.5 and dist_y > 0.1 and dist_y < 4.5: return true 
		return false
	return true

func _is_colliding_with_world(pos: Vector3, ghost: Node3D) -> bool:
	var space_state = player_ref.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.4
	query.shape = sphere
	query.transform = Transform3D(Basis(), pos + Vector3(0, 1, 0))
	query.collision_mask = LAYER_WORLD
	var results = space_state.intersect_shape(query)
	return results.size() > 0

func _update_ghost_position(is_initial_setup: bool = false):
	if not is_instance_valid(player_ref) or not is_instance_valid(global_ghost): return
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var mouse_pos = get_viewport().get_visible_rect().size / 2
	var origin = camera.project_ray_origin(mouse_pos)
	var end = origin + camera.project_ray_normal(mouse_pos) * 15.0 
	
	# State for this frame
	var territories = get_tree().get_nodes_in_group("territory")
	var is_within_any = false
	var delta = get_process_delta_time()
	
	var result = _perform_raycast(origin, end, MASK_PLACEMENT)
	if result:
		var raw_hit = result.position
		current_target_collider = result.collider
		
		# 0. LOW-PASS FILTER (Input Smoothing)
		hit_pos_history.append(raw_hit)
		if hit_pos_history.size() > smoothing_frames: hit_pos_history.remove_at(0)
		
		var hit_pos = Vector3.ZERO
		for p in hit_pos_history: hit_pos += p
		hit_pos /= hit_pos_history.size()

		# Snap hit_pos to slightly filter jitter
		hit_pos = Vector3(round(hit_pos.x * 20)/20.0, hit_pos.y, round(hit_pos.z * 20)/20.0)
		
		if is_instance_valid(aim_marker): 
			aim_marker.visible = true
			aim_marker.global_position = hit_pos
		
		# Snapping Config
		var snap = _get_snap_size(current_blueprint)
		if is_initial_setup and not current_blueprint: snap = 0.25
		var effective_snap = snap
		if not is_within_any and not (is_initial_setup and not current_blueprint):
			effective_snap = 1.0 
			
		var target_grid = _get_snapped_pos(hit_pos, effective_snap)
		
		# Wall logic
		var cam_fwd = -camera.global_transform.basis.z
		cam_fwd.y = 0
		if cam_fwd.length() < 0.2: cam_fwd = -camera.global_transform.basis.y; cam_fwd.y = 0
		var target_rotation = round(atan2(cam_fwd.x, cam_fwd.z) / (PI/2)) * (PI/2) + manual_rotation_offset
		if _is_wall(current_blueprint):
			var ang_deg = round(rad_to_deg(target_rotation))
			if int(abs(ang_deg) + 0.5) % 180 == 0: target_grid.z = round(hit_pos.z / effective_snap) * effective_snap
			else: target_grid.x = round(hit_pos.x / effective_snap) * effective_snap
		
		# 2. SEAMLESS SOCKET CHECK (Collider-Locked)
		var is_socketed = false
		var type_to_find = ""
		if current_blueprint:
			match current_blueprint.sub_category:
				"Foundation": type_to_find = "foundation"
				"Walls": type_to_find = "wall"
				"Doors/Windows": type_to_find = "wall" if "frame" in current_blueprint.name.to_lower() else "door"
				"Floor/Roof": type_to_find = "roof"
		
		var candidate_pos = target_grid
		var candidate_rot = target_rotation
		
		# Territory logic (Check calculated candidate position, not just where mouse is)
		for t in territories:
			if t.is_within_territory(candidate_pos): is_within_any = true; break
		
		if type_to_find != "" and is_instance_valid(current_target_collider):
			# ONLY check the foundation/wall we are looking at!
			var socket = _get_best_socket_on_target(hit_pos, type_to_find, current_target_collider)
			if socket:
				candidate_pos = socket.global_position
				candidate_rot = socket.global_rotation.y
				is_socketed = true

		# 3. IRON-GRIP HYSTERESIS
		if last_calculated_final_pos == Vector3.ZERO:
			last_calculated_final_pos = candidate_pos
		elif candidate_pos != last_calculated_final_pos:
			var grip = effective_snap * 0.4
			if last_socket_id != 0: grip = 1.8 # Extreme grip for sockets
			if hit_pos.distance_to(last_calculated_final_pos) > grip:
				last_calculated_final_pos = candidate_pos
				last_socket_id = 1 if is_socketed else 0
				
		var final_pos = last_calculated_final_pos
		target_rotation = candidate_rot
		# 4. SMOOTH INTERPOLATION
		# This makes the ghost transition between snaps smoothly rather than popping
		if smoothed_pos == Vector3.ZERO: 
			smoothed_pos = final_pos
			smoothed_rot = target_rotation
		
		# High-response lerp (30.0) for a "premium" feel
		smoothed_pos = smoothed_pos.lerp(final_pos, delta * 30.0)
		smoothed_rot = lerp_angle(smoothed_rot, target_rotation, delta * 30.0)
		
		var is_occ = _is_spot_occupied(final_pos, current_blueprint, target_rotation)
		var has_sup = _check_structural_support(final_pos, current_blueprint)
		var world_col = _is_colliding_with_world(final_pos, global_ghost)
		
		# FINAL CAN_PLACE CALCULATION
		var last_can_place = can_place
		var snap_required = true
		if current_blueprint and current_blueprint.sub_category == "Foundation": snap_required = false
		if is_initial_setup: snap_required = false # Initial flag is always free
		
		# Pro Logic: If it's a wall/roof, it MUST be socketed
		var socket_valid = true
		if snap_required and not is_socketed: socket_valid = false
		
		can_place = (not is_occ) and has_sup and (not world_col) and (is_within_any or is_initial_setup) and socket_valid
		
		# REAL-TIME CONSOLE: Pulse on coordinate change
		if final_pos != last_logged_grid_pos or can_place != last_can_place:
			last_logged_grid_pos = final_pos
			var status = "READY" if can_place else "BLOCKED"
			# Round for clean console display
			var display_pos = Vector3(round(final_pos.x * 100)/100, round(final_pos.y * 100)/100, round(final_pos.z * 100)/100)
			print("--- BUILD GHOST: %s [%s] ---" % [str(display_pos), status])
			if can_place != last_can_place:
				print("REASONS: [Occ: %s] [Sup: %s] [Col: %s] [Terr: %s]" % [is_occ, has_sup, world_col, is_within_any])
		
		if is_instance_valid(debug_label):
			debug_label.text = "--- STRUCTURE GHOST DEBUG ---\n"
			debug_label.text += "Ghost Pos: %s\n" % str(final_pos).substr(0, 24)
			debug_label.text += "Snap Size: %.2fm\n" % effective_snap
			debug_label.text += "IS OCCUPIED: %s\n" % ("YES" if is_occ else "NO")
			debug_label.text += "HAS SUPPORT: %s\n" % ("YES" if has_sup else "NO")
			debug_label.text += "IN TERRITORY: %s\n" % ("YES" if is_within_any else "NO")
			debug_label.text += "----------------------------\n"
			debug_label.text += "FINAL STATUS: %s" % ("READY" if can_place else "BLOCKED")
			debug_label.add_theme_color_override("font_color", Color.GREEN if can_place else Color.RED)

		_update_ghost_color(can_place)
		global_ghost.global_position = smoothed_pos
		global_ghost.global_rotation.y = smoothed_rot
		global_ghost.visible = true
	else:
		if is_instance_valid(global_ghost): global_ghost.visible = false
		if is_instance_valid(aim_marker): aim_marker.visible = false
		if is_instance_valid(debug_ui): debug_ui.visible = false

func _get_best_socket_on_target(at_pos: Vector3, type: String, target: Node3D) -> Marker3D:
	if not is_instance_valid(target): return null
	# Get top level structure from collision
	var structure = target
	while structure and not structure.is_in_group("structure"):
		structure = structure.get_parent()
	
	if not is_instance_valid(structure): return null
	
	var closest = null
	var min_dist = 3.0 # Strict search radius on target
	# Only search grandchildren of the structure (where sockets live)
	for child in structure.get_children():
		if child.name == "Sockets":
			for s in child.get_children():
				if s is Marker3D and s.has_meta("type") and s.get_meta("type") == type:
					var d = s.global_position.distance_to(at_pos)
					if d < min_dist: min_dist = d; closest = s
	return closest

func handle_input(event: InputEvent):
	if not is_active: return
	var is_initial_setup = is_instance_valid(player_ref) and not player_ref.has_territory
	if current_blueprint or is_initial_setup:
		if event.is_action_pressed("build_rotate"): manual_rotation_offset += PI/2.0
		if event.is_action_pressed("player_interact") or event.is_action_pressed("build_place"): _place_object()
		if event.is_action_pressed("build_menu") and not is_initial_setup: 
			select_blueprint(null)
	else:
		if is_instance_valid(hovered_structure):
			if event.is_action_pressed("build_destroy"): _destroy_structure(hovered_structure)
			elif event.is_action_pressed("build_relocate"): _relocate_structure(hovered_structure)
			elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
				_eyedropper_structure(hovered_structure)

func _eyedropper_structure(node: Node3D):
	if node.has_meta("blueprint_path"):
		var bp = load(node.get_meta("blueprint_path"))
		if bp is BuildBlueprint:
			select_blueprint(bp)
			_clear_hover()

func _destroy_structure(node: Node3D):
	if not is_instance_valid(node): return
	
	# Immediately remove from interaction groups so it can't be hovered or blocked
	if node.is_in_group("structure"): node.remove_from_group("structure")
	
	# JUICE 1: Spawn Physical Debris
	_spawn_debris(node.global_position)
	
	# JUICE 2: Scale down before deleting
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	tween.tween_callback(node.queue_free)
	_clear_hover()

func _spawn_debris(pos: Vector3):
	# Create a few simple physics fragments
	for i in range(6):
		var debris = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.2, 0.2, 0.2)
		debris.mesh = box
		
		# Holographic look for debris
		var mat = ShaderMaterial.new()
		mat.shader = GHOST_SHADER
		mat.set_shader_parameter("base_color", Color(1, 0.5, 0, 0.8)) # Orange energy debris
		debris.material_override = mat
		
		var body = RigidBody3D.new()
		body.collision_layer = 0 # No collision with anything
		body.collision_mask = 1 # Only collide with world
		
		var shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = box.size
		shape.shape = box_shape
		
		body.add_child(shape)
		body.add_child(debris)
		get_tree().root.add_child(body)
		
		body.global_position = pos + Vector3(randf()-0.5, 0.5, randf()-0.5)
		body.apply_central_impulse(Vector3(randf()-0.5, 1.0, randf()-0.5) * 5.0)
		body.apply_torque_impulse(Vector3(randf(), randf(), randf()) * 2.0)
		
		# Auto-cleanup debris
		var t = create_tween()
		t.tween_interval(1.2)
		t.tween_property(debris, "scale", Vector3.ZERO, 0.3)
		t.tween_callback(body.queue_free)

func _relocate_structure(node: Node3D):
	if node.has_meta("blueprint_path"):
		var bp = load(node.get_meta("blueprint_path"))
		if bp is BuildBlueprint:
			select_blueprint(bp)
			node.queue_free()
			_clear_hover()

func _place_object():
	if not is_active or not is_instance_valid(global_ghost) or not can_place: return
	var new_obj = null
	var should_exit_mode = false
	if not player_ref.has_territory:
		new_obj = territory_scene.instantiate()
		new_obj.name = "TerritoryFlag"
		new_obj.add_to_group("territory")
		player_ref.has_territory = true
		should_exit_mode = true
	elif current_blueprint and current_blueprint.scene:
		new_obj = current_blueprint.scene.instantiate()
	
	if new_obj:
		get_tree().root.add_child(new_obj)
		new_obj.add_to_group("structure")
		
		# RECURSIVELY setup physics for interaction
		_setup_placed_physics(new_obj)
		
		new_obj.global_transform = global_ghost.global_transform
		new_obj.global_transform.origin = new_obj.global_transform.origin.snapped(Vector3(0.01, 0.01, 0.01))
		
		var s_size = 4.0
		if current_blueprint:
			s_size = current_blueprint.snap_size
			new_obj.set_meta("blueprint_path", current_blueprint.resource_path)
		new_obj.set_meta("snap_size", s_size)
		
		_play_placement_animation(new_obj)
		if should_exit_mode: player_ref.toggle_build_mode()

func _setup_placed_physics(node: Node):
	if node is CollisionObject3D:
		node.collision_layer = 5 # Layer 1 (World) | Layer 4 (Structure)
		node.collision_mask = 1  # Collide with world
	
	if node is CSGPrimitive3D or node is CSGCombiner3D:
		node.use_collision = true
		node.collision_layer = 5
		node.collision_mask = 1
		
	for child in node.get_children():
		_setup_placed_physics(child)

func _play_placement_animation(obj: Node3D):
	var tween = get_tree().create_tween()
	obj.scale = Vector3(0.001, 0.001, 0.001)
	tween.tween_property(obj, "scale", Vector3.ONE * 1.1, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(obj, "scale", Vector3.ONE, 0.05)
