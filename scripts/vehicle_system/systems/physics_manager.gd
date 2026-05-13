class_name PhysicsManager
extends Node

var _vehicle: VehicleRoot
var _prev_velocity: Vector3 = Vector3.ZERO
var _delta_v_magnitude: float = 0.0

var stress_map: Dictionary = {}
var suspension_offsets: Dictionary = {}

func _ready() -> void:
	_vehicle = get_parent() as VehicleRoot

func _physics_process(delta: float) -> void:
	if not _vehicle or _vehicle.parts.is_empty():
		return
	_update_center_of_mass()
	_update_delta_v()
	_distribute_impact_stress()

func _update_center_of_mass() -> void:
	var total_mass := 0.0
	var com := Vector3.ZERO
	for gp: Vector3i in _vehicle.parts:
		var part := _vehicle.parts[gp] as VehiclePartBase
		if part and part.definition:
			var pm: float = part.definition.mass
			total_mass += pm
			com += _vehicle.grid_to_local(gp) * pm
	if total_mass > 0.0:
		_vehicle.mass = total_mass
		_vehicle.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		_vehicle.center_of_mass = com / total_mass

func _update_delta_v() -> void:
	var current_vel: Vector3 = _vehicle.linear_velocity
	_delta_v_magnitude = (current_vel - _prev_velocity).length()
	_prev_velocity = current_vel

func _distribute_impact_stress() -> void:
	if _delta_v_magnitude < 2.0:
		stress_map.clear()
		return
	var com := _vehicle.center_of_mass
	for gp: Vector3i in _vehicle.parts:
		var local_pos := _vehicle.grid_to_local(gp)
		var dist := local_pos.distance_to(com)
		var stress := _vehicle.mass * _delta_v_magnitude * (1.0 + dist * 0.3)
		stress_map[gp] = stress
