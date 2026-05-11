extends Label

var fps_sum := 0.0
var frame_count := 0
var fps_min := INF
var fps_avg := 0.0

func _process(_delta):
	var fps := Engine.get_frames_per_second()

	# Min FPS
	fps_min = min(fps_min, fps)

	# Avg FPS
	fps_sum += fps
	frame_count += 1
	fps_avg = fps_sum / frame_count

	text = "FPS: %d | AVG: %d | MIN: %d" % [
		fps,
		int(fps_avg),
		int(fps_min)
	]
