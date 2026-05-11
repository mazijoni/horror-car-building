class_name FuelTankPart
extends VehiclePartBase

@export var capacity: float = 20.0
var fuel_level: float = 20.0

func _build_mesh() -> void:
	_mesh_inst = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * VehicleRoot.CELL_SIZE * 0.92
	_mesh_inst.mesh = bm
	_mat.albedo_color = Color(0.9, 0.6, 0.1)
	_mesh_inst.material_override = _mat
	add_child(_mesh_inst)

func get_collision_shape() -> Shape3D:
	var s := BoxShape3D.new()
	s.size = Vector3.ONE * VehicleRoot.CELL_SIZE
	return s

func drain(amount: float) -> float:
	var taken := minf(amount, fuel_level)
	fuel_level -= taken
	return taken

func fill(amount: float) -> void:
	fuel_level = minf(fuel_level + amount, capacity)

func _get_settings() -> Dictionary:
	return { "capacity": capacity, "fuel_level": fuel_level }
