# ServerTerminal — физическое подключение к серверу и запуск мини-игры.
extends Node2D

signal hack_finished(kind: String, result: Dictionary)

@export var minigame_kind: String = "data_routing"   # ключ в HackingMinigameSystem.FRAMES
@export var objective_index: int = 3                 # какой индекc цели засчитывать
@export var requires_item: String = "deck"           # устройство подключения
@export var difficulty: float = 1.0
@export var label_success: String = "Данные извлечены"

var hacked: bool = false
var busy: bool = false

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group("interactable")


func get_interact_label() -> String:
	if hacked: return ""
	if not GameState.has_item(requires_item):
		return "[E] Сервер — нужно устройство подключения"
	return "[E] Подключиться к серверу"


func try_interact(actor: Node2D) -> void:
	if hacked or busy: return
	if not GameState.has_item(requires_item):
		AudioDirector.play("fail")
		return
	busy = true
	AudioDirector.play("connect")
	actor.frozen = true
	visual.color = Color(0.2, 0.9, 0.7)
	var ms = get_tree().get_first_node_in_group("minigame_system")
	ms.minigame_finished.connect(_on_done, CONNECT_ONE_SHOT)
	get_tree().create_timer(0.6).timeout.connect(func(): ms.open_minigame(minigame_kind, difficulty))


func _on_done(kind: String, result: Dictionary) -> void:
	busy = false
	var p := get_tree().get_first_node_in_group("player")
	if p: p.frozen = false
	var status: String = str(result.get("status", "failure"))
	match status:
		"success":
			hacked = true
			visual.color = Color(0.5, 0.5, 0.55)
			AudioDirector.play("success")
		"partial_success":
			hacked = true
			result["partial"] = true
			AudioDirector.play("success")
		_:
			visual.color = Color(0.8, 0.25, 0.3)
			AudioDirector.play("fail")
	hack_finished.emit(kind, result)
