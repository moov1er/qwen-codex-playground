# Guard — охранник с конусом зрения, слухом и конечным автоматом (GuardAI).
extends CharacterBody2D

signal alarm_raised(guard: Node)
signal player_captured

@export var vision_range := 260.0
@export var vision_angle_deg := 70.0
@export var patrol_points: Array[Vector2] = []   # задаётся миссией через setup()

var ai: GuardAI
var player: Node2D = null
var stealth_system: Node = null
var arrived: bool = false
var facing: float = 0.0                          # угол взгляда в радианах
var _patrol_index: int = 0
var _wander_target: Vector2 = Vector2.ZERO
var _search_phase: float = 0.0

@onready var body: Polygon2D = $Body
@onready var cone: Node2D = $VisionCone


func _ready() -> void:
	add_to_group("guards")
	ai = GuardAI.new()
	add_child(ai)
	ai.setup(self)
	ai.state_changed.connect(_on_state_changed)
	if patrol_points.is_empty():
		patrol_points = [global_position, global_position + Vector2(120, 0)]


func setup(p: Node2D, ssys: Node, points: Array) -> void:
	player = p
	stealth_system = ssys
	patrol_points = []
	for pt in points:
		patrol_points.append(pt as Vector2)


# ---------- API для GuardAI ----------

func stop() -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	arrived = true


func goto(target: Vector2, speed: float) -> void:
	var to := target - global_position
	arrived = to.length() < 14.0
	if arrived:
		velocity = Vector2.ZERO
	else:
		velocity = to.normalized() * speed
		facing = to.angle()
	move_and_slide()


func move_along_patrol(speed: float) -> void:
	if patrol_points.is_empty():
		stop(); return
	goto(patrol_points[_patrol_index], speed)
	if arrived:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()


func goto_patrol_nearest(speed: float) -> void:
	if patrol_points.is_empty(): stop(); return
	var best_i := 0
	var best_d := 1e9
	for i in patrol_points.size():
		var d := global_position.distance_to(patrol_points[i])
		if d < best_d: best_d = d; best_i = i
	_patrol_index = best_i
	goto(patrol_points[best_i], speed)


func look_towards(target: Vector2, delta: float) -> void:
	var want := (target - global_position).angle()
	facing = lerp_angle(facing, want, clampf(delta * 4.0, 0.0, 1.0))


func wander_around(center: Vector2, speed: float) -> void:
	_search_phase -= get_physics_process_delta_time()
	if _search_phase <= 0.0 or (center - global_position).length() < 16.0:
		_search_phase = randf_range(1.2, 2.2)
		_wander_target = center + Vector2(randf_range(-110, 110), randf_range(-110, 110))
	goto(_wander_target, speed)


func caught_player() -> bool:
	return player != null and is_instance_valid(player) \
		and global_position.distance_to(player.global_position) < 26.0


func captured() -> void:
	player_captured.emit()
	if player and player.has_method("on_captured"):
		player.on_captured()


func trigger_alarm() -> void:
	AudioDirector.play("alert")
	alarm_raised.emit(self)


func play_chase_music() -> void:
	AudioDirector.set_tension(1.0)


# ---------- зрение ----------

func _physics_process(delta: float) -> void:
	_update_vision()
	ai.step(delta)
	cone.rotation = facing
	body.rotation = 0.0  # тело смотрит всегда "прямо" — спрайт-квадрат


func _update_vision() -> void:
	if player == null or not is_instance_valid(player): return
	if player.is_in_group("hidden"):
		ai.on_lost_visual(); return
	var to := player.global_position - global_position
	var dist := to.length()
	if dist > vision_range:
		ai.on_lost_visual(); return
	var ang := absf(wrapf(to.angle() - facing, -PI, PI))
	if ang > deg_to_rad(vision_angle_deg / 2.0):
		ai.on_lost_visual(); return
	# линия видимости (без стен — упрощённый raycast через пространство дверей)
	var vis: float = 1.0
	if stealth_system:
		vis = stealth_system.compute_visibility()
	# дальность размывает силуэт
	vis *= clampf(1.0 - (dist / vision_range) * 0.5, 0.3, 1.0)
	if vis < 0.05:
		ai.on_lost_visual()
	else:
		ai.on_visual(vis)


func _on_state_changed(state: int) -> void:
	# Цветовые индикаторы состояния (см. требования): серый/жёлтый/оранжевый/красный/синий
	match state:
		GuardAI.S.PATROL: body.color = Color(0.45, 0.48, 0.55)
		GuardAI.S.SUSPICIOUS: body.color = Color(0.85, 0.75, 0.3)
		GuardAI.S.INVESTIGATE: body.color = Color(0.9, 0.55, 0.2)
		GuardAI.S.SEARCH: body.color = Color(0.35, 0.55, 0.85)
		GuardAI.S.ALERT, GuardAI.S.CHASE: body.color = Color(0.9, 0.2, 0.25)
		GuardAI.S.RETURN, GuardAI.S.CALM_DOWN: body.color = Color(0.5, 0.6, 0.55)
	cone.color.a = 0.16 if state >= GuardAI.S.SUSPICIOUS else 0.10
