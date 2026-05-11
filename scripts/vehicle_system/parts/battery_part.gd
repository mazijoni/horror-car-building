class_name BatteryPart
extends VehiclePartBase

var capacity: float = 1000.0
var charge: float   = 1000.0

func _build_mesh() -> void:
	_mesh_inst = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * VehicleRoot.CELL_SIZE * 0.92
	_mesh_inst.mesh = bm
	_mat.albedo_color = Color(0.1, 0.8, 0.2)
	_mesh_inst.material_override = _mat
	add_child(_mesh_inst)

func get_collision_shape() -> Shape3D:
	var s := BoxShape3D.new()
	s.size = Vector3.ONE * VehicleRoot.CELL_SIZE
	return s

func draw_power(amount_ws: float) -> float:
	var taken := minf(amount_ws, charge)
	charge -= taken
	return taken

func store_power(amount_ws: float) -> void:
	charge = minf(charge + amount_ws, capacity)

func _get_settings() -> Dictionary:
	return { "capacity": capacity, "charge": charge }
