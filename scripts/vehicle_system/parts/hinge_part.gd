class_name HingePart
extends VehiclePartBase

var motor_speed: float = 0.0
var angle_min: float  = -PI
var angle_max: float  =  PI

func _get_settings() -> Dictionary:
	return { "motor_speed": motor_speed, "angle_min": angle_min, "angle_max": angle_max }
