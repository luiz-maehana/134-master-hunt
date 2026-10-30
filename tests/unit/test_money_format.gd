extends TestSuite


func test_group_thousands() -> void:
	check_eq(MoneyFormat.group(0), "0", "zero")
	check_eq(MoneyFormat.group(999), "999", "sem separador")
	check_eq(MoneyFormat.group(1000), "1.000", "milhar")
	check_eq(MoneyFormat.group(134_000_000), "134.000.000", "meta")
	check_eq(MoneyFormat.group(-1234567), "-1.234.567", "negativo")


func test_coins_plural() -> void:
	check_eq(MoneyFormat.coins(0), "0 moedas", "zero no plural")
	check_eq(MoneyFormat.coins(1), "1 moeda", "uma no singular")
	check_eq(MoneyFormat.coins(1500), "1.500 moedas", "milhar no plural")


func test_brl() -> void:
	check_eq(MoneyFormat.brl(0), "R$ 0,00", "zero")
	check_eq(MoneyFormat.brl(1), "R$ 0,01", "um centavo")
	check_eq(MoneyFormat.brl(100), "R$ 1,00", "um real")
	check_eq(MoneyFormat.brl(10_000), "R$ 100,00", "cem reais")
	check_eq(MoneyFormat.brl(134_000_000), "R$ 1.340.000,00", "valor da meta")
	check_eq(MoneyFormat.brl(-250), "-R$ 2,50", "negativo")


func test_progress() -> void:
	check_eq(MoneyFormat.progress(0), "0,000000%", "zero")
	check_eq(MoneyFormat.progress(1), "0,000001%", "menor unidade")
	check_eq(MoneyFormat.progress(50_000_000), "50,000000%", "metade")
	check_eq(MoneyFormat.progress(100_000_000), "100,000000%", "completo")


func test_percent_truncates() -> void:
	check_eq(MoneyFormat.percent(0, 33_051), "0,0%", "zero")
	check_eq(MoneyFormat.percent(123, 1000), "12,3%", "uma casa")
	check_eq(MoneyFormat.percent(33_050, 33_051), "99,9%", "falta 1 moeda: não arredonda para 100")
	check_eq(MoneyFormat.percent(33_051, 33_051), "100,0%", "completo")
	check_eq(MoneyFormat.percent(5, 0), "100,0%", "bairro sem moedas")
