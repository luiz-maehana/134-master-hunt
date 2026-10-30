extends TestSuite


func test_one_coin_is_one_cent() -> void:
	var ledger := CoinLedger.new()
	ledger.register_found(1)
	check_eq(ledger.total_coins_found, 1, "quantidade encontrada")
	check_eq(ledger.recovered_value_cents(), 1, "valor recuperado")
	check_eq(ledger.money_cents, 1, "dinheiro")


func test_known_amounts() -> void:
	var cases := [[100, "R$ 1,00"], [10_000, "R$ 100,00"], [134_000_000, "R$ 1.340.000,00"]]
	for case in cases:
		var ledger := CoinLedger.new()
		ledger.register_found(case[0])
		check_eq(MoneyFormat.brl(ledger.recovered_value_cents()), case[1], "%d moedas" % case[0])


func test_spending_keeps_total() -> void:
	var ledger := CoinLedger.new()
	ledger.register_found(500)
	check(ledger.spend(200), "compra com saldo")
	check_eq(ledger.money_cents, 300, "desconta o preço exato")
	check_eq(ledger.total_coins_found, 500, "total não diminui")
	check_eq(ledger.recovered_value_cents(), 500, "valor recuperado não diminui")
	check_eq(ledger.total_spent_cents, 200, "total gasto")


func test_cannot_overspend() -> void:
	var ledger := CoinLedger.new()
	ledger.register_found(99)
	check(not ledger.spend(100), "sem saldo suficiente")
	check_eq(ledger.money_cents, 99, "saldo intacto")
	check(not ledger.spend(-5), "preço negativo recusado")
	check(ledger.spend(99), "pode gastar exatamente o saldo")
	check_eq(ledger.money_cents, 0, "saldo zerado")


func test_progress_is_truncated() -> void:
	var ledger := CoinLedger.new()
	check_eq(ledger.progress_scaled(), 0, "início")
	ledger.register_found(1)
	check_eq(ledger.progress_scaled(), 0, "1 centavo < 0,000001%")
	ledger.register_found(1, 13_399)
	check_eq(ledger.progress_scaled(), 100, "R$ 134,00 = 0,0001%")
	ledger = CoinLedger.new()
	ledger.register_found(1, 6_700_000_000)
	check_eq(ledger.progress_scaled(), 50_000_000, "metade = 50%")


func test_goal_boundary() -> void:
	var ledger := CoinLedger.new()
	ledger.register_found(1, CoinLedger.GOAL_CENTS - 1)
	check(not ledger.is_goal_reached(), "um centavo antes da meta não vence")
	check(ledger.progress_scaled() < CoinLedger.PROGRESS_SCALE, "não mostra 100% antes da meta")
	check_eq(ledger.remaining_cents(), 1, "falta 1 centavo")
	ledger.register_found(1)
	check(ledger.is_goal_reached(), "meta exata vence (R$ 134 milhões)")
	check_eq(ledger.total_coins_found, 2, "a quantidade de moedas não importa para a meta")
	check_eq(ledger.progress_scaled(), CoinLedger.PROGRESS_SCALE, "100%")
	ledger.register_found(10)
	check(ledger.is_goal_reached(), "acima da meta continua vencido")
	check_eq(ledger.progress_scaled(), CoinLedger.PROGRESS_SCALE, "progresso limitado a 100%")
	check_eq(ledger.remaining_cents(), 0, "nada falta")


func test_carry_capacity_and_deposit() -> void:
	var ledger := CoinLedger.new()
	ledger.carry_capacity = 50
	check(ledger.add_carried(50), "enche o bolso")
	check(not ledger.add_carried(1), "não passa da capacidade")
	check_eq(ledger.carried_coins, 50, "bolso cheio")
	check_eq(ledger.total_coins_found, 0, "bolso ainda não conta")
	check_eq(ledger.deposit_carried(), 50, "deposita tudo")
	check_eq(ledger.carried_coins, 0, "bolso vazio")
	check_eq(ledger.total_coins_found, 50, "contabilizadas")
	check_eq(ledger.money_cents, 50, "viraram dinheiro")
	check_eq(ledger.deposit_carried(), 0, "depositar vazio não muda nada")
	check_eq(ledger.total_coins_found, 50, "total igual")
	check(not ledger.add_carried(0), "zero recusado")
	check(not ledger.add_carried(-3), "negativo recusado")
