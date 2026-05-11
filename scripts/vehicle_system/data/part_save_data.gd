class_name PartSaveData
extends Resource

@export var part_id: String = ""
@export var grid_pos: Vector3i = Vector3i.ZERO
@export var orientation_idx: int = 0
@export var health: float = 100.0
@export var color: Color = Color.WHITE
@export var settings: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"part_id": part_id,
		"grid_pos": [grid_pos.x, grid_pos.y, grid_pos.z],
		"orientation_idx": orientation_idx,
		"health": health,
		"color": [color.r, color.g, color.b],
		"settings": settings,
	}

static func from_dict(d: Dictionary) -> PartSaveData:
	var s := PartSaveData.new()
	s.part_id = d.get("part_id", "")
	var gp: Array = d.get("grid_pos", [0, 0, 0])
	s.grid_pos = Vector3i(gp[0], gp[1], gp[2])
	s.orientation_idx = d.get("orientation_idx", 0)
	s.health = d.get("health", 100.0)
	var c: Array = d.get("color", [1.0, 1.0, 1.0])
	s.color = Color(c[0], c[1], c[2])
	s.settings = d.get("settings", {})
	return s
