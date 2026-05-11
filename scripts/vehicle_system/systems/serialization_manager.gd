class_name SerializationManager
extends Node

const SAVE_DIR: String = "user://vehicles/"

var _vehicle: VehicleRoot

func _ready() -> void:
	_vehicle = get_parent() as VehicleRoot
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func save(filename: String) -> void:
	var data := _vehicle.to_save_data()
	var json_str := JSON.stringify(data.to_dict(), "\t")
	var path := SAVE_DIR + filename + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("VehicleSystem: Saved to " + path)
	else:
		push_error("VehicleSystem: Failed to save to " + path)

func load_vehicle(filename: String) -> bool:
	var path := SAVE_DIR + filename + ".json"
	if not FileAccess.file_exists(path):
		push_error("VehicleSystem: File not found: " + path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var json_str := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		push_error("VehicleSystem: JSON parse error")
		return false
	var save_data := VehicleSaveData.from_dict(parsed)
	_vehicle.load_from_save_data(save_data)
	return true

func list_saves() -> Array[String]:
	var saves: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return saves
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			saves.append(fname.trim_suffix(".json"))
		fname = dir.get_next()
	return saves
