class_name GameStateNode
extends Node
## Estado da partida compartilhado entre sistemas (autoload "GameState").
##
## As regras ficam em CoinLedger (economia) e ShopRules (compras e efeitos), o que saiu do
## mundo em WorldRecord e o formato do save em SaveSerializer; aqui só se guarda o estado,
## aplica as regras e avisa as mudanças por sinais.
##
## Invariante: moedas retiradas do mundo (`world_removed`) = encontradas + no bolso.
## (Robôs depositam direto: o que recolhem vira "encontrado" a cada entrega.)

signal economy_changed
signal tools_changed
signal robots_changed
signal stats_changed
signal tool_granted(id: StringName)
signal notified(text: String)
signal goal_reached
signal shop_requested
## Portal usado (com contrato): a tela de destinos abre a partir de `from` (posição do portal).
signal portal_requested(from: Vector3)
## Uma tela (loja, inventário, mapa, menu) abriu ou fechou. O jogo NÃO pausa: robôs, HUD e
## relógio continuam; só o controle do jogador fica parado.
signal screen_changed(open: bool)
## Para efeitos sonoros: moedas que entraram no bolso, depósito feito e compra na loja.
signal coins_picked(amount: int)
signal deposited(amount: int)
signal purchased(id: StringName)

const STARTING_ITEMS: Array[StringName] = [&"hands"]
const BASE_CARRY_CAPACITY := 100
const AUTOSAVE_SECONDS := 30.0

var ledger := CoinLedger.new()
## Ids de tudo que o jogador possui (ferramentas, melhorias e licenças de bairro).
## Itens com várias unidades (robôs) aparecem uma vez por unidade.
var owned_items: Array[StringName] = STARTING_ITEMS.duplicate()
## Variante escolhida por grupo de ferramenta (ex.: &"hands" -> &"glove").
var selected_variants := {}
var move_speed_multiplier := 1.0
var robot_speed_multiplier := 1.0
## Alcance da lanterna (m), da melhor possuída; 0 = sem lanterna.
var flashlight_range := 0.0
## Hora do dia (0 = meia-noite, 0.5 = meio-dia). Salva com a partida.
var time_of_day := 0.3
## Há uma tela por cima do jogo (ver set_screen_open).
var screen_open := false
## Robôs no mapa: {"id": StringName, "pos": Vector2 (x, z)}. Vector2.INF = ainda sem
## lugar (a frota posiciona perto do jogador).
var robots: Array[Dictionary] = []
## O que já foi recolhido no mundo (por bloco e no total).
var world := WorldRecord.new()
## Assinatura da distribuição das moedas da cidade (CoinWorld) a que o registro do mundo se
## refere. Se a cidade mudar numa versão nova, o registro antigo não vale mais.
var world_signature := ""
## Atalhos de leitura para o registro do mundo (ver WorldRecord).
var world_state: Dictionary:
	get:
		return world.entries
var world_removed: int:
	get:
		return world.removed
var world_removed_value: int:
	get:
		return world.removed_value
## Última posição conhecida do jogador (para continuar de onde parou). null = início.
var player_position: Variant = null
## Mensagem a mostrar quando o HUD abrir (ex.: save antigo descartado).
var pending_notice := ""
## Testes desligam para nunca tocar no save real do jogador.
var save_enabled := true
var save_path := SaveGame.DEFAULT_PATH
var _goal_announced := false
## Segredos da cidade (sátira): conquistas, jornais lidos, votos na urna, encontros com o Senhor V.
## Só tipos simples (vai direto para o JSON do save).
var extras := {}


func _ready() -> void:
	if save_enabled:
		load_game()
	recompute_stats()
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_SECONDS
	timer.autostart = true
	timer.timeout.connect(save_game)
	add_child(timer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _exit_tree() -> void:
	# Caches estáticos seguram recursos até o fim do processo; soltar evita avisos na saída.
	ToolCatalog.release_cache()
	ShopCatalog.release_cache()
	WorldDefinition.release_cache()
	CityLayout.release_cache()
	CoinVisuals.release_cache()


# --- Moedas ----------------------------------------------------------------------------

## Põe moedas no bolso. Falha (sem efeito) se não couber. `value_cents` < 0 = 1 centavo cada.
func add_carried(amount: int, value_cents := -1) -> bool:
	if not ledger.add_carried(amount, value_cents):
		return false
	economy_changed.emit()
	coins_picked.emit(amount)
	return true


## Contabiliza o bolso. Retorna quantas moedas foram depositadas.
func deposit() -> int:
	var value := ledger.carried_value_cents
	var coins := ledger.deposit_carried()
	if coins > 0:
		notify("Depositou %s: +%s" % [MoneyFormat.coins(coins), MoneyFormat.brl(value)])
		extras["biggest_deposit"] = maxi(int(extras.get("biggest_deposit", 0)), coins)
		economy_changed.emit()
		deposited.emit(coins)
		_check_goal()
		save_game()
	return coins


## Moedas recolhidas e depositadas sem passar pelo bolso (robôs). Já saíram do mundo.
func collect_direct(amount: int, value_cents := -1) -> void:
	if amount <= 0:
		return
	ledger.register_found(amount, value_cents)
	economy_changed.emit()
	_check_goal()


## Registro de uma retirada do mundo (chamado por CoinWorld.take). `value` = centavos;
## `pile_count` = pilhas do bloco (o restante de cada uma fica em "rem"; 255 = intocada).
func record_world_take(key: Vector2i, index: int, remaining: int, amount: int, value := -1, pile_count := 0) -> void:
	world.record_take(key, index, remaining, amount, value, pile_count)


func world_entry(key: Vector2i) -> Dictionary:
	return world.entry(key)


# --- Itens ----------------------------------------------------------------------------

func owns(id: StringName) -> bool:
	return owned_items.has(id)


func item_count(id: StringName) -> int:
	return owned_items.count(id)


## Compra na loja. Falha (sem efeito) se não estiver disponível para o jogador.
func purchase(id: StringName) -> bool:
	var item := ShopCatalog.get_default().find(id)
	if item == null or ShopRules.status(item, owned_items, ledger.money_cents, ledger.total_value_found_cents) != ShopRules.Status.AVAILABLE:
		return false
	var price := ShopRules.next_price(item, owned_items)
	if not ledger.spend(price):
		return false
	_grant(item)
	notify("Comprou %s por %s" % [item.display_name, MoneyFormat.brl(price)])
	purchased.emit(id)
	economy_changed.emit()
	save_game()
	return true


## Ganha um item sem pagar (testes, recompensas).
func grant(id: StringName) -> void:
	var item := find_item(id)
	if item == null or item_count(id) >= item.max_count():
		return
	_grant(item)
	notify("Nova ferramenta: %s" % item.display_name if item is ToolDefinition else "Novo item: %s" % item.display_name)


func owned_upgrades() -> Array[UpgradeDefinition]:
	var upgrades: Array[UpgradeDefinition] = []
	for item in ShopCatalog.get_default().items:
		if item is UpgradeDefinition and owns(item.id):
			upgrades.append(item)
	return upgrades


func is_district_unlocked(district: DistrictDefinition) -> bool:
	return district.permit_id == &"" or owns(district.permit_id)


## Ferramenta com os bônus das melhorias possuídas.
func effective_tool(definition: ToolDefinition) -> ToolDefinition:
	return ShopRules.apply_tool_bonuses(definition, owned_upgrades())


## Variante a usar para um grupo: a escolhida, ou a melhor possuída. null se nenhuma.
func tool_for_group(group: StringName) -> ToolDefinition:
	var catalog := ToolCatalog.get_default()
	var selected: StringName = selected_variants.get(group, &"")
	if selected != &"" and owns(selected):
		return catalog.find(selected)
	var best: ToolDefinition = null
	for variant in catalog.variants(group):
		if owns(variant.id):
			best = variant
	return best


func select_variant(id: StringName) -> void:
	var definition := ToolCatalog.get_default().find(id)
	if definition == null or not owns(id):
		return
	selected_variants[definition.slot_group] = id
	tools_changed.emit()


func recompute_stats() -> void:
	var upgrades := owned_upgrades()
	ledger.carry_capacity = ShopRules.carry_capacity(BASE_CARRY_CAPACITY, upgrades)
	move_speed_multiplier = ShopRules.move_speed_multiplier(upgrades)
	robot_speed_multiplier = ShopRules.robot_speed_multiplier(upgrades)
	flashlight_range = ShopRules.flashlight_range(upgrades)
	stats_changed.emit()
	economy_changed.emit()


## Chamado pelo CoinWorld ao montar a cidade. Partida nova: só anota a assinatura. Save de
## uma cidade diferente (outra versão do traçado): as moedas voltam todas ao chão e o progresso
## da meta recomeça, mas dinheiro, itens e robôs ficam (o registro antigo não bate mais com as
## pilhas, e mantê-lo deixaria contar a mesma moeda duas vezes).
## `legacy`: assinatura do formato antigo (só a alocação), aceita uma vez sem zerar o mundo:
## saves de antes da mudança são da mesma geração de pilhas desta versão.
func check_world_signature(signature: String, legacy := "") -> void:
	if world_signature == signature:
		return
	if legacy != "" and world_signature == legacy:
		world_signature = signature
		return
	var had_progress := world.removed > 0 or ledger.total_coins_found > 0
	world_signature = signature
	if not had_progress:
		return
	world = WorldRecord.new()
	ledger.total_coins_found = 0
	ledger.total_value_found_cents = 0
	ledger.carried_coins = 0
	ledger.carried_value_cents = 0
	_goal_announced = false
	pending_notice = "A cidade mudou nesta versão: as moedas voltaram todas ao chão. Você manteve o dinheiro, os itens e os robôs."
	economy_changed.emit()
	save_game()


func set_screen_open(open: bool) -> void:
	if screen_open == open:
		return
	screen_open = open
	screen_changed.emit(open)


func request_shop() -> void:
	shop_requested.emit()


func request_portal(from: Vector3) -> void:
	portal_requested.emit(from)


## Libera uma conquista (Achievements.LIST). Retorna false se já tinha. `quiet`: sem aviso (quem
## chama avisa várias de uma vez).
func unlock(id: StringName, quiet := false) -> bool:
	var list: Array = extras.get("achievements", [])
	if String(id) in list:
		return false
	list.append(String(id))
	extras["achievements"] = list
	if not quiet:
		notify("Conquista: %s" % Achievements.title_of(id))
		Sfx.play(&"chime", 0.0, -3.0)
	save_game()
	return true


func has_achievement(id: StringName) -> bool:
	return String(id) in (extras.get("achievements", []) as Array)


## Contador dos segredos (jornal lido, votos...). Soma `by` e devolve o valor novo.
func bump(key: String, by := 1) -> int:
	var value := int(extras.get(key, 0)) + by
	extras[key] = value
	return value


func notify(text: String) -> void:
	notified.emit(text)


# --- Partida e salvamento ------------------------------------------------------------

## Volta ao início (sem tocar no disco).
func reset() -> void:
	ledger = CoinLedger.new()
	owned_items = STARTING_ITEMS.duplicate()
	selected_variants = {}
	world = WorldRecord.new()
	player_position = null
	world_signature = ""
	robots = []
	time_of_day = 0.3
	screen_open = false
	_goal_announced = false
	extras = {}
	recompute_stats()
	tools_changed.emit()
	robots_changed.emit()


## Apaga o save e recomeça.
func new_game() -> void:
	if save_enabled:
		SaveGame.delete(save_path)
	reset()


func save_game() -> void:
	if save_enabled:
		SaveGame.write(save_path, SaveSerializer.to_dict(self))


func load_game() -> void:
	apply_save(SaveGame.read(save_path))


func to_save() -> Dictionary:
	return SaveSerializer.to_dict(self)


## Aplica um save validando cada campo; valores ausentes ou inválidos viram o padrão.
## Saves de versões antigas (outro modelo de jogo) começam uma partida nova.
func apply_save(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return
	if not SaveSerializer.is_current(data):
		pending_notice = SaveSerializer.OLD_VERSION_NOTICE
		return
	SaveSerializer.apply(self, data)
	robots_changed.emit()
	recompute_stats()
	# O bolso é o que saiu do mundo e ainda não foi contabilizado; mantém a invariante.
	ledger.carried_coins = clampi(world_removed - ledger.total_coins_found, 0, ledger.carry_capacity)
	# Valor do bolso pelo mesmo raciocínio, entre 1 centavo e R$ 1 por moeda.
	ledger.carried_value_cents = clampi(world_removed_value - ledger.total_value_found_cents, ledger.carried_coins, ledger.carried_coins * Denomination.VALUES[-1])
	_goal_announced = ledger.is_goal_reached()
	economy_changed.emit()
	tools_changed.emit()


func _grant(item: ShopItem) -> void:
	owned_items.append(item.id)
	if item is ToolDefinition:
		selected_variants[(item as ToolDefinition).slot_group] = item.id
	if item is RobotDefinition:
		robots.append({"id": item.id, "pos": Vector2.INF})
		robots_changed.emit()
	recompute_stats()
	tools_changed.emit()
	if item is ToolDefinition:
		tool_granted.emit(item.id)


## Muda o robô `index` de lugar (x, z no chão).
func move_robot(index: int, pos: Vector2) -> void:
	if index < 0 or index >= robots.size():
		return
	robots[index].pos = pos
	robots_changed.emit()


## Item de qualquer catálogo (ferramentas ou loja) pelo id; null se não existir.
func find_item(id: StringName) -> ShopItem:
	var tool_def := ToolCatalog.get_default().find(id)
	return tool_def if tool_def != null else ShopCatalog.get_default().find(id)


func _check_goal() -> void:
	if not _goal_announced and ledger.is_goal_reached():
		_goal_announced = true
		goal_reached.emit()

