# SaveManager — сохранение/загрузка состояния через JSON.
extends Node

const SAVE_PATH := "user://crimson_sunset_save.json"

signal game_saved
signal game_loaded


func save_game() -> bool:
	var data := {
		"version": GameState.SAVE_VERSION,
		"money": GameState.money,
		"heat": GameState.heat,
		"stress": GameState.stress,
		"energy": GameState.energy,
		"reputation": GameState.reputation,
		"flags": GameState.flags,
		"relationships": GameState.relationships,
		"evidence": GameState.evidence,
		"news_history": GameState.news_history,
		"day": GameState.day,
		"time_of_day": GameState.time_of_day,
		"missions_state": GameState.missions_state,
		"inventory": GameState.inventory,
		"equipped": GameState.equipped,
		"hideout": GameState.hideout,
		"active_mission_id": GameState.active_mission_id,
		"time": TimeSystem.export_state(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Не удалось сохранить игру: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	game_saved.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save(): return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Файл сохранения повреждён.")
		return false
	var d: Dictionary = parsed
	GameState.money = int(d.get("money", 120))
	GameState.heat = int(d.get("heat", 0))
	GameState.stress = int(d.get("stress", 0))
	GameState.energy = int(d.get("energy", 100))
	GameState.reputation = int(d.get("reputation", 0))
	GameState.flags = _as_dict(d.get("flags"))
	GameState.relationships = _as_dict(d.get("relationships"))
	GameState.evidence.clear()
	for e in _as_array(d.get("evidence")): GameState.evidence.append(str(e))
	GameState.news_history.clear()
	for n in _as_array(d.get("news_history")): GameState.news_history.append(str(n))
	GameState.day = int(d.get("day", 1))
	GameState.time_of_day = str(d.get("time_of_day", "evening"))
	GameState.missions_state = _as_dict(d.get("missions_state"))
	GameState.inventory = _as_dict(d.get("inventory"))
	GameState.equipped = _as_dict(d.get("equipped"))
	var h := _as_dict(d.get("hideout"))
	if not h.is_empty(): GameState.hideout = h
	GameState.active_mission_id = str(d.get("active_mission_id", ""))
	TimeSystem.import_state(_as_dict(d.get("time")))
	GameState.stats_changed.emit()
	game_loaded.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _as_dict(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}

func _as_array(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []
