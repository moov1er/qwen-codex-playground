# Main — корневой переключатель экранов. Все экраны живут как дочерние сцены,
# виден только активный (экономит память и сохраняет состояние сессии).
extends Node

const SCREENS := {
	"menu":     "res://screens/MainMenu.tscn",
	"desktop":  "res://screens/Desktop.tscn",
	"hideout":  "res://screens/Hideout.tscn",
	"map":      "res://screens/CityMap.tscn",
	"briefing": "res://screens/MissionBriefing.tscn",
	"mission":  "res://gameplay/StealthMission.tscn",
	"result":   "res://screens/MissionResult.tscn",
}

var _current: String = ""
var _instances: Dictionary = {}
var pending_mission_id: String = ""   # выбранная на карте/десктопе миссия для брифинга


func _ready() -> void:
	goto("menu")


func goto(name_key: String, keep_current: bool = false) -> void:
	if not SCREENS.has(name_key):
		push_error("Неизвестный экран: " + name_key); return
	if _current != "" and _instances.has(_current):
		_instances[_current].visible = false
	if not _instances.has(name_key):
		var inst: Node = load(SCREENS[name_key]).instantiate()
		add_child(inst)
		_instances[name_key] = inst
		if inst.has_method("on_enter"):
			pass  # on_enter вызовется после visible=true ниже
	var node := _instances[name_key]
	node.visible = true
	_current = name_key
	if node.has_method("on_enter"):
		node.call_deferred("on_enter")


func quit_game() -> void:
	get_tree().quit()
