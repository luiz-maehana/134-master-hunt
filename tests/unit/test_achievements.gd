extends TestSuite
## Conquistas: progresso libera sozinho, várias de uma vez viram um aviso só, segredos contam
## para o "Caçador de segredos" e tudo volta do save.

var _notes: Array[String] = []


func before_all() -> void:
	GameState.notified.connect(_on_note)


func after_all() -> void:
	GameState.notified.disconnect(_on_note)
	GameState.reset()


func _on_note(text: String) -> void:
	_notes.append(text)


func test_catalog_is_consistent() -> void:
	for id: StringName in Achievements.LIST:
		var entry: Array = Achievements.LIST[id]
		check(entry[0] in Achievements.CATEGORIES, "%s: categoria conhecida" % id)
		if not Achievements.is_secret(id):
			check(Achievements.target(id) > 0, "%s: meta positiva (%d)" % [id, Achievements.target(id)])


func test_progress_unlocks_by_itself() -> void:
	GameState.reset()
	_notes.clear()
	GameState.ledger.total_value_found_cents = 150
	Achievements.check()
	check(GameState.has_achievement(&"goal_1"), "R$ 1,50 encontrados: Primeiro real")
	check(not GameState.has_achievement(&"goal_100"), "ainda não o Cofrinho")
	check(_notes.any(func(n: String) -> bool: return n.contains("Primeiro real")), "aviso com o nome da conquista")


func test_many_at_once_become_one_notice() -> void:
	GameState.reset()
	_notes.clear()
	GameState.ledger.total_value_found_cents = 2_000_000_000
	GameState.ledger.total_coins_found = 2_000_000
	Achievements.check()
	check(GameState.has_achievement(&"goal_10m") and GameState.has_achievement(&"coins_1m"), "save antigo: várias liberadas")
	var summaries := _notes.filter(func(n: String) -> bool: return n.begins_with("+"))
	check_eq(summaries.size(), 1, "um aviso só para todas")
	check(not _notes.any(func(n: String) -> bool: return n.begins_with("Conquista:")), "sem um aviso por conquista")


func test_secret_hunter_needs_every_secret() -> void:
	GameState.reset()
	var secrets: Array[StringName] = []
	for id: StringName in Achievements.LIST:
		if Achievements.is_secret(id):
			secrets.append(id)
	for i in secrets.size() - 1:
		GameState.unlock(secrets[i], true)
	Achievements.check()
	check(not GameState.has_achievement(&"secret_hunter"), "falta um segredo: ainda não")
	GameState.unlock(secrets[-1], true)
	Achievements.check()
	check(GameState.has_achievement(&"secret_hunter"), "todos os segredos: Caçador de segredos")
	check_eq(Achievements.current(&"secret_hunter"), Achievements.target(&"secret_hunter"), "progresso completo")


func test_counters_feed_achievements() -> void:
	GameState.reset()
	for i in 25:
		GameState.bump("portal_trips")
	GameState.extras["biggest_deposit"] = 120_000
	Achievements.check()
	check(GameState.has_achievement(&"portal_25"), "25 viagens de portal")
	check(GameState.has_achievement(&"big_deposit"), "depósito de 120 mil moedas")
