class_name RodCoinEffects
extends RefCounted
## Efeitos de moeda da vara com ímã (só visuais; a contagem é feita pela vara):
## moedas grudadas embaixo do ímã, que aparecem conforme ele enche, e moedas voando das
## pilhas até o ímã.

const STUCK_VISUALS := 24
const MAX_FLYING := 30


## Prepara o MultiMesh das moedas grudadas (posições fixas embaixo e dos lados do ímã).
static func build_stuck(stuck: MultiMeshInstance3D) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = CoinVisuals.shared_mesh()
	multimesh.instance_count = STUCK_VISUALS
	var rng := RandomNumberGenerator.new()
	rng.seed = 134
	for i in STUCK_VISUALS:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(0.0, 0.07)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.9, 0.9), rng.randf() * TAU, rng.randf_range(-0.9, 0.9)))
		var origin := Vector3(cos(angle) * radius, rng.randf_range(-0.012, 0.02), sin(angle) * radius)
		multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * 0.45), origin))
	multimesh.visible_instance_count = 0
	stuck.multimesh = multimesh
	stuck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Mostra moedas grudadas proporcionais a `held` de `budget` (pelo menos uma se houver alguma).
static func set_fill(stuck: MultiMeshInstance3D, held: int, budget: int) -> void:
	var fill := 0 if held <= 0 else clampi(ceili(STUCK_VISUALS * float(held) / maxf(budget, 1)), 1, STUCK_VISUALS)
	stuck.multimesh.visible_instance_count = fill


## Moedas voando de cada alvo (itens com position, denomination e at = duração) até o ímã
## `magnet` (que pode se mexer). Se o ímã sumir, as moedas somem junto (CoinFlight).
static func fly(world: Node, targets: Array[Dictionary], magnet: Node3D) -> void:
	for i in mini(targets.size(), MAX_FLYING):
		var item := targets[i]
		CoinFlight.launch(world, item.position, magnet, int(item.denomination), float(item.at), 0.4)
