# ConnectionStabilityFrame — мини-игра «Стабилизация соединения».
# Полоса сигнала: удерживай маркер в зелёной зоне (мышь/стрелки), пока
# загрузка не дойдёт до 100%. Вышел из зоны — рост подозрения.
extends Control

signal finished(result: Dictionary)

var progress := 0.0            # 0..100 загрузка
var marker_x := 200.0          # позиция маркера
var zone_center := 200.0
var zone_half := 60.0
var drift_speed := 90.0
var suspicion := 0.0
var time_left := 45.0
var difficulty := 1.0
var over := false

@onready var area: Control = $Center/Area
@onready var info: Label = $Top/Info


func _ready() -> void:
	difficulty = get_meta("difficulty") if has_meta("difficulty") else 1.0
	zone_half = maxf(30.0, 70.0 - 15.0 * difficulty)
	area.draw.connect(_draw)
	area.gui_input.connect(_on_mouse)


func _on_mouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		marker_x = clampf(event.position.x, 10, 390)


func _process(delta: float) -> void:
	if over: return
	time_left -= delta
	# зона дрейфует — нужно подстраиваться
	drift_speed = 60.0 + 40.0 * difficulty
	zone_center += sin(Time.get_ticks_msec() / (900.0 / difficulty)) * drift_speed * delta
	zone_center = clampf(zone_center, 80, 320)

	var in_zone := absf(marker_x - zone_center) < zone_half
	if in_zone:
		progress += (28.0 - 6.0 * difficulty) * delta
	else:
		suspicion += 22.0 * delta
		progress -= 4.0 * delta
	progress = clampf(progress, 0, 100)
	info.text = "Загрузка: %d%%   Подозрение: %d   Время: %dс\nУдерживай маркер в зелёной коридоре сигнала." % [int(progress), int(suspicion), int(maxf(time_left, 0))]

	if progress >= 100.0:
		_end("partial_success" if suspicion > 40.0 else "success", int(suspicion / 20.0))
	elif time_left <= 0.0 or suspicion >= 100.0:
		_end("failure", 8)


func _end(status: String, heat: int) -> void:
	over = true
	emit_signal("finished", {
		"status": status,
		"heat_increase": heat,
		"evidence_left": suspicion > 60.0,
		"time_penalty": 1,
		"data_gained": int(progress / 25.0),
	})
	queue_free()


func _draw() -> void:
	var w := 400.0
	area.draw_rect(Rect2(0, 60, w, 60), Color(0.08, 0.08, 0.12))
	# безопасная зона
	area.draw_rect(Rect2(zone_center - zone_half, 60, zone_half * 2, 60), Color(0.15, 0.6, 0.35, 0.6))
	# шумовые полосы
	for i in 8:
		var x := fmod(Time.get_ticks_msec() / 20.0 + i * 50.0, w)
		area.draw_rect(Rect2(x, 62, 3, 56), Color(0.5, 0.2, 0.3, 0.35))
	# маркер игрока
	area.draw_rect(Rect2(marker_x - 3, 50, 6, 80), Color(0.9, 0.85, 0.4))
	# прогресс
	area.draw_rect(Rect2(0, 140, w * progress / 100.0, 14), Color(0.85, 0.3, 0.35))
	area.draw_rect(Rect2(0, 140, w, 14), Color(0.2, 0.2, 0.3))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_end("aborted", 3)
