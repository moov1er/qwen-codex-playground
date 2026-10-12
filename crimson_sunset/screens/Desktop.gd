# Desktop — рабочий стол хакера: терминал, почта/сообщения, новости, миссии,
# файлы (улики), переходы в убежище и на карту. Ключевой хаб игры.
extends Control

@onready var terminal_out: RichTextLabel = $Main/Terminal/Out
@onready var news_list: ItemList = $Main/News/List
@onready var missions_list: ItemList = $Main/Missions/List
@onready var files_list: ItemList = $Main/Files/List
@onready var stats_label: Label = $Top/Stats
@onready var inbox_btn: Button = $Top/InboxBtn
@onready var dialogue_box: Control = $DialogueBox


func _ready() -> void:
	GameState.stats_changed.connect(_refresh_stats)
	GameState.mission_state_changed.connect(func(_i): _refresh_missions())
	NewsSystem.news_added.connect(func(_n): _refresh_news())
	_refresh_stats(); _refresh_missions(); _refresh_news(); _refresh_files()
	_terminal("# crimson shell v0.7  [соединение зашифровано]")
	_terminal("Алекс, сеть шумит. Проверь входящие.")


func on_enter() -> void:
	_refresh_all()


func _refresh_all() -> void:
	_refresh_stats(); _refresh_missions(); _refresh_news(); _refresh_files()


func _refresh_stats() -> void:
	stats_label.text = "₽ %d   Тепло %d%%   Стресс %d%%   Энергия %d%%   Репутация %d   %s" % [
		GameState.money, GameState.heat, GameState.stress, GameState.energy,
		GameState.reputation, TimeSystem.period_label()]


func _refresh_missions() -> void:
	missions_list.clear()
	for def in MissionManager.all_missions():
		var id := str(def.get("id", ""))
		if MissionManager.is_mission_available(id):
			missions_list.add_item("%s  [акт %d]" % [def.get("title", id), int(def.get("act", 1))])
			missions_list.set_item_metadata(missions_list.get_item_count() - 1, id)
	if missions_list.get_item_count() == 0:
		missions_list.add_item("Нет доступных заданий. Поговори с контактами.")


func _refresh_news() -> void:
	news_list.clear()
	var items: Array = GameState.news_history.duplicate()
	items.reverse()
	for nid in items.slice(0, 8):
		for n in NewsSystem._feed:
			if str(n.get("id", "")) == str(nid):
				news_list.add_item("▪ " + str(n.get("headline", "?")))


func _refresh_files() -> void:
	files_list.clear()
	for ev in GameState.evidence:
		files_list.add_item("📄 " + str(ev))
	if GameState.has_flag("sister_signal_found"):
		files_list.add_item("📄 пакет_САНСЕТА.enc")


func _on_mission_selected(index: int) -> void:
	var id: Variant = missions_list.get_item_metadata(index)
	if id != null:
		get_parent().pending_mission_id = str(id)
		get_parent().goto("briefing")


func _on_inbox_pressed() -> void:
	# сообщения-диалоги: первое непройденное письмо открывает диалог
	if not GameState.has_flag("met_ren"):
		DialogueManager.start_dialogue("ren_intro")
	elif not GameState.has_flag("met_mirage"):
		DialogueManager.start_dialogue("mirage_test")
	elif not GameState.has_flag("met_phoenix"):
		DialogueManager.start_dialogue("phoenix_brief")
	else:
		_terminal("[входящих нет] Город спит. Пока.")


func _on_terminal_send(text: String) -> void:
	_terminal("> " + text)
	match text.strip_edges().to_lower():
		"help": _terminal("команды: status, heat, rumors, ls")
		"status": _terminal("тепло=%d%% стресс=%d%% энергия=%d%% флагов=%d" % [GameState.heat, GameState.stress, GameState.energy, GameState.flags.size()])
		"heat": _terminal("Аврора смотрит на тебя %s." % ("слишком внимательно." if GameState.heat > 50 else "мимолётно."))
		"rumors":
			var r := NewsSystem.random_rumor()
			_terminal(r.get("body", "тишина...") if not r.is_empty() else "тишина...")
		"ls": _terminal(", ".join(GameState.evidence) if GameState.evidence.size() else "(пусто)")
		_: _terminal("неизвестная команда. help.")


func _terminal(line: String) -> void:
	terminal_out.append_text(line + "\n")
	AudioDirector.play("terminal")


func _on_hideout_pressed() -> void: get_parent().goto("hideout")
func _on_map_pressed() -> void: get_parent().goto("map")
func _on_save_pressed() -> void:
	SaveManager.save_game()
	_terminal("[сохранение записано в user://crimson_sunset_save.json]")
