# MissionBriefing — брифинг перед миссией: описание, цели, опциональные задачи,
# подготовка (экипировка/состояние) и запуск стелс-уровня.
extends Control

@onready var title_label: Label = $Top/TitleLabel
@onready var body_text: RichTextLabel = $Center/BodyText
@onready var start_btn: Button = $Bottom/StartBtn
@onready var back_btn: Button = $Bottom/BackBtn

var mission_id: String = ""


func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(func(): get_parent().goto("map"))


func on_enter() -> void:
	mission_id = get_parent().pending_mission_id
	if mission_id == "" or not MissionManager.get_definition(mission_id):
		title_label.text = "БРИФИНГ"
		body_text.text = "Миссия не выбрана. Вернись на карту города."
		start_btn.disabled = true
		return
	var def := MissionManager.get_definition(mission_id)
	title_label.text = "БРИФИНГ · %s" % def.get("title", mission_id)
	start_btn.disabled = false

	var lines: Array[String] = []
	lines.append("[b]%s[/b]  ·  акт %d  ·  локация: %s" % [
		def.get("title", ""), int(def.get("act", 1)), def.get("location", "?")])
	lines.append("")
	lines.append(str(def.get("description", "")))
	lines.append("")
	lines.append("[color=#ff6a5a][b]ОСНОВНЫЕ ЦЕЛИ:[/b][/color]")
	for o in def.get("objectives", []):
		lines.append("  ▪ " + str(o))
	lines.append("")
	lines.append("[color=#c8a24a][b]ДОПОЛНИТЕЛЬНО (по желанию):[/b][/color]")
	for o in def.get("optional_objectives", []):
		lines.append("  ○ " + str(o))
	lines.append("")
	lines.append("[color=#7fd4a0][b]НАГРАДА:[/b][/color] ₽%s · репутация +%s · тепло +%s" % [
		str(def.get("rewards", {}).get("money", 0)),
		str(def.get("rewards", {}).get("reputation", 0)),
		str(def.get("rewards", {}).get("heat", 0))])
	lines.append("")
	lines.append("[i]Время: %s. Энергия: %d%%. Стресс: %d%%. Тепло: %d%%.[/i]" % [
		TimeSystem.period_label(), GameState.energy, GameState.stress, GameState.heat])
	if TimeSystem.is_sunset():
		lines.append("[color=#ff3a3a]Закат. Экраны города мерцают красным. Crimson Sunset наблюдает.[/color]")
	if GameState.heat >= 70:
		lines.append("[color=#ff3a3a]⚠ Тепло слишком высоко: в здании будет больше патрулей и реакции.[/color]")
	if GameState.energy < 30:
		lines.append("[color=#ffaa33]⚠ Ты на исходе энергии. Поспи в убежище — иначе игрок медленнее и шумнее.[/color]")
	body_text.text = "\n".join(lines)


func _on_start_pressed() -> void:
	if mission_id == "": return
	MissionManager.start_mission(mission_id)
	GameState.advance_time(1)   # дорога до объекта занимает время
	get_parent().goto("mission")
