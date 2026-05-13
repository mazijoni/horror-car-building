class_name UndoRedoSystem
extends Node

const MAX_HISTORY: int = 50

class BuildAction:
	var description: String = ""
	func execute() -> void:
		pass
	func undo_action() -> void:
		pass

class PlaceAction extends BuildAction:
	var vehicle: VehicleRoot
	var part_id: String
	var grid_pos: Vector3i
	var orient_idx: int
	var _registry: PartRegistry

	func _init(v: VehicleRoot, pid: String, gp: Vector3i, oidx: int, reg: PartRegistry) -> void:
		vehicle = v
		part_id = pid
		grid_pos = gp
		orient_idx = oidx
		_registry = reg
		description = "Place " + pid + " at " + str(gp)

	func execute() -> void:
		var part := _registry.instantiate_part(part_id)
		if part:
			vehicle.add_part(part, grid_pos, orient_idx)

	func undo_action() -> void:
		vehicle.remove_part(grid_pos)

class RemoveAction extends BuildAction:
	var vehicle: VehicleRoot
	var saved: PartSaveData
	var _registry: PartRegistry

	func _init(v: VehicleRoot, s: PartSaveData, reg: PartRegistry) -> void:
		vehicle = v
		saved = s
		_registry = reg
		description = "Remove " + s.part_id + " at " + str(s.grid_pos)

	func execute() -> void:
		vehicle.remove_part(saved.grid_pos)

	func undo_action() -> void:
		var part := _registry.instantiate_part(saved.part_id)
		if part:
			vehicle.add_part(part, saved.grid_pos, saved.orientation_idx)

var _history: Array[BuildAction] = []
var _redo_stack: Array[BuildAction] = []

func execute(action: BuildAction) -> void:
	action.execute()
	_history.append(action)
	_redo_stack.clear()
	if _history.size() > MAX_HISTORY:
		_history.pop_front()

func undo() -> void:
	if _history.is_empty():
		return
	var action: BuildAction = _history.pop_back()
	action.undo_action()
	_redo_stack.append(action)

func redo() -> void:
	if _redo_stack.is_empty():
		return
	var action: BuildAction = _redo_stack.pop_back()
	action.execute()
	_history.append(action)

func can_undo() -> bool:
	return not _history.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func clear() -> void:
	_history.clear()
	_redo_stack.clear()
