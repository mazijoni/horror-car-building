class_name SeatPart
extends VehiclePartBase

var occupied_by: Node3D = null

func enter(player: Node3D) -> void:
	occupied_by = player

func exit() -> void:
	occupied_by = null

func is_occupied() -> bool:
	return occupied_by != null
