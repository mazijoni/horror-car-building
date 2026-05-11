class_name WheelPart
extends VehiclePartBase

const WHEEL_RADIUS: float = VehicleRoot.CELL_SIZE * 0.55
const WHEEL_WIDTH: float  = VehicleRoot.CELL_SIZE * 0.72

var is_motor: bool = true
var is_steering: bool = false
var motor_torque: float = 80.0
var steer_angle: float = 0.3
var suspension_stiffness: float = 20.0
var suspension_damping: float  = 4.0
var suspension_travel: float   = VehicleRoot.CELL_SIZE * 0.4

var _suspension_offset: float = 0.0
var _rest_dist: float = 0.0

func _build_mesh() -> void:
	_mesh_inst = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = WHEEL_RADIUS
	cyl.bottom_radius = WHEEL_RADIUS
	cyl.height        = WHEEL_WIDTH
	_mesh_inst.mesh = cyl
	_mesh_inst.material_override = _mat
	_mesh_inst.rotation = Vector3(0.0, 0.0, PI * 0.5)
	add_child(_mesh_inst)

func get_collision_shape() -> Shape3D:
	var s := CylinderShape3D.new()
	s.radius = WHEEL_RADIUS
	s.height = WHEEL_WIDTH
	return s

func _get_settings() -> Dictionary:
	return {
		"is_motor": is_motor,
		"is_steering": is_steering,
		"motor_torque": motor_torque,
		"steer_angle": steer_angle,
		"suspension_stiffness": suspension_stiffness,
		"suspension_damping": suspension_damping,
	}

func physics_tick(delta: float) -> void:
	if mechanical_body == null:
		return
	if is_motor and vehicle_root and vehicle_root.power_system:
		var throttle: float = vehicle_root.throttle_input
		if absf(throttle) > 0.01:
			var torque := Vector3(motor_torque * throttle, 0.0, 0.0)
			mechanical_body.apply_torque(mechanical_body.global_basis * torque)
