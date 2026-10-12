# Player — управление героем: ходьба, красться/бег (шум), взаимодействие, укрытие.
extends CharacterBody2D

signal stealth_state_changed(state: String)
signal caught

enum MoveState { SNEAK, WALK, RUN }

@export var walk_speed := 150.0
@export var sneak_speed := 70.0
@export var run_speed := 260.0

var move_state: int = MoveState.WALK
var hidden: bool = false                 # спрятан в укрытии
var frozen: bool = false                 # диалог/мини-игра — ввод заблокирован
var noise_system: Node = null            # узел NoiseSystem сцены миссии
var _step_timer: float = 0.0

@onready var sprite: Polygon2D = $Body
@onready var cone_hint: Node2D = null


func _ready() -> void:
	add_to_group("player")
	set_physics_process(true)


func stealth_state() -> String:
	match move_state:
		MoveState.SNEAK: return "sneak"
		MoveState.RUN:   return "run"
		_: return "walk"


func _unhandled_input(event: InputEvent) -> void:
	if frozen: return
	if event.is_action_pressed("hide_action"):
		_try_hide_toggle()
	if event.is_action_pressed("interact"):
		var isys := get_node_or_null("../InteractionSystem")
		if isys: isys.do_interact()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _set_move(MoveState.SNEAK)
			KEY_2: _set_move(MoveState.WALK)
			KEY_3: _set_move(MoveState.RUN)


func _set_move(s: int) -> void:
	if move_state == s: return
	move_state = s
	stealth_state_changed.emit(stealth_state())


func _physics_process(delta: float) -> void:
	if frozen or hidden:
		velocity = Vector2.ZERO
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := walk_speed
	match move_state:
		MoveState.SNEAK: speed = sneak_speed
		MoveState.RUN:   speed = run_speed
	velocity = velocity.lerp(dir * speed, 0.3)
	move_and_slide()

	# шаги издают шум
	if dir.length() > 0.1:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.45 if move_state == MoveState.SNEAK else (0.34 if move_state == MoveState.WALK else 0.22)
			var radius := NoiseSystem.STEP_SNEAK if move_state == MoveState.SNEAK \
				else (NoiseSystem.STEP_WALK if move_state == MoveState.WALK else NoiseSystem.STEP_RUN)
			if noise_system:
				noise_system.emit_noise(global_position, radius)
			AudioDirector.play("step" if move_state != MoveState.RUN else "run_step")


func _try_hide_toggle() -> void:
	# Q: если рядом укрытие — спрятаться; если уже спрятались — выйти
	if hidden:
		hidden = false
		remove_from_group("hidden")
		z_index = 5
		AudioDirector.play("hide")
		return
	for n in get_tree().get_nodes_in_group("hiding_spot"):
		if global_position.distance_to(n.global_position) < 48.0:
			hidden = true
			global_position = n.global_position
			add_to_group("hidden")
			z_index = 1
			AudioDirector.play("hide")
			return


func make_noise(radius: float) -> void:
	if noise_system:
		noise_system.emit_noise(global_position, radius)


# Охрана схватила игрока.
func on_captured() -> void:
	frozen = true
	caught.emit()
