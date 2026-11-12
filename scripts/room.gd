@tool
extends Node3D
## 방의 바닥과 벽 4면을 크기 값으로부터 생성한다.
## 좌표 기준: 방 안쪽 바닥 중심이 (0, 0, 0)
##   north = -Z 쪽 벽, south = +Z 쪽 벽, west = -X 쪽 벽, east = +X 쪽 벽

@export_group("방 크기 (미터)")
@export var width: float = 3.5          # X 방향 안쪽 폭
@export var depth: float = 4.0          # Z 방향 안쪽 깊이
@export var wall_height: float = 2.4
@export var wall_thickness: float = 0.12
@export var floor_thickness: float = 0.12

@export_group("색상")
@export var floor_color: Color = Color(0.86, 0.69, 0.52)
@export var wall_color: Color = Color(0.98, 0.94, 0.88)

## 이름 -> 벽 노드. 1-3단계(벽 숨김)에서 사용한다.
var walls: Dictionary = {}


func _ready() -> void:
	_build()
	# 1-1단계: 카메라가 남동쪽(+X, +Z)에 고정되어 있으므로 앞쪽 두 벽은 숨긴다.
	# 1-3단계에서 카메라 방향에 따라 자동으로 숨기도록 바꾼다.
	walls["east"].visible = false
	walls["south"].visible = false



## 바닥 판과 벽을 모두 포함하는 방의 외곽 상자. 카메라 거리 계산에 사용한다.
func get_bounds() -> AABB:
	var outer_w := width + wall_thickness * 2.0
	var outer_d := depth + wall_thickness * 2.0
	return AABB(
		Vector3(-outer_w / 2.0, -floor_thickness, -outer_d / 2.0),
		Vector3(outer_w, wall_height + floor_thickness, outer_d))


func _build() -> void:
	var floor_mat := _make_material(floor_color)
	var wall_mat := _make_material(wall_color)

	# 바닥 판: 벽 두께만큼 바깥까지 덮어서 미니어처처럼 두께가 보이게 한다.
	var outer_w := width + wall_thickness * 2.0
	var outer_d := depth + wall_thickness * 2.0
	_add_box("Floor", Vector3(outer_w, floor_thickness, outer_d),
		Vector3(0, -floor_thickness / 2.0, 0), floor_mat)

	var half_x := width / 2.0 + wall_thickness / 2.0
	var half_z := depth / 2.0 + wall_thickness / 2.0
	var y := wall_height / 2.0

	# 동서 벽은 모서리까지 덮고, 남북 벽은 그 사이에 끼워서 겹치지 않게 한다.
	walls["west"] = _add_box("WallWest", Vector3(wall_thickness, wall_height, outer_d),
		Vector3(-half_x, y, 0), wall_mat)
	walls["east"] = _add_box("WallEast", Vector3(wall_thickness, wall_height, outer_d),
		Vector3(half_x, y, 0), wall_mat)
	walls["north"] = _add_box("WallNorth", Vector3(width, wall_height, wall_thickness),
		Vector3(0, y, -half_z), wall_mat)
	walls["south"] = _add_box("WallSouth", Vector3(width, wall_height, wall_thickness),
		Vector3(0, y, half_z), wall_mat)


func _add_box(node_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	add_child(inst)
	return inst


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat
