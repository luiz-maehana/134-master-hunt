extends SceneTree
## Gera assets/ui/game_theme.tres (tema global da interface) a partir do Kenney UI Pack,
## da fonte Fredoka e dos tokens de UiStyle (cores, espaçamentos, raios). Todos os painéis e
## barras do jogo são variações nomeadas daqui (ver docs/STYLE_GUIDE.md). Para refazer:
##   godot --headless --path . --script res://tools/build_ui_theme.gd

const UI := "res://assets/third_party/kenney/ui-pack/"
const FONT := "res://assets/third_party/fonts/fredoka/Fredoka.ttf"
const OUT := "res://assets/ui/game_theme.tres"
const DARK_TEXT := UiStyle.DARK_TEXT


func _initialize() -> void:
	var theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = load(FONT)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
	theme.default_font = font
	theme.default_font_size = 20

	# Botões amarelos com profundidade; apertado = sem profundidade e texto 4 px abaixo.
	var normal := _texture("yellow_button_rectangle_depth_gradient.png", 10, 8)
	var hover := _texture("yellow_button_rectangle_depth_flat.png", 10, 8)
	var pressed := _texture("yellow_button_rectangle_flat.png", 10, 4)
	pressed.content_margin_top += 4.0
	var disabled := _texture("grey_button_rectangle_depth_flat.png", 10, 8)
	disabled.modulate_color = Color(1, 1, 1, 0.75)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.border_color = Color(1, 1, 1, 0.9)
	focus.set_corner_radius_all(8)
	focus.set_expand_margin_all(3)
	for type in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, focus)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, DARK_TEXT)
		theme.set_color("font_disabled_color", type, Color(0.3, 0.3, 0.32))
		theme.set_constant("outline_size", type, 0)

	# Botão de tecla (aba Controles): cinza, como uma tecla de teclado.
	theme.set_type_variation("KeyButton", "Button")
	theme.set_stylebox("normal", "KeyButton", _texture("grey_button_rectangle_depth_gradient.png", 10, 8))
	theme.set_stylebox("hover", "KeyButton", _texture("grey_button_rectangle_depth_flat.png", 10, 8))
	var key_pressed := _texture("grey_button_rectangle_flat.png", 10, 4)
	key_pressed.content_margin_top += 4.0
	theme.set_stylebox("pressed", "KeyButton", key_pressed)
	theme.set_stylebox("hover_pressed", "KeyButton", key_pressed)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, "KeyButton", Color(0.15, 0.16, 0.2))

	# Interruptor (tela cheia): sem fundo de botão, caixinhas da Kenney.
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(6)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckButton", empty)
		theme.set_stylebox(state, "CheckBox", empty)
	theme.set_stylebox("focus", "CheckButton", focus)
	theme.set_stylebox("focus", "CheckBox", focus)
	for type in ["CheckButton", "CheckBox"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, Color.WHITE)
		theme.set_icon("checked", type, _scaled_icon("yellow_check_square_color_checkmark.png", 34))
		theme.set_icon("unchecked", type, _scaled_icon("grey_check_square_grey.png", 34))

	# Abas: selecionada amarela, as outras cinza.
	var tab_selected := _texture("yellow_button_rectangle_flat.png", 10, 4)
	var tab_unselected := _texture("grey_button_rectangle_flat.png", 10, 4)
	tab_unselected.modulate_color = Color(0.75, 0.75, 0.8)
	var tab_hovered := _texture("grey_button_rectangle_flat.png", 10, 4)
	for style: StyleBoxTexture in [tab_selected, tab_unselected, tab_hovered]:
		style.content_margin_left = 22.0
		style.content_margin_right = 22.0
	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected)
	theme.set_stylebox("tab_hovered", "TabContainer", tab_hovered)
	theme.set_stylebox("tab_focus", "TabContainer", focus)
	theme.set_color("font_selected_color", "TabContainer", DARK_TEXT)
	theme.set_color("font_unselected_color", "TabContainer", Color(0.2, 0.2, 0.24))
	theme.set_color("font_hovered_color", "TabContainer", DARK_TEXT)
	theme.set_constant("side_margin", "TabContainer", 0)
	theme.set_constant("icon_separation", "TabContainer", 8)

	# Sliders: trilho arredondado, parte cheia amarela, puxador da Kenney.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.25, 0.26, 0.3)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = Color(1, 0.78, 0.2)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var handle := _scaled_icon("slide_handle.png", 30)
	theme.set_icon("grabber", "HSlider", handle)
	theme.set_icon("grabber_highlight", "HSlider", handle)

	# Lista das opções (OptionButton aberto).
	var popup := StyleBoxFlat.new()
	popup.bg_color = Color(0.12, 0.13, 0.16)
	popup.set_corner_radius_all(8)
	popup.set_content_margin_all(8)
	theme.set_stylebox("panel", "PopupMenu", popup)
	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = Color(1, 0.78, 0.2)
	popup_hover.set_corner_radius_all(6)
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	theme.set_color("font_hover_color", "PopupMenu", DARK_TEXT)
	theme.set_font_size("font_size", "PopupMenu", 22)

	_add_panels(theme)
	_add_bars(theme)

	_save_coin_icon()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var error := ResourceSaver.save(theme, OUT)
	print("Tema salvo em %s (%s)" % [OUT, error_string(error)])
	quit()


## Painéis (PanelContainer): cartões do HUD, pílulas, janelas, linhas de lista, avisos e as
## caixas da barra de ferramentas.
func _add_panels(theme: Theme) -> void:
	var gold_edge := {"color": UiStyle.GOLD_SOFT, "width": 2, "top": 4}
	var card := _flat(Color(UiStyle.INK, 0.88), UiStyle.RADIUS_L, UiStyle.SPACE_M, UiStyle.SPACE_M, gold_edge)
	card.shadow_color = Color(0, 0, 0, 0.35)
	card.shadow_size = UiStyle.SPACE_S
	card.shadow_offset = Vector2(0, 3)
	_variation(theme, UiStyle.CARD, "PanelContainer", "panel", card)
	_variation(theme, UiStyle.PILL, "PanelContainer", "panel", _flat(Color(UiStyle.INK, 0.88), UiStyle.RADIUS_PILL,
		UiStyle.SPACE_L, UiStyle.SPACE_S, {"color": UiStyle.GOLD_SOFT, "width": 2}))
	_variation(theme, UiStyle.WINDOW, "PanelContainer", "panel", _flat(Color(UiStyle.INK, 0.95), UiStyle.RADIUS_L,
		UiStyle.SPACE_XL, UiStyle.SPACE_L, gold_edge))
	_variation(theme, UiStyle.WINDOW_GOLD, "PanelContainer", "panel", _flat(Color(0.08, 0.07, 0.03, 0.92), UiStyle.RADIUS_L,
		UiStyle.SPACE_XL + UiStyle.SPACE_M, UiStyle.SPACE_XL, {"color": UiStyle.GOLD, "width": 4}))
	_variation(theme, UiStyle.ROW, "PanelContainer", "panel", _flat(UiStyle.INK_RAISED, UiStyle.RADIUS_M, UiStyle.SPACE_M, UiStyle.SPACE_M))
	_variation(theme, UiStyle.ROW_HIGHLIGHT, "PanelContainer", "panel", _flat(Color(0.16, 0.15, 0.08), UiStyle.RADIUS_M,
		UiStyle.SPACE_M, UiStyle.SPACE_M))
	_variation(theme, UiStyle.TOAST, "PanelContainer", "panel", _flat(Color(UiStyle.INK, 0.88), UiStyle.RADIUS_M,
		UiStyle.SPACE_M, UiStyle.SPACE_S, {"color": UiStyle.GOLD, "width": 0, "left": 4}))
	_variation(theme, UiStyle.SLOT, "PanelContainer", "panel", _flat(Color(UiStyle.INK, 0.85), UiStyle.RADIUS_L,
		UiStyle.SPACE_S, UiStyle.SPACE_S, {"color": UiStyle.GOLD_FAINT, "width": 1}))
	_variation(theme, UiStyle.SLOT_ACTIVE, "PanelContainer", "panel", _flat(Color(0.22, 0.17, 0.05, 0.92), UiStyle.RADIUS_L,
		UiStyle.SPACE_S, UiStyle.SPACE_S, {"color": UiStyle.GOLD, "width": 3}))
	# Fundo do conteúdo das abas (Opções).
	theme.set_stylebox("panel", "TabContainer", _flat(UiStyle.INK_RAISED, 0, UiStyle.SPACE_L, UiStyle.SPACE_M))


## Barras de progresso: um trilho claro e o preenchimento na cor de cada variação.
func _add_bars(theme: Theme) -> void:
	var track := _flat(Color(1, 1, 1, 0.1), UiStyle.RADIUS_S, 0, 0)
	theme.set_stylebox("background", "ProgressBar", track)
	theme.set_stylebox("fill", "ProgressBar", _flat(UiStyle.GOLD, UiStyle.RADIUS_S, 0, 0))
	for pair in [[UiStyle.BAR_GOLD, UiStyle.GOLD], [UiStyle.BAR_COPPER, UiStyle.COPPER], [UiStyle.BAR_SKY, UiStyle.SKY],
			[UiStyle.BAR_GOOD, UiStyle.GOOD], [UiStyle.BAR_WARN, UiStyle.WARN], [UiStyle.BAR_BAD, UiStyle.BAD]]:
		_variation(theme, pair[0], "ProgressBar", "fill", _flat(pair[1], UiStyle.RADIUS_S, 0, 0))
		theme.set_stylebox("background", pair[0], track)


func _variation(theme: Theme, name: StringName, base: StringName, item: StringName, style: StyleBox) -> void:
	theme.set_type_variation(name, base)
	theme.set_stylebox(item, name, style)


## Caixa lisa: fundo, raio, margens (horizontal e vertical) e borda opcional
## {color, width, top?, left?} (top/left sobrepõem a largura daquele lado).
func _flat(bg: Color, radius: int, margin_h: int, margin_v: int, border := {}) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	if not border.is_empty():
		style.border_color = border.color
		style.set_border_width_all(border.width)
		if border.has("top"):
			style.border_width_top = border.top
		if border.has("left"):
			style.border_width_left = border.left
	return style


## Ícone da moeda de R$ 1 (frente, linha 6 do atlas) com fundo transparente, para o HUD.
func _save_coin_icon() -> void:
	var atlas := (load("res://assets/textures/coin/coin_albedo.jpg") as Texture2D).get_image()
	atlas.decompress()
	var row := atlas.get_height() / 6
	var icon := atlas.get_region(Rect2i(0, row * 5, atlas.get_width() / 2, row))
	icon.convert(Image.FORMAT_RGBA8)
	icon.resize(96, 96, Image.INTERPOLATE_LANCZOS)
	for y in 96:
		for x in 96:
			var d := Vector2(x + 0.5 - 48.0, y + 0.5 - 48.0).length()
			var c := icon.get_pixel(x, y)
			c.a = clampf(47.0 - d, 0.0, 1.0)
			icon.set_pixel(x, y, c)
	icon.save_png(ProjectSettings.globalize_path("res://assets/ui/coin_icon.png"))


## Caixa 9-fatias: `side` px nas laterais e no topo, `bottom` px embaixo (profundidade).
func _texture(file: String, side: float, bottom: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(UI + file)
	style.texture_margin_left = side
	style.texture_margin_right = side
	style.texture_margin_top = side
	style.texture_margin_bottom = side + bottom * 0.5
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0 + bottom
	return style


## Ícone redimensionado (o tema usa o tamanho da textura).
func _scaled_icon(file: String, size: int) -> ImageTexture:
	var image := (load(UI + file) as Texture2D).get_image()
	image.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
