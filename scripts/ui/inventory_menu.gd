extends MenuScreen
## Inventário (Tab): quanto já foi recolhido de cada bairro, ferramentas possuídas (com a variante
## equipada por grupo) e melhorias.

const COLOR_EFFECT := Color(0.55, 0.95, 0.55)
const COLOR_INFO := Color(0.75, 0.75, 0.75)

@export var tool_user: ToolUser


func _ready() -> void:
	close_action = &"inventory"
	close_noun = "o inventário"
	live = true
	super()


func _unhandled_input(event: InputEvent) -> void:
	if not _open and event.is_action_pressed(&"inventory"):
		if open():
			get_viewport().set_input_as_handled()
		return
	super(event)


func refresh() -> void:
	super()
	var ledger := GameState.ledger
	summary_label.text = "Bolso: %s / %s moedas   ·   Moedas encontradas: %s" % [
		MoneyFormat.group(ledger.carried_coins), MoneyFormat.group(ledger.carry_capacity),
		MoneyFormat.group(ledger.total_coins_found)]
	clear_items()
	_add_district_rows()
	_add_robot_rows()
	var catalog := ToolCatalog.get_default()
	var equipped_id: StringName = tool_user.equipped_definition().id if tool_user != null and tool_user.equipped != null else &""
	for group in catalog.groups():
		for variant in catalog.variants(group):
			if not GameState.owns(variant.id):
				continue
			var selected := GameState.tool_for_group(group) == variant
			var effective := GameState.effective_tool(variant)
			var lines := [[variant.description, COLOR_INFO], [effective.effect_summary(), COLOR_EFFECT]]
			var title := "%s  —  %s" % [ToolCatalog.group_name(group), variant.display_name]
			var is_equipped := variant.id == equipped_id
			var button := make_row(title, lines, "Equipada" if is_equipped else "Equipar", not is_equipped, selected, ItemIcons.of(variant.id))
			if button != null and not is_equipped:
				button.pressed.connect(_equip.bind(variant.id))
	for upgrade in GameState.owned_upgrades():
		make_row("Melhoria  —  %s" % upgrade.display_name, [[upgrade.effect_summary(), COLOR_EFFECT]], "", false, false, ItemIcons.of(upgrade.id))
	_add_achievement_row()


## Conquistas dos segredos da cidade: as conseguidas pelo nome, as outras como "???".
func _add_achievement_row() -> void:
	var lines := []
	var done := 0
	for id: StringName in Achievements.LIST:
		if GameState.has_achievement(id):
			done += 1
			lines.append(["%s  ·  %s" % [Achievements.LIST[id][0], Achievements.LIST[id][1]], COLOR_EFFECT])
		else:
			lines.append(["???", COLOR_INFO])
	make_row("Conquistas  —  %d de %d" % [done, Achievements.LIST.size()], lines, "", false, false)


func _equip(id: StringName) -> void:
	GameState.select_variant(id)
	if tool_user != null:
		tool_user.equip(id)
	refresh()


## Uma linha por bairro: % recolhido e quanto ainda falta no chão (ou a licença que falta).
func _add_district_rows() -> void:
	var world := CoinWorld.current
	if world == null:
		return
	var districts := world.layout.definition.districts
	for i in districts.size():
		var district := districts[i]
		var total := world.district_total(i)
		var removed := world.district_removed(i)
		var lines := [[
			"%s recolhido  ·  ainda no chão: %s de %s" % [MoneyFormat.percent(removed, total),
				MoneyFormat.brl(total - removed), MoneyFormat.brl(total)], COLOR_EFFECT]]
		if not GameState.is_district_unlocked(district):
			var permit := ShopCatalog.get_default().find(district.permit_id)
			lines.append(["Fechado: compre a %s na Ferragem" % (permit.display_name if permit != null else "licença"), COLOR_INFO])
		make_row("Área  —  %s" % district.display_name, lines, "", false, removed >= total)


## Uma linha por robô: onde está, se está trabalhando e quanto já recolheu.
func _add_robot_rows() -> void:
	var fleet := RobotFleet.current
	if fleet == null:
		return
	var body := tool_user.body if tool_user != null else null
	var player_pos := body.global_position if body != null and body.is_inside_tree() else Vector3.ZERO
	var numbers := {}
	for i in fleet.count():
		var robot := fleet.robot(i)
		var id := robot.definition.id
		numbers[id] = int(numbers.get(id, 0)) + 1
		var meters := Vector2(robot.home.x - player_pos.x, robot.home.y - player_pos.z).length()
		var state := "Área limpa: traga para outro lugar" if robot.idle else "Trabalhando"
		var lines := [
			["%s · a %s m daqui · já recolheu %s" % [state, MoneyFormat.group(roundi(meters)), MoneyFormat.coins(robot.collected)],
				COLOR_INFO if robot.idle else COLOR_EFFECT],
			[robot.definition.effect_summary(), COLOR_INFO]]
		var button := make_row("Robô  —  %s #%d" % [robot.definition.display_name, numbers[id]], lines, "Trazer para cá", true, robot.idle, ItemIcons.of(id))
		if button != null:
			button.pressed.connect(_bring_robot.bind(i))


func _bring_robot(index: int) -> void:
	if RobotFleet.current != null:
		RobotFleet.current.bring_here(index)
	refresh()
