class_name BuildManager
extends Node

static var registry: PartRegistry = null

const BUILD_RANGE: float  = 14.0
const GRAB_RANGE: float   = 6.0
const GRAB_DIST: float    = 3.2
const GRAB_SPRING: float  = 16.0
const PAINT_RANGE: float  = 10.0

enum BuildTool { PLACE, REMOVE, PAINT, GRAB }

# ── State ──────────────────────────────────────────────────────────────────────
var is_building: bool = false
var current_tool: BuildTool = BuildTool.PLACE

var selected_part_idx: int = 0
var _part_list: Array[PartDefinition] = []

var paint_color: Color = Color(0.8, 0.1, 0.1)

var orientation_idx: int = 0

var mirror_mode: bool = false
var mirror_axis: int = 0

var free_placement: bool = false

var _clipboard: Array[PartSaveData] = []
var _clipboard_origin: Vector3i = Vector3i.ZERO
var _is_pasting: bool = false

var _grabbed: RigidBody3D = null

var _target_vehicle: VehicleRoot = null
var _hovered_place_pos: Vector3i
var _hovered_remove_pos: Vector3i
var _placement_valid: bool = false
var _removal_valid: bool   = false
var _last_hit_normal: Vector3 = Vector3.UP

var _camera: Camera3D
var _ghost: GhostPreview
var _undo_redo: UndoRedoSystem
var _canvas: CanvasLayer
var _panel: Panel
var _part_labels: Array[Label] = []
var _tool_label: Label
var _status_label: Label
var _hint_label: Label
var _info_panel: PanelContainer

func _ready() -> void:
	add_to_group("build_manager")
	_undo_redo = UndoRedoSystem.new()
	add_child(_undo_redo)
	registry = PartRegistry.new()
	add_child(registry)
	_part_list = registry.get_all_definitions()
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	_camera = get_viewport().get_camera_3d()
	_ghost = GhostPreview.new()
	get_tree().current_scene.add_child(_ghost)
	_init_hud()
	_refresh_part_list_display()

# ── HUD ───────────────────────────────────────────────────────────────────────

func _init_hud() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer   = 10
	_canvas.visible = false
	add_child(_canvas)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.size = Vector2(320, 10)
	_panel.position = Vector2(24, -24)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_style_panel(_panel, Color(0.05, 0.05, 0.08, 0.90))
	_canvas.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	_tool_label = _make_label("▣ BUILD MODE", 20, Color(1.0, 0.85, 0.1))
	vbox.add_child(_tool_label)
	vbox.add_child(HSeparator.new())

	for i: int in _part_list.size():
		var lbl := _make_label(_part_list[i].display_name, 15, Color(0.5, 0.5, 0.6))
		_part_labels.append(lbl)
		vbox.add_child(lbl)

	vbox.add_child(HSeparator.new())

	_status_label = _make_label("", 14, Color(0.6, 0.72, 0.85))
	vbox.add_child(_status_label)

	vbox.add_child(HSeparator.new())

	var hints := [
		"[LMB] Place  [RMB] Remove",
		"[R] Rotate Y  [Shift+R] Rotate X  [Ctrl+R] Rotate Z",
		"[Scroll] Next part  [P] Paint mode",
		"[G] Free placement  [M] Mirror",
		"[Ctrl+C/V] Copy/Paste  [Ctrl+Z/Y] Undo/Redo",
		"[N] New vehicle  [Tab] Next vehicle",
		"[E] Grab (outside build)  [B] Exit build",
	]
	for h: String in hints:
		vbox.add_child(_make_label(h, 12, Color(0.4, 0.45, 0.55)))

	_info_panel = PanelContainer.new()
	_info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info_panel.position = Vector2(-300, 20)
	_info_panel.size = Vector2(280, 10)
	_style_panel(_info_panel, Color(0.05, 0.05, 0.08, 0.88))
	_canvas.add_child(_info_panel)

	var ivbox := VBoxContainer.new()
	_info_panel.add_child(ivbox)
	ivbox.add_child(_make_label("VEHICLE INFO", 16, Color(0.9, 0.6, 0.1)))
	_hint_label = _make_label("", 14, Color(0.6, 0.7, 0.8))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	ivbox.add_child(_hint_label)

func _style_panel(p: Control, bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left   = 14
	style.content_margin_right  = 14
	style.content_margin_top    = 12
	style.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", style)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _refresh_hud() -> void:
	_refresh_part_list_display()
	_refresh_status()
	_refresh_vehicle_info()

func _refresh_part_list_display() -> void:
	for i: int in _part_labels.size():
		var def := _part_list[i]
		if i == selected_part_idx:
			_part_labels[i].text = "▶  " + def.display_name + " (" + str(def.mass) + "kg)"
			_part_labels[i].add_theme_color_override("font_color", Color.WHITE)
		else:
			_part_labels[i].text = "    " + def.display_name
			_part_labels[i].add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	match current_tool:
		BuildTool.PLACE:  _tool_label.text = "▣ BUILD  [Place]"
		BuildTool.REMOVE: _tool_label.text = "▣ BUILD  [Remove]"
		BuildTool.PAINT:  _tool_label.text = "▣ BUILD  [Paint]"
	if mirror_mode:
		_tool_label.text += "  ↔ Mirror"
	if free_placement:
		_tool_label.text += "  Free"

func _refresh_status() -> void:
	if _target_vehicle:
		var n := _target_vehicle.parts.size()
		var m := _target_vehicle.mass
		_status_label.text = "Parts: %d  |  Mass: %.0f kg" % [n, m]
		if _removal_valid:
			_status_label.text += "\n⬛ RMB = delete highlighted"
	else:
		_status_label.text = "No vehicle targeted"

func _refresh_vehicle_info() -> void:
	if not _target_vehicle:
		_hint_label.text = "Aim at a vehicle or floor"
		return
	var v := _target_vehicle
	var ps := v.power_system
	var txt := "Parts: %d\nMass: %.1f kg\n" % [v.parts.size(), v.mass]
	if ps:
		txt += "Power: %.0f / %.0f W\nFuel: %.1fL" % [
			ps.get_available_power(), ps._power_demand, ps.get_fuel()
		]
	txt += "\nOrient: %d / 23" % orientation_idx
	_hint_label.text = txt

# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_process_grab(delta)
	if not is_building:
		_ghost.hide_all()
		return
	if not _camera:
		_camera = get_viewport().get_camera_3d()
		return
	_update_ghost()
	_refresh_hud()

func _input(event: InputEvent) -> void:
	_handle_toggle_keys(event)
	if not is_building:
		_handle_grab_input(event)
		return
	_handle_build_input(event)

func _handle_toggle_keys(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if key.is_action("build_toggle"):
		_toggle_build()
		get_viewport().set_input_as_handled()
	elif key.is_action("spawn_vehicle"):
		_spawn_new_vehicle()
		get_viewport().set_input_as_handled()

func _handle_build_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var ctrl  := key.ctrl_pressed
		var shift := key.shift_pressed

		if ctrl and key.keycode == KEY_Z:
			_undo_redo.undo()
			get_viewport().set_input_as_handled()
		elif ctrl and (key.keycode == KEY_Y or (shift and key.keycode == KEY_Z)):
			_undo_redo.redo()
			get_viewport().set_input_as_handled()
		elif ctrl and key.keycode == KEY_C:
			_copy_selection()
			get_viewport().set_input_as_handled()
		elif ctrl and key.keycode == KEY_V:
			_start_paste()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_R:
			if ctrl:
				_rotate_orientation(Vector3.FORWARD)
			elif shift:
				_rotate_orientation(Vector3.RIGHT)
			else:
				_rotate_orientation(Vector3.UP)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_G:
			free_placement = not free_placement
			_refresh_hud()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_M:
			mirror_mode = not mirror_mode
			_refresh_hud()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_P:
			current_tool = BuildTool.PAINT if current_tool != BuildTool.PAINT else BuildTool.PLACE
			_refresh_hud()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_TAB:
			_cycle_target_vehicle()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_on_lmb()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				_on_rmb()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				selected_part_idx = (selected_part_idx - 1 + _part_list.size()) % _part_list.size()
				_refresh_hud()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				selected_part_idx = (selected_part_idx + 1) % _part_list.size()
				_refresh_hud()
				get_viewport().set_input_as_handled()

func _handle_grab_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.is_action("grab"):
			if _grabbed:
				_release_grab()
			else:
				_try_grab()
			get_viewport().set_input_as_handled()

# ── Rotation ──────────────────────────────────────────────────────────────────

func _rotate_orientation(axis: Vector3) -> void:
	var cur := PartDefinition.get_orientation(orientation_idx)
	var rot := Basis(axis, PI * 0.5)
	var target := (rot * cur).orthonormalized()
	var best := orientation_idx
	var best_dot := -2.0
	for i: int in 24:
		var candidate := PartDefinition.get_orientation(i)
		var dot: float = 0.0
		for col: int in 3:
			dot += candidate[col].dot(target[col])
		if dot > best_dot:
			best_dot = dot
			best = i
	orientation_idx = best

# ── Actions ───────────────────────────────────────────────────────────────────

func _on_lmb() -> void:
	match current_tool:
		BuildTool.PLACE:
			if _is_pasting:
				_confirm_paste()
			elif _target_vehicle and _placement_valid:
				var def := _part_list[selected_part_idx]
				var action := UndoRedoSystem.PlaceAction.new(
					_target_vehicle, def.part_id, _hovered_place_pos, orientation_idx,
					paint_color, registry
				)
				_undo_redo.execute(action)
				if mirror_mode:
					var mirror_pos := _get_mirror_pos(_hovered_place_pos)
					var mirror_orient := _get_mirror_orient(orientation_idx)
					if _target_vehicle.can_place(mirror_pos, def):
						var mirror_action := UndoRedoSystem.PlaceAction.new(
							_target_vehicle, def.part_id, mirror_pos, mirror_orient,
							paint_color, registry
						)
						_undo_redo.execute(mirror_action)
		BuildTool.PAINT:
			if _target_vehicle and _removal_valid:
				var old_part := _target_vehicle.parts.get(_hovered_remove_pos) as VehiclePartBase
				if old_part:
					var action := UndoRedoSystem.PaintAction.new(
						_target_vehicle, _hovered_remove_pos, old_part.part_color, paint_color
					)
					_undo_redo.execute(action)

func _on_rmb() -> void:
	if _is_pasting:
		_cancel_paste()
		return
	if _target_vehicle and _removal_valid:
		var old_part := _target_vehicle.parts.get(_hovered_remove_pos) as VehiclePartBase
		if old_part:
			var saved := old_part.to_save_data()
			var action := UndoRedoSystem.RemoveAction.new(_target_vehicle, saved, registry)
			_undo_redo.execute(action)

func _toggle_build() -> void:
	is_building = not is_building
	_canvas.visible = is_building
	if _grabbed:
		_release_grab()

# ── Copy / Paste ──────────────────────────────────────────────────────────────

func _copy_selection() -> void:
	if not _target_vehicle:
		return
	if not _removal_valid:
		_clipboard.clear()
		var min_gp := Vector3i(999, 999, 999)
		for gp: Vector3i in _target_vehicle.parts:
			min_gp.x = mini(min_gp.x, gp.x)
			min_gp.y = mini(min_gp.y, gp.y)
			min_gp.z = mini(min_gp.z, gp.z)
		_clipboard_origin = min_gp
		for gp: Vector3i in _target_vehicle.parts:
			var p := _target_vehicle.parts[gp] as VehiclePartBase
			var psd := p.to_save_data()
			psd.grid_pos = gp - min_gp
			_clipboard.append(psd)
		print("BuildManager: Copied %d parts" % _clipboard.size())
	else:
		var p := _target_vehicle.parts.get(_hovered_remove_pos) as VehiclePartBase
		if p:
			_clipboard = [p.to_save_data()]
			_clipboard[0].grid_pos = Vector3i.ZERO
			_clipboard_origin = Vector3i.ZERO
			print("BuildManager: Copied 1 part")

func _start_paste() -> void:
	if _clipboard.is_empty():
		return
	_is_pasting = true

func _confirm_paste() -> void:
	if not _target_vehicle or not _is_pasting:
		return
	for psd: PartSaveData in _clipboard:
		var paste_pos := _hovered_place_pos + psd.grid_pos
		if _target_vehicle.can_place(paste_pos, registry.get_definition(psd.part_id)):
			var action := UndoRedoSystem.PlaceAction.new(
				_target_vehicle, psd.part_id, paste_pos, psd.orientation_idx, psd.color, registry
			)
			_undo_redo.execute(action)
	_is_pasting = false

func _cancel_paste() -> void:
	_is_pasting = false

# ── Mirror helpers ────────────────────────────────────────────────────────────

func _get_mirror_pos(gp: Vector3i) -> Vector3i:
	match mirror_axis:
		0: return Vector3i(-gp.x, gp.y, gp.z)
		1: return Vector3i(gp.x, -gp.y, gp.z)
		2: return Vector3i(gp.x, gp.y, -gp.z)
	return gp

func _get_mirror_orient(orient_idx: int) -> int:
	var cur := PartDefinition.get_orientation(orient_idx)
	var mirrored: Basis
	match mirror_axis:
		0: mirrored = Basis(Vector3(-1,0,0), Vector3(0,1,0), Vector3(0,0,1)) * cur
		1: mirrored = Basis(Vector3(1,0,0), Vector3(0,-1,0), Vector3(0,0,1)) * cur
		2: mirrored = Basis(Vector3(1,0,0), Vector3(0,1,0), Vector3(0,0,-1)) * cur
		_: return orient_idx
	mirrored = mirrored.orthonormalized()
	var best := orient_idx
	var best_dot := -2.0
	for i: int in 24:
		var c := PartDefinition.get_orientation(i)
		var dot: float = c.x.dot(mirrored.x) + c.y.dot(mirrored.y) + c.z.dot(mirrored.z)
		if dot > best_dot:
			best_dot = dot
			best = i
	return best

# ── Raycasting ────────────────────────────────────────────────────────────────

func _raycast(range_val: float = BUILD_RANGE) -> Dictionary:
	if not _camera:
		return {}
	var space  := get_viewport().get_world_3d().direct_space_state
	var origin := _camera.global_position
	var fwd    := -_camera.global_transform.basis.z
	var query  := PhysicsRayQueryParameters3D.create(origin, origin + fwd * range_val)
	var player := get_tree().get_first_node_in_group("Player")
	if player:
		query.exclude = [player]
	return space.intersect_ray(query)

func _update_ghost() -> void:
	_ghost.hide_all()
	_placement_valid = false
	_removal_valid   = false
	_target_vehicle  = null

	var hit := _raycast()
	if hit.is_empty():
		return

	var hit_pos: Vector3    = hit["position"]
	var hit_normal: Vector3 = hit["normal"]
	var hit_body            = hit["collider"]
	_last_hit_normal = hit_normal

	var v: VehicleRoot = null
	if hit_body is VehicleRoot:
		v = hit_body as VehicleRoot
	elif hit_body is RigidBody3D:
		for node in get_tree().get_nodes_in_group("vehicle"):
			if node is VehicleRoot:
				var vr := node as VehicleRoot
				for gp: Vector3i in vr.parts:
					var part := vr.parts[gp] as VehiclePartBase
					if part and part.mechanical_body == hit_body:
						v = vr
						break
				if v:
					break

	var def := _part_list[selected_part_idx] if not _part_list.is_empty() else null
	var current_ghost_id := def.part_id if def else ""
	_ghost.update_for_part(current_ghost_id, registry)

	if v:
		_target_vehicle = v
		_hovered_place_pos  = v.world_to_grid(hit_pos + hit_normal * VehicleRoot.CELL_SIZE * 0.6)
		_hovered_remove_pos = v.world_to_grid(hit_pos - hit_normal * VehicleRoot.CELL_SIZE * 0.25)
		_placement_valid    = v.can_place(_hovered_place_pos, def)
		_removal_valid      = v.cell_map.has(_hovered_remove_pos)

		if def:
			var orient := PartDefinition.get_orientation(orientation_idx)
			var world_pos := v.to_global(v.grid_to_local(_hovered_place_pos))
			var t := Transform3D(v.global_basis * orient, world_pos)
			_ghost.show_place(t, _placement_valid)

		if _removal_valid:
			var rp := v.to_global(v.grid_to_local(_hovered_remove_pos))
			_ghost.show_remove(Transform3D(v.global_basis, rp))
	else:
		var nearest := _nearest_vehicle()
		if not nearest:
			return
		_target_vehicle = nearest
		_hovered_place_pos = nearest.world_to_grid(hit_pos + hit_normal * VehicleRoot.CELL_SIZE * 0.5)
		_placement_valid = nearest.can_place(_hovered_place_pos, def)
		if def and _placement_valid:
			var orient := PartDefinition.get_orientation(orientation_idx)
			var world_pos := nearest.to_global(nearest.grid_to_local(_hovered_place_pos))
			var t := Transform3D(nearest.global_basis * orient, world_pos)
			_ghost.show_place(t, true)

func _nearest_vehicle() -> VehicleRoot:
	var best: VehicleRoot = null
	var best_dist := INF
	var cam_pos := _camera.global_position if _camera else Vector3.ZERO
	for node in get_tree().get_nodes_in_group("vehicle"):
		if node is VehicleRoot:
			var d := (node as VehicleRoot).global_position.distance_to(cam_pos)
			if d < best_dist:
				best_dist = d
				best = node as VehicleRoot
	return best

func _cycle_target_vehicle() -> void:
	var vehicles := get_tree().get_nodes_in_group("vehicle")
	if vehicles.is_empty():
		return
	var idx := 0
	for i: int in vehicles.size():
		if vehicles[i] == _target_vehicle:
			idx = (i + 1) % vehicles.size()
			break
	_target_vehicle = vehicles[idx] as VehicleRoot

func _spawn_new_vehicle() -> void:
	if not _camera:
		return
	var scene: PackedScene = load("res://scenes/vehicle_system/vehicle_root.tscn")
	var v: VehicleRoot = scene.instantiate() as VehicleRoot
	get_tree().current_scene.add_child(v)
	var fwd := -_camera.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() > 0.001:
		fwd = fwd.normalized()
	else:
		fwd = Vector3.FORWARD
	v.global_position = _camera.global_position + fwd * 3.5
	v.global_position.y = 0.5

# ── Grab mechanic ─────────────────────────────────────────────────────────────

func _try_grab() -> void:
	if not _camera:
		return
	var hit := _raycast(GRAB_RANGE)
	if hit.is_empty():
		return
	var body = hit["collider"]
	if body is RigidBody3D and not (body is VehicleRoot):
		_grabbed = body as RigidBody3D
		_grabbed.freeze = false
	elif body is VehicleRoot:
		_grabbed = body as VehicleRoot

func _release_grab() -> void:
	if _grabbed and is_instance_valid(_grabbed):
		_grabbed.gravity_scale = 1.0
	_grabbed = null

func _process_grab(delta: float) -> void:
	if not _grabbed or not _camera:
		return
	if not is_instance_valid(_grabbed):
		_grabbed = null
		return
	var target := _camera.global_position + (-_camera.global_transform.basis.z) * GRAB_DIST
	var diff   := target - _grabbed.global_position
	_grabbed.linear_velocity  = diff * GRAB_SPRING
	_grabbed.angular_velocity = _grabbed.angular_velocity * 0.7
	_grabbed.gravity_scale    = 0.0

func _exit_tree() -> void:
	_release_grab()
