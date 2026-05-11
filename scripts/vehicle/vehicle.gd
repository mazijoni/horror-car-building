class_name Vehicle
extends RigidBody3D

const CELL_SIZE: float = 0.75

var _vehicle_scene: PackedScene = preload("res://scenes/vehicle/vehicle.tscn")

# origin grid pos → { part, mesh, shape_owner_id }
var placed_parts: Dictionary = {}
# every occupied cell → its origin grid pos
var cell_map: Dictionary = {}


func _ready() -> void:
	add_to_group("vehicle")
	freeze = true


# ── Grid helpers ──────────────────────────────────────────────────────────────

func world_to_grid(world_pos: Vector3) -> Vector3i:
	var local := to_local(world_pos)
	return Vector3i(
		roundi(local.x / CELL_SIZE),
		roundi(local.y / CELL_SIZE),
		roundi(local.z / CELL_SIZE)
	)


func grid_to_local(gp: Vector3i) -> Vector3:
	return Vector3(gp.x, gp.y, gp.z) * CELL_SIZE


# ── Placement queries ─────────────────────────────────────────────────────────

func can_place(gp: Vector3i) -> bool:
	if cell_map.has(gp):
		return false
	if placed_parts.is_empty():
		return true
	var dirs := [
		Vector3i(1,0,0), Vector3i(-1,0,0),
		Vector3i(0,1,0), Vector3i(0,-1,0),
		Vector3i(0,0,1), Vector3i(0,0,-1),
	]
	for d: Vector3i in dirs:
		if cell_map.has(gp + d):
			return true
	return false


# ── Part management ───────────────────────────────────────────────────────────

func add_part(part: VehiclePart, gp: Vector3i, face_normal: Vector3 = Vector3.ZERO) -> void:
	if not can_place(gp):
		return

	var local_pos := grid_to_local(gp)
	var wheel_rot := _wheel_basis(face_normal)

	# Mesh
	var mesh_inst := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = part.color

	if part.part_type == VehiclePart.PartType.WHEEL:
		var cyl := CylinderMesh.new()
		cyl.top_radius    = CELL_SIZE * 0.55
		cyl.bottom_radius = CELL_SIZE * 0.55
		cyl.height        = CELL_SIZE * 0.72
		mesh_inst.mesh = cyl
		mesh_inst.basis = wheel_rot
	else:
		var box := BoxMesh.new()
		box.size = Vector3.ONE * CELL_SIZE
		mesh_inst.mesh = box

	mesh_inst.material_override = mat
	mesh_inst.position = local_pos
	add_child(mesh_inst)

	# Collision shape
	var shape: Shape3D
	var shape_basis := Basis()
	if part.part_type == VehiclePart.PartType.WHEEL:
		var s := CylinderShape3D.new()
		s.radius = CELL_SIZE * 0.55
		s.height = CELL_SIZE * 0.72
		shape = s
		shape_basis = wheel_rot
	else:
		var s := BoxShape3D.new()
		s.size = Vector3.ONE * CELL_SIZE
		shape = s

	var sid: int = create_shape_owner(self)
	shape_owner_add_shape(sid, shape)
	shape_owner_set_transform(sid, Transform3D(shape_basis, local_pos))

	placed_parts[gp] = {
		part           = part,
		mesh           = mesh_inst,
		shape_owner_id = sid,
	}
	cell_map[gp] = gp
	_update_physics()


func remove_part_at_cell(gp: Vector3i) -> void:
	if not cell_map.has(gp):
		return
	var origin: Vector3i = cell_map[gp]
	if not placed_parts.has(origin):
		return
	var data: Dictionary = placed_parts[origin]
	(data["mesh"] as MeshInstance3D).queue_free()
	remove_shape_owner(data["shape_owner_id"])
	placed_parts.erase(origin)
	cell_map.erase(origin)
	_split_disconnected()


# ── Connectivity ──────────────────────────────────────────────────────────────

func _split_disconnected() -> void:
	if placed_parts.is_empty():
		_update_physics()
		return

	var components := _find_all_components()
	if components.size() <= 1:
		_update_physics()
		return

	# Keep the largest component here, split off the rest
	components.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	for i: int in range(1, components.size()):
		_split_off_component(components[i])
	_update_physics()


func _find_all_components() -> Array:
	var remaining := {}
	for gp: Vector3i in placed_parts.keys():
		remaining[gp] = true

	var components: Array = []
	var dirs: Array[Vector3i] = [
		Vector3i(1,0,0), Vector3i(-1,0,0),
		Vector3i(0,1,0), Vector3i(0,-1,0),
		Vector3i(0,0,1), Vector3i(0,0,-1),
	]

	while not remaining.is_empty():
		var start: Vector3i = remaining.keys()[0]
		var component: Array[Vector3i] = []
		var queue: Array[Vector3i] = [start]
		remaining.erase(start)

		while not queue.is_empty():
			var current: Vector3i = queue.pop_front()
			component.append(current)
			for d: Vector3i in dirs:
				var neighbor := current + d
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					queue.append(neighbor)

		components.append(component)

	return components


func _split_off_component(component: Array) -> void:
	var new_vehicle: Vehicle = _vehicle_scene.instantiate()
	get_parent().add_child(new_vehicle)
	new_vehicle.global_transform = global_transform

	for gp: Vector3i in component:
		if not placed_parts.has(gp):
			continue
		var data: Dictionary = placed_parts[gp]
		var part: VehiclePart = data["part"]
		(data["mesh"] as MeshInstance3D).queue_free()
		remove_shape_owner(data["shape_owner_id"])
		placed_parts.erase(gp)
		cell_map.erase(gp)
		new_vehicle.add_part(part, gp, Vector3.ZERO)


# ── Helpers ───────────────────────────────────────────────────────────────────

# Returns the basis that rotates a Y-axis cylinder into wheel orientation
# based on which face it is being mounted on.
func _wheel_basis(face_normal: Vector3) -> Basis:
	var a := face_normal.abs()
	if a.z > a.x and a.z > a.y:
		# Front / back face → axle along Z
		return Basis.from_euler(Vector3(PI / 2.0, 0.0, 0.0))
	else:
		# Left / right or top / bottom → axle along X
		return Basis.from_euler(Vector3(0.0, 0.0, PI / 2.0))


# ── Physics sync ──────────────────────────────────────────────────────────────

func _update_physics() -> void:
	if placed_parts.is_empty():
		mass = 1.0
		center_of_mass_mode = CENTER_OF_MASS_MODE_AUTO
		freeze = true
		return

	var total_mass := 0.0
	var com := Vector3.ZERO
	for gp: Vector3i in placed_parts:
		var data: Dictionary = placed_parts[gp]
		var pm: float = (data["part"] as VehiclePart).mass
		total_mass += pm
		com += grid_to_local(gp) * pm

	mass = total_mass
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = com / total_mass
	freeze = false
