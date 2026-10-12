# DialogueManager — диалоговая система с выборами, флагами и отношениями.
# Данные: res://data/dialogues.json и res://data/characters.json
extends Node

signal dialogue_started(dialogue_id: String)
signal line_shown(node: Dictionary)
signal dialogue_ended(dialogue_id: String)

var dialogues: Dictionary = {}     # id -> {character, lines:{node_id: node}}
var characters: Dictionary = {}    # id -> описание персонажа
var current_id: String = ""
var current_node: Dictionary = {}


func _ready() -> void:
	dialogues = _load_dict("res://data/dialogues.json", "id")
	characters = _load_dict("res://data/characters.json", "id")


func get_character(cid: String) -> Dictionary:
	return characters.get(cid, {"name": cid})


func character_name(cid: String) -> String:
	return str(get_character(cid).get("name", cid))


func start_dialogue(id: String) -> bool:
	if not dialogues.has(id):
		push_warning("Нет диалога: " + id)
		return false
	current_id = id
	dialogue_started.emit(id)
	goto("start")
	return true


func goto(node_id: String) -> void:
	var d: Dictionary = dialogues.get(current_id, {})
	var lines: Dictionary = d.get("lines", {})
	if not lines.has(node_id):
		end_dialogue()
		return
	current_node = lines[node_id]
	current_node["_character"] = d.get("character", "")
	line_shown.emit(current_node)


func choose(index: int) -> void:
	var choices: Array = current_node.get("choices", [])
	if index < 0 or index >= choices.size():
		end_dialogue(); return
	var ch: Dictionary = choices[index]
	_apply_effects(ch)
	var next: String = str(ch.get("next", ""))
	if next == "" or next == "END":
		end_dialogue()
	else:
		goto(next)


func advance() -> void:
	# линия без выборов: идём к "next" или завершаем
	_apply_effects(current_node)
	var next: String = str(current_node.get("next", ""))
	if next == "" or next == "END":
		end_dialogue()
	else:
		goto(next)


func end_dialogue() -> void:
	var id := current_id
	current_id = ""
	current_node = {}
	dialogue_ended.emit(id)


func _apply_effects(src: Dictionary) -> void:
	for fl in src.get("flags", []):
		GameState.set_flag(str(fl))
	var rels: Dictionary = src.get("relationships", {})
	for who in rels:
		GameState.increase_relationship(str(who), int(rels[who]))
	if src.has("money"): GameState.add_money(int(src["money"]))
	for n in src.get("news", []):
		NewsSystem.push_news(str(n))


# Проверка условий появления выбора (флаги, предметы, отношения).
func choice_available(ch: Dictionary) -> bool:
	for fl in ch.get("need_flags", []):
		if not GameState.has_flag(str(fl)): return false
	for fl in ch.get("hide_if_flags", []):
		if GameState.has_flag(str(fl)): return false
	for it in ch.get("need_items", []):
		if not GameState.has_item(str(it)): return false
	var cond_rel: Dictionary = ch.get("min_relationship", {})
	for who in cond_rel:
		if GameState.get_relationship(str(who)) < int(cond_rel[who]): return false
	return true


func _load_dict(path: String, key: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		push_warning("Нет файла: " + path); return out
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY: return out
	for item in parsed:
		if typeof(item) == TYPE_DICTIONARY and item.has(key):
			out[str(item[key])] = item
	return out
