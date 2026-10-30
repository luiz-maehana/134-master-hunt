class_name DistrictDefinition
extends Resource
## Bairro da cidade: um trecho do Eixo Monumental, com riqueza e tamanho de pilhas próprios.
## Liberado por uma licença vendida na loja.

@export var id: StringName
@export var display_name := ""
## Quarteirões do bairro (x, z, largura, altura, em quarteirões). Os que já pertencem a um
## bairro anterior da lista ficam com ele.
@export var area := Rect2i(0, 0, 1, 1)
## Peso relativo de dinheiro (valor) por m² caminhável. As fatias de todos os bairros somam o total.
@export var density_weight := 1.0
## Perfil das pilhas: três faixas de tamanho [mín, máx] e a chance de cada uma.
@export var pile_small := Vector2i(1, 1)
@export var pile_medium := Vector2i(2, 5)
@export var pile_large := Vector2i(10, 30)
@export var pile_chances := Vector3(0.7, 0.25, 0.05)
## Chance relativa de cada valor de moeda por pilha (índices de Denomination:
## 1, 5, 10, 25, 50 centavos e R$ 1). Bairros mais ricos têm moedas mais valiosas.
@export var denomination_weights := PackedFloat32Array([1, 0, 0, 0, 0, 0])
## Altura dos prédios do bairro (m).
@export var building_height := Vector2(5, 10)
## Item da loja que libera o bairro (vazio = liberado desde o início).
@export var permit_id: StringName


## Sorteia o tamanho de uma pilha segundo o perfil.
func roll_pile_size(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf() * (pile_chances.x + pile_chances.y + pile_chances.z)
	var band := pile_small
	if roll >= pile_chances.x + pile_chances.y:
		band = pile_large
	elif roll >= pile_chances.x:
		band = pile_medium
	return rng.randi_range(band.x, band.y)


## Sorteia o valor (índice de Denomination) de uma pilha.
func roll_denomination(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight in denomination_weights:
		total += weight
	var roll := rng.randf() * total
	for i in denomination_weights.size():
		roll -= denomination_weights[i]
		if roll < 0.0:
			return i
	return 0
