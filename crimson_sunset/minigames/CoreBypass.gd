# CoreBypassFrame — мини-игра «Обход ядра» (для финальной миссии среза).
# Цифровое поле: ведём курсором "пакет" от левого края к правому, уклоняясь
# от блуждающих защитных процессов. Касание — +подозрение.
extends Control

signal finished(result: Dictionary)

var player_pos := Vector2(20, 120)
var hazards: Array[Dictionary] = []
var suspicion := 0.0
var time_left := 25.0
var difficulty := 1.0
var over := false

@onready var area: Control = $Center/Area
@onready var info: Label = $Top/Info


func _ready() -> void:
	difficulty = get_meta("difficulty") if has_meta("difficulty") else 1.0
	randomize()
	for i in range(4 + int(3 * difficulty)):
		hazards.append({
			"pos": Vector2(randf_range(60, 360), randf_range(20, 220)),
			"vel": Vector2(randf_range(-60, 60), randf_range(-60, 60)) * difficulty,
			"r": randf_range(14, 24),
		})
	area.draw.connect(_draw)
	area.gui_input.connect(_on_mouse)


func _on_mouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		player_pos = Vector2(clampf(event.position.x, 10, 390), clampf(event.position.y, 10, 230))


func _process(delta: float) -> void:
	if over: return
	time_left -= delta
	for hz in hazards:
		hz["pos"] += hz["vel"] * delta
		if hz["pos"].x < 20 or hz["pos"].x > 380: hz["vel"].x *= -1
		if hz["pos"].y < 15 or hz["pos"].y > 225: hz["vel"].y *= -1
		if player_pos.distance_to(hz["pos"]) < hz["r"] + 8:
			suspicion += 40.0 * delta
	info.text = "Доведи пакет до правой границы. Подозрение: %d%%, Время: %dс" % [int(suspicion), int(maxf(time_left, 0))]
	if player_pos.x > 385:
		_end("partial_success" if suspicion > 30.0 else "success", int(suspicion / 15.0))
	elif time_left <= 0.0 or suspicion >= 100.0:
		_end("failure", 8)


func _end(status: String, heat: int) -> void:
	over = true
	emit_signal("finished", {
		"status": status,
		"heat_increase": heat,
		"evidence_left": suspicion > 50.0,
		"time_penalty": 1,
		"data_gained": 2 if status == "success" else 1,
	})
	queue_free()


func _draw() -> void:
	area.draw_rect(Rect2(0, 0, 400, 240), Color(0.06, 0.07, 0.1))
	for hz in hazards:
		area.draw_circle(hz["pos"], hz["r"], Color(0.85, 0.2, 0.25, 0.7))
	area.draw_rect(Rect2(385, 0, 15, 240), Color(0.2, 0.8, 0.5, 0.5))
	area.draw_circle(player_pos, 8, Color(0.3, 0.85, 0.95))
