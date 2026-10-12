# MainMenu — главный экран: новая игра / продолжить / настройки / выход.
extends Control

@onready var continue_btn: Button = $Center/VBox/ContinueBtn


func _ready() -> void:
	continue_btn.disabled = not SaveManager.has_save()


func on_enter() -> void:
	continue_btn.disabled = not SaveManager.has_save()


func _on_new_pressed() -> void:
	GameState.reset_new_game()
	MissionManager.unlock_initial()
	NewsSystem.push_news("news_black_sunset_rumor")
	get_parent().goto("desktop")


func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		get_parent().goto("desktop")


func _on_settings_pressed() -> void:
	get_parent().goto("hideout")   # в вертикальном срезе настройки живут в убежище


func _on_quit_pressed() -> void:
	get_tree().quit()
