class_name SaveSerializer
extends RefCounted
## Converte o estado da partida (GameState) em dicionário de save e de volta, validando cada
## campo: valores ausentes, de tipo errado ou impossíveis viram o padrão. O disco fica com
## SaveGame; as invariantes (bolso, meta) ficam com o GameState depois de aplicar.

const OLD_VERSION_NOTICE := "O jogo mudou: a meta agora é encontrar R$ 134 milhões, e a cidade foi redistribuída. Sua partida antiga foi reiniciada."


static func to_dict(state: GameStateNode) -> Dictionary:
	var ledger := state.ledger
	var data := {
		"version": SaveGame.VERSION,
		"coins_found": ledger.total_coins_found,
		"value_found_cents": ledger.total_value_found_cents,
		"money_cents": ledger.money_cents,
		"spent_cents": ledger.total_spent_cents,
		"carried_coins": ledger.carried_coins,
		"owned": state.owned_items.map(func(id: StringName) -> String: return String(id)),
		"selected": state.selected_variants.duplicate(),
		"world": state.world.to_save(),
		"time_of_day": state.time_of_day,
		"world_signature": state.world_signature,
	}
	if state.player_position is Vector3:
		var p: Vector3 = state.player_position
		data["player_position"] = [p.x, p.y, p.z]
	var robot_list: Array = []
	for robot in state.robots:
		var at: Vector2 = robot.pos
		robot_list.append([String(robot.id), at.x, at.y] if at.is_finite() else [String(robot.id)])
	data["robots"] = robot_list
	return data


## Save do modelo de jogo atual? (versões antigas recomeçam a partida)
static func is_current(data: Dictionary) -> bool:
	return non_negative_int(data.get("version")) >= SaveGame.VERSION


## Preenche `state` (já zerado) com o que for válido em `data`.
static func apply(state: GameStateNode, data: Dictionary) -> void:
	var ledger := state.ledger
	ledger.total_coins_found = non_negative_int(data.get("coins_found"))
	# Saves de antes dos valores de moeda: tudo era de 1 centavo.
	ledger.total_value_found_cents = non_negative_int(data.get("value_found_cents", ledger.total_coins_found))
	ledger.money_cents = non_negative_int(data.get("money_cents"))
	ledger.total_spent_cents = non_negative_int(data.get("spent_cents"))
	_apply_owned(state, data.get("owned"))
	_apply_selected(state, data.get("selected"))
	state.world.load_save(data.get("world"))
	var pos: Variant = data.get("player_position")
	if pos is Array and pos.size() == 3 and (pos as Array).all(_is_finite_number):
		state.player_position = Vector3(pos[0], pos[1], pos[2])
	var hour: Variant = data.get("time_of_day")
	if _is_finite_number(hour):
		state.time_of_day = fposmod(float(hour), 1.0)
	var signature: Variant = data.get("world_signature")
	if signature is String:
		state.world_signature = signature
	state.robots = _robots_for(state, data.get("robots"))


static func non_negative_int(value: Variant) -> int:
	if _is_finite_number(value) and float(value) >= 0.0:
		return int(value)
	return 0


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


## Só ids que existem no catálogo, até o limite de unidades de cada item.
static func _apply_owned(state: GameStateNode, raw: Variant) -> void:
	if not raw is Array:
		return
	for id in raw:
		if not id is String:
			continue
		var item := state.find_item(StringName(id))
		if item != null and state.item_count(item.id) < item.max_count():
			state.owned_items.append(item.id)


## Variante escolhida só se for uma ferramenta possuída do mesmo grupo.
static func _apply_selected(state: GameStateNode, raw: Variant) -> void:
	if not raw is Dictionary:
		return
	for group in raw:
		var id := StringName(str(raw[group]))
		var tool_def := ToolCatalog.get_default().find(id)
		if tool_def != null and state.owns(id) and tool_def.slot_group == StringName(str(group)):
			state.selected_variants[tool_def.slot_group] = id


## Um robô por unidade possuída: posições salvas válidas são mantidas; as que faltam ficam
## sem lugar (a frota coloca perto do jogador) e as que sobram são descartadas.
static func _robots_for(state: GameStateNode, raw: Variant) -> Array[Dictionary]:
	var saved: Dictionary = {}   # id -> Array[Vector2]
	if raw is Array:
		for entry in raw:
			if not entry is Array or (entry as Array).is_empty() or not entry[0] is String:
				continue
			var pos := Vector2.INF
			if entry.size() == 3 and _is_finite_number(entry[1]) and _is_finite_number(entry[2]):
				pos = Vector2(float(entry[1]), float(entry[2]))
			var list: Array = saved.get(StringName(entry[0]), [])
			list.append(pos)
			saved[StringName(entry[0])] = list
	var robots: Array[Dictionary] = []
	for id in state.owned_items:
		if state.find_item(id) is RobotDefinition:
			var list: Array = saved.get(id, [])
			robots.append({"id": id, "pos": list.pop_front() if not list.is_empty() else Vector2.INF})
	return robots
