class_name BuildManager
extends Node

static var registry: PartRegistry = null

const BUILD_RANGE: float  = 14.0
const GRAB_RANGE: float   = 6.0
const GRAB_DIST: float    = 3.2
const GRAB_SPRING: float  = 16.0
const SLOT_SIZE: int      = 68

enum BuildTool { PLACE, GRAB, WRENCH }

# ── State ──────────────────────────────────────────────────────────────────────
var is_building: bool = false
var current_tool: BuildTool = BuildTool.PLACE

# selected_part_idx == _part_list.size()  →  wrench selected
var selected_part_idx: int = 0
var _part_list: Array[PartDefinition] = []

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

var _floor_snap_active: bool = false
var _floor_snap_world_pos: Vector3 = Vector3.ZERO

# ── UI nodes ───────────────────────────────────────────────────────────────────
var _camera: Camera3D
var _ghost: GhostPreview
var _undo_redo: UndoRedoSystem
var _canvas: CanvasLayer
var _hotbar_box: HBoxContainer
var _hotbar_slots: Array[Panel] = []
var _mode_label: Label
var _selected_name_label: Label
var _hint_label: Label
var _info_panel: PanelContainer

# ── Hand item (block shown in player's view) ───────────────────────────────────
var _hand_node: Node3D
var _hand_mesh: MeshInstance3D

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
	_init_hand_item()
	_refresh_hud()

# ── HUD ───────────────────────────────────────────────────────────────────────

func _init_hud() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer   = 10
	_canvas.visible = false
	add_child(_canvas)

	# ── Hotbar (bottom-centre) ────────────────────────────────────────────────
	# Part-name label above the hotbar
	_selected_name_label = _make_label("", 16, Color(1, 1, 1))
	_selected_name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_selected_name_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_selected_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_name_label.offset_top    = -(SLOT_SIZE + 44)
	_selected_name_label.offset_bottom = -(SLOT_SIZE + 24)
	_selected_name_label.add_theme_constant_override("shadow_offset_x", 2)
	_selected_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_selected_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_canvas.add_child(_selected_name_label)

	# Slot row anchored bottom-center
	_hotbar_box = HBoxContainer.new()
	_hotbar_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hotbar_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar_box.add_theme_constant_override("separation", 4)
	_hotbar_box.offset_top    = -(SLOT_SIZE + 10)
	_hotbar_box.offset_bottom = -10
	_canvas.add_child(_hotbar_box)

	# Build one slot per part + one wrench slot
	var total := _part_list.size() + 1
	for i in range(total):
		var slot := _make_hotbar_slot(i)
		_hotbar_slots.append(slot)
		_hotbar_box.add_child(slot)

	# ── Mode label (top-left) ─────────────────────────────────────────────────
	_mode_label = _make_label("▣ BUILD", 18, Color(1.0, 0.85, 0.1))
	_mode_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_mode_label.position = Vector2(20, 20)
	_canvas.add_child(_mode_label)

	# ── Vehicle info panel (top-right) ────────────────────────────────────────
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

func _make_hotbar_slot(idx: int) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.08, 0.1, 0.88)
	normal_style.border_color = Color(0.25, 0.25, 0.3, 1)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(6)
	slot.add_theme_stylebox_override("panel", normal_style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vbox)

	# Slot number (top-left via a small label)
	var num_str: String
	if idx < _part_list.size():
		num_str = str((idx + 1) % 10)   # 1-9, then 0
	else:
		num_str = "W"
	var num_lbl := _make_label(num_str, 11, Color(0.5, 0.5, 0.55))
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(num_lbl)

	# Category colour dot / icon area
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 6)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if idx < _part_list.size():
		dot.color = _category_color(_part_list[idx].category)
	else:
		dot.color = Color(1.0, 0.5, 0.05)   # wrench = orange
	vbox.add_child(dot)

	# Short part name
	var name_str: String
	if idx < _part_list.size():
		name_str = _short_name(_part_list[idx].display_name)
	else:
		name_str = "Wrench"
	var name_lbl := _make_label(name_str, 10, Color(0.75, 0.75, 0.8))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_lbl)

	return slot

func _category_color(cat: PartDefinition.Category) -> Color:
	match cat:
		PartDefinition.Category.STRUCTURAL: return Color(0.4, 0.5, 0.7)
		PartDefinition.Category.MECHANICAL: return Color(0.8, 0.5, 0.1)
		PartDefinition.Category.POWER:      return Color(0.9, 0.8, 0.1)
		PartDefinition.Category.CONTROL:    return Color(0.1, 0.7, 0.8)
	return Color(0.5, 0.5, 0.5)

func _short_name(full: String) -> String:
	if full.length() <= 8:
		return full
	return full.substr(0, 7) + "…"

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
	_refresh_hotbar()
	_refresh_vehicle_info()

func _refresh_hotbar() -> void:
	for i in _hotbar_slots.size():
		var slot := _hotbar_slots[i]
		var selected := i == selected_part_idx
		var style := StyleBoxFlat.new()
		if selected:
			style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
			style.border_color = Color(1.0, 0.9, 0.2, 1.0)
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(0.08, 0.08, 0.1, 0.88)
			style.border_color = Color(0.25, 0.25, 0.3, 1)
			style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", style)

	# Part name above hotbar
	if _is_wrench_selected():
		_selected_name_label.text = "🔧 Wrench"
	elif not _part_list.is_empty():
		var def := _part_list[selected_part_idx]
		var suffix := ""
		_selected_name_label.text = def.display_name + suffix

	# Mode label
	var mode_txt := "▣ BUILD"
	if _is_wrench_selected():
		mode_txt += "  [Wrench]"
	elif current_tool == BuildTool.GRAB:
		mode_txt += "  [Grab]"
	if mirror_mode:
		mode_txt += "  ↔"
	_mode_label.text = mode_txt

func _refresh_vehicle_info() -> void:
	if not _target_vehicle:
		_hint_label.text = "Aim at a vehicle or floor\n\n[RMB] Place  [LMB] Remove\n[1-9,0] Select  [R] Rotate\n[P] Paint  [M] Mirror\n[N] New  [B] Exit"
		return
	var v := _target_vehicle
	var ps := v.power_system
	var txt := "Parts: %d  Mass: %.0fkg\n" % [v.parts.size(), v.mass]
	if ps:
		txt += "Power: %.0f/%.0fW  Fuel:%.1fL\n" % [ps.get_available_power(), ps._power_demand, ps.get_fuel()]
	txt += "Orient: %d/23" % orientation_idx
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
		elif key.keycode == KEY_TAB:
			_cycle_target_vehicle()
			get_viewport().set_input_as_handled()
		elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
			_select_slot(key.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_0:
			_select_slot(_part_list.size())   # wrench
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var total_slots := _part_list.size() + 1
		match mb.button_index:
			MOUSE_BUTTON_LEFT:          # LMB = remove (Minecraft style)
				_on_lmb()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:         # RMB = place / wrench (Minecraft style)
				_on_rmb()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				_select_slot((selected_part_idx - 1 + total_slots) % total_slots)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_select_slot((selected_part_idx + 1) % total_slots)
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
# LMB = REMOVE  (Minecraft convention)
func _on_lmb() -> void:
	if _is_pasting:
		_cancel_paste()
		return
	if _target_vehicle and _removal_valid:
		var old_part := _target_vehicle.parts.get(_hovered_remove_pos) as VehiclePartBase
		if old_part:
			var saved := old_part.to_save_data()
			var action := UndoRedoSystem.RemoveAction.new(_target_vehicle, saved, registry)
			_undo_redo.execute(action)

# RMB = PLACE / WRENCH  (Minecraft convention)
func _on_rmb() -> void:
	if _is_pasting:
		_confirm_paste()
		return

	if _is_wrench_selected():
		_do_wrench_rotate()
		return

	if _floor_snap_active and _placement_valid:
		_spawn_vehicle_at_floor_snap()
		return

	if _target_vehicle and _placement_valid:
		var def := _part_list[selected_part_idx]
		var action := UndoRedoSystem.PlaceAction.new(
			_target_vehicle, def.part_id, _hovered_place_pos, orientation_idx, registry
		)
		_undo_redo.execute(action)
		if mirror_mode:
			var mirror_pos := _get_mirror_pos(_hovered_place_pos)
			var mirror_orient := _get_mirror_orient(orientation_idx)
			if _target_vehicle.can_place(mirror_pos, def):
				var mirror_action := UndoRedoSystem.PlaceAction.new(
					_target_vehicle, def.part_id, mirror_pos, mirror_orient, registry
				)
				_undo_redo.execute(mirror_action)

func _toggle_build() -> void:
	is_building = not is_building
	_canvas.visible = is_building
	if _hand_node:
		_hand_node.visible = is_building
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
				_target_vehicle, psd.part_id, paste_pos, psd.orientation_idx, registry
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
	_placement_valid  = false
	_removal_valid    = false
	_target_vehicle   = null
	_floor_snap_active = false

	var hit := _raycast()
	if hit.is_empty():
		return

	var hit_pos: Vector3    = hit["position"]
	var hit_normal: Vector3 = hit["normal"]
	var hit_body            = hit["collider"]
	_last_hit_normal = hit_normal

	var def: PartDefinition = null
	if not _is_wrench_selected() and not _part_list.is_empty():
		def = _part_list[selected_part_idx]
	var current_ghost_id := def.part_id if def else ""
	_ghost.update_for_part(current_ghost_id, registry)

	# ── Resolve which VehicleRoot was hit ─────────────────────────────────────
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

	# ── Snap to vehicle grid ───────────────────────────────────────────────────
	if v:
		_target_vehicle = v
		_hovered_place_pos  = v.world_to_grid(hit_pos + hit_normal * VehicleRoot.CELL_SIZE * 0.6)
		_hovered_remove_pos = v.world_to_grid(hit_pos - hit_normal * VehicleRoot.CELL_SIZE * 0.25)
		_placement_valid    = not _is_wrench_selected() and v.can_place(_hovered_place_pos, def)
		_removal_valid      = v.cell_map.has(_hovered_remove_pos)

		if not _is_wrench_selected() and def:
			var orient    := PartDefinition.get_orientation(orientation_idx)
			var world_pos := v.to_global(v.grid_to_local(_hovered_place_pos))
			_ghost.show_place(Transform3D(v.global_basis * orient, world_pos), _placement_valid)

		if _removal_valid:
			var rp := v.to_global(v.grid_to_local(_hovered_remove_pos))
			_ghost.show_highlight(Transform3D(v.global_basis, rp))

	# ── Snap to floor world-grid (static geometry) ────────────────────────────
	else:
		var cell := VehicleRoot.CELL_SIZE
		# Snap X/Z to cell grid; keep actual surface Y
		var snapped := Vector3(
			snappedf(hit_pos.x, cell),
			hit_pos.y,
			snappedf(hit_pos.z, cell)
		)
		# Lift ghost half a cell above the surface along the normal
		_floor_snap_world_pos = snapped + hit_normal * cell * 0.5
		_floor_snap_active    = true
		_placement_valid      = def != null

		if def:
			var orient := PartDefinition.get_orientation(orientation_idx)
			_ghost.show_place(Transform3D(orient, _floor_snap_world_pos), _placement_valid)

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

func _spawn_vehicle_at_floor_snap() -> void:
	if _part_list.is_empty() or _is_wrench_selected():
		return
	var scene: PackedScene = load("res://scenes/vehicle_system/vehicle_root.tscn")
	var v: VehicleRoot = scene.instantiate() as VehicleRoot
	get_tree().current_scene.add_child(v)
	v.global_position = _floor_snap_world_pos
	var def := _part_list[selected_part_idx]
	var part := registry.instantiate_part(def.part_id)
	if part:
		v.add_part(part, Vector3i.ZERO, orientation_idx)
	_target_vehicle = v

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

var _grab_local_offset: Vector3 = Vector3.ZERO   # hit point in body-local space

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
	else:
		return
	# Record where on the body the player clicked, in local space
	_grab_local_offset = _grabbed.to_local(hit["position"])

func _release_grab() -> void:
	if _grabbed and is_instance_valid(_grabbed):
		_grabbed.gravity_scale = 1.0
	_grabbed = null
	_grab_local_offset = Vector3.ZERO

func _process_grab(delta: float) -> void:
	if not _grabbed or not _camera:
		return
	if not is_instance_valid(_grabbed):
		_grabbed = null
		return
	var forward := -_camera.global_transform.basis.z
	# The world-space point on the object where the player clicked
	var grab_world := _grabbed.to_global(_grab_local_offset)
	# Where that point should be (in front of camera)
	var target := _camera.global_position + forward * GRAB_DIST
	var diff   := target - grab_world
	# Pull velocity — proportional to distance, capped to avoid tunnelling
	var pull_speed := clampf(diff.length() * GRAB_SPRING, 0.0, 30.0)
	_grabbed.linear_velocity  = diff.normalized() * pull_speed if diff.length_squared() > 0.0001 else Vector3.ZERO
	_grabbed.angular_velocity = Vector3.ZERO
	_grabbed.gravity_scale    = 0.0

func _exit_tree() -> void:
	_release_grab()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _is_wrench_selected() -> bool:
	return selected_part_idx >= _part_list.size()

func _select_slot(idx: int) -> void:
	var total := _part_list.size() + 1
	selected_part_idx = clampi(idx, 0, total - 1)
	_update_hand_item()
	_refresh_hud()

func _do_wrench_rotate() -> void:
	if not _target_vehicle or not _removal_valid:
		return
	var pos := _hovered_remove_pos
	var part := _target_vehicle.parts.get(pos) as VehiclePartBase
	if not part:
		return
	var new_orient := (part.orientation_idx + 1) % 24
	_target_vehicle.rotate_part(pos, new_orient)

# ── Hand item ─────────────────────────────────────────────────────────────────

func _init_hand_item() -> void:
	if not _camera:
		return
	_hand_node = Node3D.new()
	_hand_node.position   = Vector3(0.35, -0.25, -0.5)
	_hand_node.rotation   = Vector3(0.3, -0.5, 0.15)
	_hand_node.visible    = false
	_camera.add_child(_hand_node)

	_hand_mesh = MeshInstance3D.new()
	_hand_node.add_child(_hand_mesh)
	_update_hand_item()

func _update_hand_item() -> void:
	if not _hand_mesh:
		return
	if _is_wrench_selected():
		# Orange elongated box to represent wrench
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.08, 0.55)
		_hand_mesh.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color        = Color(1.0, 0.5, 0.05)
		mat.emission_enabled    = true
		mat.emission            = Color(0.6, 0.25, 0.0)
		mat.emission_energy_multiplier = 0.5
		_hand_mesh.material_override = mat
	elif not _part_list.is_empty():
		var def := _part_list[selected_part_idx]
		_hand_mesh.mesh = _make_hand_mesh(def)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _category_color(def.category)
		_hand_mesh.material_override = mat

func _make_hand_mesh(def: PartDefinition) -> Mesh:
	if def.category == PartDefinition.Category.MECHANICAL:
		var cm := CylinderMesh.new()
		cm.top_radius    = VehicleRoot.CELL_SIZE * 0.34
		cm.bottom_radius = VehicleRoot.CELL_SIZE * 0.34
		cm.height        = VehicleRoot.CELL_SIZE * 0.5
		return cm
	var bm := BoxMesh.new()
	var s := VehicleRoot.CELL_SIZE * 0.68
	bm.size = Vector3(s, s, s)
	return bm
