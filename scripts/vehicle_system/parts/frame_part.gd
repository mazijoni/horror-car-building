class_name FramePart
extends VehiclePartBase

func _build_mesh() -> void:
	_mesh_inst = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * VehicleRoot.CELL_SIZE * 0.90
	_mesh_inst.mesh = bm
	_mesh_inst.material_override = _mat
	add_child(_mesh_inst)

func get_collision_shape() -> Shape3D:
	var s := BoxShape3D.new()
	s.size = Vector3.ONE * VehicleRoot.CELL_SIZE
	return s
