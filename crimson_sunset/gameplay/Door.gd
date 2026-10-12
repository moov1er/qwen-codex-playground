# Door — дверь: закрытая / открытая / запертая на ключ-карту или абстрактный замок.
extends StaticBody2D

@export var locked_by_key: String = ""       # item_id ключ-карты, "" = без ключа
@export var lockpick_minutes: int = 2        # "шумная" возня с замком = время потери
@export var auto_open_time := 6.0            # автозакрытие

var open: bool = false
var collision_shape: CollisionShape2D

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group("interactable")
	collision_shape = $CollisionShape2D
	set_process(false)


func get_interact_label() -> String:
	if open: return "[E] Закрыть дверь"
	if locked_by_key != "":
		return "[E] Дверь — нужен пропуск"
	return "[E] Открыть дверь"


func try_interact(actor: Node2D) -> void:
	if open:
		open = false
		collision_shape.disabled = false
		visual.color = Color(0.35, 0.3, 0.4)
		AudioDirector.play("door")
		actor.make_noise(NoiseSystem.DOOR)
		return
	if locked_by_key != "":
		if GameState.has_item(locked_by_key):
			GameState.remove_item(locked_by_key, 1)
			_open(actor)
		else:
			# абстрактный взлом замка: мини-игра «подбор последовательности»,
			# провал = шум и улики (никаких реальных методов — игровая условность)
			var ms := get_tree().get_first_node_in_group("minigame_system")
			if ms != null and ms.active_kind == "":
				ms.minigame_finished.connect(_on_lock_done.bind(actor), CONNECT_ONE_SHOT)
				ms.open_minigame("sequence_match", 1.0)
			else:
				_noisy_open(actor)
		return
	_open(actor)


func _on_lock_done(_kind: String, result: Dictionary, actor: Node2D) -> void:
	var status: String = str(result.get("status", "failure"))
	if status == "success":
		_open(actor)
	elif status == "partial_success":
		_open(actor)
		GameState.time_penalty_minutes += lockpick_minutes / 2
		actor.make_noise(NoiseSystem.BROKEN_LOCK)
	else:
		# замок не поддаётся — очень шумно
		actor.make_noise(NoiseSystem.BROKEN_LOCK)
		GameState.time_penalty_minutes += lockpick_minutes
		MissionManager.apply_consequences("evidence")


func _noisy_open(actor: Node2D) -> void:
	GameState.time_penalty_minutes += lockpick_minutes
	_open(actor)
	actor.make_noise(NoiseSystem.BROKEN_LOCK)
	MissionManager.apply_consequences("evidence")


func _open(actor: Node2D) -> void:
	open = true
	collision_shape.disabled = true
	visual.color = Color(0.2, 0.45, 0.35)
	AudioDirector.play("door")
	actor.make_noise(NoiseSystem.DOOR)
	set_process(true)


func _process(delta: float) -> void:
	auto_open_time -= delta
	if auto_open_time <= 0.0:
		set_process(false)
		open = false
		collision_shape.disabled = false
		visual.color = Color(0.35, 0.3, 0.4)
		AudioDirector.play("door")
