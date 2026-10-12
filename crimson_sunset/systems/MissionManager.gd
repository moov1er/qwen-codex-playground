# MissionManager — управление миссиями. Данные: res://data/missions.json
extends Node

signal missions_loaded

var definitions: Dictionary = {}   # id -> определение миссии


func _ready() -> void:
	load_definitions()


func load_definitions() -> void:
	definitions.clear()
	if not FileAccess.file_exists("res://data/missions.json"):
		push_warning("Нет missions.json"); return
	var f := FileAccess.open("res://data/missions.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("missions.json повреждён"); return
	for m in parsed:
		if typeof(m) == TYPE_DICTIONARY and m.has("id"):
			definitions[str(m["id"])] = m
	missions_loaded.emit()


func get_definition(id: String) -> Dictionary:
	return definitions.get(id, {})


func all_missions() -> Array:
	return definitions.values()


# Миссия доступна, если разблокирована в GameState и выполнены требования.
func is_mission_available(id: String) -> bool:
	var def := get_definition(id)
	if def.is_empty(): return false
	if GameState.is_mission_completed(id): return false
	# статус
	var entry: Dictionary = GameState.missions_state.get(id, {"status": "locked"})
	if str(entry.get("status", "locked")) != "available": return false
	# требования-флаги
	for req in def.get("requirements", []):
		if not GameState.has_flag(str(req)): return false
	# требования-миссии (завершённые)
	for req in def.get("require_missions", []):
		if not GameState.is_mission_completed(str(req)): return false
	return true


# Открыть все стартовые миссии (для новой игры).
func unlock_initial() -> void:
	for id in definitions:
		var def: Dictionary = definitions[id]
		if int(def.get("act", 1)) <= 1 and (def.get("requirements", []) as Array).is_empty():
			GameState.unlock_mission(id)


func start_mission(id: String) -> void:
	GameState.active_mission_id = id
	GameState.set_flag("mission_started_" + id)


# Завершение по результату из стелс-сцены.
func finish_mission(id: String, success: bool, result: Dictionary) -> void:
	var def := get_definition(id)
	GameState.active_mission_id = ""
	if success:
		GameState.complete_mission(id)
		apply_rewards(def, result)
		for fl in def.get("flags_on_complete", []):
			GameState.set_flag(str(fl))
		for n in def.get("news_on_complete", []):
			NewsSystem.push_news(str(n))
		# открытие следующих миссий
		for nxt in def.get("unlocks", []):
			GameState.unlock_mission(str(nxt))
	else:
		GameState.fail_mission_record(id)
		for fl in def.get("flags_on_fail", []):
			GameState.set_flag(str(fl))
		GameState.unlock_mission(id)  # провал не блокирует повтор
	result["mission_id"] = id
	result["success"] = success
	GameState.last_mission_result = result
	SaveManager.save_game()


func apply_rewards(def: Dictionary, result: Dictionary) -> void:
	var rw: Dictionary = def.get("rewards", {})
	var mult: float = float(result.get("reward_mult", 1.0))
	if rw.has("money"): GameState.add_money(int(round(int(rw["money"]) * mult)))
	if rw.has("reputation"): GameState.change_reputation(int(rw["reputation"]))
	# тепло: базовое из наград + штраф за тревогу/шум/улики
	var heat_gain: int = int(rw.get("heat", 0))
	heat_gain += int(result.get("extra_heat", 0))
	if int(result.get("alarms", 0)) > 0: heat_gain += 8 * int(result["alarms"])
	if result.get("evidence_left", false): heat_gain += 10
	GameState.change_heat(heat_gain)
	if rw.has("items"):
		for it in rw["items"]:
			GameState.add_item(str(it), 1)
	if rw.has("evidence"):
		for ev in rw["evidence"]:
			GameState.add_evidence(str(ev))


func complete_objective(mission_id: String, index: int, optional: bool = false) -> void:
	GameState.set_objective_done(mission_id, index, optional)


func fail_objective(mission_id: String, index: int) -> void:
	GameState.set_objective_fail(mission_id, index)


func apply_consequences(kind: String) -> void:
	match kind:
		"alarm":
			GameState.change_heat(6)
			GameState.change_stress(8)
		"evidence":
			GameState.change_heat(10)
			GameState.add_evidence("trace_%d" % randi_range(100, 999))
		"clean_exit":
			GameState.increase_relationship("phoenix", 2)
