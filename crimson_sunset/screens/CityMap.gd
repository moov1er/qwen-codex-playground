# CityMap — карта города Меридиан: районы, маркеры доступных миссий, уровень тепла.
extends Control

const TILE := 20.0                      # размер клетки карты в пикселях
const HEAT_COLOR := Color(0.85, 0.15, 0.2)

@onready var map_area: Control = $MapArea
@onready var info_label: Label = $Bottom/InfoLabel
@onready var missions_list: ItemList = $Side/MissionsList
@onready var go_btn: Button = $Side/GoBtn
@onready var heat_bar: ProgressBar = $Top/HeatBar


func _ready() -> void:
	missions_list.item_selected.connect(_on_mission_selected)
	go_btn.pressed.connect(_on_go_pressed)
	$Bottom/BackBtn.pressed.connect(func(): get_parent().goto("desktop"))
	map_area.gui_input.connect(_on_map_input)
	GameState.stats_changed.connect(_refresh)
	GameState.mission_state_changed.connect(func(_id): _refresh())
	_refresh()


func on_enter() -> void:
	_refresh()


func _refresh() -> void:
	heat_bar.value = GameState.heat
	info_label.text = "Меридиан. Время: %s. Тепло корпорации: %d%%. Репутация: %d" % [
		TimeSystem.period_label(), GameState.heat, GameState.reputation]
	missions_list.clear()
	for def in MissionManager.all_missions():
		var id := str(def.get("id", ""))
		if MissionManager.is_mission_available(id):
			missions_list.add_item("%s [%s]" % [def.get("title", id), def.get("location", "?")])
			missions_list.set_item_metadata(missions_list.get_item_count() - 1, id)
	if missions_list.get_item_count() == 0:
		missions_list.add_item("Сейчас активных точек нет. Вернись на рабочий стол.")
		go_btn.disabled = true
	else:
		go_btn.disabled = missions_list.get_selected_items().is_empty()
	queue_redraw()


func _on_mission_selected(_index: int) -> void:
	go_btn.disabled = false


func _on_go_pressed() -> void:
	var sel: Array = missions_list.get_selected_items()
	if sel.is_empty(): return
	var id: Variant = missions_list.get_item_metadata(sel[0])
	var main := get_parent()
	main.pending_mission_id = str(id)
	main.goto("briefing")


# Отрисовка карты: закатный градиент, сетка районов, маркеры миссий.
func _draw() -> void:
	var r := map_area.get_rect()
	# фон-градиент «багровый закат»
	for i in range(int(r.height / 4.0)):
		var t := float(i) / maxf(1.0, r.height / 4.0)
		var c := Color(0.10 + 0.25 * t, 0.06 + 0.03 * t, 0.12 + 0.02 * (1.0 - t))
		draw_rect(Rect2(r.position + Vector2(0, i * 4.0), Vector2(r.width, 4.0)), c)
	# сетка улиц
	var line_col := Color(0.9, 0.5, 0.5, 0.10)
	var x := 0.0
	while x < r.width:
		draw_line(r.position + Vector2(x, 0), r.position + Vector2(x, r.height), line_col)
		x += TILE * 4.0
	var y := 0.0
	while y < r.height:
		draw_line(r.position + Vector2(0, y), r.position + Vector2(r.width, y), line_col)
		y += TILE * 4.0
	# подписи районов
	_draw_label(Vector2(r.position.x + 30, r.position.y + 40), "СТАРЫЙ КАНАЛ")
	_draw_label(Vector2(r.position.x + r.width * 0.45, r.position.y + r.height * 0.35), "ФИНАНСОВЫЙ КВАРТАЛ")
	_draw_label(Vector2(r.position.x + r.width * 0.6, r.position.y + r.height * 0.75), "AURORA YARD")
	_draw_label(Vector2(r.position.x + r.width * 0.15, r.position.y + r.height * 0.8), "НАБЕРЕЖНАЯ")
	# маркеры доступных миссий
	var positions := {
		"m01_dead_channel": Vector2(0.18, 0.28),
		"m02_archive": Vector2(0.52, 0.42),
		"m03_helios7": Vector2(0.72, 0.68),
	}
	for def in MissionManager.all_missions():
		var id := str(def.get("id", ""))
		if not MissionManager.is_mission_available(id): continue
		var frac: Vector2 = positions.get(id, Vector2(randf(), randf()))
		var p := r.position + Vector2(r.width * frac.x, r.height * frac.y)
		draw_circle(p, 10.0, Color(0.9, 0.2, 0.25, 0.9))
		draw_circle(p, 16.0, Color(0.9, 0.2, 0.25, 0.25))
		_draw_label(p + Vector2(-30, 34), str(def.get("title", id)))
	# силуэт убежища
	_draw_label(Vector2(r.position.x + r.width - 150, r.position.y + 30), "▪ УБЕЖИЩЕ")


func _draw_label(pos: Vector2, text: String) -> void:
	# рисуем текст через шрифт по умолчанию (для отладочной карты этого достаточно)
	var font := ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.6, 0.6, 0.75))


func _on_map_input(event: InputEvent) -> void:
	# клик по маркеру выделяет соответствующий пункт списка
	if event is InputEventMouseButton and event.pressed:
		var r := map_area.get_rect()
		var idx := 0
		for def in MissionManager.all_missions():
			var id := str(def.get("id", ""))
			if not MissionManager.is_mission_available(id): continue
			var frac := {"m01_dead_channel": Vector2(0.18, 0.28),
				"m02_archive": Vector2(0.52, 0.42),
				"m03_helios7": Vector2(0.72, 0.68)}.get(id, Vector2(0.5, 0.5))
			var p := Vector2(r.width * frac.x, r.height * frac.y)
			if p.distance_to(event.position) < 20.0 and idx < missions_list.item_count:
				missions_list.select(idx)
				go_btn.disabled = false
			idx += 1
