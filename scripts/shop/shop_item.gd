class_name ShopItem
extends Resource
## Base de tudo que pode ser possuído ou comprado: ferramentas e melhorias.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Preço em centavos (0 = não vendido na loja: inicial ou encontrado no mundo).
@export var price_cents := 0
## Ids que precisam ser possuídos antes da compra.
@export var requires: Array[StringName] = []
## Valor encontrado (centavos, o mesmo da meta) necessário para desbloquear (0 = nenhum).
@export var required_value_cents := 0


## Efeito mensurável, em texto, para a loja e o inventário.
func effect_summary() -> String:
	return ""


## Quantas unidades o jogador pode ter (robôs: várias; o resto: uma).
func max_count() -> int:
	return 1


## Preço da próxima unidade para quem já tem `owned_count`.
func price_for(_owned_count: int) -> int:
	return price_cents
