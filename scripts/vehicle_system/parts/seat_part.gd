class_name SeatPart
extends VehiclePartBase

var occupied_by: Node3D = null

func enter(player: Node3D) -> void:
	occupied_by = player
	if vehicle_root:
		vehicle_root._driver = player

func exit() -> void:
	occupied_by = null
	if vehicle_root:
		vehicle_root._driver = null

func is_occupied() -> bool:
	return occupied_by != null
