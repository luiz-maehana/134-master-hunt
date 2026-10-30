class_name ToolHotbar
extends HBoxContainer
## Barra de atalhos no rodapé: uma caixa por grupo de ferramenta possuído (ícone, tecla, variante
## escolhida e tipo), com a ferramenta ativa destacada.

const SLOT_SIZE := Vector2(250, 96)
## Menor largura de uma caixa (o HUD encolhe a barra antes de mudá-la de lugar).
const MIN_SLOT_WIDTH := 170.0
const SEPARATION := UiStyle.SPACE_S

## Largura atual de cada caixa (o HUD ajusta conforme a largura da tela).
var slot_width := SLOT_SIZE.x:
	set(value):
		var width := clampf(value, MIN_SLOT_WIDTH, SLOT_SIZE.x)
		if not is_equal_approx(width, slot_width):
			slot_width = width
			refresh()
const COLOR_ACTIVE := UiStyle.GOLD
const COLOR_IDLE_TEXT := Color(0.7, 0.7, 0.7)

var tool_user: ToolUser:
	set = set_tool_user


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", SEPARATION)
	GameState.tools_changed.connect(refresh)
	GameState.stats_changed.connect(refresh)
	Settings.changed.connect(refresh)


func set_tool_user(value: ToolUser) -> void:
	tool_user = value
	if tool_user != null:
		tool_user.equipped_changed.connect(func(_definition: ToolDefinition) -> void: refresh())
	refresh()


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if tool_user == null:
		return
	var active := tool_user.equipped_definition()
	var groups := tool_user.slot_groups()
	for i in groups.size():
		var definition := GameState.tool_for_group(groups[i])
		add_child(_make_slot(i + 1, groups[i], definition, active != null and active.slot_group == groups[i]))


## Largura total da barra com `count` caixas de `slot` de largura (padrão: a atual).
func width_for(count: int, slot := -1.0) -> float:
	return count * (slot_width if slot < 0.0 else slot) + maxi(count - 1, 0) * SEPARATION


## Caixa da ferramenta ativa do grupo (para testes e outras telas).
func active_slot() -> Control:
	for child in get_children():
		if child.get_meta("active", false):
			return child
	return null


func _make_slot(key: int, group: StringName, definition: ToolDefinition, active: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(slot_width, SLOT_SIZE.y)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("tool_id", definition.id)
	panel.set_meta("active", active)
	panel.theme_type_variation = UiStyle.SLOT_ACTIVE if active else UiStyle.SLOT

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiStyle.SPACE_S)
	panel.add_child(row)
	var icon := ItemIcons.of(definition.id)
	if icon != null:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.custom_minimum_size = Vector2(64, 64)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not active:
			picture.modulate = Color(1, 1, 1, 0.7)
		row.add_child(picture)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	row.add_child(box)
	box.add_child(_label(InputBindings.label_of(StringName("tool_slot_%d" % key)), 18, COLOR_ACTIVE if active else COLOR_IDLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_label(definition.display_name, 20 if slot_width < 220.0 else 22, Color.WHITE if active else Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label(ToolCatalog.group_name(group), 16, COLOR_IDLE_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	return panel


static func _label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nome comprido em caixa estreita: quebra em até duas linhas em vez de alargar a caixa.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
