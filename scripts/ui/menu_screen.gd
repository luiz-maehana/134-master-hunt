class_name MenuScreen
extends CanvasLayer
## Base das telas por cima do jogo (loja, inventário, mapa). O jogo não pausa (robôs e HUD
## continuam); só abre se nenhuma outra tela estiver aberta. Esc ou `close_action` fecham.

const REFRESH_INTERVAL := 0.5

@export var close_action: StringName = &"pause"
## Complemento do rodapé ("o inventário"): "<tecla> ou Esc fecha <isto>".
var close_noun := ""
## Refazer sempre (a cada REFRESH_INTERVAL) mesmo sem aviso de mudança (inventário: robôs).
var live := false
## Aberta (a tela ainda fica visível enquanto esmaece ao fechar).
var _open := false
var _dirty := false
var _since_refresh := 0.0

@onready var items_box: VBoxContainer = %Items
@onready var money_label: Label = %Money
@onready var summary_label: Label = %Summary
@onready var _close: Button = %Close


func _ready() -> void:
	visible = false
	_close.pressed.connect(close)
	GameState.economy_changed.connect(_refresh_if_open)
	GameState.tools_changed.connect(_refresh_if_open)


func is_open() -> bool:
	return _open


func open() -> bool:
	if _open or GameState.screen_open:
		return false
	GameState.set_screen_open(true)
	_open = true
	ScreenTransition.open(self)
	var help := get_node_or_null(^"Center/Panel/VBox/Footer/Help") as Label
	if help != null and close_noun != "":
		help.text = "%s ou Esc fecha %s" % [InputBindings.label_of(close_action), close_noun]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	ScreenTransition.close(self)
	GameState.set_screen_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if _open and (event.is_action_pressed(&"pause") or event.is_action_pressed(close_action)):
		close()
		get_viewport().set_input_as_handled()


## Reconstrói o conteúdo. Subclasses preenchem `items_box`.
func refresh() -> void:
	_dirty = false
	_since_refresh = 0.0
	money_label.text = "Dinheiro: %s" % MoneyFormat.brl(GameState.ledger.money_cents)


## O jogo continua rodando com a tela aberta (robôs entregam a cada 0,5 s): as mudanças só
## marcam a tela, que se refaz no máximo a cada REFRESH_INTERVAL, sem perder a rolagem.
func _refresh_if_open() -> void:
	if _open:
		_dirty = true


func _process(delta: float) -> void:
	if not _open:
		return
	_since_refresh += delta
	if _since_refresh < REFRESH_INTERVAL or not (_dirty or live):
		return
	# Refazer a lista no meio de um clique perderia o clique.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var scroll := items_box.get_parent() as ScrollContainer
	var keep := scroll.scroll_vertical if scroll != null else 0
	refresh()
	if scroll != null:
		scroll.set_deferred("scroll_vertical", keep)


func clear_items() -> void:
	for child in items_box.get_children():
		# queue_free: a reconstrução pode acontecer dentro do clique de um botão da lista.
		items_box.remove_child(child)
		child.queue_free()


## Linha padrão: ícone opcional, título, textos e um botão opcional à direita.
func make_row(title: String, lines: Array, button_text := "", button_enabled := false, highlight := false, icon: Texture2D = null) -> Button:
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiStyle.ROW_HIGHLIGHT if highlight else UiStyle.ROW
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiStyle.SPACE_L)
	panel.add_child(row)
	if icon != null:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.custom_minimum_size = Vector2(72, 72)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picture)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	texts.add_child(make_label(title, 26))
	for line: Array in lines:
		texts.add_child(make_label(line[0], 18, line[1]))
	var button: Button = null
	if button_text != "":
		button = Button.new()
		button.text = button_text
		button.disabled = not button_enabled
		button.custom_minimum_size = Vector2(220, 56)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 22)
		# Clicar num botão desativado (ex.: sem dinheiro) responde com o som de erro.
		button.gui_input.connect(func(event: InputEvent) -> void:
			if button.disabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				Sfx.play(&"ui_error", 0.0, -8.0))
		row.add_child(button)
	items_box.add_child(panel)
	return button


static func make_label(text: String, size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
