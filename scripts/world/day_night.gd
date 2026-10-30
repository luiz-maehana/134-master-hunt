class_name DayNight
extends Node
## Ciclo de dia e noite: move o sol (e a lua), muda céu, névoa e luz ambiente, acende as
## janelas dos prédios e os postes. A hora fica em GameState.time_of_day (salva).
##
## 0 = meia-noite, 0.25 = nascer do sol, 0.5 = meio-dia, 0.75 = pôr do sol. Um dia inteiro
## dura CYCLE_SECONDS; a noite escura ocupa ~30% dele.

const CYCLE_SECONDS := 1200.0
## Luzes de verdade só nos postes mais perto do jogador (o resto só brilha).
const LAMP_LIGHTS := 8
## Luz ambiente mínima à noite na web (sem as luzes dos postes e da lanterna).
const WEB_NIGHT_AMBIENT := 0.45
const LAMP_UPDATE := 0.4
## A hora é aplicada a céu e luzes só a cada APPLY_INTERVAL: mudar o céu refaz o reflexo dele,
## que é caro; num dia de 20 min a diferença entre duas aplicações é invisível.
const APPLY_INTERVAL := 0.5
## Ponto da cabeça do poste no modelo light-curved (antes da escala).
const LAMP_HEAD := Vector3(0, 0.64, -0.18)

const SKY_DAY := Color(0.22, 0.42, 0.78)
const SKY_NIGHT := Color(0.015, 0.025, 0.07)
const HORIZON_DAY := Color(0.86, 0.8, 0.7)
const HORIZON_DUSK := Color(0.95, 0.55, 0.32)
const HORIZON_NIGHT := Color(0.05, 0.06, 0.11)
const SUN_DAY := Color(1, 0.93, 0.8)
const SUN_LOW := Color(1, 0.6, 0.35)
const MOON := Color(0.55, 0.65, 1.0)

static var current: DayNight

## Pausa o relógio (testes, capturas).
var frozen := false
## 1 = dia claro, 0 = noite.
var daylight := 1.0

var _sun: DirectionalLight3D
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _building_material: ShaderMaterial
var _glow_material: StandardMaterial3D
var _lamp_heads := PackedVector3Array()
var _lights: Array[OmniLight3D] = []
var _lamp_timer := 0.0
var _apply_timer := 0.0
var _was_night := false


## `lamps`: transformações dos postes (para achar a cabeça de cada um).
func setup(sun: DirectionalLight3D, environment: Environment, building_material: ShaderMaterial, lamps: Array[Transform3D]) -> void:
	_sun = sun
	_environment = environment
	_sky = environment.sky.sky_material as ProceduralSkyMaterial if environment.sky != null else null
	_building_material = building_material
	if environment.sky != null:
		# Reflexo do céu refeito aos poucos, em vários quadros, em vez de tudo de uma vez.
		environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	for lamp in lamps:
		_lamp_heads.append(lamp * LAMP_HEAD)


func _ready() -> void:
	current = self
	_build_lamp_glow()
	# Na web as luzes dos postes ficam só no brilho das lâmpadas: cada luz nova no WebGL obriga a
	# compilar shaders de tudo na tela (trava de segundos). Lá a noite é um pouco mais clara.
	for i in 0 if WebPlatform.active() else LAMP_LIGHTS:
		var light := OmniLight3D.new()
		light.light_color = Color(1, 0.82, 0.55)
		light.light_energy = 2.2
		light.omni_range = 16.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)
	_was_night = is_night()
	apply()


func _exit_tree() -> void:
	if current == self:
		current = null


func _process(delta: float) -> void:
	if not frozen:
		GameState.time_of_day = fposmod(GameState.time_of_day + delta / CYCLE_SECONDS, 1.0)
	_apply_timer -= delta
	if _apply_timer <= 0.0:
		_apply_timer = APPLY_INTERVAL
		apply()
	_lamp_timer -= delta
	if _lamp_timer <= 0.0:
		_lamp_timer = LAMP_UPDATE
		_place_lamp_lights()
	var night := is_night()
	if night != _was_night:
		_was_night = night
		if night:
			GameState.notify("Anoiteceu. %s" % ("As moedas brilham no facho da lanterna (%s)." % InputBindings.label_of(&"flashlight")
				if GameState.flashlight_range > 0.0 else "Uma lanterna da Ferragem faz as moedas brilharem no escuro."))
		else:
			GameState.notify("Amanheceu!")


func is_night() -> bool:
	return daylight < 0.35


## "18:40"
static func clock_text() -> String:
	var minutes := int(GameState.time_of_day * 24.0 * 60.0)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## Aplica a hora atual a luzes, céu e materiais.
func apply() -> void:
	var t := GameState.time_of_day
	var elevation := sin((t - 0.25) * TAU)
	daylight = smoothstep(-0.12, 0.18, elevation)
	var dusk := clampf(1.0 - absf(elevation) / 0.25, 0.0, 1.0)
	var night := 1.0 - daylight
	if _sun != null:
		# De dia, o sol; de noite, a lua do lado oposto, fraca e azulada.
		var azimuth := t * TAU
		var height := elevation if elevation > -0.05 else -elevation
		height = maxf(height, 0.08)
		var direction := Vector3(cos(azimuth) * cos(asin(height)), height, sin(azimuth) * cos(asin(height)))
		_sun.global_basis = Basis.looking_at(-direction, Vector3.UP)
		if elevation > -0.05:
			_sun.light_color = SUN_LOW.lerp(SUN_DAY, smoothstep(0.0, 0.35, elevation))
			_sun.light_energy = 1.25 * daylight
		else:
			_sun.light_color = MOON
			_sun.light_energy = 0.22 * night
	if _sky != null:
		_sky.sky_top_color = SKY_NIGHT.lerp(SKY_DAY, daylight)
		var horizon := HORIZON_NIGHT.lerp(HORIZON_DAY, daylight).lerp(HORIZON_DUSK, dusk * 0.7)
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = horizon
		_sky.sky_energy_multiplier = lerpf(0.35, 1.0, daylight)
	if _environment != null:
		_environment.ambient_light_energy = lerpf(WEB_NIGHT_AMBIENT if WebPlatform.active() else 0.28, 1.0, daylight)
		_environment.fog_light_color = HORIZON_NIGHT.lerp(Color(0.84, 0.8, 0.74), daylight)
	if _building_material != null:
		_building_material.set_shader_parameter(&"night", night)
	if _glow_material != null:
		_glow_material.emission_energy_multiplier = 4.0 * night
		_glow_material.albedo_color = Color(1, 0.9, 0.7).lerp(Color(0.6, 0.6, 0.6), daylight)
	# Moedas: no escuro brilham menos sozinhas e refletem mais (o facho da lanterna "acende" elas).
	var coins := CoinVisuals.shared_mesh().surface_get_material(0) as ShaderMaterial
	if coins != null:
		coins.set_shader_parameter(&"self_glow", lerpf(0.015, 0.06, daylight))
		coins.set_shader_parameter(&"roughness", lerpf(0.25, 0.45, daylight))


func _build_lamp_glow() -> void:
	if _lamp_heads.is_empty():
		return
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.4
	mesh.radial_segments = 10
	mesh.rings = 4
	_glow_material = StandardMaterial3D.new()
	_glow_material.emission_enabled = true
	_glow_material.emission = Color(1, 0.8, 0.5)
	mesh.material = _glow_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = _lamp_heads.size()
	for i in _lamp_heads.size():
		multimesh.set_instance_transform(i, Transform3D(Basis(), _lamp_heads[i] - Vector3.UP * 0.12))
	var instance := MultiMeshInstance3D.new()
	instance.name = "LampGlow"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## Põe as luzes de verdade nos postes mais perto da câmera (só de noite).
func _place_lamp_lights() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var on := daylight < 0.6 and camera != null
	if not on:
		for light in _lights:
			light.visible = false
		return
	var from := camera.global_position
	var order: Array = []
	for i in _lamp_heads.size():
		order.append([_lamp_heads[i].distance_squared_to(from), i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in _lights.size():
		var light := _lights[k]
		light.visible = k < order.size()
		if light.visible:
			light.global_position = _lamp_heads[order[k][1]] - Vector3.UP * 0.3
			light.light_energy = 2.2 * (1.0 - daylight)
