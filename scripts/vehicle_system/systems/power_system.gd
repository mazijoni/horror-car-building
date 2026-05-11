class_name PowerSystem
extends Node

var _vehicle: VehicleRoot
var _total_fuel: float = 0.0
var _total_power: float = 0.0
var _power_demand: float = 0.0

func _ready() -> void:
	_vehicle = get_parent() as VehicleRoot

func _physics_process(delta: float) -> void:
	_collect_resources()
	_distribute_power(delta)

func _collect_resources() -> void:
	_total_fuel = 0.0
	_total_power = 0.0
	for gp: Vector3i in _vehicle.parts:
		var part: VehiclePartBase = _vehicle.parts[gp]
		if part is FuelTankPart:
			_total_fuel += (part as FuelTankPart).fuel_level
		if part is EnginePart:
			_total_power += (part as EnginePart).get_power_output()
		if part is BatteryPart:
			_total_power += (part as BatteryPart).charge * 0.1

func _distribute_power(_delta: float) -> void:
	_power_demand = 0.0
	for gp: Vector3i in _vehicle.parts:
		var part := _vehicle.parts[gp] as VehiclePartBase
		if part and part.definition:
			_power_demand += part.definition.power_consumption

func get_fuel() -> float:
	return _total_fuel

func consume_fuel(amount: float) -> void:
	if _total_fuel <= 0.0:
		return
	for gp: Vector3i in _vehicle.parts:
		var part: VehiclePartBase = _vehicle.parts[gp]
		if part is FuelTankPart:
			var tank := part as FuelTankPart
			var fraction := tank.fuel_level / _total_fuel if _total_fuel > 0.0 else 0.0
			tank.drain(amount * fraction)

func get_available_power() -> float:
	return _total_power

func get_power_ratio() -> float:
	if _power_demand <= 0.0:
		return 1.0
	return minf(1.0, _total_power / _power_demand)
