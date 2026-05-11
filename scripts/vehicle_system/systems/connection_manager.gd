class_name ConnectionManager
extends Node

var _structural_connections: Dictionary = {}
var _mechanical_joints: Dictionary = {}

var _vehicle: VehicleRoot

func _ready() -> void:
	_vehicle = get_parent() as VehicleRoot

func register_structural(part: VehiclePartBase) -> void:
	var gp := part.grid_position
	_structural_connections[gp] = []
	var dirs := [
		Vector3i(1,0,0), Vector3i(-1,0,0),
		Vector3i(0,1,0), Vector3i(0,-1,0),
		Vector3i(0,0,1), Vector3i(0,0,-1),
	]
	for d: Vector3i in dirs:
		var neighbour := gp + d
		if _vehicle.parts.has(neighbour):
			_structural_connections[gp].append(neighbour)
			if not _structural_connections.has(neighbour):
				_structural_connections[neighbour] = []
			_structural_connections[neighbour].append(gp)

func unregister_structural(gp: Vector3i) -> void:
	if not _structural_connections.has(gp):
		return
	for neighbour: Vector3i in _structural_connections[gp]:
		if _structural_connections.has(neighbour):
			_structural_connections[neighbour].erase(gp)
	_structural_connections.erase(gp)

func create_wheel_joint(part: WheelPart) -> HingeJoint3D:
	var joint := HingeJoint3D.new()
	joint.name = "WheelJoint_" + str(part.grid_position)
	_vehicle.add_child(joint)
	joint.global_transform = part.mechanical_body.global_transform
	joint.set_node_a(joint.get_path_to(_vehicle))
	joint.set_node_b(joint.get_path_to(part.mechanical_body))
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	if part.is_motor:
		joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	_mechanical_joints[part.grid_position] = joint
	return joint

func create_generic_joint(part: VehiclePartBase, _linear_free_axis: int = -1, _angular_free_axis: int = 0) -> Generic6DOFJoint3D:
	var joint := Generic6DOFJoint3D.new()
	joint.name = "MechJoint_" + str(part.grid_position)
	_vehicle.add_child(joint)
	joint.global_transform = part.mechanical_body.global_transform
	joint.set_node_a(joint.get_path_to(_vehicle))
	joint.set_node_b(joint.get_path_to(part.mechanical_body))
	_mechanical_joints[part.grid_position] = joint
	return joint

func remove_joint(gp: Vector3i) -> void:
	if _mechanical_joints.has(gp):
		_mechanical_joints[gp].queue_free()
		_mechanical_joints.erase(gp)

func is_all_connected() -> bool:
	if _structural_connections.is_empty():
		return true
	var start: Vector3i = _structural_connections.keys()[0]
	var visited := {}
	var queue: Array[Vector3i] = [start]
	visited[start] = true
	while not queue.is_empty():
		var cur: Vector3i = queue.pop_front()
		for nb: Vector3i in _structural_connections.get(cur, []):
			if not visited.has(nb):
				visited[nb] = true
				queue.append(nb)
	return visited.size() == _structural_connections.size()

func get_islands() -> Array[Array]:
	var unvisited := {}
	for gp: Vector3i in _structural_connections:
		unvisited[gp] = true
	var islands: Array[Array] = []
	while not unvisited.is_empty():
		var start: Vector3i = unvisited.keys()[0]
		var island: Array = []
		var queue: Array[Vector3i] = [start]
		while not queue.is_empty():
			var cur: Vector3i = queue.pop_front()
			if not unvisited.has(cur):
				continue
			unvisited.erase(cur)
			island.append(cur)
			for nb: Vector3i in _structural_connections.get(cur, []):
				if unvisited.has(nb):
					queue.append(nb)
		islands.append(island)
	return islands
