# Hideout — убежище: сон, еда, чистка следов, улучшения, доска расследования,
# разговоры с персонажами (диалоги по флагам сюжета).
extends Control

@onready var log_label: Label = $Log
@onready var board_label: RichTextLabel = $Board/Text


func _ready() -> void:
	GameState.stats_changed.connect(_refresh)
	GameState.mission_state_changed.connect(func(_id): _refresh_board())
	# соединения кнопок — кодом, чтобы .tscn оставался простым и читаемым
	$Actions/SleepBtn.pressed.connect(_on_sleep_pressed)
	$Actions/EatBtn.pressed.connect(_on_eat_pressed)
	$Actions/CoolBtn.pressed.connect(_on_cool_pressed)
	$Upgrades/SecurityBtn.pressed.connect(_on_upgrade_security_pressed)
	$Upgrades/EquipmentBtn.pressed.connect(_on_upgrade_equipment_pressed)
	$Upgrades/BedBtn.pressed.connect(_on_upgrade_bed_pressed)
	$Upgrades/PowerBtn.pressed.connect(_on_upgrade_power_pressed)
	$Upgrades/ShieldBtn.pressed.connect(_on_upgrade_shield_pressed)
	$People/TalkRenBtn.pressed.connect(_on_talk_ren_pressed)
	$People/TalkPhoenixBtn.pressed.connect(_on_talk_phoenix_pressed)
	$People/TalkAshBtn.pressed.connect(_on_talk_ash_pressed)
	$Nav/DeskBtn.pressed.connect(_on_desk_pressed)
	$Nav/MapBtn.pressed.connect(_on_map_pressed)
	_refresh()
	_refresh_board()


func on_enter() -> void:
	_refresh(); _refresh_board()


func _refresh() -> void:
	var h: Dictionary = GameState.hideout
	log_label.text = "₽ %d  Тепло %d%%  Стресс %d%%  Энергия %d%%\nУбежище: безопасность %d, оборудование %d, кровать %d, резервное питание %s, экранирование %s" % [
		GameState.money, GameState.heat, GameState.stress, GameState.energy,
		int(h.security), int(h.equipment), int(h.bed_quality),
		"есть" if h.backup_power else "нет", "есть" if h.shielding else "нет"]


func _refresh_board() -> void:
	# доска расследования: улики + флаги -> зацепки
	var lines: Array[String] = ["[ доска расследования ]"]
	if GameState.has_flag("sister_signal_found"):
		lines.append("▪ Пакет САНСЕТА: последние координаты Лины — старый сервисный узел. Она жива?")
	if GameState.has_flag("m02_completed"):
		lines.append("▪ Файл HELIOS: система 'предсказывает' людей. Лина была в списке 'профилактики'.")
	if GameState.has_flag("m03_completed"):
		lines.append("▪ Ключ доступа к Solar Spire. Акт 5 близко.")
	for ev in GameState.evidence:
		lines.append("▪ (улика наружу): " + str(ev))
	if lines.size() == 1:
		lines.append("Пока пусто. Начни с заданий на карте.")
	board_label.text = "\n".join(lines)


func _say(res: Dictionary) -> void:
	log_label.text += "\n" + str(res.get("text", ""))
	AudioDirector.play("message")


func _on_sleep_pressed() -> void: _say(HideoutSystem.sleep_hours()); _refresh()
func _on_eat_pressed() -> void: _say(HideoutSystem.eat()); _refresh()
func _on_cool_pressed() -> void: _say(HideoutSystem.cool_heat()); _refresh()


func _on_upgrade_security_pressed() -> void: _say(HideoutSystem.upgrade("security")); _refresh()
func _on_upgrade_equipment_pressed() -> void: _say(HideoutSystem.upgrade("equipment")); _refresh()
func _on_upgrade_bed_pressed() -> void: _say(HideoutSystem.upgrade("bed_quality")); _refresh()
func _on_upgrade_power_pressed() -> void: _say(HideoutSystem.upgrade("backup_power")); _refresh()
func _on_upgrade_shield_pressed() -> void: _say(HideoutSystem.upgrade("shielding")); _refresh()


func _on_talk_ren_pressed() -> void:
	DialogueManager.start_dialogue("ren_hideout" if GameState.has_flag("joined_crimson") else "ren_intro")
func _on_talk_phoenix_pressed() -> void:
	DialogueManager.start_dialogue("phoenix_brief")
func _on_talk_ash_pressed() -> void:
	DialogueManager.start_dialogue("ash_advice")
func _on_desk_pressed() -> void: get_parent().goto("desktop")
func _on_map_pressed() -> void: get_parent().goto("map")
