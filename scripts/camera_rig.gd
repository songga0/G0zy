extends Node3D
## 방을 내려다보는 카메라.
## 카메라 위치를 직접 움직이지 않고, 네 개의 값으로 매번 계산한다.
##   yaw   : 좌우 회전 각도
##   pitch : 내려다보는 각도
##   pivot : 바라보는 지점 (지금은 방 중심 고정, 1-4단계에서 확대 초점으로 이동)
##   zoom  : 확대 정도 (1-4단계에서 추가)
##
## 1-2단계: 한 손가락(마우스) 드래그로 좌우 회전 + 손을 뗐을 때 관성

## 카메라가 움직이기 시작/완전히 멈출 때 알림. (나중에 RenderGovernor가 사용)
signal motion_started
signal motion_stopped

@export var room_path: NodePath

@export_group("기본 시점")
@export_range(0.0, 360.0) var yaw_degrees: float = 45.0
@export_range(20.0, 80.0) var pitch_degrees: float = 48.0
## 방(벽 포함)이 화면 폭에서 차지하는 비율
@export_range(0.3, 1.0) var room_fill: float = 0.78
## 방 중심이 놓일 세로 위치 (0 = 화면 맨 위, 0.5 = 정중앙)
@export_range(0.2, 0.6) var room_screen_y: float = 0.42

@export_group("회전 조작감")
## 화면 폭 전체를 드래그했을 때 회전하는 각도
@export var degrees_per_screen_width: float = 180.0
## 목표 각도를 따라가는 속도 (클수록 즉각적)
@export var follow_speed: float = 18.0
## 관성 감속 정도 (클수록 빨리 멈춤)
@export var inertia_damping: float = 4.0

@onready var camera: Camera3D = $Camera3D

var _yaw: float            # 현재 화면에 보이는 각도 (라디안)
var _target_yaw: float     # 따라가야 할 목표 각도
var _pivot := Vector3.ZERO
var _distance := 12.0

var _dragging := false
var _drag_index := -1
var _velocity := 0.0       # 회전 속도 (라디안/초), 관성에 사용
var _last_move_time := 0.0
var _moving := false


func _ready() -> void:
	_yaw = deg_to_rad(yaw_degrees)
	_target_yaw = _yaw
	get_viewport().size_changed.connect(_fit_to_room)
	_fit_to_room()
	_set_moving(false)


## 방 크기와 화면 비율로 카메라 거리와 세로 위치를 계산한다.
func _fit_to_room() -> void:
	var bounds := AABB(Vector3(-2, 0, -2), Vector3(4, 2.4, 4))
	var room := get_node_or_null(room_path)
	if room and room.has_method("get_bounds"):
		bounds = room.get_bounds()
	_pivot = bounds.get_center()

	# 방 전체(벽 높이 포함)를 감싸는 구가 화면 폭의 room_fill 만큼 차지하는 거리
	# camera.keep_aspect = 가로 기준이므로 fov는 가로 시야각이다.
	var radius := bounds.size.length() / 2.0
	var half_fov := deg_to_rad(camera.fov) / 2.0
	_distance = radius / (room_fill * tan(half_fov))

	# 방을 화면 중앙보다 위로 올리기: 카메라를 화면 아래 방향으로 평행이동
	var vp := get_viewport().get_visible_rect().size
	var visible_w := 2.0 * _distance * tan(half_fov)
	var visible_h := visible_w * vp.y / vp.x
	camera.v_offset = -(0.5 - room_screen_y) * visible_h
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	# 터치 이벤트만 사용한다. (Mac에서는 마우스가 터치로 변환되어 들어옴)
	if event is InputEventScreenTouch:
		if event.pressed and not _dragging:
			_dragging = true
			_drag_index = event.index
			# 관성으로 돌고 있었다면 지금 보이는 각도에서 멈춘다.
			_velocity = 0.0
			_target_yaw = _yaw
			_last_move_time = _now()
			_set_moving(true)
		elif not event.pressed and event.index == _drag_index:
			_dragging = false
			_drag_index = -1
			# 손을 떼기 직전에 멈춰 있었다면 관성을 주지 않는다.
			if _now() - _last_move_time > 0.08:
				_velocity = 0.0
	elif event is InputEventScreenDrag and _dragging and event.index == _drag_index:
		var drag := event as InputEventScreenDrag
		var width := get_viewport().get_visible_rect().size.x
		# 오른쪽으로 끌면 방이 오른쪽으로 돌아가도록 (= 카메라는 왼쪽으로 이동)
		var delta: float = -drag.relative.x / width * deg_to_rad(degrees_per_screen_width)
		_target_yaw += delta
		var t := _now()
		var dt := maxf(t - _last_move_time, 0.001)
		_velocity = lerpf(_velocity, delta / dt, 0.5)
		_last_move_time = t


func _process(delta: float) -> void:
	# 관성: 손을 뗀 뒤 남은 속도로 계속 돌면서 점점 감속
	if not _dragging and _velocity != 0.0:
		_target_yaw += _velocity * delta
		_velocity *= exp(-inertia_damping * delta)
		if absf(_velocity) < 0.02:
			_velocity = 0.0

	# 현재 각도가 목표 각도를 부드럽게 따라감
	_yaw = lerpf(_yaw, _target_yaw, 1.0 - exp(-follow_speed * delta))
	_apply()

	# 완전히 멈췄으면 매 프레임 계산을 끈다.
	if not _dragging and _velocity == 0.0 and absf(_target_yaw - _yaw) < 0.0005:
		_yaw = _target_yaw
		_apply()
		_set_moving(false)


func _apply() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	var dir := Vector3(cos(pitch) * sin(_yaw), sin(pitch), cos(pitch) * cos(_yaw))
	camera.global_position = _pivot + dir * _distance
	camera.look_at(_pivot, Vector3.UP)


func _set_moving(value: bool) -> void:
	set_process(value)
	if value == _moving:
		return
	_moving = value
	if value:
		motion_started.emit()
	else:
		motion_stopped.emit()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
