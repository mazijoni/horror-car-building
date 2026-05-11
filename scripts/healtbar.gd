extends Control

@onready var health_number: Label = $HealthNumber

@export var max_health := 100
@export var line_width := 2.0
@export var scan_speed := 600.0
@export var fade_speed := 2.5
@export var base_amplitude := 10.0
@export var max_amplitude := 40.0
@export var point_spacing := 6

const ECG_PATTERN := [
	0.0, 0.0, 0.0,
	0.2,
	-0.6,
	2.5,
	-1.2,
	0.4,
	0.0, 0.0, 0.0
]

var health := 100
var scan_x := 0.0
var pattern_index := 0
var points: PackedVector2Array = []
var alphas: PackedFloat32Array = []
var last_added_x := -INF

func _ready():
	set_process(true)
	health_number.text = str(health)
	health_number.modulate = _get_health_color()

func set_health(value: int):
	health = clamp(value, 0, max_health)
	if health == 0:
		health_number.text = "\\\\\\"
	else:
		health_number.text = str(health)
	health_number.modulate = _get_health_color()

func _process(delta):
	# Fade existing points
	for i in range(alphas.size()):
		alphas[i] = max(alphas[i] - fade_speed * delta, 0.0)

	# Advance scan
	scan_x += scan_speed * delta
	if scan_x >= size.x:
		scan_x = 0.0
		pattern_index = 0
		last_added_x = -INF

	# Add point at fixed spacing
	if scan_x - last_added_x >= point_spacing:
		_add_point(scan_x)

	# Prune fully faded points
	var i := 0
	while i < alphas.size():
		if alphas[i] <= 0.0:
			points.remove_at(i)
			alphas.remove_at(i)
		else:
			i += 1

	queue_redraw()

func _add_point(x_pos: float):
	last_added_x = x_pos
	var health_ratio := float(health) / max_health
	var amplitude := base_amplitude + (base_amplitude * (1.0 - health_ratio))
	if health == 0:
		amplitude = 0.0
	var center_y := size.y * 0.5
	var spike_value: float = ECG_PATTERN[pattern_index]
	pattern_index = (pattern_index + 1) % ECG_PATTERN.size()
	var y := center_y + spike_value * amplitude
	points.append(Vector2(x_pos, y))
	alphas.append(1.0)

func _draw():
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		if alphas[i] <= 0.0:
			continue
		if points[i + 1].x < points[i].x:
			continue
		var color := _get_health_color()
		color.a = alphas[i]
		var outline_color := Color(0.0, 0.0, 0.0, alphas[i])
		draw_line(points[i], points[i + 1], outline_color, line_width + 2.0)
		draw_line(points[i], points[i + 1], color, line_width)

func _get_health_color() -> Color:
	if health <= 25:
		return Color(1.0, 0.2, 0.2)
	elif health <= 75:
		return Color(1.0, 0.9, 0.2)
	else:
		return Color(0.2, 1.0, 0.2)
