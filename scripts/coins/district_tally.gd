class_name DistrictTally
extends RefCounted
## Quanto cada bairro tinha no começo e quanto já saiu dele (no bolso ou depositado), somando
## o estado salvo por bloco. Só refaz a soma quando algo saiu do mundo.

var _chunks_x := 0
var _chunk_district := PackedByteArray()
var _totals := PackedInt64Array()
var _removed := PackedInt64Array()
## Valor de GameState.world_removed_value quando _removed foi calculado.
var _removed_at := -1


func _init(chunks_x: int, chunk_district: PackedByteArray, totals: PackedInt64Array) -> void:
	_chunks_x = chunks_x
	_chunk_district = chunk_district
	_totals = totals


## Valor (centavos) que o bairro tinha no início do jogo.
func total(index: int) -> int:
	return _totals[index] if index >= 0 and index < _totals.size() else 0


## Valor (centavos) já retirado do bairro.
func removed(index: int) -> int:
	if _removed_at != GameState.world_removed_value:
		_recount()
	return _removed[index] if index >= 0 and index < _removed.size() else 0


## Fração recolhida do bairro, de 0 a 1.
func progress(index: int) -> float:
	var all := total(index)
	return float(removed(index)) / all if all > 0 else 1.0


@warning_ignore("integer_division")
func _recount() -> void:
	_removed.resize(_totals.size())
	_removed.fill(0)
	var chunks_z := _chunk_district.size() / _chunks_x
	for text in GameState.world_state:
		var parts := (text as String).split(",")
		if parts.size() != 2:
			continue
		var x := int(parts[0])
		var z := int(parts[1])
		if x >= 0 and z >= 0 and x < _chunks_x and z < chunks_z:
			_removed[_chunk_district[z * _chunks_x + x]] += int(GameState.world_state[text].get("v", 0))
	_removed_at = GameState.world_removed_value
