class_name BuildingController
extends Node

const BUILD_RANGE: float = 12.0
const GRAB_RANGE: float  = 6.0
const GRAB_DIST: float   = 3.0

var _spawn_on_ground: bool = false
var _ground_spawn_pos: Vector3 = Vector3.ZERO

# Raycast results, updated every frame
var _hovered_vehicle: Vehicle = null
var _hovered_place_pos: Vector3i
var _hovered_remove_pos: Vector3i
var _last_hit_normal: Vector3 = Vector3.UP
var _placement_valid: bool = false
var _removal_valid: bool   = false

var _camera: Camera3D

# Two ghost meshes: green for placement, orange for deletion highlight
var _ghost_place: MeshInstance3D
var _ghost_remove: MeshInstance3D
var _mat_place: StandardMaterial3D
var _mat_remove: StandardMaterial3D

# Grab state
var _grabbed: RigidBody3D = null

var _parts: Array[VehiclePart] = []

# HUD
var _canvas: CanvasLayer
var _panel: Panel
var _status_label: Label
var _grab_label: Label

var _vehicle_scene: PackedScene = preload("res://scenes/vehicle/vehicle.tscn")


func _ready() -> void:
	_build_part_registry()
	call_deferred("_deferred_init")


func _build_part_registry() -> void:
	var frame := VehiclePart.new()
	frame.part_id      = "frame"
	frame.display_name = "Frame"
	frame.part_type    = VehiclePart.PartType.FRAME
	frame.mass         = 20.0
	frame.color        = Color(0.55, 0.55, 0.62)
	_parts.append(frame)


func _deferred_init() -> void:
	_camera = get_viewport().get_camera_3d()
	_init_ghosts()
	_init_hud()


# ── Ghost meshes ──────────────────────────────────────────────────────────────

func _init_ghosts() -> void:
	_mat_place = StandardMaterial3D.new()
	_mat_place.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_place.albedo_color  = Color(0.1, 1.0, 0.3, 0.45)
	_mat_place.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_place.no_depth_test = true

	_mat_remove = StandardMaterial3D.new()
	_mat_remove.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_remove.albedo_color  = Color(1.0, 0.45, 0.05, 0.65)
	_mat_remove.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_remove.no_depth_test = true

	_ghost_place = MeshInstance3D.new()
	_ghost_place.material_override = _mat_place
	_ghost_place.visible = false
	_update_ghost_mesh()

	_ghost_remove = MeshInstance3D.new()
	_ghost_remove.material_override = _mat_remove
	_ghost_remove.visible = false
	var rb := BoxMesh.new()
	rb.size = Vector3.ONE * Vehicle.CELL_SIZE * 0.98
	_ghost_remove.mesh = rb

	get_tree().current_scene.add_child(_ghost_place)
	get_tree().current_scene.add_child(_ghost_remove)


func _update_ghost_mesh() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * Vehicle.CELL_SIZE * 0.98
	_ghost_place.mesh = box
	_ghost_place.material_override = _mat_place


# ── HUD ───────────────────────────────────────────────────────────────────────

func _init_hud() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer   = 10
	_canvas.visible = false
	add_child(_canvas)
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.size = Vector2(290, 10)
	_panel.position = Vector2(24, -24)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color                = Color(0.06, 0.06, 0.09, 0.88)
	style.corner_radius_top_left  = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left   = 16
	style.content_margin_right  = 16
	style.content_margin_top    = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "▣  BUILD MODE"
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	_status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_status_label)

	_grab_label = Label.new()
	_grab_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_grab_label.add_theme_font_size_override("font_size", 14)
	_grab_label.text = ""
	vbox.add_child(_grab_label)

	vbox.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "[LMB] Place   [RMB] Delete\n[E] Grab / Release"
	hint.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58))
	hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hint)

	_refresh_hud()


func _refresh_hud() -> void:
	if _hovered_vehicle:
		_status_label.text = "Parts: %d  |  Mass: %.0f kg" % [
			_hovered_vehicle.placed_parts.size(),
			_hovered_vehicle.mass,
		]
	elif _spawn_on_ground:
		_status_label.text = "Look at ground — LMB to start building"
	else:
		_status_label.text = "No vehicle targeted"

	if _removal_valid:
		_grab_label.text = "⬛ RMB to delete highlighted part"
	else:
		_grab_label.text = ""


# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_3d()
		return

	_update_ghost()
	_refresh_hud()
	# Show HUD only when something is targetable or an object is held
	_canvas.visible = _hovered_vehicle != null or _spawn_on_ground or _grabbed != null


func _physics_process(_delta: float) -> void:
	if not _grabbed:
		return
	if not is_instance_valid(_grabbed):
		_grabbed = null
		return
	if not _camera:
		return
	var target := _camera.global_position + (-_camera.global_transform.basis.z) * GRAB_DIST
	_grabbed.global_position = target


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("grab"):
			if _grabbed:
				_release_grab()
			else:
				_try_grab()
			get_viewport().set_input_as_handled()
			return

	# Block build inputs while holding something
	if _grabbed:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_try_place()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				_try_remove()
				get_viewport().set_input_as_handled()
# ── Raycasting ────────────────────────────────────────────────────────────────

func _raycast() -> Dictionary:
	if not _camera:
		return {}
	var space  := get_viewport().get_world_3d().direct_space_state
	var origin := _camera.global_position
	var fwd    := -_camera.global_transform.basis.z
	var query  := PhysicsRayQueryParameters3D.create(origin, origin + fwd * BUILD_RANGE)
	var player := get_tree().get_first_node_in_group("Player")
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	if _grabbed and is_instance_valid(_grabbed):
		exclude.append(_grabbed.get_rid())
	query.exclude = exclude
	return space.intersect_ray(query)


func _update_ghost() -> void:
	_ghost_place.visible  = false
	_ghost_remove.visible = false
	_hovered_vehicle      = null
	_placement_valid      = false
	_removal_valid        = false
	_spawn_on_ground      = false

	var hit := _raycast()
	if hit.is_empty():
		return

	var hit_pos: Vector3    = hit["position"]
	var hit_normal: Vector3 = hit["normal"]
	var hit_body            = hit["collider"]
	_last_hit_normal = hit_normal

	var v: Vehicle = null
	if hit_body is Vehicle:
		v = hit_body as Vehicle

	if v:
		_hovered_vehicle = v
		_hovered_place_pos  = v.world_to_grid(hit_pos + hit_normal * Vehicle.CELL_SIZE * 0.6)
		_hovered_remove_pos = v.world_to_grid(hit_pos - hit_normal * Vehicle.CELL_SIZE * 0.25)
		_placement_valid    = v.can_place(_hovered_place_pos)
		_removal_valid      = v.cell_map.has(_hovered_remove_pos)

		if _placement_valid:
			_show_place_ghost(v, _hovered_place_pos, hit_normal)

		if _removal_valid:
			var rp := v.to_global(v.grid_to_local(_hovered_remove_pos))
			_ghost_remove.global_transform = Transform3D(v.global_basis, rp)
			_ghost_remove.visible = true
	else:
		# Hitting the ground — offer to start a new vehicle here
		if hit_normal.y > 0.7:
			_spawn_on_ground = true
			_ground_spawn_pos = hit_pos + hit_normal * Vehicle.CELL_SIZE * 0.5
			_ghost_place.global_transform = Transform3D(Basis(), _ground_spawn_pos)
			_ghost_place.visible = true


func _show_place_ghost(v: Vehicle, gp: Vector3i, _face_normal: Vector3) -> void:
	var world_pos := v.to_global(v.grid_to_local(gp))
	_ghost_place.global_transform = Transform3D(v.global_basis, world_pos)
	_ghost_place.visible = true



# ── Place / Remove ────────────────────────────────────────────────────────────

func _try_place() -> void:
	if _spawn_on_ground:
		_spawn_vehicle_at_ground()
		return
	if not _hovered_vehicle or not _placement_valid:
		return
	_hovered_vehicle.add_part(_parts[0], _hovered_place_pos, _last_hit_normal)
	_refresh_hud()


func _spawn_vehicle_at_ground() -> void:
	var v: Vehicle = _vehicle_scene.instantiate() as Vehicle
	get_tree().current_scene.add_child(v)
	v.global_position = _ground_spawn_pos
	v.add_part(_parts[0], Vector3i.ZERO, Vector3.UP)
	_hovered_vehicle = v
	_refresh_hud()


func _try_remove() -> void:
	if not _hovered_vehicle or not _removal_valid:
		return
	_hovered_vehicle.remove_part_at_cell(_hovered_remove_pos)
	_refresh_hud()


# ── Grab mechanic (E key, works outside build mode) ───────────────────────────

func _try_grab() -> void:
	if not _camera:
		return
	var space  := get_viewport().get_world_3d().direct_space_state
	var origin := _camera.global_position
	var fwd    := -_camera.global_transform.basis.z
	var query  := PhysicsRayQueryParameters3D.create(origin, origin + fwd * GRAB_RANGE)
	var player := get_tree().get_first_node_in_group("Player")
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var body = hit["collider"]
	if body is RigidBody3D:
		_grabbed = body as RigidBody3D
		_grabbed.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		_grabbed.freeze = true


func _release_grab() -> void:
	if _grabbed and is_instance_valid(_grabbed):
		_grabbed.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		_grabbed.freeze = false
		_grabbed.gravity_scale = 1.0
		_grabbed.linear_velocity  = Vector3.ZERO
		_grabbed.angular_velocity = Vector3.ZERO
	_grabbed = null


func _exit_tree() -> void:
	_release_grab()
