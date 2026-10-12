# Pickup — подбираемый предмет (ключ-карта, файл Лины, модуль).
extends Node2D

@export var item_id: String = "keycard"
@export var is_evidence: bool = false
@export var evidence_id: String = ""
@export var objective_index: int = -1     # опциональная цель, если >=0

var taken := false

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group("interactable")


func get_interact_label() -> String:
	if taken: return ""
	return "[E] Взять: %s" % item_id


func try_interact(_actor: Node2D) -> void:
	if taken: return
	taken = true
	visual.visible = false
	GameState.add_item(item_id, 1)
	if is_evidence and evidence_id != "":
		GameState.add_evidence(evidence_id)
	if objective_index >= 0:
		GameState.set_objective_done(GameState.active_mission_id, objective_index, true)
	AudioDirector.play("pickup")
