class_name CreditsScreen
extends Control
## Créditos numa tela própria (tela inicial e menu): seções com título, rolando sozinhas devagar.
## A roda ou o arraste do mouse assumem a rolagem por um tempo. Esc ou Voltar fecham.
## A lista completa, com links e licenças, fica em ASSET_CREDITS.md; os CC BY precisam estar aqui.

signal closed

const SCROLL_SPEED := 40.0
## Espera antes de começar a rolar, e depois que o jogador mexeu na rolagem.
const SCROLL_DELAY := 1.5
const IDLE_AFTER_INPUT := 4.0
const GOLD := UiStyle.GOLD
const SOFT := Color(1, 1, 1, 0.75)

## [título, [linhas]].
const SECTIONS := [
	["Modelos 3D", [
		"Kenney (kenney.nl), CC0: City Kit Roads, City Kit Suburban, Car Kit, Survival Kit (pás)",
		"Quaternius, CC0: luva e vara de pescar (via Poly Pizza)",
		"Poly by Google, CC BY 3.0: ímã (\"Magnet\", poly.pizza/m/7dHLjQ8eZhu)",
	]],
	["Ícones dos itens (modelos via Poly Pizza)", [
		"Quaternius, CC0: pochete e mochila",
		"Poly by Google, CC BY 3.0: \"Sneakers\", \"Wheelbarrow\" e \"Computer\"",
		"Michael Ruddy, CC BY 3.0: \"Golf cart\"",
		"KolosStudios, CC BY 3.0: \"Dumpster\"",
		"Jarlan Perez, CC BY 3.0: \"Manila Envelope\"",
		"Bruno Oliveira, CC BY 3.0: \"Battery\" e \"Flashlight\"",
		"Robert Ramsay, CC BY 3.0: \"Flashlight\"",
		"joney_lol, CC BY 3.0: \"Hard hat\"",
	]],
	["Texturas", [
		"Poly Haven (polyhaven.com), CC0: asfalto e concreto",
	]],
	["Interface e som", [
		"Kenney, CC0: UI Pack (botões, clique) e Game Icons",
		"Fonte Fredoka, The Fredoka Project Authors, SIL Open Font License 1.1",
		"Os demais sons são sintetizados pelo próprio jogo",
	]],
	["Código de terceiros", [
		"Basic FPS Controller, Arjun Bhumula (ar-bh), MIT",
		"Godot Engine, Juan Linietsky, Ariel Manzur e colaboradores, MIT",
	]],
]

var _scroll: ScrollContainer
var _idle := SCROLL_DELAY
var _position := 0.0
var _back: Button


## Abre os créditos por cima de `parent` (ocupando a tela toda).
static func open(parent: Node) -> CreditsScreen:
	var screen := CreditsScreen.new()
	parent.add_child(screen)
	return screen


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 0.94)
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
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.gui_input.connect(_on_scroll_input)
	column.add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 900
	content.add_theme_constant_override("separation", UiStyle.SPACE_S)
	center.add_child(content)
	_fill(content)
	_back = Button.new()
	_back.text = "Voltar"
	_back.custom_minimum_size = Vector2(260, 60)
	_back.add_theme_font_size_override("font_size", 24)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(close)
	column.add_child(_back)
	_back.grab_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, ScreenTransition.OPEN_SECONDS)
	Sfx.play(&"ui_open", 0.03, -10.0)


func _fill(content: VBoxContainer) -> void:
	content.add_child(_label("134 Master Hunt", 56, GOLD))
	content.add_child(_label("Versão %s" % ProjectSettings.get_setting("application/config/version"), 20, SOFT))
	content.add_child(_spacer(40))
	content.add_child(_label("Um jogo sobre catar R$ 134 milhões em moedas, uma pilha de cada vez.", 22, Color.WHITE))
	content.add_child(_label("Feito com Godot Engine.", 20, SOFT))
	for section: Array in SECTIONS:
		content.add_child(_spacer(36))
		content.add_child(_label(section[0], 30, GOLD))
		for line: String in section[1]:
			content.add_child(_label(line, 20, Color.WHITE))
	content.add_child(_spacer(48))
	content.add_child(_label("Lista completa, com links e licenças: ASSET_CREDITS.md no repositório.", 18, SOFT))
	content.add_child(_label("Obrigado por jogar!", 26, GOLD))


func _process(delta: float) -> void:
	_idle -= delta
	if _idle > 0.0:
		_position = _scroll.scroll_vertical
		return
	_position += SCROLL_SPEED * delta
	_scroll.scroll_vertical = int(_position)


func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenDrag or event is InputEventMouseMotion and event.button_mask != 0:
		_idle = IDLE_AFTER_INPUT


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if is_queued_for_deletion():
		return
	set_process_unhandled_input(false)
	Sfx.play(&"ui_close", 0.03, -12.0)
	closed.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, ScreenTransition.CLOSE_SECONDS)
	tween.tween_callback(queue_free)


static func _label(text: String, size: int, color: Color) -> Label:
	var label := MenuScreen.make_label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer
