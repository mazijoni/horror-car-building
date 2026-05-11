class_name HingePart
extends VehiclePartBase

var motor_speed: float = 0.0
var angle_min: float  = -PI
var angle_max: float  =  PI

func _build_mesh() -> void:
	_mesh_inst = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = VehicleRoot.CELL_SIZE * 0.25
	cyl.bottom_radius = VehicleRoot.CELL_SIZE * 0.25
	cyl.height        = VehicleRoot.CELL_SIZE * 0.9
	_mesh_inst.mesh = cyl
	_mesh_inst.rotation.z = PI * 0.5
	_mat.albedo_color = Color(0.7, 0.7, 0.2)
	_mesh_inst.material_override = _mat
	add_child(_mesh_inst)

func get_collision_shape() -> Shape3D:
	var s := CylinderShape3D.new()
	s.radius = VehicleRoot.CELL_SIZE * 0.25
	s.height = VehicleRoot.CELL_SIZE * 0.9
	return s

func _get_settings() -> Dictionary:
	return { "motor_speed": motor_speed, "angle_min": angle_min, "angle_max": angle_max }
