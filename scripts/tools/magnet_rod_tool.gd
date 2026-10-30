extends GameTool
## Vara com ímã (pequena, média, grande): arremessa o ímã longe, atrai as moedas onde ele
## cai e as traz de volta ao recolher a linha.
##
## Ciclo: PRONTA → MIRANDO (segurar o clique: força e trajetória prevista; botão direito
## cancela) → VOANDO (arco com gravidade; paredes param o ímã) → NO CHÃO (atrai as moedas do
## raio, até a capacidade) → RECOLHENDO (clique ou R; o ímã volta até a ponta) → PRONTA.
##
## `reach` = distância máxima do arremesso; `area_radius` = raio de atração; `power` =
## velocidade das moedas até o ímã (m/s); `capacity` = máximo de moedas; `reel_speed` =
## velocidade do recolhimento (m/s); `use_time` = pausa depois que o ímã volta.
##
## Contagem única: cada moeda sai do mundo por CoinWorld.take() ao grudar no ímã e só entra
## no bolso quando o ímã volta. Nesse meio-tempo o save já a trata como "no bolso"
## (bolso = retirado do mundo − encontrado), então nada se perde nem é contado duas vezes.

enum State { READY, AIMING, FLYING, LANDED, REELING }

const GRAVITY := 14.0
const MIN_CHARGE := 0.3
## Tempo segurando o clique até a força máxima (s).
const CHARGE_TIME := 0.9
## Inclinação extra para cima: olhando reto, o ímã já sai em arco.
const LIFT := 0.35
const MAX_FLIGHT_TIME := 6.0
## Comprimento máximo da linha, em múltiplos do alcance da vara.
const LINE_SLACK := 1.25
const PREVIEW_STEP := 1.0 / 20.0
## Pilhas de até 10 moedas: a vara grande (15.000) precisa de ~1.800 pilhas.
const MAX_CANDIDATES := 4000
## Verificações de linha de visão (ímã → célula de busca) por arremesso, as mais próximas primeiro.
const MAX_SIGHT_CHECKS := 120
## Inclinação da vara em repouso (para cima e um pouco para o centro da tela).
const REST_ROTATION := Vector3(0.2, 0.02, 0.0)
const COLOR_LINE := Color(0.08, 0.08, 0.08)
const COLOR_AIM := Color(1.0, 0.85, 0.2, 0.75)
const COLOR_ATTRACT := Color(0.35, 0.75, 1.0, 0.8)
const COLOR_BLOCKED := Color(1.0, 0.25, 0.2, 0.8)

var state := State.READY
## Força do arremesso (MIN_CHARGE a 1).
var charge := 0.0
## Moedas grudadas no ímã: já fora do mundo, ainda fora do bolso.
var held := 0
## Valor (centavos) das moedas grudadas.
var held_value := 0
var magnet_position := Vector3.ZERO
## O ímã caiu num bairro sem licença (ou fora da cidade): não atrai nada.
var landed_blocked := false

var _velocity := Vector3.ZERO
var _launch := Vector3.ZERO
var _flight_time := 0.0
var _budget := 0
## Pilhas que vão grudar, em ordem de chegada: {key, index, amount, position, distance, at}.
var _pending: Array[Dictionary] = []
var _attract_time := 0.0
var _reel_from := Vector3.ZERO
var _reel_progress := 0.0
var _reel_length := 1.0
var _aim_from_mouse := false
var _swing := 0.0
var _time := 0.0

@onready var _rod: Node3D = $Rod
@onready var _tip: Node3D = $Rod/Tip
@onready var _magnet: Node3D = $Magnet
@onready var _stuck: MultiMeshInstance3D = $Magnet/Stuck
@onready var _line: MeshInstance3D = $Line
@onready var _preview: MeshInstance3D = $Preview
@onready var _ring: MeshInstance3D = $Ring


func _ready() -> void:
	_rod.rotation = REST_ROTATION
	_magnet.scale = Vector3.ONE * definition.visual_scale
	_tint_rod()
	for node in [_line, _preview, _ring]:
		(node as Node3D).global_transform = Transform3D.IDENTITY
	_line.mesh = ImmediateMesh.new()
	_line.material_override = RodLine.flat_material(COLOR_LINE)
	_preview.mesh = ImmediateMesh.new()
	_preview.material_override = RodLine.flat_material(COLOR_AIM)
	var ring := TorusMesh.new()
	ring.outer_radius = definition.area_radius
	ring.inner_radius = maxf(definition.area_radius - 0.08, 0.01)
	ring.rings = 48
	ring.ring_segments = 4
	_ring.mesh = ring
	_ring.material_override = RodLine.flat_material(COLOR_AIM)
	RodCoinEffects.build_stuck(_stuck)
	_hang_magnet()


func _process(delta: float) -> void:
	_time += delta
	match state:
		State.READY:
			_hang_magnet()
		State.AIMING:
			if _aim_from_mouse and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				cancel_aim()
			else:
				charge = minf(charge + delta * (1.0 - MIN_CHARGE) / CHARGE_TIME, 1.0)
				_hang_magnet()
				_update_preview()
		State.LANDED:
			_attract(delta)
			_check_line_length()
			var pulse := 1.0 + 0.04 * sin(_time * 6.0)
			_ring.scale = Vector3(pulse, 1.0, pulse)
		State.REELING:
			_reel_step(delta)
	_pose_rod(delta)
	_draw_line()


## A linha tem comprimento máximo: se o jogador se afasta do ímã além dele, a vara recolhe
## sozinha (o que já grudou vem junto).
func _check_line_length() -> void:
	if _tip.global_position.distance_to(magnet_position) > definition.reach * LINE_SLACK:
		GameState.notify("A linha esticou até o fim: recolhendo o ímã.")
		reel()


func _physics_process(delta: float) -> void:
	if state == State.FLYING:
		_fly_step(delta)


# --- Controles --------------------------------------------------------------------------

## Pinta o corpo da vara (parte laranja do modelo) com a cor da variante.
func _tint_rod() -> void:
	for node in $Rod/Model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			if material != null and material.resource_name == "Red":
				var tinted := material.duplicate() as StandardMaterial3D
				tinted.albedo_color = definition.tint
				(node as MeshInstance3D).set_surface_override_material(surface, tinted)


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("use_tool"):
		if state == State.READY:
			begin_aim(true)
		elif state == State.FLYING or state == State.LANDED:
			reel()
		return true
	if event.is_action_released("use_tool"):
		if state == State.AIMING:
			throw()
		return true
	if event.is_action_pressed("reel_line"):
		return reel()
	if event.is_action_pressed("tool_cancel") and state == State.AIMING:
		cancel_aim()
		return true
	return false


## Clique simples (sem segurar): arremessa com força total, ou recolhe se o ímã está fora.
func try_use() -> bool:
	match state:
		State.READY:
			return throw(1.0)
		State.AIMING:
			return throw()
		State.FLYING, State.LANDED:
			return reel()
	return false


func can_use() -> bool:
	return state != State.REELING and not (state == State.READY and busy)


func begin_aim(from_mouse := false) -> bool:
	if state != State.READY or busy:
		return false
	state = State.AIMING
	charge = MIN_CHARGE
	_aim_from_mouse = from_mouse
	_preview.visible = true
	_ring.visible = true
	return true


func cancel_aim() -> void:
	if state != State.AIMING:
		return
	state = State.READY
	_clear_preview()


## Arremessa o ímã. `power_` < 0 usa a força acumulada na mira.
func throw(power_ := -1.0) -> bool:
	if busy or (state != State.READY and state != State.AIMING):
		return false
	if power_ >= 0.0:
		charge = clampf(power_, MIN_CHARGE, 1.0)
	charge = maxf(charge, MIN_CHARGE)
	_clear_preview()
	busy = true
	_launch = _launch_origin()
	magnet_position = _launch
	_velocity = launch_velocity(charge)
	_flight_time = 0.0
	held = 0
	held_value = 0
	landed_blocked = false
	Sfx.play(&"whoosh", 0.08, -3.0)
	_swing = 1.0
	state = State.FLYING
	return true


## Recolhe a linha (em voo ou no chão). Moedas que ainda não grudaram ficam onde estão.
func reel() -> bool:
	if state != State.FLYING and state != State.LANDED:
		return false
	_pending.clear()
	_ring.visible = false
	_reel_from = magnet_position
	_reel_progress = 0.0
	Sfx.play(&"click", 0.05, -6.0)
	_reel_length = maxf(_reel_from.distance_to(_tip.global_position), 0.5)
	state = State.REELING
	return true


func get_hint() -> String:
	match state:
		State.READY:
			if busy:
				return ""
			if GameState.ledger.free_capacity() == 0:
				return "Bolsos cheios! Deposite no ponto de coleta"
			return "[Segure %s] Mirar · solte para arremessar" % InputBindings.label_of(&"use_tool")
		State.AIMING:
			return "Força %d%% · solte para arremessar · [%s] cancelar" % [roundi(charge * 100.0), InputBindings.label_of(&"tool_cancel")]
		State.FLYING:
			return "[%s] Recolher a linha" % _reel_keys()
		State.LANDED:
			if landed_blocked:
				return "Bairro sem licença: o ímã não atrai nada · [%s] Recolher" % _reel_keys()
			if not _pending.is_empty() and held < _budget:
				return "Atraindo… %s · [%s] Recolher" % [_coins_text(held), _reel_keys()]
			if held > 0:
				return "Ímã carregado: %s · [%s] Recolher" % [_coins_text(held), _reel_keys()]
			if _budget == 0:
				return "Bolsos cheios! · [%s] Recolher" % _reel_keys()
			return "Nada por aqui · [%s] Recolher" % _reel_keys()
		State.REELING:
			return "Recolhendo… %s" % _coins_text(held)
	return ""


## Teclas que recolhem a linha (usar ferramenta ou a tecla própria).
static func _reel_keys() -> String:
	return "%s / %s" % [InputBindings.label_of(&"use_tool"), InputBindings.label_of(&"reel_line")]


# --- Trajetória -------------------------------------------------------------------------

## Velocidade inicial para a força dada: a distância cresce com a força e nunca passa de `reach`.
func launch_velocity(power_: float) -> Vector3:
	var direction := (-user.camera.global_basis.z + Vector3.UP * LIFT).normalized()
	return direction * sqrt(GRAVITY * definition.reach * power_)


## Pontos da trajetória prevista (o último é onde o ímã vai parar).
func predict(power_: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var origin := _launch_origin()
	var pos := origin
	var vel := launch_velocity(power_)
	points.append(pos)
	var t := 0.0
	while t < MAX_FLIGHT_TIME:
		var step := _advance(origin, pos, vel, PREVIEW_STEP)
		pos = step.position
		vel = step.velocity
		points.append(pos)
		if step.landed:
			break
		t += PREVIEW_STEP
	return points


## Um passo do voo: gravidade, limite de distância e colisão com chão e paredes (camada 1).
func _advance(origin: Vector3, pos: Vector3, vel: Vector3, dt: float) -> Dictionary:
	vel.y -= GRAVITY * dt
	var next := pos + vel * dt
	var flat := Vector2(next.x - origin.x, next.z - origin.z)
	if flat.length() > definition.reach:
		# Fim da linha: o ímã para de avançar e cai.
		flat = flat.normalized() * definition.reach
		next.x = origin.x + flat.x
		next.z = origin.z + flat.y
		vel.x = 0.0
		vel.z = 0.0
	var query := PhysicsRayQueryParameters3D.create(pos, next, 1, [user.body.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"position": next, "velocity": vel, "landed": false}
	var normal: Vector3 = hit.normal
	if normal.y > 0.6:
		return {"position": hit.position, "velocity": Vector3.ZERO, "landed": true}
	# Parede (ou teto): o ímã bate e cai rente a ela.
	var back: Vector3 = hit.position + normal * 0.12
	return {"position": back, "velocity": Vector3(0.0, minf(vel.y, 0.0), 0.0), "landed": false}


func _fly_step(delta: float) -> void:
	_flight_time += delta
	var step := _advance(_launch, magnet_position, _velocity, delta)
	magnet_position = step.position
	_velocity = step.velocity
	_magnet.global_position = magnet_position
	_magnet.rotation.x += delta * 6.0
	if step.landed:
		_land(magnet_position)
	elif _flight_time > MAX_FLIGHT_TIME or magnet_position.y < -5.0:
		_land(_ground_below(magnet_position))


## Ponto de saída: a ponta da vara, ou antes dela se houver parede no caminho.
func _launch_origin() -> Vector3:
	var from := user.camera.global_position
	var tip := _tip.global_position
	var query := PhysicsRayQueryParameters3D.create(from, tip, 1, [user.body.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return tip
	return (hit.position as Vector3) + (hit.normal as Vector3) * 0.1


func _ground_below(pos: Vector3) -> Vector3:
	var layout: CityLayout = CoinWorld.current.layout if CoinWorld.current != null else null
	return Vector3(pos.x, layout.ground_height(pos.x, pos.z) if layout != null else 0.0, pos.z)


# --- Atração ----------------------------------------------------------------------------

func _land(pos: Vector3) -> void:
	magnet_position = pos
	_magnet.global_position = pos
	_magnet.rotation = Vector3.ZERO
	Sfx.play(&"clink1", 0.1, -4.0)
	state = State.LANDED
	_attract_time = 0.0
	_pending.clear()
	_budget = mini(definition.capacity, GameState.ledger.free_capacity())
	var world := CoinWorld.current
	landed_blocked = world == null or not _district_open(world.layout, pos)
	_ring.global_position = pos + Vector3.UP * 0.03
	_ring.scale = Vector3.ONE
	(_ring.material_override as StandardMaterial3D).albedo_color = COLOR_BLOCKED if landed_blocked else COLOR_ATTRACT
	_ring.visible = true
	if landed_blocked or _budget <= 0:
		return
	var planned := 0
	# Linha de visão do ímã uma vez por célula (até a primeira pilha vista nela).
	var sight := {}
	for candidate in world.find_near(pos, definition.area_radius, MAX_CANDIDATES, _budget * 2):
		var cell: Vector3i = candidate.cell
		if not sight.has(cell):
			if sight.size() >= MAX_SIGHT_CHECKS:
				break
			sight[cell] = _clear_between(pos + Vector3.UP * 0.3, (candidate.position as Vector3) + Vector3.UP * 0.05)
		if not sight[cell]:
			continue
		candidate.at = float(candidate.distance) / maxf(definition.power, 0.1)
		_pending.append(candidate)
		planned += int(candidate.amount)
		if planned >= _budget:
			break
	RodCoinEffects.fly(user.body.get_parent(), _pending, _magnet)


## Moedas chegam ao ímã na ordem da distância; cada uma sai do mundo ao grudar.
func _attract(delta: float) -> void:
	_attract_time += delta
	while not _pending.is_empty() and float(_pending[0].at) <= _attract_time:
		var target: Dictionary = _pending.pop_front()
		var room := _budget - held
		if room <= 0 or CoinWorld.current == null:
			_pending.clear()
			break
		var got := CoinWorld.current.take(target.key, target.index, room)
		if got > 0:
			held += got
			held_value += got * int(target.value)
			RodCoinEffects.set_fill(_stuck, held, _budget)


func _district_open(layout: CityLayout, pos: Vector3) -> bool:
	if layout == null or not layout.is_inside(pos.x, pos.z):
		return false
	var district := layout.district_at(pos.x, pos.z)
	return district != null and GameState.is_district_unlocked(district)


func _clear_between(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [user.body.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# --- Recolhimento -----------------------------------------------------------------------

func _reel_step(delta: float) -> void:
	_reel_progress = minf(_reel_progress + definition.reel_speed * delta / _reel_length, 1.0)
	# Volta em arco para não arrastar pelo chão; acompanha o jogador se ele andar.
	var lift := sin(_reel_progress * PI) * minf(_reel_length * 0.12, 3.0)
	magnet_position = _reel_from.lerp(_hang_point(), _reel_progress) + Vector3.UP * lift
	_magnet.global_position = magnet_position
	if _reel_progress >= 1.0:
		_finish()


func _finish() -> void:
	state = State.READY
	_hang_magnet()
	# Só a vara põe moedas no bolso enquanto ela está fora, e o orçamento já respeitou o
	# espaço livre no arremesso: tudo o que grudou cabe.
	var delivered := mini(held, GameState.ledger.free_capacity())
	if delivered > 0:
		GameState.add_carried(delivered, held_value if delivered == held else -1)
	else:
		GameState.notify("A vara voltou vazia.")
	held = 0
	held_value = 0
	RodCoinEffects.set_fill(_stuck, held, _budget)
	var pop := create_tween()
	pop.tween_property(_magnet, "scale", Vector3.ONE * definition.visual_scale * 1.35, 0.08)
	pop.tween_property(_magnet, "scale", Vector3.ONE * definition.visual_scale, 0.18)
	await get_tree().create_timer(definition.use_time, false).timeout
	busy = false
	used.emit()


# --- Visual -----------------------------------------------------------------------------

func _hang_point() -> Vector3:
	return _tip.global_position + Vector3.DOWN * 0.1 * definition.visual_scale


func _hang_magnet() -> void:
	magnet_position = _hang_point()
	_magnet.global_position = magnet_position
	_magnet.rotation = Vector3.ZERO


func _pose_rod(delta: float) -> void:
	var pitch := 0.0
	match state:
		State.AIMING:
			pitch = 0.4 * charge       # puxa a vara para trás
		State.FLYING:
			pitch = -0.3
		State.LANDED:
			pitch = -0.02 - 0.08 * clampf(float(held) / maxf(_budget, 1), 0.0, 1.0)
		State.REELING:
			pitch = -0.1 + 0.03 * sin(_time * 40.0)
	_swing = move_toward(_swing, 0.0, delta * 4.0)
	var target := REST_ROTATION + Vector3(pitch - 0.5 * _swing, 0.0, 0.0)
	_rod.rotation = _rod.rotation.lerp(target, minf(delta * 14.0, 1.0))


func _draw_line() -> void:
	var points := RodLine.sag_points(_tip.global_position, magnet_position, 0.03 if state == State.LANDED else 0.01)
	RodLine.ribbon(_line.mesh as ImmediateMesh, points, false, user.camera.global_position)


func _update_preview() -> void:
	var points := predict(charge)
	RodLine.ribbon(_preview.mesh as ImmediateMesh, points, true, user.camera.global_position)
	var landing := points[points.size() - 1]
	_ring.global_position = landing + Vector3.UP * 0.03
	_ring.scale = Vector3.ONE
	var open := CoinWorld.current != null and _district_open(CoinWorld.current.layout, landing)
	(_ring.material_override as StandardMaterial3D).albedo_color = COLOR_AIM if open else COLOR_BLOCKED


func _clear_preview() -> void:
	(_preview.mesh as ImmediateMesh).clear_surfaces()
	_ring.visible = false


static func _coins_text(amount: int) -> String:
	return MoneyFormat.coins(amount)
