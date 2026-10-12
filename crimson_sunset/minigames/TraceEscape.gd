# TraceEscapeFrame — мини-игра «Побег от трассировки».
# Красный трекер движется по кольцевой схеме; игрок кликает по узлам-ячейкам,
# переключая мосты так, чтобы трекер никогда не догнал синий пакет.
# Упрощённая аркада: следи за трекером и жми ПРОБЕЛ в момент совпадения окна.
extends Control

signal finished(result: Dictionary)

var tracker_pos := 0.0        # 0..1 по кругу
var packet_pos := 0.85
var speed := 0.18
var window_open := false
var jumps := 0
var needed_jumps := 4
var lives := 3
var time_left := 30.0
var difficulty := 1.0
var over := false

@onready var area: Control = $Center/Area
@onready var info: Label = $Top/Info


func _ready() -> void:
	difficulty = get_meta("difficulty") if has_meta("difficulty") else 1.0
	speed = 0.14 + 0.06 * difficulty
	needed_jumps = 3 + int(2 * difficulty)
	area.draw.connect(_draw)


func _process(delta: float) -> void:
	if over: return
	time_left -= delta
	tracker_pos = fmod(tracker_pos + speed * delta, 1.0)
	packet_pos = fmod(packet_pos + speed * 0.9 * delta, 1.0)
	# окно синхронизации: когда трекер далеко от пакета, можно "прыгнуть" маршрутом
	window_open = absf(fmod(tracker_pos - packet_pos + 0.5, 1.0) - 0.5) > 0.35
	info.text = ("РЫВОК ДОСТУПЕН (Пробел). Прыжков: %d/%d, Жизни: %d, Время: %dс" % [jumps, needed_jumps, lives, int(maxf(time_left, 0))]) if window_open \
		else ("Трекер рядом — жди окно... Жизни: %d, Время: %dс" % [lives, int(maxf(time_left, 0))])
	if time_left <= 0.0:
		_end("partial_success" if jumps >= needed_jumps - 1 else "failure", 6)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_end("aborted", 3)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_SPACE:
		if window_open:
			jumps += 1
			AudioDirector.play("terminal")
			packet_pos = fmod(packet_pos + 0.25, 1.0)   # прыжок вперёд по кольцу
			if jumps >= needed_jumps:
				_end("success", 0)
		else:
			lives -= 1
			AudioDirector.play("fail")
			GameState.change_heat(2)
			if lives <= 0:
				_end("failure", 10)


func _end(status: String, heat: int) -> void:
	over = true
	emit_signal("finished", {
		"status": status,
		"heat_increase": heat,
		"evidence_left": status == "failure",
		"time_penalty": 1,
		"data_gained": jumps,
	})
	queue_free()


func _draw() -> void:
	var c := Vector2(200, 110)
	var r := 90.0
	area.draw_circle(c, r, Color(0.08, 0.08, 0.12))
	area.draw_arc(c, r, 0, TAU, 64, Color(0.3, 0.35, 0.5), 3.0)
	var tp := c + Vector2(cos(tracker_pos * TAU), sin(tracker_pos * TAU)) * r
	var pp := c + Vector2(cos(packet_pos * TAU), sin(packet_pos * TAU)) * r
	area.draw_circle(tp, 12, Color(0.9, 0.15, 0.2))       # трекер
	area.draw_circle(pp, 10, Color(0.2, 0.8, 0.9))        # пакет
	if window_open:
		area.draw_rect(Rect2(140, 210, 120, 10), Color(0.2, 0.8, 0.4))
