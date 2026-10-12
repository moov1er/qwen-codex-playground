# DataRoutingFrame — мини-игра «Маршрутизация данных».
# Сетка узлов: клик по узлу поворачивает его трубу на 90°. Нужно провести
# непрерывный багровый путь от ИСТОЧНИКА (слева) к ЯДРУ (справа).
# Ограничение — ходы и время: чем дольше, тем выше след (heat).
extends Control

signal finished(result: Dictionary)

const CELL := 72
const N := 5   # сетка NxN

var grid: Array = []           # [y][x] -> rotation_steps 0..3 (битмаска связей)
var steps_used := 0
var max_steps := 40
var time_left := 60.0
var difficulty := 1.0
var solved := false

@onready var board: Control = $Center/Board
@onready var info: Label = $Top/Info


func _ready() -> void:
	difficulty = get_meta("difficulty") if has_meta("difficulty") else 1.0
	max_steps = int(30 + 20 / difficulty)
	time_left = 70.0 - 15.0 * difficulty
	_generate()
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_input)


func _generate() -> void:
	randomize()
	grid.resize(N)
	for y in N:
		grid[y] = Array()
		grid[y].resize(N)
		for x in N:
			grid[y][x] = randi_range(0, 3)
	# Клик переключает ориентацию трассы (горизонталь/вертикаль).
	# Победа — непрерывная цепочка однотипных соседей от левого края до правого.
	# Случайная сетка всегда решаема: достаточно привести путь к одному типу.


# Связность: упрощённая модель — узел "проводит" сигнал между соседями,
# если его текущая ориентация (шаги % 4) чётна (гориз.) или нечётна (верт.).
func _is_open_h(x: int, y: int) -> bool:
	return grid[y][x] % 2 == 0

func _is_open_v(x: int, y: int) -> bool:
	return grid[y][x] % 2 == 1


func _connected() -> bool:
	# BFS от любого узла левого края до правого края
	var visited := {}
	var queue: Array[Vector2i] = []
	for y in N:
		queue.append(Vector2i(0, y)); visited[Vector2i(0, y)] = true
	while not queue.is_empty():
		var c := queue.pop_front()
		if c.x == N - 1: return true
		# вправо
		if _is_open_h(c.x, c.y) and c.x + 1 < N and not visited.has(Vector2i(c.x+1, c.y)) \
		   and _is_open_h(c.x+1, c.y):
			visited[Vector2i(c.x+1, c.y)] = true; queue.append(Vector2i(c.x+1, c.y))
		if _is_open_h(c.x, c.y) and c.x - 1 >= 0 and not visited.has(Vector2i(c.x-1, c.y)) \
		   and _is_open_h(c.x-1, c.y):
			visited[Vector2i(c.x-1, c.y)] = true; queue.append(Vector2i(c.x-1, c.y))
		# вниз/вверх
		if _is_open_v(c.x, c.y) and c.y + 1 < N and not visited.has(Vector2i(c.x, c.y+1)) \
		   and _is_open_v(c.x, c.y+1):
			visited[Vector2i(c.x, c.y+1)] = true; queue.append(Vector2i(c.x, c.y+1))
		if _is_open_v(c.x, c.y) and c.y - 1 >= 0 and not visited.has(Vector2i(c.x, c.y-1)) \
		   and _is_open_v(c.x, c.y-1):
			visited[Vector2i(c.x, c.y-1)] = true; queue.append(Vector2i(c.x, c.y-1))
	return false


func _process(delta: float) -> void:
	if solved: return
	time_left -= delta
	info.text = "Ходы: %d/%d   Время: %dс\nСоедини источник (слева) с ядром (справа). Клик — переключить трассу." % [steps_used, max_steps, int(maxf(time_left, 0))]
	if time_left <= 0.0: _end("failure", 8)
	if steps_used >= max_steps and not _connected(): _end("failure", 5)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := event.position
		var cx := int(pos.x / CELL); var cy := int(pos.y / CELL)
		if cx >= 0 and cx < N and cy >= 0 and cy < N:
			grid[cy][cx] = (grid[cy][cx] + 1) % 4
			steps_used += 1
			AudioDirector.play("click")
			board.queue_redraw()
			if _connected():
				solved = true
				_end("success", 0)


func _end(status: String, heat: int) -> void:
	emit_signal("finished", {
		"status": status,
		"heat_increase": heat,
		"evidence_left": status == "failure",
		"time_penalty": int(maxf(0.0, 70.0 - time_left)) / 60,
		"data_gained": 1 if status == "success" else 0,
	})
	queue_free()


func _draw_board() -> void:
	for y in N:
		for x in N:
			var r := Rect2(x * CELL, y * CELL, CELL, CELL).grow(-4)
			var horiz := _is_open_h(x, y)
			var col := Color(0.85, 0.25, 0.3) if solved else Color(0.35, 0.4, 0.55)
			board.draw_rect(r, Color(0.1, 0.1, 0.16))
			if horiz:
				board.draw_line(Vector2(r.position.x - 4, r.get_center().y), Vector2(r.end.x + 4, r.get_center().y), col, 6.0)
			else:
				board.draw_line(Vector2(r.get_center().x, r.position.y - 4), Vector2(r.get_center().x, r.end.y + 4), col, 6.0)
			board.draw_circle(r.get_center(), 7.0, col.lightened(0.2))
	# маркеры входа/выхода
	board.draw_circle(Vector2(6, N * CELL / 2.0), 12, Color(0.2, 0.9, 0.6))
	board.draw_circle(Vector2(N * CELL - 6, N * CELL / 2.0), 12, Color(0.95, 0.6, 0.1))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_end("aborted", 3)
