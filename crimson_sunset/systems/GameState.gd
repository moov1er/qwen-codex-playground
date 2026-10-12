# GameState — глобальное состояние игры (автозагрузка).
# Хранит ресурсы, тепло, стресс, энергию, флаги, отношения, инвентарь, миссии.
extends Node

signal stats_changed
signal flag_changed(key: String, value: bool)
signal relationship_changed(who: String, value: int)
signal inventory_changed
signal mission_state_changed(id: String)
signal objective_completed(mission_id: String, index: int)
signal objective_failed(mission_id: String, index: int)

const SAVE_VERSION := 1

# --- базовые ресурсы ---
var money: int = 120
var heat: int = 5            # "тепло" корпорации 0..100
var stress: int = 20         # стресс героя 0..100
var energy: int = 80         # энергия 0..100
var reputation: int = 0      # репутация в сети Crimson Sunset

# --- сюжет ---
var flags: Dictionary = {}                       # строковые флаги -> bool
var relationships: Dictionary = {}               # id персонажа -> -100..100
var evidence: Array[String] = []                 # найденные улики
var news_history: Array[String] = []             # показанные новости
var day: int = 1
var time_of_day: String = "evening"              # morning/day/evening/sunset/night
var time_penalty_minutes: int = 0                # потерянное время (шумные замки, долгие взломы)

# --- миссии ---
var missions_state: Dictionary = {}              # id -> {status, objectives:[bool], optionals:[bool]}

# --- инвентарь и снаряжение ---
var inventory: Dictionary = {}                   # item_id -> количество
var equipped: Dictionary = {}                    # slot -> item_id

# --- убежище ---
var hideout: Dictionary = {
	"security": 1,       # уровень безопасности
	"equipment": 1,      # уровень оборудования
	"bed_quality": 1,    # качество сна
	"backup_power": false,
	"shielding": false,
}

# --- текущая активная миссия (для стелс-режима) ---
var active_mission_id: String = ""
var last_mission_result: Dictionary = {}   # результат последней миссии для Desktop-отчёта


func _ready() -> void:
	reset_new_game()


func reset_new_game() -> void:
	money = 120; heat = 5; stress = 20; energy = 80; reputation = 0
	flags.clear(); relationships.clear(); evidence.clear(); news_history.clear()
	day = 1; time_of_day = "evening"
	missions_state.clear(); inventory.clear(); equipped.clear()
	hideout = {"security": 1, "equipment": 1, "bed_quality": 1, "backup_power": false, "shielding": false}
	active_mission_id = ""
	last_mission_result = {}
	add_item("deck", 1)        # терминал-«палуба» (устройство подключения)
	add_item("noise_box", 1)   # абстрактный генератор отвлекающего звука
	stats_changed.emit()


# ===================== РЕСУРСЫ =====================

func add_money(amount: int) -> void:
	money = max(0, money + amount)
	stats_changed.emit()

func spend_money(amount: int) -> bool:
	if money < amount: return false
	money -= amount
	stats_changed.emit()
	return true

func change_heat(delta: int) -> void:
	heat = clampi(heat + delta, 0, 100)
	stats_changed.emit()

func change_stress(delta: int) -> void:
	stress = clampi(stress + delta, 0, 100)
	stats_changed.emit()

func change_energy(delta: int) -> void:
	energy = clampi(energy + delta, 0, 100)
	stats_changed.emit()

func change_reputation(delta: int) -> void:
	reputation += delta
	stats_changed.emit()


# ===================== ФЛАГИ =====================

func set_flag(key: String, value: bool = true) -> void:
	flags[key] = value
	flag_changed.emit(key, value)

func has_flag(key: String) -> bool:
	return bool(flags.get(key, false))

func clear_flag(key: String) -> void:
	set_flag(key, false)


# ===================== ОТНОШЕНИЯ =====================

func increase_relationship(who: String, delta: int = 1) -> void:
	relationships[who] = clampi(int(relationships.get(who, 0)) + delta, -100, 100)
	relationship_changed.emit(who, relationships[who])

func decrease_relationship(who: String, delta: int = 1) -> void:
	increase_relationship(who, -delta)

func get_relationship(who: String) -> int:
	return int(relationships.get(who, 0))


# ===================== ПРЕДМЕТЫ =====================

func add_item(item_id: String, count: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	inventory_changed.emit()

func remove_item(item_id: String, count: int = 1) -> bool:
	var have: int = int(inventory.get(item_id, 0))
	if have < count: return false
	inventory[item_id] = have - count
	if inventory[item_id] <= 0: inventory.erase(item_id)
	inventory_changed.emit()
	return true

func has_item(item_id: String, count: int = 1) -> bool:
	return int(inventory.get(item_id, 0)) >= count

func equip_item(slot: String, item_id: String) -> void:
	equipped[slot] = item_id
	inventory_changed.emit()


# ===================== УЛИКИ =====================

func add_evidence(ev_id: String) -> void:
	if not evidence.has(ev_id):
		evidence.append(ev_id)
		set_flag("evidence_" + ev_id)
		stats_changed.emit()


# ===================== МИССИИ =====================

func is_mission_completed(id: String) -> bool:
	return str(_mission_entry(id).get("status", "")) == "completed"

func is_mission_failed(id: String) -> bool:
	return str(_mission_entry(id).get("status", "")) == "failed"

func _mission_entry(id: String) -> Dictionary:
	if not missions_state.has(id):
		missions_state[id] = {"status": "locked", "objectives": [], "optionals": []}
	return missions_state[id]

func unlock_mission(id: String) -> void:
	var e := _mission_entry(id)
	if e["status"] == "locked":
		e["status"] = "available"
		mission_state_changed.emit(id)

func complete_mission(id: String) -> void:
	_mission_entry(id)["status"] = "completed"
	mission_state_changed.emit(id)

func fail_mission_record(id: String) -> void:
	_mission_entry(id)["status"] = "failed"
	mission_state_changed.emit(id)

func set_objective_done(id: String, index: int, optional: bool = false) -> void:
	var e := _mission_entry(id)
	var arr_key := "optionals" if optional else "objectives"
	var arr: Array = e[arr_key]
	while arr.size() <= index: arr.append(false)
	arr[index] = true
	objective_completed.emit(id, index)

func set_objective_fail(id: String, index: int) -> void:
	var e := _mission_entry(id)
	var arr: Array = e["objectives"]
	while arr.size() <= index: arr.append(false)
	arr[index] = false
	objective_failed.emit(id, index)


# ===================== ВРЕМЯ =====================

func advance_time(hours: int = 1) -> void:
	TimeSystem.advance(hours)
	day = TimeSystem.day
	time_of_day = TimeSystem.period
	stats_changed.emit()
