class_name PartRegistry
extends Node

var _definitions: Dictionary = {}
var _factory: Dictionary = {}

func _ready() -> void:
	_register_defaults()

func _register_defaults() -> void:
	# FRAME
	var frame_def := PartDefinition.new()
	frame_def.part_id          = "frame_1x1"
	frame_def.display_name     = "Frame Block"
	frame_def.description      = "Basic structural block"
	frame_def.category         = PartDefinition.Category.STRUCTURAL
	frame_def.mass             = 15.0
	frame_def.max_health       = 120.0
	frame_def.break_force      = 8000.0
	register(frame_def, func(): return FramePart.new())

	# HEAVY PLATE
	var plate_def := PartDefinition.new()
	plate_def.part_id          = "heavy_plate"
	plate_def.display_name     = "Heavy Plate"
	plate_def.description      = "Dense armour plate"
	plate_def.category         = PartDefinition.Category.STRUCTURAL
	plate_def.mass             = 50.0
	plate_def.max_health       = 300.0
	plate_def.break_force      = 15000.0
	register(plate_def, func(): return FramePart.new())

	# WHEEL
	var wheel_def := PartDefinition.new()
	wheel_def.part_id           = "wheel"
	wheel_def.display_name      = "Wheel"
	wheel_def.description       = "Motorised rubber wheel"
	wheel_def.category          = PartDefinition.Category.MECHANICAL
	wheel_def.mass              = 12.0
	wheel_def.max_health        = 80.0
	wheel_def.break_force       = 3000.0
	wheel_def.is_mechanical     = true
	wheel_def.power_consumption = 40.0
	register(wheel_def, func(): return WheelPart.new())

	# STEERING WHEEL
	var sw_def := PartDefinition.new()
	sw_def.part_id           = "wheel_steer"
	sw_def.display_name      = "Steering Wheel"
	sw_def.description       = "Motorised wheel with steering"
	sw_def.category          = PartDefinition.Category.MECHANICAL
	sw_def.mass              = 12.0
	sw_def.max_health        = 80.0
	sw_def.break_force       = 3000.0
	sw_def.is_mechanical     = true
	sw_def.power_consumption = 40.0
	register(sw_def, func():
		var w := WheelPart.new()
		w.is_steering = true
		w.is_motor = false
		return w
	)

	# ENGINE
	var eng_def := PartDefinition.new()
	eng_def.part_id          = "engine"
	eng_def.display_name     = "Engine"
	eng_def.description      = "Combustion engine"
	eng_def.category         = PartDefinition.Category.POWER
	eng_def.mass             = 80.0
	eng_def.max_health       = 150.0
	eng_def.break_force      = 5000.0
	eng_def.power_generation = 500.0
	eng_def.fuel_consumption = 0.05
	register(eng_def, func(): return EnginePart.new())

	# FUEL TANK
	var fuel_def := PartDefinition.new()
	fuel_def.part_id      = "fuel_tank"
	fuel_def.display_name = "Fuel Tank"
	fuel_def.description  = "Holds 20L of fuel"
	fuel_def.category     = PartDefinition.Category.POWER
	fuel_def.mass         = 10.0
	fuel_def.max_health   = 80.0
	fuel_def.break_force  = 2000.0
	register(fuel_def, func(): return FuelTankPart.new())

	# BATTERY
	var bat_def := PartDefinition.new()
	bat_def.part_id      = "battery"
	bat_def.display_name = "Battery"
	bat_def.description  = "1000Wh electric storage"
	bat_def.category     = PartDefinition.Category.POWER
	bat_def.mass         = 30.0
	bat_def.max_health   = 100.0
	bat_def.break_force  = 2000.0
	register(bat_def, func(): return BatteryPart.new())

	# SEAT
	var seat_def := PartDefinition.new()
	seat_def.part_id      = "seat"
	seat_def.display_name = "Driver Seat"
	seat_def.description  = "Allows player to drive"
	seat_def.category     = PartDefinition.Category.CONTROL
	seat_def.mass         = 20.0
	seat_def.max_health   = 100.0
	seat_def.break_force  = 4000.0
	register(seat_def, func(): return SeatPart.new())

	# HINGE
	var hinge_def := PartDefinition.new()
	hinge_def.part_id      = "hinge"
	hinge_def.display_name = "Hinge"
	hinge_def.description  = "Rotational mechanical joint"
	hinge_def.category     = PartDefinition.Category.MECHANICAL
	hinge_def.mass         = 8.0
	hinge_def.max_health   = 100.0
	hinge_def.break_force  = 4000.0
	hinge_def.is_mechanical = true
	register(hinge_def, func(): return HingePart.new())

func register(def: PartDefinition, factory: Callable) -> void:
	_definitions[def.part_id] = def
	_factory[def.part_id] = factory

func get_definition(part_id: String) -> PartDefinition:
	return _definitions.get(part_id, null)

func instantiate_part(part_id: String) -> VehiclePartBase:
	if not _factory.has(part_id):
		push_error("PartRegistry: Unknown part_id: " + part_id)
		return null
	var part: VehiclePartBase = _factory[part_id].call()
	part.definition = _definitions[part_id]
	return part

func get_all_definitions() -> Array[PartDefinition]:
	var arr: Array[PartDefinition] = []
	for d: PartDefinition in _definitions.values():
		arr.append(d)
	return arr
