class_name GhostPreview
extends Node3D

var _place_ghost_root: Node3D
var _highlight_ghost_root: Node3D

var _mat_ok: StandardMaterial3D
var _mat_bad: StandardMaterial3D
var _mat_highlight: StandardMaterial3D

var current_part_id: String = ""
var is_valid: bool = false

func _ready() -> void:
	_build_materials()

	_place_ghost_root = Node3D.new()
	_place_ghost_root.visible = false
	add_child(_place_ghost_root)

	# Shell-outline highlight: same model scaled slightly larger, rendered
	# back-face-only so it peeks around the edges (classic outline trick).
	_highlight_ghost_root = Node3D.new()
	_highlight_ghost_root.visible = false
	add_child(_highlight_ghost_root)

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
	_set_place_mesh(def, reg)

func _set_place_mesh(def: PartDefinition, reg: PartRegistry) -> void:
	for c in _place_ghost_root.get_children():
		c.queue_free()
	for c in _highlight_ghost_root.get_children():
		c.queue_free()

	var part := reg.instantiate_part(def.part_id)
	if not part:
		return

	var mesh_children: Array[MeshInstance3D] = []
	for child in part.get_children():
		if child is MeshInstance3D:
			mesh_children.append(child as MeshInstance3D)

	if mesh_children.is_empty():
		# Fallback: no mesh in catalog scene, build a generic shape
		mesh_children = _build_fallback_meshes(def)
		for mi in mesh_children:
			part.add_child(mi)

	for mi in mesh_children:
		var place_mi := MeshInstance3D.new()
		place_mi.mesh = mi.mesh
		place_mi.transform = mi.transform
		place_mi.material_override = _mat_ok
		_place_ghost_root.add_child(place_mi)

		# Slightly scale up the basis for the back-face outline trick
		var hl_mi := MeshInstance3D.new()
		hl_mi.mesh = mi.mesh
		var hl_t := mi.transform
		hl_t.basis = hl_t.basis.scaled(Vector3.ONE * 1.06)
		hl_mi.transform = hl_t
		hl_mi.material_override = _mat_highlight
		_highlight_ghost_root.add_child(hl_mi)

	part.queue_free()

func _build_fallback_meshes(def: PartDefinition) -> Array[MeshInstance3D]:
	var mi := MeshInstance3D.new()
	if def.part_id.begins_with("wheel"):
		var cyl := CylinderMesh.new()
		cyl.top_radius    = WheelPart.WHEEL_RADIUS
		cyl.bottom_radius = WheelPart.WHEEL_RADIUS
		cyl.height        = VehicleRoot.CELL_SIZE * 0.5
		mi.mesh = cyl
	else:
		var box := BoxMesh.new()
		box.size = Vector3.ONE * VehicleRoot.CELL_SIZE * 0.93
		mi.mesh = box
	return [mi]

func show_place(world_transform: Transform3D, valid: bool) -> void:
	_place_ghost_root.global_transform = world_transform
	var mat := _mat_ok if valid else _mat_bad
	for child in _place_ghost_root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = mat
	_place_ghost_root.visible = true
	is_valid = valid

func show_highlight(world_transform: Transform3D) -> void:
	_highlight_ghost_root.global_transform = world_transform
	_highlight_ghost_root.visible = true

func hide_place() -> void:
	_place_ghost_root.visible = false

func hide_highlight() -> void:
	_highlight_ghost_root.visible = false

func hide_all() -> void:
	hide_place()
	hide_highlight()
