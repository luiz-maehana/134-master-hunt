class_name Flashlight
extends SpotLight3D
## Lanterna presa à câmera. Alcance e abertura vêm da melhor lanterna comprada
## (GameState.flashlight_range). Liga e desliga com a ação "flashlight"; acende sozinha
## quando anoitece e apaga quando amanhece (o jogador pode mudar depois).
##
## Na web a luz em si fica apagada: cada luz nova no WebGL obriga a compilar variações de
## shader de todos os materiais na tela (segundos de trava). Lá a lanterna "ligada" mantém o
## que importa para jogar: as moedas brilhando no facho (shader das moedas) e a mancha de luz
## no chão (shader do chão da web, web_ground.gdshader).

## Ligada pelo jogador (ou pela noite). A luz só aparece fora da web.
var on := false:
	set(value):
		on = value
		visible = value and not WebPlatform.active()
		if _held != null:
			_held.visible = value
## Onde a lanterna fica na tela (relativo à câmera): embaixo, à esquerda.
const HELD_AT := Vector3(-0.24, -0.2, -0.5)

var _night := false
## Lanterna na mão esquerda (embaixo, à esquerda da tela), visível quando ligada.
var _held: Node3D


func _ready() -> void:
	light_color = Color(1, 0.95, 0.85)
	light_energy = 4.0
	spot_attenuation = 0.8
	shadow_enabled = true
	# A luz sai da ponta da lanterna da mão esquerda.
	position = HELD_AT + Vector3(0, 0, -0.14)
	_build_held.call_deferred()
	on = false
	GameState.stats_changed.connect(_apply_stats)
	_apply_stats()


## Lanterna e mão esquerda em peças simples, presas à câmera. Materiais de shaders que o
## aquecimento da web já compila (cor lisa e o da linha da vara): ligar não trava.
func _build_held() -> void:
	_held = Node3D.new()
	_held.name = "HeldFlashlight"
	_held.position = HELD_AT
	# Levemente virada para o centro da tela, como quem aponta para frente.
	_held.rotation = Vector3(0.08, -0.12, 0.25)
	_held.scale = Vector3.ONE * 0.8
	get_parent().add_child(_held)
	var metal := _held_material(Color(0.16, 0.17, 0.19))
	var trim := _held_material(Color(0.95, 0.72, 0.15))
	var hand := _held_material(Color(0.86, 0.64, 0.5))
	_held_part(_cylinder(0.02, 0.02, 0.16), Vector3(0, 0, 0.02), metal)
	_held_part(_cylinder(0.032, 0.022, 0.05), Vector3(0, 0, -0.08), metal)
	_held_part(_cylinder(0.034, 0.034, 0.012), Vector3(0, 0, -0.1), trim)
	_held_part(_cylinder(0.029, 0.029, 0.006), Vector3(0, 0, -0.107), RodLine.flat_material(Color(1, 0.96, 0.8)))
	var palm := MeshInstance3D.new()
	palm.mesh = BoxMesh.new()
	(palm.mesh as BoxMesh).size = Vector3(0.075, 0.05, 0.09)
	palm.material_override = hand
	palm.position = Vector3(-0.01, -0.012, 0.04)
	palm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.add_child(palm)
	var thumb := MeshInstance3D.new()
	thumb.mesh = BoxMesh.new()
	(thumb.mesh as BoxMesh).size = Vector3(0.02, 0.02, 0.05)
	thumb.material_override = hand
	thumb.position = Vector3(0.03, 0.022, 0.015)
	thumb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.add_child(thumb)
	_held.visible = on


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return mesh


## Cilindro deitado ao longo de z (a ponta da lanterna fica em -z, para onde a câmera olha).
func _held_part(mesh: Mesh, at: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation.x = PI * 0.5
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.add_child(part)


static func _held_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material


func _apply_stats() -> void:
	var range_ := GameState.flashlight_range
	spot_range = range_
	# Lanternas melhores abrem mais o facho.
	spot_angle = clampf(20.0 + range_ * 0.5, 22.0, 40.0)
	if range_ <= 0.0:
		on = false


func _process(_delta: float) -> void:
	var cycle := DayNight.current
	var night := cycle != null and cycle.is_night()
	if night != _night:
		_night = night
		on = night and GameState.flashlight_range > 0.0
	# Sombra da lanterna só na qualidade alta (é a luz mais cara da cena).
	shadow_enabled = Settings.quality_index >= 2
	_update_coin_glint(cycle)


## O shader das moedas faz as que estão no facho brilharem (mais quanto mais escuro).
func _update_coin_glint(cycle: DayNight) -> void:
	var material := CoinVisuals.shared_mesh().surface_get_material(0) as ShaderMaterial
	if material == null:
		return
	var darkness := 1.0 - cycle.daylight if cycle != null else 0.0
	var glint := darkness if on and is_inside_tree() else 0.0
	material.set_shader_parameter(&"flash_glint", glint)
	if WebPlatform.active():
		_update_web_ground(glint)
	if glint <= 0.0:
		return
	material.set_shader_parameter(&"flash_pos", global_position)
	material.set_shader_parameter(&"flash_dir", -global_basis.z)
	material.set_shader_parameter(&"flash_cos", cos(deg_to_rad(spot_angle)))
	material.set_shader_parameter(&"flash_range", spot_range)


## Web: a mancha de luz no chão (web_ground.gdshader), já que lá não há luz de verdade.
func _update_web_ground(strength: float) -> void:
	RenderingServer.global_shader_parameter_set(&"flash_light", strength)
	if strength <= 0.0:
		return
	RenderingServer.global_shader_parameter_set(&"flash_light_pos", global_position)
	RenderingServer.global_shader_parameter_set(&"flash_light_dir", -global_basis.z)
	RenderingServer.global_shader_parameter_set(&"flash_light_cos", cos(deg_to_rad(spot_angle)))
	RenderingServer.global_shader_parameter_set(&"flash_light_range", spot_range)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"flashlight") and GameState.flashlight_range > 0.0:
		on = not on
		Sfx.play(&"click", 0.05, -8.0)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# O material das moedas é compartilhado: não deixa o brilho ligado sem lanterna.
	var material := CoinVisuals.shared_mesh().surface_get_material(0) as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"flash_glint", 0.0)
