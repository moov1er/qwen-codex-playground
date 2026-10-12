# MissionResult — экран последствий после миссии: успех/провал, награды, тепло,
# улики, сюжетные флаги. По кнопке — возврат на рабочий стол (данные уже применены
# через MissionManager.finish_mission до показа этого экрана).
extends Control

# StealthMission заполняет эти поля перед добавлением сцены в дерево:
var success: bool = false
var result_data: Dictionary = {}


@onready var title_label: Label = $Top/TitleLabel
@onready var body_text: RichTextLabel = $Center/BodyText
@onready var ok_btn: Button = $Bottom/OkBtn


func _ready() -> void:
	ok_btn.pressed.connect(func(): get_parent().goto("desktop"))
	_show()


func _show() -> void:
	var d := result_data if not result_data.is_empty() else GameState.last_mission_result
	var mid := str(d.get("mission_id", ""))
	var def := MissionManager.get_definition(mid) if mid != "" else {}
	title_label.text = "ОПЕРАЦИЯ ЗАВЕРШЕНА" if success else "ПРОВАЛ ОПЕРАЦИИ"
	title_label.add_theme_color_override("font_color",
		Color(0.5, 0.9, 0.6) if success else Color(0.95, 0.25, 0.25))

	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % def.get("title", mid))
	lines.append("")
	if success:
		lines.append("Ты вышел незамеченным... или почти. Данные у тебя.")
	else:
		lines.append("Система тебя поймала. Часть данных потеряна, следы горячее.")
	lines.append("")
	lines.append("Тревог поднято: [b]%d[/b]" % int(d.get("alarms", 0)))
	lines.append("Улик оставлено: [b]%d[/b]" % int(d.get("evidence_left", 0)))
	lines.append("Взломов успешно: [b]%d[/b]" % int(d.get("data_gained", 0)))
	lines.append("Множитель награды: x%.1f" % float(d.get("reward_mult", 1.0)))
	lines.append("")
	lines.append("[color=#c8a24a]Текущее состояние:[/color]")
	lines.append("₽ %d · Тепло %d%% · Стресс %d%% · Репутация %d" % [
		GameState.money, GameState.heat, GameState.stress, GameState.reputation])
	if not GameState.evidence.is_empty():
		lines.append("")
		lines.append("[color=#ff5a4a]⚠ Улики наружу (корпорация ближе к тебе):[/color]")
		for ev in GameState.evidence:
			lines.append("  ▪ " + str(ev))
	if success and def.has("flags_on_complete"):
		lines.append("")
		lines.append("[color=#7fd4a0]Приобретено:[/color]")
		for fl in def["flags_on_complete"]:
			lines.append("  ✔ " + _flag_name(str(fl)))
	body_text.text = "\n".join(lines)
	AudioDirector.play("alarm" if not success else "message")


func _flag_name(fl: String) -> String:
	match fl:
		"sister_signal_found": return "Пакет САНСЕТА — сигнал сестры"
		"helios_file_found": return "Файл о проекте Helios"
		"access_key_spire": return "Ключ доступа к Solar Spire"
		"joined_crimson": return "Crimson Sunset приняла тебя"
		"m01_completed": return "Миссия «Мёртвый канал» закрыта"
		"m02_completed": return "Миссия «Архив под стеклом» закрыта"
		"m03_completed": return "Миссия «Гелиос-7» закрыта"
		_: return fl.replace("_", " ")
