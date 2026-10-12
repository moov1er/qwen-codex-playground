# StealthSystem — расчёт видимости игрока. Автозагрузка сцены нет:
# вешается на узел с именем StealthSystem внутри StealthMission.
extends Node

signal visibility_updated(value: float)

var player: Node2D = null
var light_nodes: Array[Node2D] = []   # PointLight2D источников света
@export var shadows: Array[Rect2] = []   # зоны тени (заполняются из maps.json)

const BASE_VISIBLE := 0.9
const CROUCH_FACTOR := 0.5            # приседание снижает видимость вдвое
const HIDDEN_VISIBLE := 0.0           # в укрытии игрок невидим


func compute_visibility() -> float:
	if player == null: return 0.0
	if player.is_in_group("hidden"): return HIDDEN_VISIBLE
	var v := BASE_VISIBLE
	# скорость движения повышает заметность
	var st := player.get("stealth_state")
	match st:
		"sneak": v *= CROUCH_FACTOR
		"walk":  v *= 0.8
		_: pass
	# освещённость: в тени темнее
	var lit := _light_at(player.global_position)
	v *= lerpf(0.25, 1.0, lit)
	return clampf(v, 0.0, 1.0)


func _light_at(pos: Vector2) -> float:
	var best := 0.0
	for l in light_nodes:
		if not is_instance_valid(l) or not l.enabled: continue
		var d: float = pos.distance_to(l.global_position)
		var r: float = l.range_max if "range_max" in l else 200.0
		best = maxf(best, clampf(1.0 - d / maxf(r, 1.0), 0.0, 1.0))
	# вне любого света — базовая полутьма
	return maxf(best, 0.35)
