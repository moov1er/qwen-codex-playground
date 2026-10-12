# NewsSystem — городские новости Меридиана. Данные: res://data/news.json
extends Node

signal news_added(item: Dictionary)

var _feed: Array = []          # все определения новостей из JSON
var queue: Array = []          # очередь непросмотренных


func _ready() -> void:
	_feed = _load_json("res://data/news.json")


func push_news(id: String) -> void:
	for n in _feed:
		if str(n.get("id", "")) == id:
			queue.append(n)
			GameState.news_history.append(id)
			news_added.emit(n)


func unread_count() -> int:
	return queue.size()


func pop_next() -> Dictionary:
	if queue.is_empty(): return {}
	return queue.pop_front()


func random_rumor() -> Dictionary:
	# атмосферные слухи зависят от тепла
	var pool: Array = []
	for n in _feed:
		var min_heat: int = int(n.get("min_heat", 0))
		if GameState.heat >= min_heat: pool.append(n)
	if pool.is_empty(): return {}
	return pool[randi() % pool.size()]


func _load_json(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Нет файла: " + path); return []
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_ARRAY else []
