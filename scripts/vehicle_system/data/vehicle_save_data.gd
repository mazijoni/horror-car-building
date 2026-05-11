class_name VehicleSaveData
extends Resource

@export var vehicle_name: String = "Vehicle"
@export var parts: Array[PartSaveData] = []
@export var world_position: Vector3 = Vector3.ZERO
@export var world_basis: Basis = Basis.IDENTITY

func to_dict() -> Dictionary:
	var parts_arr: Array = []
	for p: PartSaveData in parts:
		parts_arr.append(p.to_dict())
	return {
		"vehicle_name": vehicle_name,
		"parts": parts_arr,
		"world_pos": [world_position.x, world_position.y, world_position.z],
	}

static func from_dict(d: Dictionary) -> VehicleSaveData:
	var s := VehicleSaveData.new()
	s.vehicle_name = d.get("vehicle_name", "Vehicle")
	var wpos: Array = d.get("world_pos", [0.0, 0.5, 0.0])
	s.world_position = Vector3(wpos[0], wpos[1], wpos[2])
	for pd in d.get("parts", []):
		s.parts.append(PartSaveData.from_dict(pd))
	return s
