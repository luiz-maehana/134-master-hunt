class_name Denomination
extends RefCounted
## Os seis valores de moeda do real. Índice 0..5 = 1, 5, 10, 25, 50 centavos e R$ 1.
## Cada pilha do mundo tem um único valor; o bolso conta moedas e o dinheiro conta o valor.

const VALUES: Array[int] = [1, 5, 10, 25, 50, 100]
const NAMES: Array[String] = ["1 centavo", "5 centavos", "10 centavos", "25 centavos", "50 centavos", "1 real"]
## Tamanho relativo: a de R$ 1 tem o tamanho da moeda original; as menores encolhem.
const SCALES: Array[float] = [0.55, 0.64, 0.72, 0.8, 0.9, 1.0]
## Cores de cada valor (usadas pelo shader se o atlas for desligado).
## Miolo e anel/borda (a de R$ 1 é bimetálica).
const FACE_COLORS: Array[Color] = [
	Color(0.80, 0.47, 0.30), Color(0.78, 0.50, 0.32), Color(0.80, 0.52, 0.36),
	Color(0.88, 0.70, 0.36), Color(0.80, 0.81, 0.83), Color(0.82, 0.83, 0.85)]
const RING_COLORS: Array[Color] = [
	Color(0.80, 0.47, 0.30), Color(0.78, 0.50, 0.32), Color(0.80, 0.52, 0.36),
	Color(0.88, 0.70, 0.36), Color(0.80, 0.81, 0.83), Color(0.90, 0.72, 0.35)]


static func count() -> int:
	return VALUES.size()


static func value_of(index: int) -> int:
	return VALUES[clampi(index, 0, VALUES.size() - 1)]


static func scale_of(index: int) -> float:
	return SCALES[clampi(index, 0, SCALES.size() - 1)]


## Valor médio (centavos por moeda) para pesos por pilha.
static func average_value(weights: PackedFloat32Array) -> float:
	var total := 0.0
	var value := 0.0
	for i in mini(weights.size(), VALUES.size()):
		total += weights[i]
		value += weights[i] * VALUES[i]
	return value / total if total > 0.0 else 1.0
