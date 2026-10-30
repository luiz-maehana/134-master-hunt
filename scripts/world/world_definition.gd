class_name WorldDefinition
extends Resource
## Parâmetros da cidade e do total de moedas. A cidade é uma grade retangular de quarteirões
## centrada na origem, comprida em x (oeste → leste): o Eixo Monumental de Brasília, da
## Rodoviária ao Congresso. As ruas passam nas bordas dos quarteirões; no gramado central
## (linhas `open_rows`) não há ruas, e as avenidas que o ladeiam são mais largas.

const DEFAULT_PATH := "res://data/world/city.tres"

static var _default: WorldDefinition

## Dinheiro total da cidade, em centavos (R$ 134.000.000,00).
@export var total_value_cents := 13_400_000_000
## Quarteirões em x (ao longo do eixo) e em z (ímpar, para haver uma linha central).
@export var blocks_x := 49
@export var blocks_z := 7
@export var block_size := 64.0
## Meia largura da rua (a rua passa centrada na borda entre dois quarteirões).
@export var road_half_width := 4.0
## Meia largura das avenidas do eixo (N1 e S1), dos dois lados do gramado central.
@export var avenue_half_width := 9.0
@export var sidewalk_width := 2.0
@export var curb_height := 0.12
## Linhas (z) do gramado central, sem ruas entre elas.
@export var open_rows := Vector2i(2, 4)
## A partir desta coluna (x) o gramado vira a Praça dos Três Poderes (piso de pedra).
@export var paved_from := 38
## Colunas (x) com os blocos dos ministérios nas linhas vizinhas ao gramado.
@export var ministry_columns := Vector2i(12, 26)
## Colunas (x) dos anexos do Congresso (lâminas mais baixas, no mesmo desenho dos ministérios).
@export var annex_columns := Vector2i(30, 32)
## Largura das vias N2 e S2 nas bordas norte e sul (o limite da área andável).
@export var outer_road_width := 10.0
## Lado dos blocos de dados/streaming das moedas. Deve dividir `block_size`.
@export var chunk_size := 16.0
@export var random_seed := 134
## Do mais pobre (o começo) ao mais rico. Cada quarteirão pertence ao primeiro bairro cuja
## área o contém; o último cobre o que sobrar.
@export var districts: Array[DistrictDefinition] = []


static func get_default() -> WorldDefinition:
	if _default == null:
		_default = load(DEFAULT_PATH)
	return _default


## Solta a referência estática (chamado ao encerrar, evita aviso de recurso em uso).
static func release_cache() -> void:
	_default = null


func world_size_x() -> float:
	return blocks_x * block_size


func world_size_z() -> float:
	return blocks_z * block_size


func chunks_x() -> int:
	return roundi(world_size_x() / chunk_size)


func chunks_z() -> int:
	return roundi(world_size_z() / chunk_size)


func find_district(id: StringName) -> DistrictDefinition:
	for district in districts:
		if district.id == id:
			return district
	return null
