class_name GhostPreview
extends Node3D

var _place_ghost: MeshInstance3D
var _remove_ghost: MeshInstance3D
var _mat_ok: StandardMaterial3D
var _mat_bad: StandardMaterial3D
var _mat_remove: StandardMaterial3D

var current_part_id: String = ""
var is_valid: bool = false
var hovered_remove_pos: Vector3i

func _ready() -> void:
	_build_materials()
	_place_ghost = MeshInstance3D.new()
	_place_ghost.material_override = _mat_ok
	_place_ghost.visible = false
	add_child(_place_ghost)

	_remove_ghost = MeshInstance3D.new()
	_remove_ghost.material_override = _mat_remove
	_remove_ghost.visible = false
	var remove_box := BoxMesh.new()
	remove_box.size = Vector3.ONE * VehicleRoot.CELL_SIZE * 0.98
	_remove_ghost.mesh = remove_box
	add_child(_remove_ghost)

func _build_materials() -> void:
	_mat_ok = StandardMaterial3D.new()
	_mat_ok.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ok.albedo_color  = Color(0.1, 1.0, 0.3, 0.4)
	_mat_ok.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_ok.no_depth_test = true

	_mat_bad = StandardMaterial3D.new()
	_mat_bad.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_bad.albedo_color  = Color(1.0, 0.15, 0.15, 0.4)
	_mat_bad.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_bad.no_depth_test = true

	_mat_remove = StandardMaterial3D.new()
	_mat_remove.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_remove.albedo_color  = Color(1.0, 0.4, 0.0, 0.6)
	_mat_remove.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_remove.no_depth_test = true

func update_for_part(part_id: String, reg: PartRegistry) -> void:
	if part_id == current_part_id:
		return
	current_part_id = part_id
	var def := reg.get_definition(part_id)
	if not def:
		return
	_set_place_mesh(def)

func _set_place_mesh(def: PartDefinition) -> void:
	var m: Mesh
	if def.part_id.begins_with("wheel"):
		var cyl := CylinderMesh.new()
		cyl.top_radius    = WheelPart.WHEEL_RADIUS
		cyl.bottom_radius = WheelPart.WHEEL_RADIUS
		cyl.height        = WheelPart.WHEEL_WIDTH
		m = cyl
	else:
		var box := BoxMesh.new()
		box.size = Vector3.ONE * VehicleRoot.CELL_SIZE * 0.93
		m = box
	_place_ghost.mesh = m
	_place_ghost.material_override = _mat_ok

func show_place(world_transform: Transform3D, valid: bool) -> void:
	_place_ghost.global_transform = world_transform
	_place_ghost.material_override = _mat_ok if valid else _mat_bad
	_place_ghost.visible = true
	is_valid = valid

func show_remove(world_transform: Transform3D) -> void:
	_remove_ghost.global_transform = world_transform
	_remove_ghost.visible = true

func hide_place() -> void:
	_place_ghost.visible = false

func hide_remove() -> void:
	_remove_ghost.visible = false

func hide_all() -> void:
	hide_place()
	hide_remove()
