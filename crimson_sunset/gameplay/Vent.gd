# Vent — вентиляционный лаз: быстрый скрытный проход с шумом при входе/выходе.
extends Node2D

@export var exit_point: Marker2D        # куда выходить
@export var noise_radius := NoiseSystem.STEP_WALK

func _ready() -> void:
	add_to_group("interactable")


func get_interact_label() -> String:
	return "[E] Пролезть в вентиляцию"


func try_interact(actor: Node2D) -> void:
	if exit_point == null:
		push_warning("Vent: не задан exit_point"); return
	actor.global_position = exit_point.global_position
	actor.make_noise(noise_radius)
	AudioDirector.play("hide")
