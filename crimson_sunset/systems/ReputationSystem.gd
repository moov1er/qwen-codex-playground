# ReputationSystem — отношения с фракциями (справочная логика поверх GameState.relationships).
extends Node

const FACTIONS := ["crimson", "aurora", "black_market", "informants"]

static func faction_standing(f: String) -> int:
	match f:
		"aurora": return -GameState.heat  # чем выше тепло, тем хуже отношение Авроры
		"crimson": return GameState.reputation * 5
		_: return GameState.get_relationship(f)

static func standing_label(v: int) -> String:
	if v <= -60: return "Вражда"
	if v <= -20: return "Недоверие"
	if v < 20: return "Наблюдение"
	if v < 60: return "Уважение"
	return "Союз"
