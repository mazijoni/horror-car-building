class_name VehiclePartBase
extends Node3D

signal part_damaged(amount: float)
signal part_destroyed()

var definition: PartDefinition
var grid_position: Vector3i = Vector3i.ZERO
var orientation_idx: int = 0
var health: float = 100.0
var part_color: Color = Color.WHITE
var vehicle_root: VehicleRoot

# For structural parts: shape owner id in the chassis RigidBody3D
var shape_owner_id: int = -1

# For mechanical parts: the sub-body and joint
var mechanical_body: RigidBody3D = null
var joint_node: Joint3D = null

var _mesh_inst: MeshInstance3D = null
var _mat: StandardMaterial3D = null

func _ready() -> void:
	if definition:
		health = definition.max_health

func setup(def: PartDefinition, gp: Vector3i, orient_idx: int, color: Color) -> void:
	definition = def
	grid_position = gp
	orientation_idx = orient_idx
	part_color = color
	health = def.max_health
	name = def.part_id + "_" + str(gp.x) + "_" + str(gp.y) + "_" + str(gp.z)
	_build_visual()

func _build_visual() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = part_color
	_mat.roughness = 0.7
	_build_mesh()

func _build_mesh() -> void:
	_mesh_inst = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * VehicleRoot.CELL_SIZE * 0.92
	_mesh_inst.mesh = bm
	_mesh_inst.material_override = _mat
	add_child(_mesh_inst)

func get_collision_shape() -> Shape3D:
	var s := BoxShape3D.new()
	s.size = Vector3.ONE * VehicleRoot.CELL_SIZE
	return s

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if _mat:
		var t := 1.0 - (health / definition.max_health)
		_mat.albedo_color = part_color.lerp(Color(0.3, 0.05, 0.0), t * 0.6)
	emit_signal("part_damaged", amount)
	if health <= 0.0:
		emit_signal("part_destroyed")

func to_save_data() -> PartSaveData:
	var s := PartSaveData.new()
	s.part_id = definition.part_id
	s.grid_pos = grid_position
	s.orientation_idx = orientation_idx
	s.health = health
	s.color = part_color
	s.settings = _get_settings()
	return s

func _get_settings() -> Dictionary:
	return {}

func physics_tick(_delta: float) -> void:
	pass
