class_name GhostPreview
extends Node3D

var _place_ghost: MeshInstance3D
var _highlight_ghost: MeshInstance3D

var _mat_ok: StandardMaterial3D
var _mat_bad: StandardMaterial3D
var _mat_highlight: StandardMaterial3D

var current_part_id: String = ""
var is_valid: bool = false

func _ready() -> void:
	_build_materials()

	_place_ghost = MeshInstance3D.new()
	_place_ghost.material_override = _mat_ok
	_place_ghost.visible = false
	add_child(_place_ghost)

	# Shell-outline highlight: slightly larger box rendered back-face-only,
	# so it peeks around the edges of the real block (classic outline trick).
	_highlight_ghost = MeshInstance3D.new()
	_highlight_ghost.material_override = _mat_highlight
	_highlight_ghost.visible = false
	var hl_box := BoxMesh.new()
	hl_box.size = Vector3.ONE * VehicleRoot.CELL_SIZE * 1.06
	_highlight_ghost.mesh = hl_box
	add_child(_highlight_ghost)

func _build_materials() -> void:
	_mat_ok = StandardMaterial3D.new()
	_mat_ok.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ok.albedo_color  = Color(0.1, 1.0, 0.3, 0.35)
	_mat_ok.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_ok.no_depth_test = true

	_mat_bad = StandardMaterial3D.new()
	_mat_bad.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_bad.albedo_color  = Color(1.0, 0.15, 0.15, 0.35)
	_mat_bad.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_bad.no_depth_test = true

	# Back-face-only shell rendered on the oversized box creates an emissive outline
	_mat_highlight = StandardMaterial3D.new()
	_mat_highlight.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_highlight.emission_enabled = true
	_mat_highlight.emission = Color(1.0, 0.85, 0.15)
	_mat_highlight.emission_energy_multiplier = 3.0
	_mat_highlight.albedo_color = Color(1.0, 0.85, 0.15, 1.0)
	_mat_highlight.cull_mode = BaseMaterial3D.CULL_FRONT

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

func show_highlight(world_transform: Transform3D) -> void:
	_highlight_ghost.global_transform = world_transform
	_highlight_ghost.visible = true

func hide_place() -> void:
	_place_ghost.visible = false

func hide_highlight() -> void:
	_highlight_ghost.visible = false

func hide_all() -> void:
	hide_place()
	hide_highlight()

