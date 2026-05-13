class_name WheelPart
extends VehiclePartBase

const WHEEL_RADIUS: float = VehicleRoot.CELL_SIZE * 0.55
const WHEEL_WIDTH: float  = VehicleRoot.CELL_SIZE * 0.72

# ── @export — configure in the wheel part scene Inspector ─────────────────────
@export_category("Wheel Config")
@export var is_motor: bool = true
@export var is_steering: bool = false
@export var motor_torque: float = 80.0
@export var steer_angle: float = 0.3
@export var suspension_stiffness: float = 20.0
@export var suspension_damping: float  = 4.0
@export var suspension_travel: float   = VehicleRoot.CELL_SIZE * 0.4

var _suspension_offset: float = 0.0
var _rest_dist: float = 0.0

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
