class_name EnginePart
extends VehiclePartBase

var is_running: bool = false
var rpm: float = 0.0
var max_rpm: float = 3000.0
var max_output: float = 500.0

func _build_mesh() -> void:
	_mesh_inst = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(VehicleRoot.CELL_SIZE * 0.9, VehicleRoot.CELL_SIZE * 1.2, VehicleRoot.CELL_SIZE * 0.9)
	_mesh_inst.mesh = bm
	_mesh_inst.material_override = _mat
	add_child(_mesh_inst)

func get_collision_shape() -> Shape3D:
	var s := BoxShape3D.new()
	s.size = Vector3(VehicleRoot.CELL_SIZE, VehicleRoot.CELL_SIZE * 1.2, VehicleRoot.CELL_SIZE)
	return s

func start() -> void:
	if vehicle_root and vehicle_root.power_system:
		var fuel := vehicle_root.power_system.get_fuel()
		if fuel > 0.0:
			is_running = true

func stop() -> void:
	is_running = false
	rpm = 0.0

func get_power_output() -> float:
	if not is_running:
		return 0.0
	return max_output * (rpm / max_rpm)

func physics_tick(delta: float) -> void:
	if not is_running:
		rpm = move_toward(rpm, 0.0, 200.0 * delta)
		return
	var throttle := vehicle_root.throttle_input if vehicle_root else 0.0
	var target_rpm := max_rpm * maxf(0.1, absf(throttle))
	rpm = move_toward(rpm, target_rpm, 1500.0 * delta)
	if vehicle_root and vehicle_root.power_system:
		var consumed := definition.fuel_consumption * (rpm / max_rpm) * delta
		vehicle_root.power_system.consume_fuel(consumed)
		if vehicle_root.power_system.get_fuel() <= 0.0:
			stop()

func _get_settings() -> Dictionary:
	return { "max_output": max_output, "max_rpm": max_rpm }
