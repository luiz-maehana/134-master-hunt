extends CanvasLayer
## HUD: progresso da missão (com marcos), dinheiro, bolso com seta até o ponto de coleta,
## quanto do bairro atual já foi recolhido, barra de ferramentas, dica, faixa de bairro e
## mensagens.
## Só exibe dados; o estado real fica em GameState/CoinLedger.

## Margem de segurança: nada do HUD chega mais perto da borda da tela que isso.
const SAFE_MARGIN := 24.0
const MAX_TOASTS := 4
const TOAST_SECONDS := 2.5
const HINT_REFRESH := 0.1
## Coletas seguidas dentro desse intervalo somam no mesmo "+N" do bolso.
const GAIN_MERGE_SECONDS := 1.2
## HUD mínimo: a barra de ferramentas fica visível por este tempo depois de trocar.
const HOTBAR_SHOW_SECONDS := 2.0
## Segundos até a virada do final (a prancheta da prestação de contas).
const VICTORY_TWIST_SECONDS := 6.0

## Marcos em centavos: R$ 1, R$ 10, R$ 100... até os R$ 134 milhões.
const MILESTONES: Array[int] = [100, 1_000, 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000,
	1_000_000_000, 5_000_000_000, 10_000_000_000, 13_400_000_000]

@export var tool_user: ToolUser

var _last_carried := -1
var _gain := 0
var _last_value := 0
var _gain_value := 0
var _gain_time := -100.0
var _gain_tween: Tween
var _district_id := &""
var _banner_tween: Tween
## Meta e carteira "sobem" até o valor novo.
var _found_roll := RollingValue.new()
var _money_roll := RollingValue.new()
var _hotbar_tween: Tween

@onready var _coins: Label = %Coins
@onready var _goal: Label = %Goal
@onready var _goal_bar: ProgressBar = %GoalBar
@onready var _value: Label = %Value
@onready var _progress: Label = %Progress
@onready var _milestone: Label = %Milestone
@onready var _milestone_bar: ProgressBar = %MilestoneBar
@onready var _time: Label = %Time
@onready var _sky: SkyIcon = %Sky
@onready var _money: Label = %Money
@onready var _pocket: Label = %Pocket
@onready var _pocket_bar: ProgressBar = %PocketBar
@onready var _gain_label: Label = %Gain
@onready var _deposit: Label = %Deposit
@onready var _deposit_arrow: DirectionArrow = %DepositArrow
@onready var _district: Label = %District
@onready var _district_bar: ProgressBar = %DistrictBar
@onready var _robots: Label = %Robots
@onready var _banner: Label = %DistrictBanner
@onready var _hotbar: ToolHotbar = %Hotbar
@onready var _hint_panel: PanelContainer = %HintPanel
@onready var _hint: Label = %Hint
@onready var _toasts: VBoxContainer = %Toasts
@onready var _victory: Control = %Victory
@onready var _victory_text: Label = %Text
@onready var _stats: Control = %Stats
@onready var _status: Control = %Status


## Relógio do ciclo de dia e noite (topo da tela): hora e o ícone de sol ou lua.
func _refresh_clock() -> void:
	var clock := get_node_or_null(^"%Clock") as Control
	if clock == null:
		return
	clock.visible = DayNight.current != null and not Settings.hud_minimal
	if not clock.visible:
		return
	var text := DayNight.clock_text()
	if _time.text != text:
		_time.text = text
		_sky.phase = SkyIcon.phase_at(GameState.time_of_day)


func _process(delta: float) -> void:
	_refresh_clock()
	if _found_roll.step(delta):
		_coins.text = MoneyFormat.brl(_found_roll.value())
	if _money_roll.step(delta):
		_money.text = MoneyFormat.brl(_money_roll.value())


## Rodapé com as teclas atuais (mudam na aba Controles).
func _update_help() -> void:
	var label := get_node_or_null(^"%Help") as Label
	if label == null:
		return
	label.text = "%s–%s: ferramentas  ·  %s: inventário  ·  %s: mapa  ·  %s: conquistas  ·  Esc: menu" % [
		InputBindings.label_of(&"tool_slot_1"), InputBindings.label_of(&"tool_slot_4"), InputBindings.label_of(&"inventory"),
		InputBindings.label_of(&"map"), InputBindings.label_of(&"achievements")]


func _ready() -> void:
	GameState.economy_changed.connect(refresh_economy)
	GameState.notified.connect(show_toast)
	GameState.goal_reached.connect(_show_victory)
	Settings.changed.connect(_update_help)
	_update_help()
	Settings.changed.connect(_apply_minimal)
	GameState.tools_changed.connect(_refresh_equipment)
	GameState.robots_changed.connect(_refresh_equipment)
	_refresh_equipment()
	_hotbar.tool_user = tool_user
	if tool_user != null:
		tool_user.equipped_changed.connect(func(_definition: ToolDefinition) -> void: _flash_hotbar())
	_apply_minimal()
	get_viewport().size_changed.connect(_layout)
	_hotbar.child_order_changed.connect(_layout.call_deferred)
	_status.resized.connect(_layout)
	_layout.call_deferred()
	# Dica, bairro e seta dependem da posição/mira; 10x por segundo basta.
	var timer := Timer.new()
	timer.wait_time = HINT_REFRESH
	timer.autostart = true
	timer.timeout.connect(_refresh_hint)
	add_child(timer)
	refresh_economy()
	if GameState.pending_notice != "":
		show_toast.call_deferred(GameState.pending_notice)
		GameState.pending_notice = ""


func refresh_economy() -> void:
	var ledger := GameState.ledger
	# A meta é em reais; a quantidade de moedas aparece só como curiosidade.
	var found := ledger.total_value_found_cents
	_found_roll.set_target(found)
	_coins.text = MoneyFormat.brl(_found_roll.value())
	_goal.text = "de %s" % MoneyFormat.brl(CoinLedger.GOAL_CENTS)
	_goal_bar.value = float(found) / CoinLedger.GOAL_CENTS
	_progress.text = MoneyFormat.progress(ledger.progress_scaled())
	var coins := ledger.total_coins_found
	_value.text = MoneyFormat.coins(coins)
	_refresh_milestone(found)
	_money_roll.set_target(ledger.money_cents)
	_money.text = MoneyFormat.brl(_money_roll.value())
	_refresh_pocket()


## Marco seguinte (R$ 1, R$ 10, R$ 100...): dá sensação de avanço muito antes do 1%.
func _refresh_milestone(found: int) -> void:
	var previous := 0
	for target in MILESTONES:
		if found < target:
			_milestone.text = "Próximo marco: %s" % MoneyFormat.brl(target)
			_milestone_bar.value = float(found - previous) / (target - previous)
			return
		previous = target
	_milestone.text = "Todos os marcos alcançados!"
	_milestone_bar.value = 1.0


func _refresh_pocket() -> void:
	var ledger := GameState.ledger
	var carried := ledger.carried_coins
	_pocket.text = "Bolso: %s / %s moedas · %s" % [MoneyFormat.group(carried), MoneyFormat.group(ledger.carry_capacity), MoneyFormat.brl(ledger.carried_value_cents)]
	var fill := float(carried) / maxf(ledger.carry_capacity, 1)
	_pocket_bar.value = fill
	var bar := UiStyle.BAR_GOOD
	if ledger.free_capacity() == 0:
		bar = UiStyle.BAR_BAD
	elif fill >= 0.75:
		bar = UiStyle.BAR_WARN
	_pocket_bar.theme_type_variation = bar
	_pocket.modulate = UiStyle.BAD if ledger.free_capacity() == 0 else Color.WHITE
	if _last_carried >= 0 and carried > _last_carried:
		_show_gain(carried - _last_carried, ledger.carried_value_cents - _last_value)
	_last_carried = carried
	_last_value = ledger.carried_value_cents


func _show_gain(amount: int, value: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var merge := now - _gain_time < GAIN_MERGE_SECONDS
	_gain = (_gain if merge else 0) + amount
	_gain_value = (_gain_value if merge else 0) + value
	_gain_time = now
	_gain_label.text = "+%s · %s" % [MoneyFormat.group(_gain), MoneyFormat.brl(_gain_value)]
	if _gain_tween != null:
		_gain_tween.kill()
	_gain_label.modulate.a = 1.0
	_gain_label.scale = Vector2.ONE * 1.25
	_gain_label.pivot_offset = _gain_label.size * 0.5
	_gain_tween = create_tween()
	_gain_tween.tween_property(_gain_label, "scale", Vector2.ONE, 0.15)
	_gain_tween.tween_interval(GAIN_MERGE_SECONDS)
	_gain_tween.tween_property(_gain_label, "modulate:a", 0.0, 0.4)


## Mensagens com fundo; uma igual à que já está na tela só renova o tempo dela.
func show_toast(text: String) -> void:
	for existing in _toasts.get_children():
		if existing.get_meta("text", "") == text and not existing.is_queued_for_deletion():
			_start_toast_timer(existing)
			return
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiStyle.TOAST
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("text", text)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	panel.add_child(label)
	_toasts.add_child(panel)
	while _toasts.get_child_count() > MAX_TOASTS:
		_toasts.get_child(0).free()
	_start_toast_timer(panel)


func _start_toast_timer(panel: Control) -> void:
	if panel.has_meta("tween"):
		(panel.get_meta("tween") as Tween).kill()
	panel.modulate.a = 1.0
	var tween := panel.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)
	panel.set_meta("tween", tween)


func _refresh_hint() -> void:
	var text := tool_user.get_hint() if tool_user != null else ""
	if _hint.text != text:
		_hint.text = text
		# O painel encolhe para o texto novo; a posição (centro ou borda da barra) vem de _layout.
		_hint_panel.reset_size()
		_layout()
	_hint_panel.visible = text != ""
	_refresh_location()
	_refresh_robots()


## Faixa "Equipamentos": ícone e nome de cada item passivo possuído (bolsos, transporte,
## tênis, melhorias dos robôs) e de cada tipo de robô, com a quantidade. Licenças ficam de
## fora (o bairro aberto já mostra).
func _refresh_equipment() -> void:
	var box := get_node_or_null(^"%Equipment") as HFlowContainer
	if box == null:
		return
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for item in ShopCatalog.get_default().items:
		var count := GameState.item_count(item.id)
		if count == 0 or item is ToolDefinition:
			continue
		if item is UpgradeDefinition and (item as UpgradeDefinition).effect == UpgradeDefinition.Effect.UNLOCK_DISTRICT:
			continue
		box.add_child(_equipment_entry(item, count))
	(get_node(^"%Gear") as Control).visible = box.get_child_count() > 0


## Ícone do item com a quantidade num selo (×3); o nome aparece ao passar o mouse.
func _equipment_entry(item: ShopItem, count: int) -> Control:
	var picture := TextureRect.new()
	picture.texture = ItemIcons.of(item.id)
	picture.custom_minimum_size = Vector2(46, 46)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.tooltip_text = item.display_name if count == 1 else "%s ×%d" % [item.display_name, count]
	picture.set_meta("name", picture.tooltip_text)
	if count > 1:
		var badge := Label.new()
		badge.text = "×%d" % count
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_constant_override("outline_size", 5)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
		picture.add_child(badge)
	return picture
func _refresh_robots() -> void:
	var fleet := RobotFleet.current
	_robots.visible = fleet != null and fleet.count() > 0
	if not _robots.visible:
		return
	var idle := fleet.idle_count()
	var text := "Robôs: %d trabalhando · %s moedas/min" % [fleet.count() - idle, MoneyFormat.group(roundi(fleet.coins_per_minute))]
	if idle > 0:
		text += "\n%d %s sem moedas por perto (%s para trazer)" % [idle, "parado" if idle == 1 else "parados", InputBindings.label_of(&"inventory")]
	_robots.text = text


func _refresh_location() -> void:
	if CoinWorld.current == null or tool_user == null or tool_user.body == null:
		return
	var body := tool_user.body
	var pos := body.global_position
	var layout := CoinWorld.current.layout
	var district := layout.district_at(pos.x, pos.z)
	if district != null:
		var index := layout.definition.districts.find(district)
		var world := CoinWorld.current
		var done := MoneyFormat.percent(world.district_removed(index), world.district_total(index))
		_district.text = "%s · %s recolhido" % [district.display_name, done]
		_district_bar.value = world.district_progress(index)
		if district.id != _district_id:
			_district_id = district.id
			_show_banner("%s\n%s recolhido" % [district.display_name, done])
	var nearest := Vector3.INF
	for hub in layout.hubs:
		var deposit: Vector3 = hub.deposit
		if pos.distance_squared_to(deposit) < pos.distance_squared_to(nearest):
			nearest = deposit
	if nearest != Vector3.INF:
		var meters := Vector2(nearest.x - pos.x, nearest.z - pos.z).length()
		_deposit.text = "Ponto de coleta: %s m" % MoneyFormat.group(roundi(meters))
		_deposit_arrow.angle = DirectionArrow.bearing(body, nearest)


func _show_banner(text: String) -> void:
	_banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_interval(1.8)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _show_victory() -> void:
	var ledger := GameState.ledger
	_victory_text.text = "OBJETIVO CONCLUÍDO!\n%s encontrados\nem %s moedas" % [
		MoneyFormat.brl(ledger.total_value_found_cents), MoneyFormat.group(ledger.total_coins_found)]
	_victory.visible = true
	GameState.unlock(&"accountability")
	# O final secreto: a montanha de moedas ainda precisa de explicação.
	await get_tree().create_timer(VICTORY_TWIST_SECONDS).timeout
	_victory_text.text = "Um funcionário com uma prancheta:\n“Parabéns! Agora precisamos verificar\na origem de cada moeda.”\n\n134 MASTER HUNT 2:\nA PRESTAÇÃO DE CONTAS\nEm breve."


# --- HUD mínimo ---------------------------------------------------------------------------

## Esconde o que não é essencial (cartões da esquerda, relógio, bairro, teclas). Bolso, seta
## para o ponto de coleta, dica, avisos e a faixa ao entrar num bairro continuam.
func _apply_minimal() -> void:
	var minimal := Settings.hud_minimal
	for path in [^"Left", ^"%District", ^"%DistrictBar", ^"%Help"]:
		(get_node(path) as CanvasItem).visible = not minimal
	_refresh_clock()
	if minimal:
		_flash_hotbar()
	else:
		if _hotbar_tween != null:
			_hotbar_tween.kill()
		_hotbar.modulate.a = 1.0


## HUD mínimo: mostra a barra de ferramentas por um instante (ao trocar de ferramenta).
func _flash_hotbar() -> void:
	if not Settings.hud_minimal:
		return
	if _hotbar_tween != null:
		_hotbar_tween.kill()
	_hotbar.modulate.a = 1.0
	_hotbar_tween = create_tween()
	_hotbar_tween.tween_interval(HOTBAR_SHOW_SECONDS)
	_hotbar_tween.tween_property(_hotbar, "modulate:a", 0.0, 0.4)


# --- Layout ------------------------------------------------------------------------------

## Reorganiza o rodapé conforme a largura da tela (a altura é sempre 1080 virtuais): a barra
## de ferramentas fica no centro se couber ao lado do painel do bolso; senão vai para a
## esquerda; senão as caixas encolhem; em último caso, a barra sobe acima do painel do bolso.
## A dica de ação fica sempre centrada logo acima da barra.
func _layout() -> void:
	if not is_inside_tree():
		return
	var screen := get_viewport().get_visible_rect().size
	var count := maxi(_hotbar.get_child_count(), 1)
	var status_width := maxf(_status.size.x, _status.get_combined_minimum_size().x)
	# Espaço livre à esquerda do painel do bolso.
	var room := screen.x - status_width - SAFE_MARGIN * 3.0
	var slot := ToolHotbar.SLOT_SIZE.x
	if _hotbar.width_for(count, slot) > room:
		slot = (room - (count - 1) * ToolHotbar.SEPARATION) / count
	_hotbar.slot_width = slot
	var width := _hotbar.width_for(count)
	var bottom := SAFE_MARGIN
	var left := (screen.x - width) * 0.5
	if width > room:
		# Nem encolhida cabe ao lado: sobe acima do painel do bolso, centrada.
		bottom = _status.size.y + SAFE_MARGIN * 2.0
	elif left + width > room + SAFE_MARGIN:
		left = maxf(SAFE_MARGIN, room + SAFE_MARGIN - width)
	var center := left + width * 0.5 - screen.x * 0.5
	_hotbar.offset_left = left - screen.x * 0.5
	_hotbar.offset_right = _hotbar.offset_left + width
	_hotbar.offset_bottom = -bottom
	_hotbar.offset_top = -bottom - ToolHotbar.SLOT_SIZE.y
	if is_equal_approx(left, (screen.x - width) * 0.5):
		_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_hint_panel.offset_left = center
		_hint_panel.offset_right = center
	else:
		# Barra deslocada para a esquerda: a dica começa na borda dela, longe do painel do bolso.
		_hint_panel.grow_horizontal = Control.GROW_DIRECTION_END
		_hint_panel.offset_left = _hotbar.offset_left
		_hint_panel.offset_right = _hotbar.offset_left
	_hint_panel.offset_bottom = _hotbar.offset_top - 18.0
	_hint_panel.offset_top = _hint_panel.offset_bottom - 46.0


## Retângulos dos painéis do HUD (para o teste de sobreposição em várias resoluções).
func panel_rects() -> Dictionary:
	var rects := {"left": (get_node(^"Left") as Control).get_global_rect(), "status": _status.get_global_rect(),
		"clock": (get_node(^"%Clock") as Control).get_global_rect()}
	if _hotbar.get_child_count() > 0:
		rects["hotbar"] = _hotbar.get_global_rect()
	return rects
