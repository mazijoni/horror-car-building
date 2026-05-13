class_name BatteryPart
extends VehiclePartBase

var capacity: float = 1000.0
var charge: float   = 1000.0

func draw_power(amount_ws: float) -> float:
	var taken := minf(amount_ws, charge)
	charge -= taken
	return taken

func store_power(amount_ws: float) -> void:
	charge = minf(charge + amount_ws, capacity)

func _get_settings() -> Dictionary:
	return { "capacity": capacity, "charge": charge }
