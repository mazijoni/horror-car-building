class_name VehiclePart
extends Resource

enum PartType { FRAME, HEAVY_PLATE, WHEEL }

@export var part_id: String = ""
@export var display_name: String = ""
@export var part_type: PartType = PartType.FRAME
@export var mass: float = 20.0
@export var color: Color = Color(0.6, 0.6, 0.65)
