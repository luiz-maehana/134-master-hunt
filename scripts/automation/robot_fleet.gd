class_name RobotFleet
extends Node3D
## Mantém um CollectorRobot no mapa para cada robô em GameState.robots, faz todos
## trabalharem e entrega o que recolheram (direto como "encontradas", sem passar pelo
## bolso) a cada DELIVERY_SECONDS, para não atualizar a economia a cada quadro.

const DELIVERY_SECONDS := 0.5
## Distância à frente do jogador onde aparece um robô novo (ou trazido para perto).
const PLACE_AHEAD := 3.0

static var current: RobotFleet

@export var player: Node3D

var _robots: Array[CollectorRobot] = []
var _pending := 0
var _pending_value := 0
var _delivery := 0.0
var _rate_window := 0
var _rate_time := 0.0
## Moedas por minuto (média dos últimos segundos), para o HUD.
var coins_per_minute := 0.0


func _ready() -> void:
	current = self
	GameState.robots_changed.connect(sync)
	# Depois do Main posicionar o jogador (robôs novos aparecem perto dele).
	sync.call_deferred()


func _exit_tree() -> void:
	_deliver()
	if current == self:
		current = null


func robot(index: int) -> CollectorRobot:
	return _robots[index] if index >= 0 and index < _robots.size() else null


func count() -> int:
	return _robots.size()


func idle_count() -> int:
	return _robots.filter(func(r: CollectorRobot) -> bool: return r.idle).size()


## Leva o robô para perto do jogador (e ele recomeça ali).
func bring_here(index: int) -> void:
	if player != null:
		GameState.move_robot(index, _spot_near_player())


## Recria/atualiza os robôs para bater com GameState.robots.
func sync() -> void:
	var entries := GameState.robots
	while _robots.size() > entries.size():
		_robots.pop_back().queue_free()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var definition := ShopCatalog.get_default().find(entry.id) as RobotDefinition
		if definition == null:
			continue
		if not (entry.pos as Vector2).is_finite():
			entry.pos = _spot_near_player()
		var node: CollectorRobot = _robots[i] if i < _robots.size() else null
		if node != null and node.definition != definition:
			node.queue_free()
			_robots.remove_at(i)
			node = null
		if node == null:
			node = CollectorRobot.new()
			node.definition = definition
			node.name = "Robot%d" % i
			add_child(node)
			_robots.insert(i, node)
			node.relocate(entry.pos)
		elif node.home != entry.pos:
			node.relocate(entry.pos)


func _physics_process(delta: float) -> void:
	var multiplier := GameState.robot_speed_multiplier
	CollectorRobot.scan_budget = 1
	if CoinWorld.current != null:
		CoinWorld.current.cold_budget = 1
	var got := 0
	for node in _robots:
		var was_idle := node.idle
		got += node.work(delta, multiplier)
		_pending_value += node.last_value
		if node.idle and not was_idle:
			GameState.notify("%s limpou a área. Traga para outro lugar (%s)." % [node.definition.display_name, InputBindings.label_of(&"inventory")])
	_pending += got
	_rate_window += got
	_rate_time += delta
	if _rate_time >= 3.0:
		coins_per_minute = _rate_window / _rate_time * 60.0
		_rate_window = 0
		_rate_time = 0.0
	_delivery -= delta
	if _delivery <= 0.0:
		_delivery = DELIVERY_SECONDS
		_deliver()


func _deliver() -> void:
	if _pending > 0:
		GameState.collect_direct(_pending, _pending_value)
		_pending = 0
		_pending_value = 0


func _spot_near_player() -> Vector2:
	if player == null:
		return Vector2.ZERO
	var ahead := player.global_position - player.global_basis.z * PLACE_AHEAD
	var layout: CityLayout = CoinWorld.current.layout if CoinWorld.current != null else null
	if layout != null and not layout.is_free(ahead.x, ahead.z):
		ahead = player.global_position
	return Vector2(ahead.x, ahead.z)
