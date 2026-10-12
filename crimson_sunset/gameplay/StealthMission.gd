# StealthMission — корневой узел стелс-миссии. Строит уровень из JSON (maps.json),
# связывает игрока, охрану, камеры, шум, HUD и результат миссии.
extends Node2D

const WALL_COLOR := Color(0.16, 0.15, 0.24)
const FLOOR_COLOR := Color(0.09, 0.08, 0.13)
const SUNSET_GLOW := Color(0.55, 0.12, 0.18, 0.10)

var mission_id: String = ""
var map_data: Dictionary = {}
var player: CharacterBody2D
var stealth_system: Node
var noise_system: Node
var interaction_system: Node
var minigame_system: HackingMinigameSystem
var hud: Control

var alarms: int = 0
var seen_by_guard: bool = false
var seen_by_camera: bool = false
var evidence_left: bool = false
var hack_results: Array = []
var escaped: bool = false
var _over: bool = false


func _ready() -> void:
	mission_id = GameState.active_mission_id
	map_data = _load_map(mission_id)
	_build_world()
	_connect_signals()
	hud = preload("res://ui/StealthHUD.tscn").instantiate()
	add_child(hud)
	hud.setup(self)


func _load_map(id: String) -> Dictionary:
	var f := FileAccess.open("res://data/maps.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	for m in parsed:
		if str(m.get("mission_id", "")) == id:
			return m
	push_error("Карта не найдена для миссии " + id)
	return {}


func _build_world() -> void:
	# фоновый закатный свет поверх карты
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(-200,-200), Vector2(1700,-200), Vector2(1700,900), Vector2(-200,900)])
	glow.color = SUNSET_GLOW
	glow.z_index = -10
	add_child(glow)

	# стены
	for w in map_data.get("walls", []):
		var rect: Array = w
		var poly := Polygon2D.new()
		var x: float = rect[0]; var y: float = rect[1]; var ww: float = rect[2]; var hh: float = rect[3]
		poly.polygon = PackedVector2Array([Vector2(x,y), Vector2(x+ww,y), Vector2(x+ww,y+hh), Vector2(x,y+hh)])
		poly.color = WALL_COLOR
		poly.z_index = -5
		add_child(poly)
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var cs := RectangleShape2D.new()
		cs.size = Vector2(ww, hh)
		shape.shape = cs
		body.position = Vector2(x + ww/2, y + hh/2)
		body.add_child(shape)
		add_child(body)

	# зоны света (для видимости)
	stealth_system = StealthSystem.new()
	stealth_system.name = "StealthSystem"
	add_child(stealth_system)
	for l in map_data.get("lights", []):
		var pl := PointLight2D.new()
		pl.position = Vector2(l[0], l[1])
		pl.texture = _circle_texture()
		pl.range_max = float(l[2])
		pl.energy = 1.2
		pl.color = Color(1.0, 0.6, 0.4)
		add_child(pl)
		stealth_system.light_nodes.append(pl)

	# игрок
	player = preload("res://gameplay/Player.tscn").instantiate()
	var sp: Array = map_data.get("player_start", [100, 400])
	player.position = Vector2(sp[0], sp[1])
	add_child(player)
	stealth_system.player = player

	noise_system = NoiseSystem.new()
	noise_system.name = "NoiseSystem"
	add_child(noise_system)
	player.noise_system = noise_system

	interaction_system = InteractionSystem.new()
	interaction_system.name = "InteractionSystem"
	add_child(interaction_system)
	interaction_system.player = player

	minigame_system = HackingMinigameSystem.new()
	minigame_system.name = "HackingMinigameSystem"
	add_child(minigame_system)

	# укрытия
	for h in map_data.get("hiding_spots", []):
		var hs := preload("res://gameplay/HidingSpot.tscn").instantiate()
		hs.position = Vector2(h[0], h[1])
		add_child(hs)

	# вентиляция
	for v in map_data.get("vents", []):
		var vent := preload("res://gameplay/Vent.tscn").instantiate()
		vent.position = Vector2(v["from"][0], v["from"][1])
		var exit_pt := Marker2D.new()
		exit_pt.position = Vector2(v["to"][0], v["to"][1])
		vent.exit_point = exit_pt
		add_child(vent)
		add_child(exit_pt)

	# предметы
	for it in map_data.get("pickups", []):
		var pk := preload("res://gameplay/Pickup.tscn").instantiate()
		pk.position = Vector2(it["pos"][0], it["pos"][1])
		pk.item_id = str(it["item"])
		pk.is_evidence = bool(it.get("evidence", false))
		pk.evidence_id = str(it.get("evidence_id", ""))
		pk.objective_index = int(it.get("objective", -1))
		add_child(pk)

	# шумовые точки отвлечения
	for nsrc in map_data.get("noise_points", []):
		var nz := preload("res://gameplay/NoiseSource.tscn").instantiate()
		nz.position = Vector2(nsrc[0], nsrc[1])
		add_child(nz)

	# серверы
	for s in map_data.get("servers", []):
		var srv := preload("res://gameplay/ServerTerminal.tscn").instantiate()
		srv.position = Vector2(s["pos"][0], s["pos"][1])
		srv.minigame_kind = str(s.get("minigame", "data_routing"))
		srv.objective_index = int(s.get("objective", 3))
		srv.difficulty = float(s.get("difficulty", 1.0))
		add_child(srv)
		srv.hack_finished.connect(_on_hack_finished)

	# двери
	for d in map_data.get("doors", []):
		var door := preload("res://gameplay/Door.tscn").instantiate()
		door.position = Vector2(d["pos"][0], d["pos"][1])
		door.locked_by_key = str(d.get("key", ""))
		if d.has("vertical") and d["vertical"]:
			door.rotation_degrees = 90
		add_child(door)

	# камеры
	for c in map_data.get("cameras", []):
		var cam := preload("res://gameplay/Camera.tscn").instantiate()
		cam.position = Vector2(c[0], c[1])
		add_child(cam)
		cam.setup(player, stealth_system)
		cam.camera_spotted.connect(_on_camera_spotted)
		cam.camera_disabled.connect(func(): MissionManager.complete_objective(mission_id, 0, true))

	# охрана
	for g in map_data.get("guards", []):
		var guard := preload("res://gameplay/Guard.tscn").instantiate()
		guard.position = Vector2(g["pos"][0], g["pos"][1])
		add_child(guard)
		var pts: Array = []
		for p in g.get("patrol", []):
			pts.append(Vector2(p[0], p[1]))
		guard.setup(player, stealth_system, pts)
		guard.alarm_raised.connect(_on_alarm)
		guard.player_captured.connect(_on_captured)

	# выход
	var exit_zone := Area2D.new()
	exit_zone.name = "ExtractionZone"
	var ex: Array = map_data.get("exit", [1200, 400])
	exit_zone.position = Vector2(ex[0], ex[1])
	var col := CollisionShape2D.new()
	var rs := RectangleShape2D.new(); rs.size = Vector2(90, 90)
	col.shape = rs
	exit_zone.add_child(col)
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(-40,-40), Vector2(40,-40), Vector2(40,40), Vector2(-40,40)])
	marker.color = Color(0.2, 0.8, 0.5, 0.35)
	exit_zone.add_child(marker)
	add_child(exit_zone)
	exit_zone.body_entered.connect(_on_exit_body)

	# камера слежения
	var cam2d := Camera2D.new()
	var vc: Array = map_data.get("view_center", [640, 360])
	cam2d.position = Vector2(vc[0], vc[1])
	cam2d.enabled = true
	add_child(cam2d)
	cam2d.make_current()


func _connect_signals() -> void:
	noise_system.noise_emitted.connect(_on_noise)


func _circle_texture() -> GradientTexture2D:
	# мягкая круглая текстура для PointLight2D без внешних файлов
	var grad := Gradient.new()
	grad.set_color(0, Color(1,1,1,1))
	grad.set_color(1, Color(1,1,1,0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = gt.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	return gt


# ---------- события ----------

func _on_noise(pos: Vector2, radius: float, _strength: float) -> void:
	for g in get_tree().get_nodes_in_group("guards"):
		if g.ai: g.ai.on_noise(pos, radius)


func _on_camera_spotted(_vis: float) -> void:
	seen_by_camera = true
	evidence_left = true
	_on_alarm(null)


func _on_alarm(_guard) -> void:
	alarms += 1
	MissionManager.apply_consequences("alarm")
	hud.flash_alert()
	AudioDirector.play("siren")
	AudioDirector.set_tension(1.0)


func _on_captured() -> void:
	if _over: return
	_over = true
	seen_by_guard = true
	evidence_left = true
	GameState.change_stress(20)
	hud.show_message("ТЕБЯ СХВАТИЛИ. НОЧЬ БУДЕТ ДОЛГОЙ.")
	get_tree().create_timer(1.6).timeout.connect(func(): _finish(false))


func _on_hack_finished(kind: String, result: Dictionary) -> void:
	hack_results.append({"kind": kind, "result": result})
	if result.get("status", "") == "success":
		MissionManager.complete_objective(mission_id, 3)     # подключись к серверу
		MissionManager.complete_objective(mission_id, 4)     # извлеки данные
	elif result.get("status", "") == "partial_success":
		MissionManager.complete_objective(mission_id, 3)
		evidence_left = true
	if int(result.get("heat_increase", 0)) > 0:
		GameState.change_heat(int(result["heat_increase"]))


func _on_exit_body(body: Node) -> void:
	if _over or body != player: return
	escaped = true
	_finish(true)


func _finish(success: bool) -> void:
	if _over and not success: pass
	_over = true
	var objectives_done := 0
	var def := MissionManager.get_definition(mission_id)
	var obj_count: int = (def.get("objectives", []) as Array).size()
	var entry: Dictionary = GameState.missions_state.get(mission_id, {})
	for o in entry.get("objectives", []):
		if o: objectives_done += 1
	# успех = дошёл до выхода И выполнил цель взлома
	success = success and objectives_done >= mini(obj_count, 5)
	var reward_mult := 1.0
	if alarms == 0 and not seen_by_guard and not seen_by_camera:
		reward_mult = 1.3
		MissionManager.complete_objective(mission_id, 0, true)   # не поднимай тревогу
		MissionManager.apply_consequences("clean_exit")
	if not seen_by_camera:
		MissionManager.complete_objective(mission_id, 1, true)
	var result := {
		"reward_mult": reward_mult,
		"alarms": alarms,
		"evidence_left": evidence_left,
		"extra_heat": clampi(alarms * 3 + GameState.time_penalty_minutes, 0, 30),
		"data_gained": hack_results.filter(func(h): return h["result"].get("status","") in ["success","partial_success"]).size(),
	}
	GameState.time_penalty_minutes = 0
	MissionManager.finish_mission(mission_id, success, result)
	var scene := load("res://screens/MissionResult.tscn").instantiate()
	scene.result_data = result
	scene.success = success
	add_child(scene)


func on_hack_finished(_kind: String, _result: Dictionary) -> void:
	pass  # вызывается из ServerConnectionSystem.apply_outcome (совместимость API)


func _process(_dt: float) -> void:
	if _over: return
	# цель "проникни в здание": игрок внутри прямоугольника bounds
	var b: Array = map_data.get("bounds", [])
	if b.size() == 4 and not GameState.missions_state.get(mission_id, {}).get("objectives", [false])[0]:
		var r := Rect2(b[0], b[1], b[2], b[3])
		if r.has_point(player.global_position):
			MissionManager.complete_objective(mission_id, 0)

func current_stealth_visibility() -> float:
	return stealth_system.compute_visibility() if stealth_system else 0.0

func guard_max_suspicion() -> float:
	var m := 0.0
	for g in get_tree().get_nodes_in_group("guards"):
		if g.ai: m = maxf(m, g.ai.suspicion)
	return m
