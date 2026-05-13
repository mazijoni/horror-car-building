class_name PartRegistry
extends Node

var _definitions: Dictionary = {}
var _factory: Dictionary = {}

func _ready() -> void:
	_load_catalog()

func _load_catalog() -> void:
	var scene: PackedScene = load("res://scenes/vehicle_system/block_catalog.tscn")
	if not scene:
		push_error("PartRegistry: block_catalog.tscn not found!")
		return
	var catalog := scene.instantiate()
	for child: Node in catalog.get_children():
		var base := child as VehiclePartBase
		if not base:
			continue
		if base.part_id.is_empty():
			push_warning("PartRegistry: node '%s' has empty part_id \u2014 skipped." % child.name)
			continue
		var def := base.build_definition()
		var template: VehiclePartBase = base.duplicate() as VehiclePartBase
		register_part(def, func() -> VehiclePartBase: return template.duplicate() as VehiclePartBase)
	catalog.queue_free()

func register_part(def: PartDefinition, factory: Callable) -> void:
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