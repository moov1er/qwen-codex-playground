# StealthHUD — интерфейс стелс-миссии: цели, шум/видимость/тревога, подсказка взаимодействия.
extends CanvasLayer

var mission: Node2D = null

@onready var objectives_label: Label = $Panel/VBox/Objectives
@onready var visibility_bar: ProgressBar = $Bottom/VisibilityBar
@onready var noise_bar: ProgressBar = $Bottom/NoiseBar
@onready var alarm_bar: ProgressBar = $Bottom/AlarmBar
@onready var hint_label: Label = $Bottom/Hint
@onready var toast: Label = $Toast
@onready var alert_flash: ColorRect = $AlertFlash


func setup(m: Node2D) -> void:
	mission = m
	alert_flash.visible = false
	toast.modulate.a = 0.0
	GameState.objective_completed.connect(_refresh_objectives)
	GameState.mission_state_changed.connect(func(_id): _refresh_objectives())
	_refresh_objectives()


func _process(_dt: float) -> void:
	if mission == null: return
	visibility_bar.value = mission.current_stealth_visibility() * 100.0
	noise_bar.value = clampf(mission.player.velocity.length() / 260.0 * 100.0, 0, 100)
	alarm_bar.value = clampf(mission.guard_max_suspicion(), 0, 100)
	hint_label.text = mission.interaction_system.target_label()
	AudioDirector.set_tension(clampf(mission.guard_max_suspicion() / 100.0, 0, 1))


func _refresh_objectives(_a = null, _b = null) -> void:
	if mission == null: return
	var def := MissionManager.get_definition(mission.mission_id)
	var entry: Dictionary = GameState.missions_state.get(mission.mission_id, {})
	var lines: Array[String] = []
	lines.append("— ЦЕЛИ —")
	var objs: Array = def.get("objectives", [])
	var done: Array = entry.get("objectives", [])
	for i in objs.size():
		var ok: bool = bool(done[i]) if i < done.size() else false
		lines.append(("[x] " if ok else "[ ] ") + str(objs[i]))
	var opts: Array = def.get("optional_objectives", [])
	var odone: Array = entry.get("optionals", [])
	if opts.size() > 0:
		lines.append("— ДОП. —")
		for i in opts.size():
			var ok2: bool = bool(odone[i]) if i < odone.size() else false
			lines.append(("(+)" if not ok2 else "(✓)") + " " + str(opts[i]))
	objectives_label.text = "\n".join(lines)


func flash_alert() -> void:
	alert_flash.visible = true
	var t := create_tween()
	t.tween_property(alert_flash, "modulate:a", 0.0, 1.2).from(0.5)
	t.tween_callback(func(): alert_flash.visible = false)


func show_message(text: String) -> void:
	toast.text = text
	var t := create_tween()
	t.tween_property(toast, "modulate:a", 1.0, 0.3)
	t.tween_interval(1.4)
	t.tween_property(toast, "modulate:a", 0.0, 0.6)
