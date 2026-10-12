# ServerConnectionSystem — физическое подключение к серверу.
# Логика встроена в ServerTerminal (gameplay/ServerTerminal.gd); этот узел
# хранит правила последствий и общий знаменатель для мини-игр подключения.
extends Node

signal connection_progress(percent: float)
signal connection_outcome(outcome: String)   # success / partial / failure

# Итоговый пересчёт результата мини-игры в последствия миссии.
func apply_outcome(mission_root: Node, kind: String, result: Dictionary) -> void:
	var status: String = str(result.get("status", "failure"))
	match status:
		"success":
			connection_outcome.emit("success")
		"partial_success":
			connection_outcome.emit("partial")
		_:
			connection_outcome.emit("failure")
	mission_root.on_hack_finished(kind, result)
