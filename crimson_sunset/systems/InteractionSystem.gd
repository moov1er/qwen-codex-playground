# InteractionSystem — трекер ближайшей интерактивной цели.
# Узел InteractionSystem находится в сцене миссии; объекты добавляют себя
# в группу "interactable" и реализуют метод get_interact_label() и try_interact().
extends Node

signal target_changed(target: Node)

var player: Node2D = null
var current_target: Node = null
var range_px: float = 56.0


func _process(_dt: float) -> void:
	if player == null: return
	var best: Node = null
	var best_d := range_px
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n): continue
		if n.has_meta("disabled") and n.get_meta("disabled"): continue
		var d: float = player.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best != current_target:
		current_target = best
		target_changed.emit(best)


func do_interact() -> void:
	if current_target and current_target.has_method("try_interact"):
		current_target.try_interact(player)


func target_label() -> String:
	if current_target and current_target.has_method("get_interact_label"):
		return current_target.get_interact_label()
	return ""
