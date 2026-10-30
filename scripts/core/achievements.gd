class_name Achievements
extends RefCounted
## Conquistas. Dois tipos:
## - Segredos da cidade (Stat.NONE): liberadas por evento (GameState.unlock), na sátira
##   (personagens, partidos e manchetes fictícios).
## - Progresso: liberadas sozinhas (check) quando a estatística passa da meta.
## As segredas ainda não achadas aparecem como "???" na tela de Conquistas (AchievementsMenu).

enum Stat { NONE, VALUE_FOUND, COINS_FOUND, MONEY, SPENT, DISTRICTS, CLEAN_DISTRICT, TOOLS, ROBOTS, PORTAL_TRIPS, BIG_DEPOSIT, SECRETS }

## Meta -1: calculada (todas as ferramentas, todos os segredos).
const ALL := -1
## Categorias na ordem da tela.
const CATEGORIES := ["Meta", "Moedas", "Dinheiro", "Cidade", "Equipamentos", "Segredos"]
## id -> [categoria, título, como conseguir, estatística, meta].
const LIST := {
	&"goal_1": ["Meta", "Primeiro real", "Encontrar R$ 1,00.", Stat.VALUE_FOUND, 100],
	&"goal_100": ["Meta", "Cofrinho", "Encontrar R$ 100,00.", Stat.VALUE_FOUND, 10_000],
	&"goal_10k": ["Meta", "Bolada", "Encontrar R$ 10 mil.", Stat.VALUE_FOUND, 1_000_000],
	&"goal_1m": ["Meta", "Milionário de centavos", "Encontrar R$ 1 milhão.", Stat.VALUE_FOUND, 100_000_000],
	&"goal_10m": ["Meta", "Emenda de bancada", "Encontrar R$ 10 milhões.", Stat.VALUE_FOUND, 1_000_000_000],
	&"goal_50m": ["Meta", "Mala de dinheiro vivo", "Encontrar R$ 50 milhões.", Stat.VALUE_FOUND, 5_000_000_000],
	&"accountability": ["Meta", "A prestação de contas", "Encontrar os R$ 134 milhões.", Stat.VALUE_FOUND, 13_400_000_000],
	&"coins_1k": ["Moedas", "Mil moedas", "Pegar 1.000 moedas.", Stat.COINS_FOUND, 1_000],
	&"coins_100k": ["Moedas", "Cem mil moedas", "Pegar 100 mil moedas.", Stat.COINS_FOUND, 100_000],
	&"coins_1m": ["Moedas", "Um milhão de moedas", "Pegar 1 milhão de moedas.", Stat.COINS_FOUND, 1_000_000],
	&"coins_10m": ["Moedas", "Dez milhões de moedas", "Pegar 10 milhões de moedas.", Stat.COINS_FOUND, 10_000_000],
	&"coins_100m": ["Moedas", "Cem milhões de moedas", "Pegar 100 milhões de moedas.", Stat.COINS_FOUND, 100_000_000],
	&"big_deposit": ["Moedas", "Depósito à vista", "Depositar 100 mil moedas de uma vez.", Stat.BIG_DEPOSIT, 100_000],
	&"wallet_1m": ["Dinheiro", "Saldo de gabinete", "Ter R$ 1 milhão na carteira.", Stat.MONEY, 100_000_000],
	&"spent_10k": ["Dinheiro", "Cliente da Ferragem", "Gastar R$ 10 mil na Ferragem.", Stat.SPENT, 1_000_000],
	&"spent_1m": ["Dinheiro", "Sócio do Seu Zé", "Gastar R$ 1 milhão na Ferragem.", Stat.SPENT, 100_000_000],
	&"district_1": ["Cidade", "Licença para catar", "Liberar o primeiro bairro novo.", Stat.DISTRICTS, 1],
	&"district_all": ["Cidade", "Livre trânsito", "Liberar todos os bairros.", Stat.DISTRICTS, 3],
	&"clean_district": ["Cidade", "Varrição completa", "Recolher 100% de um bairro.", Stat.CLEAN_DISTRICT, 1],
	&"portal_1": ["Cidade", "Primeira viagem", "Viajar por um portal.", Stat.PORTAL_TRIPS, 1],
	&"portal_25": ["Cidade", "Milhas de gabinete", "Viajar 25 vezes pelos portais.", Stat.PORTAL_TRIPS, 25],
	&"tools_5": ["Equipamentos", "Caixa de ferramentas", "Ter 5 ferramentas.", Stat.TOOLS, 5],
	&"tools_all": ["Equipamentos", "A Ferragem inteira", "Ter todas as ferramentas.", Stat.TOOLS, ALL],
	&"robot_1": ["Equipamentos", "Assessor robótico", "Comprar o primeiro robô.", Stat.ROBOTS, 1],
	&"robot_10": ["Equipamentos", "Gabinete completo", "Ter 10 robôs trabalhando.", Stat.ROBOTS, 10],
	&"legendary_coin": ["Segredos", "Agora só faltam 133.999.999", "Achar a moeda lendária de 1 centavo.", Stat.NONE, 0],
	&"democracy_loop": ["Segredos", "Democracia em Loop", "Votar 10 vezes na urna das promessas.", Stat.NONE, 0],
	&"newsroom": ["Segredos", "Leitor de errata", "Ler as três versões de uma mesma manchete.", Stat.NONE, 0],
	&"popcorn": ["Segredos", "Orçamento da pipoca", "Comprar pipoca com 1 centavo no cinema do Dark Horse.", Stat.NONE, 0],
	&"complex_structure": ["Segredos", "Estrutura muito complexa", "Encontrar o Senhor V. três vezes.", Stat.NONE, 0],
	&"three_hundred_pages": ["Segredos", "Contrato de 300 páginas", "Pedir a melhoria do Senhor V.", Stat.NONE, 0],
	&"not_in_system": ["Segredos", "Não consta no sistema", "Seguir as pegadas no aeroporto até o passaporte.", Stat.NONE, 0],
	&"investigative_tourism": ["Segredos", "Turismo investigativo", "Abrir as três malas do esconderijo.", Stat.NONE, 0],
	&"unavailable_balance": ["Segredos", "Saldo indisponível", "Insistir com o caixa do Banco Central de Tudo.", Stat.NONE, 0],
	&"almost_done": ["Segredos", "Quase pronto", "Perguntar do orçamento na Produções Milionárias.", Stat.NONE, 0],
	&"secret_hunter": ["Segredos", "Caçador de segredos", "Achar todos os segredos da cidade.", Stat.SECRETS, ALL],
}
## Conquistas novas de uma vez acima disto viram um aviso só.
const NOTIFY_LIMIT := 2


static func title_of(id: StringName) -> String:
	return LIST[id][1] if LIST.has(id) else String(id)


static func category_of(id: StringName) -> String:
	return LIST[id][0] if LIST.has(id) else ""


static func is_secret(id: StringName) -> bool:
	return LIST.has(id) and LIST[id][3] == Stat.NONE


## Meta de uma conquista de progresso (0 nos segredos).
static func target(id: StringName) -> int:
	var entry: Array = LIST[id]
	if entry[4] != ALL:
		return entry[4]
	match entry[3]:
		Stat.TOOLS:
			return _tool_ids().size()
		Stat.SECRETS:
			return _secret_ids().size()
	return 0


## Valor atual da estatística da conquista.
static func current(id: StringName) -> int:
	var ledger := GameState.ledger
	match LIST[id][3]:
		Stat.VALUE_FOUND:
			return ledger.total_value_found_cents
		Stat.COINS_FOUND:
			return ledger.total_coins_found
		Stat.MONEY:
			return ledger.money_cents
		Stat.SPENT:
			return ledger.total_spent_cents
		Stat.DISTRICTS:
			var count := 0
			for district in WorldDefinition.get_default().districts:
				if district.permit_id != &"" and GameState.is_district_unlocked(district):
					count += 1
			return count
		Stat.CLEAN_DISTRICT:
			var world := CoinWorld.current
			if world != null:
				for i in WorldDefinition.get_default().districts.size():
					if world.district_progress(i) >= 1.0:
						return 1
			return 0
		Stat.TOOLS:
			return _tool_ids().filter(func(tool_id: StringName) -> bool: return GameState.owns(tool_id)).size()
		Stat.ROBOTS:
			return GameState.robots.size()
		Stat.PORTAL_TRIPS:
			return int(GameState.extras.get("portal_trips", 0))
		Stat.BIG_DEPOSIT:
			return int(GameState.extras.get("biggest_deposit", 0))
		Stat.SECRETS:
			return _secret_ids().filter(func(secret: StringName) -> bool: return GameState.has_achievement(secret)).size()
	return 0


## Libera as conquistas de progresso já merecidas. Poucas: um aviso para cada; muitas (um save
## antigo, por exemplo): um aviso só.
static func check() -> void:
	var fresh: Array[StringName] = []
	for id: StringName in LIST:
		if LIST[id][3] != Stat.NONE and not GameState.has_achievement(id) and current(id) >= target(id):
			fresh.append(id)
	if fresh.is_empty():
		return
	for id in fresh:
		GameState.unlock(id, fresh.size() > NOTIFY_LIMIT)
	if fresh.size() > NOTIFY_LIMIT:
		GameState.notify("+%d conquistas! Veja em Conquistas (%s)." % [fresh.size(), InputBindings.label_of(&"achievements")])
	# Caçador de segredos depende das outras: pode ter ficado pronto agora.
	check.call_deferred()


static func _secret_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in LIST:
		if LIST[id][3] == Stat.NONE:
			ids.append(id)
	return ids


## Ferramentas compráveis (todas menos as mãos).
static func _tool_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var catalog := ToolCatalog.get_default()
	for group in catalog.groups():
		for variant in catalog.variants(group):
			if variant.price_cents > 0:
				ids.append(variant.id)
	return ids
