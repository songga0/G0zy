extends Label

# 0단계 기준선 측정용: FPS와 프레임 처리 시간 표시
func _process(_delta: float) -> void:
	text = "FPS %d\n%.1f ms" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
	]
