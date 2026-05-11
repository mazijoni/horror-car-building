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
	var color: Color
	var _registry: PartRegistry

	func _init(v: VehicleRoot, pid: String, gp: Vector3i, oidx: int, c: Color, reg: PartRegistry) -> void:
		vehicle = v
		part_id = pid
		grid_pos = gp
		orient_idx = oidx
		color = c
		_registry = reg
		description = "Place " + pid + " at " + str(gp)

	func execute() -> void:
		var part := _registry.instantiate_part(part_id)
		if part:
			vehicle.add_part(part, grid_pos, orient_idx, color)

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
			vehicle.add_part(part, saved.grid_pos, saved.orientation_idx, saved.color)

class PaintAction extends BuildAction:
	var vehicle: VehicleRoot
	var grid_pos: Vector3i
	var old_color: Color
	var new_color: Color

	func _init(v: VehicleRoot, gp: Vector3i, old_c: Color, new_c: Color) -> void:
		vehicle = v
		grid_pos = gp
		old_color = old_c
		new_color = new_c
		description = "Paint at " + str(gp)

	func execute() -> void:
		var part := vehicle.parts.get(grid_pos) as VehiclePartBase
		if part:
			part.part_color = new_color
			if part._mat:
				part._mat.albedo_color = new_color

	func undo_action() -> void:
		var part := vehicle.parts.get(grid_pos) as VehiclePartBase
		if part:
			part.part_color = old_color
			if part._mat:
				part._mat.albedo_color = old_color

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
