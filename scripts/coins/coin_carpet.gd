class_name CoinCarpet
extends RefCounted
## Longe do jogador, cada bloco com moedas vira um decalque de "tapete de moedas" no chão, mais
## forte quanto mais moedas restam. Só desenho: não dá para pegar nada dele.

var _world: CoinWorld
var _decals := {}   # Vector2i -> Decal


func _init(world: CoinWorld) -> void:
	_world = world


## Tapete nos blocos até `far` de `center`, fora dos desenhados (até `near` ou em `hot`).
func refresh(center: Vector2i, near: int, far: int, hot: Dictionary) -> void:
	for key: Vector2i in _decals.keys():
		if CoinWorld.chebyshev(key, center) > far or hot.has(key):
			remove(key)
	var size := _world.definition.chunk_size
	for dx in range(-far, far + 1):
		for dz in range(-far, far + 1):
			var key := center + Vector2i(dx, dz)
			if not _world.is_valid_key(key) or _decals.has(key) or CoinWorld.chebyshev(key, center) <= near:
				continue
			var remaining := _world.remaining_in(key)
			var area := _world.free_area_of(key)
			if remaining <= 0 or area <= 0.0:
				continue
			# Densidade aproximada em moedas (valor / moeda média de ~50 centavos).
			var density := remaining / 50.0 / area
			var decal := Decal.new()
			decal.size = Vector3(size, 3.0, size)
			decal.texture_albedo = CoinVisuals.carpet_texture()
			decal.modulate = Color(1, 1, 1, clampf(0.25 + 0.75 * log(1.0 + density) / log(301.0), 0.25, 1.0))
			decal.normal_fade = 0.6
			decal.cull_mask = 1
			var origin := _world.chunk_origin(key)
			decal.position = Vector3(origin.x + size * 0.5, 1.0, origin.y + size * 0.5)
			_world.add_child(decal)
			_decals[key] = decal


func remove(key: Vector2i) -> void:
	var decal: Decal = _decals.get(key)
	if decal != null:
		decal.queue_free()
	_decals.erase(key)
