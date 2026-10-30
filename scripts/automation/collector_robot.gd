class_name CollectorRobot
extends Node3D
## Um robô de coleta no mapa. Trabalha num raio ao redor do ponto onde foi posicionado
## (`home`): recolhe `rate` moedas por segundo da pilha mais próxima, depois da seguinte, até
## a área ficar limpa. Funciona também longe do jogador (blocos frios do CoinWorld).
##
## A contagem é feita por CoinWorld.take(); o robô só devolve quantas moedas tirou para a
## frota entregar (GameState.collect_direct). O movimento até as pilhas é só visual.

const RESCAN_SECONDS := 4.0

## Buscas de pilhas permitidas neste quadro (a frota repõe a cada quadro).
static var scan_budget := 1

var definition: RobotDefinition
var home := Vector2.ZERO
var collected := 0
## Valor (centavos) do que tirou na última chamada de work().
var last_value := 0
## Área limpa: nada mais ao alcance (o jogador precisa trazê-lo para outro lugar).
var idle := false

var _work := 0.0
var _targets: Array[Vector3i] = []
var _rescan := 0.0
var _beacon_material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	_build_model()
	# Motor do aspirador, ouvido só por perto.
	var hum := AudioStreamPlayer3D.new()
	hum.stream = Sfx.hum_stream()
	hum.volume_db = -14.0
	hum.unit_size = 3.0
	hum.max_distance = 30.0
	hum.pitch_scale = randf_range(0.9, 1.1)
	hum.autoplay = true
	add_child(hum)


## Trabalha `delta` segundos com o multiplicador das melhorias. Retorna as moedas tiradas;
## o valor delas (centavos) fica em `last_value`.
func work(delta: float, multiplier: float) -> int:
	last_value = 0
	var world := CoinWorld.current
	if world == null:
		return 0
	if idle and not _wake_up(world, delta):
		return 0
	# Esperando a vez de procurar, o trabalho não acumula mais que ~1 s.
	_work = minf(_work + definition.rate * multiplier * delta, definition.rate * multiplier + 1.0)
	var want := int(_work)
	if want <= 0:
		return 0
	var got := 0
	while want > 0:
		if _targets.is_empty():
			# Procurar gera blocos frios; um robô por quadro, para não engasgar.
			if scan_budget <= 0:
				break
			scan_budget -= 1
			_targets = world.scan_around(_home3(), definition.radius)
			if _targets.is_empty() and world.last_scan_incomplete:
				break   # faltou orçamento para gerar blocos: tenta no próximo quadro
			if _targets.is_empty():
				idle = true
				_work = 0.0
				_rescan = RESCAN_SECONDS
				break
		var target := _targets[0]
		var taken := world.take(Vector2i(target.x, target.y), target.z, want)
		last_value += taken * world.value_of_pile(Vector2i(target.x, target.y), target.z)
		if taken < want:
			_targets.pop_front()
		got += taken
		want -= taken
		_work -= taken
	collected += got
	return got


## Robô parado: de tempos em tempos procura pilhas de novo (um robô por quadro). true = achou.
func _wake_up(world: CoinWorld, delta: float) -> bool:
	_rescan -= delta
	if _rescan > 0.0 or scan_budget <= 0:
		return false
	scan_budget -= 1
	_rescan = RESCAN_SECONDS
	_targets = world.scan_around(_home3(), definition.radius)
	if _targets.is_empty():
		if world.last_scan_incomplete:
			_rescan = 0.1   # bloco ainda sendo gerado: tenta logo
		return false
	idle = false
	return true


## Novo ponto de trabalho (o robô aparece lá e recomeça a procurar).
func relocate(pos: Vector2) -> void:
	home = pos
	_targets.clear()
	idle = false
	_rescan = 0.0
	global_position = _ground(pos)


func _process(delta: float) -> void:
	_time += delta
	# Anda até a pilha atual; parado, só pisca vermelho.
	if not idle and not _targets.is_empty() and CoinWorld.current != null:
		var target := _targets[0]
		var goal := CoinWorld.current.pile_position(Vector2i(target.x, target.y), target.z)
		var flat := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
		var distance := flat.length()
		if distance > 0.6:
			var step := minf(definition.move_speed * delta, distance - 0.5)
			global_position = _ground(Vector2(global_position.x, global_position.z) + Vector2(flat.x, flat.z) / distance * step)
			rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(delta * 6.0, 1.0))
	var on := fmod(_time, 1.0) < (0.5 if idle else 0.25)
	_beacon_material.emission_energy_multiplier = 3.0 if on else 0.2
	_beacon_material.emission = Color(1, 0.2, 0.15) if idle else Color(1, 0.7, 0.1)
	if not idle:
		for child in get_children():
			if child.has_meta("brush"):
				(child as Node3D).rotation.y += delta * 18.0 * float(child.get_meta("brush"))


func _home3() -> Vector3:
	return _ground(home)


func _ground(pos: Vector2) -> Vector3:
	var layout: CityLayout = CoinWorld.current.layout if CoinWorld.current != null else null
	return Vector3(pos.x, layout.ground_height(pos.x, pos.y) if layout != null else 0.0, pos.y)


## Aspirador robô: disco baixo com para-choque, tampa colorida, sensor no topo, botão que
## pisca (amarelo trabalhando, vermelho parado) e duas escovinhas laterais que giram.
func _build_model() -> void:
	var s := definition.visual_scale
	add_child(_disc(0.36 * s, 0.07 * s, 0.045 * s, Color(0.16, 0.17, 0.19)))          # base / para-choque
	add_child(_disc(0.34 * s, 0.03 * s, 0.095 * s, definition.body_color))           # tampa
	add_child(_disc(0.2 * s, 0.006 * s, 0.112 * s, definition.body_color.darkened(0.25)))
	add_child(_disc(0.07 * s, 0.035 * s, 0.13 * s, Color(0.1, 0.1, 0.12), Vector3(0, 0, 0.16 * s)))   # sensor
	var button := _disc(0.045 * s, 0.012 * s, 0.118 * s, Color(1, 0.7, 0.1), Vector3(0, 0, -0.12 * s))
	_beacon_material = button.mesh.material as StandardMaterial3D
	_beacon_material.emission_enabled = true
	add_child(button)
	for side in [-1.0, 1.0]:
		var brush := _disc(0.09 * s, 0.004 * s, 0.006 * s, Color(0.25, 0.25, 0.28), Vector3(side * 0.24 * s, 0, -0.26 * s))
		brush.set_meta("brush", side)
		add_child(brush)


static func _disc(radius: float, height: float, y: float, color: Color, offset := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	mesh.material = _material(color)
	node.mesh = mesh
	node.position = Vector3(offset.x, y, offset.z)
	return node


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material
