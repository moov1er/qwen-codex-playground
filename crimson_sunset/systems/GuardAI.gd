# GuardAI — конечный автомат охраны. Прикреплён к узлу Guard.
# Состояния: PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, ALERT, CHASE, RETURN, CALM_DOWN.
class_name GuardAI
extends Node

enum S { PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, ALERT, CHASE, RETURN, CALM_DOWN }

signal state_changed(state: int)

var guard: Node2D = null
var state: int = S.PATROL
var suspicion: float = 0.0            # 0..100 накопленное подозрение
var last_known_pos: Vector2 = Vector2.ZERO
var see_player: bool = false
var visibility_now: float = 1.0       # видимость игрока в конусе (0..1)
var investigate_timer: float = 0.0
var search_timer: float = 0.0
var calm_timer: float = 0.0
var reaction_timer: float = 0.0       # пауза-реакция перед погоней

@export var patrol_speed: float = 70.0
@export var chase_speed: float = 150.0
@export var hear_radius: float = 240.0
@export var suspicion_threshold: float = 45.0
@export var alert_threshold: float = 85.0


func setup(g: Node2D) -> void:
    guard = g


# Слышимость: шум долетает в пределах радиуса (и собственного слуха охранника).
func on_noise(pos: Vector2, radius: float) -> void:
    if state == S.ALERT or state == S.CHASE: return
    var d := guard.global_position.distance_to(pos)
    if d <= minf(radius, hear_radius):
            last_known_pos = pos
            _bump_suspicion(18.0)
            if state == S.PATROL: _enter(S.SUSPICIOUS)


# Визуальный контакт: вызывается каждый кадр, пока игрок в конусе зрения.
func on_visual(v: float) -> void:
    visibility_now = v
    see_player = true
    last_known_pos = guard.player_pos
    if v >= 0.75:
            _bump_suspicion(60.0 * get_process_delta_time())
    elif v >= 0.35:
            _bump_suspicion(22.0 * get_process_delta_time())
    else:
            _bump_suspicion(8.0 * get_process_delta_time())


func on_lost_visual() -> void:
    see_player = false


func _bump_suspicion(amount: float) -> void:
    suspicion = clampf(suspicion + amount, 0.0, 100.0)
    if suspicion >= alert_threshold and state != S.ALERT and state != S.CHASE:
            _enter(S.ALERT)
            guard.trigger_alarm()
    elif suspicion >= suspicion_threshold:
            match state:
                    S.PATROL, S.SUSPICIOUS:
                            _enter(S.INVESTIGATE)
                    _:
                            pass
    elif suspicion >= 15.0 and state == S.PATROL:
            _enter(S.SUSPICIOUS)


func _enter(new_state: int) -> void:
    state = new_state
    match new_state:
            S.INVESTIGATE:
                    investigate_timer = 4.0
            S.SEARCH:
                    search_timer = 8.0
            S.ALERT:
                    reaction_timer = 0.8
                    guard.play_chase_music()
            S.CALM_DOWN:
                    calm_timer = 5.0
    state_changed.emit(new_state)


# Основной шаг — вызывается из Guard._physics_process.
func step(delta: float) -> void:
    if not see_player:
            suspicion = clampf(suspicion - 6.0 * delta, 0.0, 100.0)
    match state:
            S.PATROL:
                    guard.move_along_patrol(patrol_speed)
            S.SUSPICIOUS:
                    guard.look_towards(last_known_pos, delta)
                    guard.stop()
                    if suspicion < 10.0: _enter(S.PATROL)
            S.INVESTIGATE:
                    investigate_timer -= delta
                    guard.goto(last_known_pos, patrol_speed * 1.2)
                    if guard.arrived or investigate_timer <= 0.0: _enter(S.SEARCH)
            S.SEARCH:
                    search_timer -= delta
                    guard.wander_around(last_known_pos, patrol_speed)
                    if search_timer <= 0.0: _enter(S.CALM_DOWN)
            S.ALERT:
                    # секундная пауза-реакция, затем погоня
                    reaction_timer -= delta
                    guard.stop()
                    if reaction_timer <= 0.0: _enter(S.CHASE)
            S.CHASE:
                    if see_player:
                            guard.goto(guard.player_pos, chase_speed)
                            if guard.caught_player():
                                    guard.captured()
                    else:
                            guard.goto(last_known_pos, chase_speed)
                            if guard.arrived: _enter(S.SEARCH)
            S.RETURN:
                    guard.goto_patrol_nearest(patrol_speed * 1.3)
                    if guard.arrived: _enter(S.PATROL)
            S.CALM_DOWN:
                    calm_timer -= delta
                    guard.stop()
                    if calm_timer <= 0.0:
                            suspicion = 0.0
                            _enter(S.RETURN)
