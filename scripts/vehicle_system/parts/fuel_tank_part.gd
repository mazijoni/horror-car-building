class_name FuelTankPart
extends VehiclePartBase

@export var capacity: float = 20.0
var fuel_level: float = 20.0

func drain(amount: float) -> float:
	var taken := minf(amount, fuel_level)
	fuel_level -= taken
	return taken

func fill(amount: float) -> void:
	fuel_level = minf(fuel_level + amount, capacity)

func _get_settings() -> Dictionary:
	return { "capacity": capacity, "fuel_level": fuel_level }
