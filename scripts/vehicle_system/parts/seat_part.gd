class_name SeatPart
extends VehiclePartBase

var occupied_by: Node3D = null

func _build_mesh() -> void:
	_mesh_inst = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(VehicleRoot.CELL_SIZE * 0.8, VehicleRoot.CELL_SIZE * 0.3, VehicleRoot.CELL_SIZE * 0.8)
	_mesh_inst.mesh = bm
	_mat.albedo_color = Color(0.2, 0.2, 0.8)
	_mesh_inst.material_override = _mat
	add_child(_mesh_inst)
	var back := MeshInstance3D.new()
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(VehicleRoot.CELL_SIZE * 0.8, VehicleRoot.CELL_SIZE * 0.9, VehicleRoot.CELL_SIZE * 0.15)
	back.mesh = bm2
	back.material_override = _mat
	back.position = Vector3(0.0, VehicleRoot.CELL_SIZE * 0.6, VehicleRoot.CELL_SIZE * 0.35)
	add_child(back)

func get_collision_shape() -> Shape3D:
	var s := BoxShape3D.new()
	s.size = Vector3.ONE * VehicleRoot.CELL_SIZE
	return s

func enter(player: Node3D) -> void:
	occupied_by = player

func exit() -> void:
	occupied_by = null

func is_occupied() -> bool:
	return occupied_by != null
