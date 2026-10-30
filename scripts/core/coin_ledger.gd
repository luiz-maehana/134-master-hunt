class_name CoinLedger
extends RefCounted
## Regras econômicas puras (sem nós nem interface), testáveis isoladamente.
##
## Tudo é inteiro: moedas são contadas uma a uma e dinheiro é guardado em centavos.
## Fluxo: moeda pega -> bolso (carried) -> depósito -> encontrada (total) + dinheiro.
## A meta é em dinheiro: encontrar R$ 134 milhões (o valor somado das moedas de 1, 5, 10, 25
## e 50 centavos e de R$ 1). A quantidade de moedas é só informativa. Sem valor informado,
## a moeda é de 1 centavo.

## Meta do jogo, em centavos: R$ 134.000.000,00.
const GOAL_CENTS := 13_400_000_000
const CENTS_PER_COIN := 1
## Escala do progresso: 100% = 100_000_000 (milionésimos de ponto percentual).
const PROGRESS_SCALE := 100_000_000

## Moedas encontradas (quantidade, informativa). Nunca diminui, nem com gastos.
var total_coins_found := 0
## Soma do valor das moedas encontradas (centavos): é o que conta para a meta. Nunca diminui.
var total_value_found_cents := 0
## Dinheiro disponível para compras, em centavos.
var money_cents := 0
var total_spent_cents := 0
## Moedas no bolso, ainda não contabilizadas, e o valor delas.
var carried_coins := 0
var carried_value_cents := 0
var carry_capacity := 50


func recovered_value_cents() -> int:
	return total_value_found_cents


func free_capacity() -> int:
	return maxi(carry_capacity - carried_coins, 0)


func can_carry(amount: int) -> bool:
	return amount > 0 and amount <= free_capacity()


## `value_cents` < 0 = moedas de 1 centavo.
func add_carried(amount: int, value_cents := -1) -> bool:
	if not can_carry(amount):
		return false
	carried_coins += amount
	carried_value_cents += _value(amount, value_cents)
	return true


## Contabiliza as moedas do bolso. Retorna quantas foram depositadas.
func deposit_carried() -> int:
	var amount := carried_coins
	var value := carried_value_cents
	carried_coins = 0
	carried_value_cents = 0
	register_found(amount, value)
	return amount


func register_found(amount: int, value_cents := -1) -> void:
	if amount <= 0:
		return
	var value := _value(amount, value_cents)
	total_coins_found += amount
	total_value_found_cents += value
	money_cents += value


func can_afford(price_cents: int) -> bool:
	return price_cents >= 0 and price_cents <= money_cents


func spend(price_cents: int) -> bool:
	if not can_afford(price_cents):
		return false
	money_cents -= price_cents
	total_spent_cents += price_cents
	return true


## Progresso truncado (nunca arredonda para cima), limitado a 100%.
## Truncar garante que a interface não mostre 100% antes da vitória.
func progress_scaled() -> int:
	@warning_ignore("integer_division")
	return mini(total_value_found_cents * PROGRESS_SCALE / GOAL_CENTS, PROGRESS_SCALE)


## Quanto falta para a meta, em centavos.
func remaining_cents() -> int:
	return maxi(GOAL_CENTS - total_value_found_cents, 0)


func is_goal_reached() -> bool:
	return total_value_found_cents >= GOAL_CENTS


static func _value(amount: int, value_cents: int) -> int:
	return amount * CENTS_PER_COIN if value_cents < 0 else value_cents
