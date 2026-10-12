# CameraObj — камера наблюдения (имя класса CameraObj, чтобы не конфликтовать с Camera3D).
# Медленно вращается туда-сюда; если игрок в секторе и освещён — накапливает подозрение.
extends Node2D

signal camera_spotted(strength: float)
signal camera_disabled()

@export var range_px := 240.0
@export var arc_deg := 80.0
@export var sweep_speed := 0.5      # рад/с

var player: Node2D = null
var stealth_system: Node = null
var enabled: bool = true
var _angle: float = PI / 2.0        # смотрит вниз по умолчанию
var _dir: float = 1.0
var suspicion: float = 0.0

@onready var cone: Polygon2D = $Cone


func setup(p: Node2D, ssys: Node) -> void:
	player = p
	stealth_system = ssys


func disable_temporarily(seconds: float = 25.0) -> void:
	if not enabled: return
	enabled = false
	camera_disabled.emit()
	cone.color = Color(0.2, 0.2, 0.25, 0.05)
	get_tree().create_timer(seconds).timeout.connect(_reboot)


func _reboot() -> void:
	enabled = true
	cone.color = Color(0.9, 0.3, 0.2, 0.12)


func _process(delta: float) -> void:
	if not enabled: return
	_angle += _dir * sweep_speed * delta
	if _angle > PI + deg_to_rad(40): _dir = -1
	if _angle < PI - deg_to_rad(40): _dir = 1
	cone.rotation = _angle

	if player == null or not is_instance_valid(player): return
	if player.is_in_group("hidden"):
		suspicion = maxf(0.0, suspicion - delta * 20.0); return
	var to := player.global_position - global_position
	if to.length() > range_px:
		suspicion = maxf(0.0, suspicion - delta * 20.0); return
	var ang := absf(wrapf(to.angle() - _angle, -PI, PI))
	if ang > deg_to_rad(arc_deg / 2.0):
		suspicion = maxf(0.0, suspicion - delta * 20.0); return
	var vis: float = stealth_system.compute_visibility() if stealth_system else 1.0
	suspicion += vis * 40.0 * delta
	if suspicion >= 35.0:
		camera_spotted.emit(vis)
		suspicion = 0.0
