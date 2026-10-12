# TimeSystem — время суток: утро, день, вечер, закат, ночь.
extends Node

signal time_changed(hour: int, period: String)

var hour: int = 18          # текущий час 0..23
var day: int = 1
var period: String = "sunset"

const PERIOD_NAMES := {
	"morning": "Утро", "day": "День", "evening": "Вечер",
	"sunset": "Закат", "night": "Ночь",
}


func advance(hours: int = 1) -> void:
	hour += hours
	while hour >= 24:
		hour -= 24
		day += 1
	GameState.day = day
	period = _period_for(hour)
	GameState.time_of_day = period
	time_changed.emit(hour, period)


func _period_for(h: int) -> String:
	if h < 6: return "night"
	if h < 11: return "morning"
	if h < 16: return "day"
	if h < 18: return "evening"
	if h < 20: return "sunset"
	return "night"


func period_label() -> String:
	return "%s, %02d:00, день %d" % [PERIOD_NAMES.get(period, "?"), hour, day]


func is_sunset() -> bool:
	return period == "sunset"


func export_state() -> Dictionary:
	return {"hour": hour, "day": day, "period": period}


func import_state(d: Dictionary) -> void:
	hour = int(d.get("hour", 18))
	day = int(d.get("day", 1))
	period = str(d.get("period", "sunset"))
