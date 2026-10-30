class_name MoneyFormat
extends RefCounted
## Formatação brasileira de quantidades, reais e porcentagens. Só aritmética inteira.


## 1340000 -> "1.340.000"
static func group(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if value < 0 else "") + out


## 1 -> "1 moeda", 1500 -> "1.500 moedas"
static func coins(amount: int) -> String:
	return "%s %s" % [group(amount), "moeda" if absi(amount) == 1 else "moedas"]


## 134000000 centavos -> "R$ 1.340.000,00"
@warning_ignore("integer_division")
static func brl(cents: int) -> String:
	var prefix := "-" if cents < 0 else ""
	var abs_cents := absi(cents)
	return "%sR$ %s,%02d" % [prefix, group(abs_cents / 100), abs_cents % 100]


## 0.35 -> "0,35" (para atributos exibidos ao jogador, não para dinheiro).
static func decimal(value: float, digits := 2) -> String:
	return ("%.*f" % [digits, value]).replace(".", ",")


## Porcentagem com uma casa, truncada: só mostra "100,0%" quando part == total.
@warning_ignore("integer_division")
static func percent(part: int, total: int) -> String:
	if total <= 0:
		return "100,0%"
	var tenths := clampi(part, 0, total) * 1000 / total
	return "%d,%d%%" % [tenths / 10, tenths % 10]


## Progresso em CoinLedger.PROGRESS_SCALE -> "0,000001%" / "100,000000%"
@warning_ignore("integer_division")
static func progress(scaled: int) -> String:
	return "%s,%06d%%" % [group(scaled / 1_000_000), scaled % 1_000_000]
