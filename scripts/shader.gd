extends Node

@onready var color_rect: ColorRect = get_node_or_null("Camera3D/CanvasLayer/ColorRect")

var flat_enabled := false
var flat_material := StandardMaterial3D.new()

func _ready():
	flat_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			flat_enabled = !flat_enabled
			toggle_flat(get_tree().current_scene)
			toggle_post_process()
			toggle_wireframe()

func toggle_flat(node: Node):
	if node is MeshInstance3D:
		node.material_override = flat_material if flat_enabled else null
	for child in node.get_children():
		toggle_flat(child)

func toggle_post_process():
	if color_rect:
		color_rect.visible = !flat_enabled

func toggle_wireframe():
	var viewport := get_viewport()
	if flat_enabled:
		RenderingServer.viewport_set_debug_draw(
			viewport.get_viewport_rid(),
			RenderingServer.VIEWPORT_DEBUG_DRAW_WIREFRAME
		)
	else:
		RenderingServer.viewport_set_debug_draw(
			viewport.get_viewport_rid(),
			RenderingServer.VIEWPORT_DEBUG_DRAW_DISABLED
		)
