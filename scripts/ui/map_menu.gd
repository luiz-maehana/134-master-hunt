class_name MapMenu
extends CanvasLayer
## Mapa da cidade (ação "map", M): bairros abertos e fechados com o % recolhido, quarteirões e
## prédios, pontos de coleta e lojas, robôs e o jogador em tempo real. O jogo continua
## rodando por trás (como as outras telas); M ou Esc fecham.

const DISTRICT_COLORS := [Color(0.45, 0.75, 0.45), Color(0.45, 0.65, 0.9), Color(0.9, 0.7, 0.35), Color(0.85, 0.45, 0.4)]
const ROAD := Color(0.16, 0.17, 0.2)
const LAWN := Color(0.32, 0.55, 0.3)
const LANDMARK := Color(0.92, 0.92, 0.88)
const LOCKED := Color(0.1, 0.1, 0.12)
const BUILDING := Color(0.08, 0.09, 0.11, 0.85)
const DEPOSIT := Color(0.35, 1.0, 0.5)
const SHOP := Color(1.0, 0.8, 0.25)
const ROBOT := Color(1.0, 0.55, 0.15)
const ROBOT_IDLE := Color(0.7, 0.7, 0.7)

var layout: CityLayout
var player: Node3D

var _static: Control
var _live: Control
var _legend: Label
var _time := 0.0
## Aberto (o mapa ainda fica visível enquanto esmaece ao fechar).
var _open := false


func setup(city_layout: CityLayout, player_node: Node3D) -> void:
	layout = city_layout
	player = player_node


func _ready() -> void:
	layer = 9
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiStyle.WINDOW
	# Faixa horizontal no meio da tela (o eixo é comprido): o painel de cima e o de baixo do
	# HUD continuam visíveis e atualizando por trás.
	panel.anchor_left = 0.02
	panel.anchor_right = 0.98
	panel.anchor_top = 0.42
	panel.anchor_bottom = 0.83
	add_child(panel)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", UiStyle.SPACE_S)
	panel.add_child(row)
	row.add_child(MenuScreen.make_label("Mapa da cidade", 26, UiStyle.GOLD))
	var map_box := Control.new()
	map_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_box.clip_contents = true
	row.add_child(map_box)
	_static = Control.new()
	_static.set_anchors_preset(Control.PRESET_FULL_RECT)
	_static.draw.connect(_draw_static)
	map_box.add_child(_static)
	_live = Control.new()
	_live.set_anchors_preset(Control.PRESET_FULL_RECT)
	_live.draw.connect(_draw_live)
	map_box.add_child(_live)
	_legend = MenuScreen.make_label("", 16)
	row.add_child(_legend)
	GameState.tools_changed.connect(_static.queue_redraw)
	_static.resized.connect(_static.queue_redraw)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"map"):
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> bool:
	if _open or GameState.screen_open or layout == null:
		return false
	GameState.set_screen_open(true)
	_open = true
	ScreenTransition.open(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_static.queue_redraw()
	_refresh_legend()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	ScreenTransition.close(self)
	GameState.set_screen_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_live.queue_redraw()
	if fmod(_time, 0.5) < delta:
		_refresh_legend()


# --- Desenho ------------------------------------------------------------------------------

## Quadrado do mapa dentro da área disponível: [canto, pixels por metro].
func _frame() -> Array:
	var area := _static.size
	var world := Vector2(layout.half_x, layout.half_z) * 2.0
	var scale := minf(area.x / world.x, area.y / world.y)
	return [(area - world * scale) * 0.5, scale]


func _to_map(x: float, z: float, frame: Array) -> Vector2:
	return frame[0] + Vector2(x + layout.half_x, z + layout.half_z) * float(frame[1])


func _draw_static() -> void:
	if layout == null:
		return
	var frame := _frame()
	var scale: float = frame[1]
	_static.draw_rect(Rect2(frame[0], Vector2(layout.half_x, layout.half_z) * 2.0 * scale), ROAD)
	var definition := layout.definition
	for key: Vector2i in layout.blocks:
		var district := definition.districts[layout.district_index_of(key)]
		var open := GameState.is_district_unlocked(district)
		var color: Color = DISTRICT_COLORS[layout.district_index_of(key) % DISTRICT_COLORS.size()]
		var lot_world := layout.lot_rect(key)
		var lot := Rect2(_to_map(lot_world.position.x, lot_world.position.y, frame), lot_world.size * scale)
		var fill := color.darkened(0.35)
		if not open:
			fill = LOCKED
		elif layout.is_lawn(key):
			fill = LAWN
		elif layout.is_paved(key):
			fill = Color(0.6, 0.58, 0.52)
		_static.draw_rect(lot, fill)
		if not open:
			continue
		var info: Dictionary = layout.blocks[key]
		for building: Dictionary in info.buildings:
			var rect: Rect2 = building.rect
			_static.draw_rect(Rect2(_to_map(rect.position.x, rect.position.y, frame), rect.size * scale), BUILDING)
	for landmark in layout.landmarks:
		var footprint: Rect2 = landmark.rect
		var block: Rect2i = landmark.blocks
		if footprint.size != Vector2.ZERO and GameState.is_district_unlocked(definition.districts[layout.district_index_of(block.position)]):
			_static.draw_rect(Rect2(_to_map(footprint.position.x, footprint.position.y, frame), footprint.size * scale), LANDMARK)
	# Contorno de cada bairro e o nome no topo dele.
	var font := _static.get_theme_default_font()
	for i in range(definition.districts.size() - 1, -1, -1):
		var bounds := layout.district_rect(i)
		var corner := _to_map(bounds.position.x, bounds.position.y, frame)
		var size := bounds.size * scale
		var district := definition.districts[i]
		var open := GameState.is_district_unlocked(district)
		var color: Color = DISTRICT_COLORS[i % DISTRICT_COLORS.size()]
		_static.draw_rect(Rect2(corner, size), color if open else Color(0.6, 0.6, 0.6), false, 2.0)
		var label := district.display_name + ("" if open else "  (fechado)")
		# Nome cortado na largura do bairro (a Rodoviária é estreita: sem nome, só a cor).
		if size.x < 60.0:
			continue
		_static.draw_string(font, corner + Vector2(6, 16), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 10.0, 16,
			color.lightened(0.3) if open else Color(0.7, 0.7, 0.7))
	for hub in layout.hubs:
		var deposit: Vector3 = hub.deposit
		var kiosk: Vector3 = hub.kiosk
		_static.draw_circle(_to_map(deposit.x, deposit.z, frame), maxf(4.0, 5.0 * scale), DEPOSIT)
		var shop := _to_map(kiosk.x, kiosk.z, frame)
		var half := maxf(3.5, 4.0 * scale)
		_static.draw_rect(Rect2(shop - Vector2.ONE * half, Vector2.ONE * half * 2.0), SHOP)


func _draw_live() -> void:
	if layout == null:
		return
	var frame := _frame()
	var fleet := RobotFleet.current
	if fleet != null:
		var pulse := 0.6 + 0.4 * sin(_time * 5.0)
		for i in fleet.count():
			var robot := fleet.robot(i)
			var at := _to_map(robot.home.x, robot.home.y, frame)
			var radius := robot.definition.radius * float(frame[1])
			_live.draw_arc(at, radius, 0.0, TAU, 24, Color(ROBOT, 0.35), 1.5)
			_live.draw_circle(at, 4.5, ROBOT_IDLE.lerp(ROBOT, pulse) if robot.idle else ROBOT)
	if player != null:
		var at := _to_map(player.global_position.x, player.global_position.z, frame)
		var yaw := player.global_rotation.y
		var forward := Vector2(-sin(yaw), -cos(yaw))
		var right := Vector2(-forward.y, forward.x)
		var tip := at + forward * 11.0
		_live.draw_colored_polygon(PackedVector2Array([tip, at - forward * 6.0 + right * 7.0, at - forward * 3.0, at - forward * 6.0 - right * 7.0]), Color.WHITE)
		_live.draw_arc(at, 14.0 + 3.0 * sin(_time * 4.0), 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.5)


func _refresh_legend() -> void:
	var lines := PackedStringArray()
	var world := CoinWorld.current
	for i in layout.definition.districts.size():
		var district := layout.definition.districts[i]
		var state := ""
		if not GameState.is_district_unlocked(district):
			state = "fechado"
		elif world != null:
			state = "%s recolhido" % MoneyFormat.percent(world.district_removed(i), world.district_total(i))
		lines.append("%s: %s" % [district.display_name, state])
	var fleet := RobotFleet.current
	var robots := fleet.count() if fleet != null else 0
	var keys := "Verde: ponto de coleta  ·  Amarelo: Ferragem  ·  Seta: você"
	if robots > 0:
		keys += "  ·  Laranja: robôs (%d; cinza piscando = parado)" % robots
	_legend.text = "%s\n%s\n%s ou Esc fecha o mapa" % ["   ·   ".join(lines), keys, InputBindings.label_of(&"map")]
