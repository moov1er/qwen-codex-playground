# NoiseSource — интерактивный генератор шума (отвлекающее устройство "шум-бокс").
extends Node2D

@export var noise_radius := NoiseSystem.DISTRACTOR
@export var duration := 8.0
@export var uses_item: String = "noise_box"

func _ready() -> void:
	add_to_group("interactable")

func get_interact_label() -> String:
	if GameState.has_item(uses_item):
		return "[E] Бросить шум-бокс (отвлечь охрану)"
	return ""   # нет предмета — не подсвечиваем

func try_interact(actor: Node2D) -> void:
	if not GameState.remove_item(uses_item, 1): return
	AudioDirector.play("click")
	var ns := actor.noise_system
	if ns == null:
		ns = get_tree().get_first_node_in_group("noise_system")
	# серия импульсов — охрана бежит сюда
	for i in int(duration / 1.5):
		var t := i * 1.5
		get_tree().create_timer(t).timeout.connect(func(): ns.emit_noise(global_position, noise_radius))
