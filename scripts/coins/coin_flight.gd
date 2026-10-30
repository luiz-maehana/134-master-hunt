class_name CoinFlight
extends MeshInstance3D
## Moeda voando até um alvo (ímã, vara): só efeito visual, a contagem já foi feita. Anda sozinha
## e sempre se apaga no fim, mesmo que o alvo suma no meio do caminho (ex.: o jogador trocou de
## ferramenta e o ímã foi recriado). Antes, a animação dependia da ferramenta e, se ela sumisse,
## a moeda ficava parada no ar para sempre.

var _start := Vector3.ZERO
var _target: Node3D
var _duration := 0.3
var _arc := 0.25
var _time := 0.0


## Lança uma moeda de valor `denomination` de `from` até `target` em `duration` segundos.
static func launch(parent: Node, from: Vector3, target: Node3D, denomination: int, duration: float, arc := 0.25) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var coin := CoinFlight.new()
	coin.mesh = CoinVisuals.shared_mesh()
	coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	CoinVisuals.set_denomination(coin, denomination)
	coin._start = from
	coin._target = target
	coin._duration = maxf(duration, 0.05)
	coin._arc = arc
	parent.add_child(coin)
	coin.global_position = from


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		queue_free()
		return
	var t := minf(_time / _duration, 1.0)
	var eased := t * t   # acelera chegando no ímã
	global_position = _start.lerp(_target.global_position, eased) + Vector3.UP * sin(eased * PI) * _arc
	rotation.y += 0.4
	if t >= 1.0:
		queue_free()
