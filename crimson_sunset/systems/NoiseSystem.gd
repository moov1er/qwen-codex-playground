# NoiseSystem — глобальный источник событий шума (автозагрузка не нужна,
# используется как синглтон через SceneTree группу "noise_system").
extends Node

signal noise_emitted(world_pos: Vector2, radius: float, strength: float)

const STEP_SNEAK := 60.0
const STEP_WALK := 130.0
const STEP_RUN := 320.0
const DOOR := 180.0
const BROKEN_LOCK := 260.0
const DISTRACTOR := 420.0


func emit_noise(world_pos: Vector2, radius: float, strength: float = 1.0) -> void:
	noise_emitted.emit(world_pos, radius, strength)


func _ready() -> void:
	add_to_group("noise_system")
