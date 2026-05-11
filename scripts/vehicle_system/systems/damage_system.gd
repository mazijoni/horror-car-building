class_name DamageSystem
extends Node

signal part_destroyed(grid_pos: Vector3i)
signal vehicle_split(new_vehicle: VehicleRoot)

var _vehicle: VehicleRoot

func _ready() -> void:
	_vehicle = get_parent() as VehicleRoot

func _physics_process(_delta: float) -> void:
	if not _vehicle or not _vehicle.physics_manager:
		return
	var stress_map: Dictionary = _vehicle.physics_manager.stress_map
	for gp: Vector3i in stress_map:
		var stress: float = stress_map[gp]
		var part := _vehicle.parts.get(gp) as VehiclePartBase
		if not part or not part.definition:
			continue
		if stress > part.definition.break_force:
			var damage := (stress - part.definition.break_force) * 0.01
			part.take_damage(damage)

func apply_damage_at(world_pos: Vector3, amount: float, radius: float) -> void:
	for gp: Vector3i in _vehicle.parts:
		var part_world := _vehicle.to_global(_vehicle.grid_to_local(gp))
		var dist := part_world.distance_to(world_pos)
		if dist < radius:
			var falloff := 1.0 - (dist / radius)
			var part := _vehicle.parts[gp] as VehiclePartBase
			part.take_damage(amount * falloff)

func on_part_health_zero(part: VehiclePartBase) -> void:
	var gp := part.grid_position
	_vehicle.remove_part(gp)
	emit_signal("part_destroyed", gp)
	if not _vehicle.connection_manager.is_all_connected():
		_split_vehicle()

func _split_vehicle() -> void:
	var islands: Array[Array] = _vehicle.connection_manager.get_islands()
	if islands.size() <= 1:
		return
	islands.sort_custom(func(a, b): return a.size() > b.size())
	for i: int in range(1, islands.size()):
		var island: Array = islands[i]
		var new_veh: VehicleRoot = _vehicle._spawn_island_as_new_vehicle(island)
		emit_signal("vehicle_split", new_veh)
