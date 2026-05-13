class_name VehicleRoot
extends RigidBody3D

const CELL_SIZE: float = 1.0

signal part_added(part: VehiclePartBase)
signal part_removed(grid_pos: Vector3i)
signal vehicle_built()

@onready var connection_manager: ConnectionManager = $ConnectionManager
@onready var physics_manager: PhysicsManager       = $PhysicsManager
@onready var damage_system: DamageSystem           = $DamageSystem
@onready var power_system: PowerSystem             = $PowerSystem
@onready var serialization_manager: SerializationManager = $SerializationManager
@onready var _part_container: Node3D               = $Parts
@onready var _mech_container: Node3D               = $MechanicalBodies

var parts: Dictionary = {}
var cell_map: Dictionary = {}

# Guard so that removing parts during a split doesn't re-trigger splitting
var _splitting: bool = false

var throttle_input: float = 0.0
var steer_input: float    = 0.0
var brake_input: float    = 0.0

var _is_frozen_empty: bool = true

func _ready() -> void:
	add_to_group("vehicle")
	freeze = true
	linear_damp  = 0.5
	angular_damp = 5.0
	_setup_systems()

func _setup_systems() -> void:
	if damage_system:
		damage_system.vehicle_split.connect(_on_vehicle_split)
	for gp: Vector3i in parts:
		var p := parts[gp] as VehiclePartBase
		if p:
			p.part_destroyed.connect(_on_part_destroyed.bind(p))

func _physics_process(delta: float) -> void:
	_apply_steering()
	for gp: Vector3i in parts:
		var p := parts[gp] as VehiclePartBase
		if p:
			p.physics_tick(delta)

func _apply_steering() -> void:
	for gp: Vector3i in parts:
		var part: VehiclePartBase = parts[gp]
		if not (part is WheelPart):
			continue
		var wheel := part as WheelPart
		if not wheel.is_steering or not wheel.mechanical_body:
			continue
		var target_angle := steer_input * wheel.steer_angle
		var cur_basis := wheel.mechanical_body.global_basis
		var desired_basis := global_basis * PartDefinition.get_orientation(wheel.orientation_idx) * Basis(Vector3.UP, target_angle)
		wheel.mechanical_body.global_basis = cur_basis.slerp(desired_basis, 0.2)

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

func can_place(gp: Vector3i, part_def: PartDefinition = null) -> bool:
	var cells := _get_part_cells(gp, part_def)
	for cell: Vector3i in cells:
		if cell_map.has(cell):
			return false
	if parts.is_empty():
		return true
	var dirs := [
		Vector3i(1,0,0), Vector3i(-1,0,0),
		Vector3i(0,1,0), Vector3i(0,-1,0),
		Vector3i(0,0,1), Vector3i(0,0,-1),
	]
	for cell: Vector3i in cells:
		for d: Vector3i in dirs:
			if cell_map.has(cell + d):
				return true
	return false

func _get_part_cells(origin: Vector3i, def: PartDefinition) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var gs := def.grid_size if def else Vector3i(1, 1, 1)
	for x: int in gs.x:
		for y: int in gs.y:
			for z: int in gs.z:
				cells.append(origin + Vector3i(x, y, z))
	return cells

# ── Part management ───────────────────────────────────────────────────────────

func add_part(part: VehiclePartBase, gp: Vector3i, orient_idx: int) -> bool:
	if not can_place(gp, part.definition):
		return false

	var local_pos := grid_to_local(gp)
	var local_basis := PartDefinition.get_orientation(orient_idx)

	part.setup(part.definition, gp, orient_idx)
	part.vehicle_root = self
	part.transform = Transform3D(local_basis, local_pos)
	part.part_destroyed.connect(_on_part_destroyed.bind(part))

	if part.definition.is_mechanical:
		_setup_mechanical_part(part)
		_mech_container.add_child(part)
	else:
		_add_structural_shape(part)
		_part_container.add_child(part)

	parts[gp] = part
	for cell: Vector3i in _get_part_cells(gp, part.definition):
		cell_map[cell] = gp

	connection_manager.register_structural(part)
	physics_manager._update_center_of_mass()
	_update_freeze_state()
	emit_signal("part_added", part)
	return true

func remove_part(gp: Vector3i) -> void:
	if not parts.has(gp):
		return
	var part := parts[gp] as VehiclePartBase

	if part.definition and part.definition.is_mechanical:
		_remove_mechanical_part(part)
	else:
		_remove_structural_shape(part)

	connection_manager.unregister_structural(gp)

	for cell: Vector3i in _get_part_cells(gp, part.definition):
		cell_map.erase(cell)
	parts.erase(gp)

	part.queue_free()
	physics_manager._update_center_of_mass()
	_update_freeze_state()
	emit_signal("part_removed", gp)

	if not _splitting:
		_check_split()

func _add_structural_shape(part: VehiclePartBase) -> void:
	var shape := part.get_collision_shape()
	if shape == null:
		return
	var sid := create_shape_owner(self)
	var orient := PartDefinition.get_orientation(part.orientation_idx)
	shape_owner_add_shape(sid, shape)
	shape_owner_set_transform(sid, Transform3D(orient, grid_to_local(part.grid_position)))
	part.shape_owner_id = sid

func _remove_structural_shape(part: VehiclePartBase) -> void:
	if part.shape_owner_id >= 0:
		remove_shape_owner(part.shape_owner_id)
		part.shape_owner_id = -1

func _setup_mechanical_part(part: VehiclePartBase) -> void:
	var body := RigidBody3D.new()
	body.name = "MechBody_" + str(part.grid_position)
	body.mass = part.definition.mass if part.definition else 10.0
	body.linear_damp  = 0.5
	body.angular_damp = 2.0
	var cshape := CollisionShape3D.new()
	cshape.shape = part.get_collision_shape()
	if cshape.shape == null:
		cshape.disabled = true
	body.add_child(cshape)
	_mech_container.add_child(body)
	body.global_transform = Transform3D(
		PartDefinition.get_orientation(part.orientation_idx),
		to_global(grid_to_local(part.grid_position))
	)
	part.mechanical_body = body

	if part is WheelPart:
		connection_manager.create_wheel_joint(part as WheelPart)
	elif part is HingePart:
		connection_manager.create_generic_joint(part, -1, 1)

func _remove_mechanical_part(part: VehiclePartBase) -> void:
	connection_manager.remove_joint(part.grid_position)
	if part.mechanical_body and is_instance_valid(part.mechanical_body):
		part.mechanical_body.queue_free()
	part.mechanical_body = null
	part.joint_node = null

func _update_freeze_state() -> void:
	if parts.is_empty():
		freeze = true
		_is_frozen_empty = true
	else:
		freeze = false
		_is_frozen_empty = false

# ── Vehicle split / island spawning ──────────────────────────────────────────

func _check_split() -> void:
	if parts.size() < 2:
		return
	if connection_manager.is_all_connected():
		return
	var islands: Array[Array] = connection_manager.get_islands()
	if islands.size() <= 1:
		return
	# Keep the largest island in this vehicle; spawn the rest as new vehicles
	islands.sort_custom(func(a, b): return a.size() > b.size())
	_splitting = true
	var reg: PartRegistry = _find_registry()
	for i: int in range(1, islands.size()):
		_spawn_island_as_new_vehicle(islands[i], reg)
	_splitting = false

func _spawn_island_as_new_vehicle(island_cells: Array, reg: PartRegistry = null) -> VehicleRoot:
	var scene: PackedScene = load("res://scenes/vehicle_system/vehicle_root.tscn")
	var new_veh: VehicleRoot = scene.instantiate() as VehicleRoot
	get_parent().add_child(new_veh)
	new_veh.global_transform = global_transform
	if reg == null:
		reg = _find_registry()

	for gp_var in island_cells:
		var gp: Vector3i = gp_var
		if not parts.has(gp):
			continue
		var old_part := parts[gp] as VehiclePartBase
		var psd := old_part.to_save_data()
		remove_part(gp)
		if reg:
			var new_part := reg.instantiate_part(psd.part_id)
			if new_part:
				new_veh.add_part(new_part, psd.grid_pos, psd.orientation_idx)

	# Inherit velocity so the split piece flies off naturally
	new_veh.linear_velocity = linear_velocity
	new_veh.angular_velocity = angular_velocity
	return new_veh

func _on_part_destroyed(part: VehiclePartBase) -> void:
	if damage_system:
		damage_system.on_part_health_zero(part)

func _on_vehicle_split(_new_vehicle: VehicleRoot) -> void:
	pass

func rotate_part(gp: Vector3i, new_orient_idx: int) -> void:
	if not parts.has(gp):
		return
	var old := parts[gp] as VehiclePartBase
	var pid := old.definition.part_id
	_splitting = true   # prevent spurious split during the swap
	remove_part(gp)
	_splitting = false
	var reg := _find_registry()
	if reg:
		var new_part := reg.instantiate_part(pid)
		if new_part:
			add_part(new_part, gp, new_orient_idx)

# ── Save / Load ───────────────────────────────────────────────────────────────

func to_save_data() -> VehicleSaveData:
	var sdata := VehicleSaveData.new()
	sdata.vehicle_name = name
	sdata.world_position = global_position
	sdata.world_basis = global_basis
	for gp: Vector3i in parts:
		var part := parts[gp] as VehiclePartBase
		sdata.parts.append(part.to_save_data())
	return sdata

func load_from_save_data(sdata: VehicleSaveData) -> void:
	for gp: Vector3i in parts.keys().duplicate():
		remove_part(gp)
	global_position = sdata.world_position
	var reg: PartRegistry = _find_registry()
	if not reg:
		push_error("VehicleRoot: No PartRegistry found for load")
		return
	for psd: PartSaveData in sdata.parts:
		var part := reg.instantiate_part(psd.part_id)
		if part:
			add_part(part, psd.grid_pos, psd.orientation_idx)

func _find_registry() -> PartRegistry:
	var bm := get_tree().get_first_node_in_group("build_manager")
	if bm is BuildManager:
		return (bm as BuildManager).registry
	return null
