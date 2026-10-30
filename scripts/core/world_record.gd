class_name WorldRecord
extends RefCounted
## O que já saiu do mundo de moedas, por bloco e no total. Puro (sem nós), salvo com a partida.
##
## entries: "cx,cz" -> {"r": moedas retiradas do bloco, "v": valor retirado (centavos),
## "rem": PackedByteArray com o restante de cada pilha (255 = intocada)}.

## Limite de pilhas por bloco aceito de um save (proteção contra arquivo adulterado).
const MAX_PILES_PER_CHUNK := 65536
## Valor de "rem" para pilha que nunca foi tocada.
const UNTOUCHED := 255

var entries := {}
## Moedas retiradas no total (soma de todos os "r").
var removed := 0
## Valor (centavos) retirado no total (soma de todos os "v").
var removed_value := 0


static func key_text(key: Vector2i) -> String:
	return "%d,%d" % [key.x, key.y]


func entry(key: Vector2i) -> Dictionary:
	return entries.get(key_text(key), {})


## Registra uma retirada. `value` < 0 = 1 centavo por moeda; `pile_count` = pilhas do bloco.
func record_take(key: Vector2i, index: int, remaining: int, amount: int, value := -1, pile_count := 0) -> void:
	if value < 0:
		value = amount
	var text := key_text(key)
	var item: Dictionary = entries.get(text, {})
	if item.is_empty():
		item = {"r": 0, "v": 0, "rem": PackedByteArray()}
		entries[text] = item
	item.r = int(item.r) + amount
	item.v = int(item.get("v", 0)) + value
	var rem: PackedByteArray = item.get("rem", PackedByteArray())
	var size := maxi(pile_count, index + 1)
	if rem.size() < size:
		var old := rem.size()
		rem.resize(size)
		for i in range(old, size):
			rem[i] = UNTOUCHED
	rem[index] = remaining
	item.rem = rem
	removed += amount
	removed_value += value


## Formato do save: o restante das pilhas vai comprimido (zstd) e em base64.
func to_save() -> Dictionary:
	var result := {}
	for text in entries:
		var item: Dictionary = entries[text]
		var rem: PackedByteArray = item.get("rem", PackedByteArray())
		result[text] = {"r": int(item.r), "v": int(item.get("v", 0)), "n": rem.size(), "b": encode_piles(rem)}
	return result


## Lê o formato do save, descartando blocos inválidos. Substitui o conteúdo atual.
func load_save(raw: Variant) -> void:
	entries = {}
	removed = 0
	removed_value = 0
	if not raw is Dictionary:
		return
	for text in raw:
		var parts := str(text).split(",")
		var item: Variant = raw[text]
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not item is Dictionary:
			continue
		var rem := decode_piles(item.get("n"), item.get("b"))
		if rem.is_empty():
			continue
		var coins := SaveSerializer.non_negative_int(item.get("r"))
		var value := SaveSerializer.non_negative_int(item.get("v", coins))
		entries["%d,%d" % [int(parts[0]), int(parts[1])]] = {"r": coins, "v": value, "rem": rem}
		removed += coins
		removed_value += value


static func encode_piles(rem: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(rem.compress(FileAccess.COMPRESSION_ZSTD))


## Inválido (tamanho errado, valores impossíveis, base64 quebrado) = vazio.
static func decode_piles(raw_count: Variant, raw_data: Variant) -> PackedByteArray:
	var count := SaveSerializer.non_negative_int(raw_count)
	if count <= 0 or count > MAX_PILES_PER_CHUNK or not raw_data is String:
		return PackedByteArray()
	var packed := Marshalls.base64_to_raw(raw_data)
	if packed.is_empty():
		return PackedByteArray()
	var rem := packed.decompress(count, FileAccess.COMPRESSION_ZSTD)
	if rem.size() != count:
		return PackedByteArray()
	for value in rem:
		if value > CoinWorld.MAX_STACK and value != UNTOUCHED:
			return PackedByteArray()
	return rem
