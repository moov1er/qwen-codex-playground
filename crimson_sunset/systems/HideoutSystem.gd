# HideoutSystem — функции убежища: сон, еда, снижение тепла, улучшения базы.
extends Node

static func sleep_hours() -> Dictionary:
	# Сон восстанавливает энергию, снижает стресс, немного снижает тепло
	TimeSystem.advance(8)
	GameState.energy = 100
	GameState.change_stress(-25)
	GameState.change_heat(-maxi(1, int(GameState.hideout.get("security", 1))))
	SaveManager.save_game()
	return {"text": "Ты проспал восемь часов. Город стал чуть спокойнее... или чуть внимательнее."}

static func eat() -> Dictionary:
	if not GameState.spend_money(15):
		return {"text": "Не хватает денег на еду. Снова лапша из автомата?"}
	GameState.change_stress(-8)
	GameState.change_energy(10)
	return {"text": "Тёплая еда. Мелочь, а руки меньше дрожат."}

static func cool_heat() -> Dictionary:
	# Ручная чистка следов: деньги -> тепло
	var cost := 40
	if not GameState.spend_money(cost):
		return {"text": "Нужно %d₽, чтобы затереть каналы отхода. Деньги кончились." % cost}
	GameState.change_heat(-12)
	return {"text": "Ты перепродал маршруты через три подставных узла. Тепло спадает."}

static func upgrade(key: String) -> Dictionary:
	var costs := {"security": 150, "equipment": 200, "bed_quality": 100,
	              "backup_power": 180, "shielding": 220}
	if not costs.has(key): return {"text": "Нет такого улучшения."}
	var lvl = GameState.hideout[key]
	var price: int = int(costs[key]) * (int(lvl) if typeof(lvl) == TYPE_INT else 1)
	if typeof(lvl) == TYPE_BOOL and lvl:
		return {"text": "Уже установлено."}
	if not GameState.spend_money(price):
		return {"text": "Не хватает %d₽." % price}
	if typeof(lvl) == TYPE_BOOL:
		GameState.hideout[key] = true
	else:
		GameState.hideout[key] = int(lvl) + 1
	SaveManager.save_game()
	return {"text": "Убежище улучшено: " + key}
