# HackingMinigameSystem — менеджер абстрактных мини-игр.
# Узел находится в сцене миссии. Открывает рамку, ждёт сигнал finished(result).
extends Node

signal minigame_started(kind: String)
signal minigame_finished(kind: String, result: Dictionary)

const FRAMES := {
	"data_routing":        "res://minigames/frames/DataRoutingFrame.tscn",
	"connection_stability":"res://minigames/frames/ConnectionStabilityFrame.tscn",
	"trace_escape":        "res://minigames/frames/TraceEscapeFrame.tscn",
	"core_bypass":         "res://minigames/frames/CoreBypassFrame.tscn",
	# «подбор последовательности» — абстрактный игровой замок для дверей
	# (та же модель трасс, никаких реальных методов)
	"sequence_match":      "res://minigames/frames/DataRoutingFrame.tscn",
}

var active_kind: String = ""


func _ready() -> void:
	add_to_group("minigame_system")


func open_minigame(kind: String, difficulty: float = 1.0) -> void:
	if not FRAMES.has(kind):
		push_warning("Неизвестная мини-игра: " + kind)
		minigame_finished.emit(kind, _default_result("failure"))
		return
	active_kind = kind
	var frame: Control = load(FRAMES[kind]).instantiate()
	frame.set_meta("difficulty", difficulty)
	add_child(frame)
	frame.finished.connect(_on_frame_finished.bind(kind))
	minigame_started.emit(kind)


func _on_frame_finished(result: Dictionary, kind: String) -> void:
	active_kind = ""
	minigame_finished.emit(kind, result)


func _default_result(status: String) -> Dictionary:
	return {
		"status": status, "heat_increase": 0, "evidence_left": false,
		"time_penalty": 0, "data_gained": 0,
	}
