class_name InputBindings
extends RefCounted
## Ações que o jogador pode remapear (aba Controles), nomes legíveis das teclas e a
## conversão de/para texto usada no arquivo de preferências. Esc (pausar) fica fixo:
## é a tecla que cancela a troca e sempre abre o menu.

## [categoria, [[ação, nome], ...]] na ordem em que aparecem na aba.
const GROUPS := [
	["Movimento", [
		[&"move_forward", "Andar para frente"],
		[&"move_backward", "Andar para trás"],
		[&"move_left", "Andar para a esquerda"],
		[&"move_right", "Andar para a direita"],
		[&"jump", "Pular"],
		[&"sprint", "Correr"],
	]],
	["Ferramentas", [
		[&"use_tool", "Usar ferramenta"],
		[&"tool_cancel", "Cancelar mira da vara"],
		[&"reel_line", "Recolher a linha da vara"],
		[&"flashlight", "Lanterna (liga e desliga)"],
		[&"tool_next", "Próxima ferramenta"],
		[&"tool_prev", "Ferramenta anterior"],
		[&"tool_slot_1", "Ferramenta 1"],
		[&"tool_slot_2", "Ferramenta 2"],
		[&"tool_slot_3", "Ferramenta 3"],
		[&"tool_slot_4", "Ferramenta 4"],
	]],
	["Telas", [
		[&"interact", "Interagir (loja, depósito)"],
		[&"inventory", "Inventário"],
		[&"map", "Mapa"],
		[&"toggle_fullscreen", "Tela cheia"],
	]],
]

## Predefinição para canhotos (mouse na mão esquerda): setas e teclado numérico.
const LEFT_HANDED := {
	&"move_forward": "k%d" % KEY_UP,
	&"move_backward": "k%d" % KEY_DOWN,
	&"move_left": "k%d" % KEY_LEFT,
	&"move_right": "k%d" % KEY_RIGHT,
	&"jump": "k%d" % KEY_KP_0,
	&"sprint": "k%d" % KEY_KP_PERIOD,
	&"interact": "k%d" % KEY_KP_ENTER,
	&"reel_line": "k%d" % KEY_KP_ADD,
	&"flashlight": "k%d" % KEY_KP_MULTIPLY,
	&"inventory": "k%d" % KEY_KP_SUBTRACT,
	&"map": "k%d" % KEY_KP_DIVIDE,
	&"tool_slot_1": "k%d" % KEY_KP_1,
	&"tool_slot_2": "k%d" % KEY_KP_2,
	&"tool_slot_3": "k%d" % KEY_KP_3,
	&"tool_slot_4": "k%d" % KEY_KP_4,
}

const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Clique",
	MOUSE_BUTTON_RIGHT: "Botão direito",
	MOUSE_BUTTON_MIDDLE: "Botão do meio",
	MOUSE_BUTTON_WHEEL_UP: "Roda para cima",
	MOUSE_BUTTON_WHEEL_DOWN: "Roda para baixo",
	MOUSE_BUTTON_WHEEL_LEFT: "Roda para a esquerda",
	MOUSE_BUTTON_WHEEL_RIGHT: "Roda para a direita",
	MOUSE_BUTTON_XBUTTON1: "Botão lateral 1",
	MOUSE_BUTTON_XBUTTON2: "Botão lateral 2",
}
const KEY_NAMES := {
	KEY_SPACE: "Espaço", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt",
	KEY_TAB: "Tab", KEY_ENTER: "Enter", KEY_BACKSPACE: "Backspace", KEY_ESCAPE: "Esc",
	KEY_UP: "Seta ↑", KEY_DOWN: "Seta ↓", KEY_LEFT: "Seta ←", KEY_RIGHT: "Seta →",
	KEY_KP_ENTER: "Num Enter", KEY_KP_ADD: "Num +", KEY_KP_SUBTRACT: "Num -",
	KEY_KP_MULTIPLY: "Num *", KEY_KP_DIVIDE: "Num /", KEY_KP_PERIOD: "Num .",
	KEY_CAPSLOCK: "Caps Lock", KEY_INSERT: "Insert", KEY_DELETE: "Delete",
	KEY_HOME: "Home", KEY_END: "End", KEY_PAGEUP: "Page Up", KEY_PAGEDOWN: "Page Down",
}


## Todas as ações remapeáveis, na ordem da aba.
static func actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for group: Array in GROUPS:
		for entry: Array in group[1]:
			result.append(entry[0])
	return result


## Primeiro evento ligado à ação (tecla ou botão do mouse), ou null.
static func binding_of(action: StringName) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return event
	return null


## Nome curto da tecla da ação, para dicas ("E", "Clique", "Seta ↑").
static func label_of(action: StringName) -> String:
	var event := binding_of(action)
	return event_label(event) if event != null else "—"


static func event_label(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var index := (event as InputEventMouseButton).button_index
		return MOUSE_NAMES.get(index, "Botão %d do mouse" % index)
	if event is InputEventKey:
		var code := key_code(event as InputEventKey)
		if KEY_NAMES.has(code):
			return KEY_NAMES[code]
		if code >= KEY_KP_0 and code <= KEY_KP_9:
			return "Num %d" % (code - KEY_KP_0)
		# Nome conforme o layout do teclado do jogador (ex.: Ç no ABNT2).
		# Sem janela (headless, testes) e no navegador o servidor não conhece o layout e só reclama.
		var shown := KEY_NONE if DisplayServer.get_name() == "headless" or OS.has_feature("web") else DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(shown if shown != KEY_NONE else code)
	return "—"


static func key_code(key: InputEventKey) -> Key:
	return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode


## Mesmo botão/tecla? (para trocar com a ação que já usava a tecla escolhida)
static func same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return key_code(a) == key_code(b)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


## "k<código físico>" ou "m<botão>". Texto vazio se o evento não puder ser salvo.
static func to_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return "k%d" % key_code(event as InputEventKey)
	if event is InputEventMouseButton:
		return "m%d" % (event as InputEventMouseButton).button_index
	return ""


## Evento a partir do texto salvo; null se inválido (arquivo editado à mão, por exemplo).
static func from_text(text: String) -> InputEvent:
	if text.length() < 2 or not text.substr(1).is_valid_int():
		return null
	var code := text.substr(1).to_int()
	if text[0] == "k" and code > 0 and code != KEY_ESCAPE and code < KEY_SPECIAL * 2:
		var key := InputEventKey.new()
		key.physical_keycode = code as Key
		return key
	if text[0] == "m" and code >= MOUSE_BUTTON_LEFT and code <= MOUSE_BUTTON_XBUTTON2:
		var button := InputEventMouseButton.new()
		button.button_index = code as MouseButton
		return button
	return null


## Tecla aceitável para uma ação? (Esc é reservado; teclas repetidas e soltas, ignoradas)
static func accepts(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo and key_code(key) != KEY_NONE and key_code(key) != KEY_ESCAPE
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return false
