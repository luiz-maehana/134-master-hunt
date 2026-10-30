class_name StoryScreen
extends Control
## A história do jogo, antes de uma partida nova (tela inicial e "Recomeçar partida"): a animação
## do ônibus espalhando moedas pela Esplanada (StoryBus) no topo da janela e, embaixo, a história em legendas que
## trocam sozinhas; clique ou Espaço passa para a próxima. Continuar começa a partida
## (`accepted`); Voltar ou Esc desistem sem apagar nada (`closed`). Tudo ficção.

signal accepted
signal closed

## Tempo de cada legenda: um mínimo e mais um pouco por letra (dá tempo de ler).
const CAPTION_SECONDS := 2.0
const SECONDS_PER_CHAR := 0.055
const FADE_SECONDS := 0.4
const SOFT := Color(1, 1, 1, 0.75)
## Largura da janela (fração da tela).
const WIDTH_SHARE := 0.62

const TITLE := "Como tudo começou"
const CAPTIONS := [
	"Era uma vez um filme.",
	"Um filme tão caro que ninguém sabe direito quanto custou. Nem quem pagou. Nem por quê. Sabe-se só que um banco muito, muito generoso achou ótima ideia bancar a superprodução: sem roteiro, sem elenco e sem data de estreia.",
	"Anos depois, a conta chegou. R$ 134 milhões foram recuperados. A boa notícia: o dinheiro apareceu. A má notícia: estava todo em moedas.",
	"O ônibus fretado que levava o tesouro de volta ao cofre (ninguém explicou por que um ônibus) fez a curva da Esplanada rápido demais. O bagageiro abriu. E choveu troco sobre Brasília, da Rodoviária ao Congresso.",
	"Agora é com você: catar cada moedinha, levar tudo aos pontos de coleta e fechar essa conta. Moeda por moeda. Centavo por centavo.",
	"R$ 134.000.000,00. Ninguém disse que ia ser fácil.",
]
const HINT := "Clique ou Espaço: próxima"
const DISCLAIMER := "Esta história é ficção. Qualquer semelhança com a realidade é mera coincidência. Ou não."

var bus: StoryBus
var _panel: PanelContainer
var _captions: Array[Label] = []
var _index := 0
var _wait := 0.0
var _hint: Label
var _disclaimer: Label
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
	dim.color = Color(0.02, 0.02, 0.03, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	# Janela no meio da tela: a animação no topo, como cabeçalho; embaixo, título e legendas.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = UiStyle.WINDOW
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiStyle.SPACE_M)
	_panel.add_child(column)
	bus = StoryBus.new()
	column.add_child(bus)
	column.add_child(_label(TITLE, 36, UiStyle.GOLD))
	# Legendas empilhadas no mesmo lugar: só uma aparece de cada vez.
	var holder := Control.new()
	holder.custom_minimum_size.y = 112
	column.add_child(holder)
	for i in CAPTIONS.size():
		var last := i == CAPTIONS.size() - 1
		var caption := _label(CAPTIONS[i], 32 if last else 26, UiStyle.GOLD if last else Color.WHITE)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.modulate.a = 1.0 if i == 0 else 0.0
		holder.add_child(caption)
		_captions.append(caption)
	_hint = _label(HINT, 16, SOFT)
	column.add_child(_hint)
	_disclaimer = _label(DISCLAIMER, 16, SOFT)
	_disclaimer.modulate.a = 0.0
	column.add_child(_disclaimer)
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
	resized.connect(_fit)
	_fit.call_deferred()
	_wait = _duration(0)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, ScreenTransition.OPEN_SECONDS)
	Sfx.play(&"ui_open", 0.03, -10.0)


## Largura da janela pela tela e cabeçalho proporcional, limitado pela altura da tela.
func _fit() -> void:
	if size.x <= 0.0:
		return
	var width := size.x * WIDTH_SHARE
	_panel.custom_minimum_size.x = width
	bus.custom_minimum_size.y = minf(width * 0.3, size.y * 0.36)


func _process(delta: float) -> void:
	if _index >= _captions.size() - 1:
		return
	_wait -= delta
	if _wait <= 0.0:
		next()


## Clique em qualquer lugar, Espaço ou seta para a direita: próxima legenda.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		next()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_RIGHT]:
		next()
		get_viewport().set_input_as_handled()


func next() -> void:
	_show(_index + 1)


## Pula direto para o fim da história.
func skip() -> void:
	_show(_captions.size() - 1)


func _show(index: int) -> void:
	if index <= _index or index >= _captions.size():
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(_captions[_index], "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_property(_captions[index], "modulate:a", 1.0, FADE_SECONDS).set_delay(FADE_SECONDS * 0.5)
	_index = index
	_wait = _duration(index)
	if index == _captions.size() - 1:
		tween.tween_property(_hint, "modulate:a", 0.0, FADE_SECONDS)
		tween.tween_property(_disclaimer, "modulate:a", 1.0, FADE_SECONDS).set_delay(FADE_SECONDS)


func _duration(index: int) -> float:
	return CAPTION_SECONDS + _captions[index].text.length() * SECONDS_PER_CHAR


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
	set_process_input(false)
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
