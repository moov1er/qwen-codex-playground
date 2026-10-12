# DialogueBox — виджет диалога: портрет, имя, текст «печатной машинкой», выборы.
# Живёт в группе "dialogue_box": любой экран может вызвать DialogueManager.start_dialogue(),
# и виджет подхватит диалог независимо от того, на каком экране игрок.
extends Control

@onready var portrait: ColorRect = $Panel/Main/Portrait
@onready var name_label: Label = $Panel/Main/Col/NameLabel
@onready var text_label: RichTextLabel = $Panel/Main/Col/TextLabel
@onready var choices_box: VBoxContainer = $Panel/Main/Col/Choices
@onready var continue_btn: Button = $Panel/Continue

var _full_text := ""
var _typed := 0.0

const PORTRAIT_COLORS := {
	"Ren": Color(0.2, 0.35, 0.5), "Phoenix": Color(0.3, 0.3, 0.25),
	"Owl": Color(0.45, 0.3, 0.5), "Ash": Color(0.35, 0.3, 0.25),
	"Lina": Color(0.55, 0.15, 0.2), "Mirage": Color(0.15, 0.15, 0.25),
	"Gale": Color(0.2, 0.22, 0.3), "Cascade": Color(0.25, 0.2, 0.35),
}


func _ready() -> void:
	add_to_group("dialogue_box")
	visible = false
	continue_btn.pressed.connect(func(): DialogueManager.advance())
	DialogueManager.line_shown.connect(_show_line)
	DialogueManager.dialogue_ended.connect(func(_id): visible = false)


func _process(delta: float) -> void:
	if not visible: return
	if _typed < _full_text.length():
		_typed += delta * 60.0
		text_label.text = _full_text.substr(0, int(_typed))
		continue_btn.visible = false
	else:
		continue_btn.visible = choices_box.get_child_count() == 0
		if Input.is_action_just_pressed("ui_accept") and choices_box.get_child_count() == 0:
			DialogueManager.advance()


func _show_line(node: Dictionary) -> void:
	visible = true
	var cid := str(node.get("_character", ""))
	name_label.text = DialogueManager.character_name(cid)
	portrait.color = PORTRAIT_COLORS.get(cid, Color(0.12, 0.1, 0.18))
	_full_text = str(node.get("text", ""))
	_typed = 0.0
	for c in choices_box.get_children():
		c.queue_free()
	var choices: Array = node.get("choices", [])
	for i in choices.size():
		var ch: Dictionary = choices[i]
		if not DialogueManager.choice_available(ch): continue
		var b := Button.new()
		b.text = str(ch.get("text", "..."))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(DialogueManager.choose.bind(i))
		choices_box.add_child(b)
