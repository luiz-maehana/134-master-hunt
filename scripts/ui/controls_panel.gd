extends VBoxContainer
## Aba Controles do menu de pausa: lista das ações por categoria com a tecla atual.
## Clicar numa ação espera a próxima tecla ou botão do mouse (Esc cancela); se a tecla
## já era de outra ação, as duas trocam (Settings.rebind).

## Ação esperando a nova tecla (vazio = nenhuma).
var waiting: StringName = &""
var _buttons := {}

@onready var _bindings: VBoxContainer = %Bindings
@onready var _hint: Label = %RemapHint


func _ready() -> void:
	%Default.pressed.connect(_on_preset.bind(false))
	%LeftHanded.pressed.connect(_on_preset.bind(true))
	for group: Array in InputBindings.GROUPS:
		var title := MenuScreen.make_label(group[0], 22, UiStyle.GOLD)
		_bindings.add_child(title)
		for entry: Array in group[1]:
			_add_row(entry[0], entry[1])
	Settings.changed.connect(_refresh)
	visibility_changed.connect(cancel)
	_refresh()


func _add_row(action: StringName, title: String) -> void:
	var row := HBoxContainer.new()
	var label := MenuScreen.make_label(title, 20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(260, 40)
	button.theme_type_variation = &"KeyButton"
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(start_waiting.bind(action))
	row.add_child(button)
	_bindings.add_child(row)
	_buttons[action] = button


func start_waiting(action: StringName) -> void:
	waiting = action
	_refresh()
	(_buttons[action] as Button).text = "Aperte uma tecla…"
	_hint.text = "Aperte a nova tecla ou botão do mouse para \"%s\". Esc cancela." % _title_of(action)


func cancel() -> void:
	if waiting == &"":
		return
	waiting = &""
	_refresh()


func _input(event: InputEvent) -> void:
	if waiting == &"" or not is_visible_in_tree():
		return
	if event is InputEventKey and (event as InputEventKey).pressed and InputBindings.key_code(event) == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancel()
		return
	if not InputBindings.accepts(event):
		return
	# A tecla não chega ao resto do jogo nem ao botão que está com foco.
	get_viewport().set_input_as_handled()
	var action := waiting
	waiting = &""
	Settings.rebind(action, event)
	_refresh()


func _on_preset(left_handed: bool) -> void:
	waiting = &""
	if left_handed:
		Settings.apply_left_handed()
	else:
		Settings.reset_bindings()


func _refresh() -> void:
	for action: StringName in _buttons:
		var button: Button = _buttons[action]
		button.text = InputBindings.label_of(action)
		# Tecla diferente do padrão aparece em laranja.
		var changed := InputBindings.to_text(InputBindings.binding_of(action)) != Settings.default_binding(action)
		if changed:
			button.add_theme_color_override("font_color", Color(0.8, 0.3, 0.02))
		else:
			button.remove_theme_color_override("font_color")
	if waiting == &"":
		_hint.text = "Clique numa ação e aperte a nova tecla ou botão do mouse. Esc cancela. Se a tecla já for de outra ação, as duas trocam."


static func _title_of(action: StringName) -> String:
	for group: Array in InputBindings.GROUPS:
		for entry: Array in group[1]:
			if entry[0] == action:
				return entry[1]
	return String(action)
