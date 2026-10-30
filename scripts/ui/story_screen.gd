class_name StoryScreen
extends Control
## A história do jogo, antes de uma partida nova (tela inicial e "Recomeçar partida"): os
## parágrafos surgem um de cada vez; clique ou tecla mostra tudo de uma vez. Continuar começa a
## partida (`accepted`); Voltar ou Esc desistem sem apagar nada (`closed`). Tudo ficção.

signal accepted
signal closed

## Tempo entre um parágrafo e o próximo, e quanto cada um leva para aparecer.
const LINE_SECONDS := 1.6
const FADE_SECONDS := 0.6
const SOFT := Color(1, 1, 1, 0.75)

const TITLE := "Como tudo começou"
const PARAGRAPHS := [
	"Era uma vez um filme.",
	"Um filme tão caro que ninguém sabe direito quanto custou. Nem quem pagou. Nem por quê. Sabe-se só que um banco muito, muito generoso achou ótima ideia bancar a superprodução: sem roteiro, sem elenco e sem data de estreia.",
	"Anos depois, a conta chegou. R$ 134 milhões foram recuperados. A boa notícia: o dinheiro apareceu. A má notícia: estava todo em moedas.",
	"O caminhão que levava o tesouro de volta ao cofre fez a curva da Esplanada rápido demais. A porta traseira abriu. E choveu troco sobre Brasília, da Rodoviária ao Congresso, do gramado ao pé do mastro da bandeira.",
	"Agora é com você: catar cada moedinha, levar tudo aos pontos de coleta e fechar essa conta. Moeda por moeda. Centavo por centavo.",
]
const CLOSING := "R$ 134.000.000,00. Ninguém disse que ia ser fácil."
const DISCLAIMER := "Esta história é ficção. Qualquer semelhança com a realidade é mera coincidência. Ou não."

var _reveal: Tween
var _continue: Button
var _done := false


## Abre a história por cima de `parent` (ocupando a tela toda).
static func open(parent: Node) -> StoryScreen:
	var screen := StoryScreen.new()
	parent.add_child(screen)
	return screen


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, UiStyle.SPACE_XL + UiStyle.SPACE_M)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiStyle.SPACE_L)
	margin.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 860
	content.add_theme_constant_override("separation", UiStyle.SPACE_L)
	center.add_child(content)
	content.add_child(_label(TITLE, 48, UiStyle.GOLD))
	var lines: Array[Label] = []
	for paragraph: String in PARAGRAPHS:
		lines.append(_label(paragraph, 24, Color.WHITE))
	lines.append(_label(CLOSING, 30, UiStyle.GOLD))
	lines.append(_label(DISCLAIMER, 18, SOFT))
	for line in lines:
		line.modulate.a = 0.0
		content.add_child(line)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UiStyle.SPACE_L)
	column.add_child(buttons)
	var back := _button("Voltar")
	back.pressed.connect(close)
	buttons.add_child(back)
	_continue = _button("Continuar")
	_continue.pressed.connect(_accept)
	buttons.add_child(_continue)
	_continue.grab_focus()
	_reveal = create_tween()
	for i in lines.size():
		_reveal.parallel().tween_property(lines[i], "modulate:a", 1.0, FADE_SECONDS).set_delay(0.3 + i * LINE_SECONDS)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, ScreenTransition.OPEN_SECONDS)
	Sfx.play(&"ui_open", 0.03, -10.0)


## Clique em qualquer lugar ou tecla (fora Enter nos botões): mostra o resto da história de uma vez.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		skip()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and _reveal.is_running():
		skip()
		get_viewport().set_input_as_handled()


func skip() -> void:
	if _reveal.is_running():
		_reveal.custom_step(60.0)


func close() -> void:
	if _finish():
		closed.emit()


func _accept() -> void:
	if _finish():
		accepted.emit()


## Some com a tela (uma vez só: Continuar e Voltar não valem os dois).
func _finish() -> bool:
	if _done:
		return false
	_done = true
	set_process_unhandled_input(false)
	Sfx.play(&"ui_close", 0.03, -12.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, ScreenTransition.CLOSE_SECONDS)
	tween.tween_callback(queue_free)
	return true


static func _label(text: String, size: int, color: Color) -> Label:
	var label := MenuScreen.make_label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 60)
	button.add_theme_font_size_override("font_size", 24)
	return button
