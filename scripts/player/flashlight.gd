class_name Flashlight
extends SpotLight3D
## Lanterna presa à câmera. Alcance e abertura vêm da melhor lanterna comprada
## (GameState.flashlight_range). Liga e desliga com a ação "flashlight"; acende sozinha
## quando anoitece e apaga quando amanhece (o jogador pode mudar depois).

var _night := false


func _ready() -> void:
	light_color = Color(1, 0.95, 0.85)
	light_energy = 4.0
	spot_attenuation = 0.8
	shadow_enabled = true
	position = Vector3(0.15, -0.1, 0)
	visible = false
	GameState.stats_changed.connect(_apply_stats)
	_apply_stats()


func _apply_stats() -> void:
	var range_ := GameState.flashlight_range
	spot_range = range_
	# Lanternas melhores abrem mais o facho.
	spot_angle = clampf(20.0 + range_ * 0.5, 22.0, 40.0)
	if range_ <= 0.0:
		visible = false


func _process(_delta: float) -> void:
	var cycle := DayNight.current
	var night := cycle != null and cycle.is_night()
	if night != _night:
		_night = night
		visible = night and GameState.flashlight_range > 0.0
	# Sombra da lanterna só na qualidade alta (é a luz mais cara da cena).
	shadow_enabled = Settings.quality_index >= 2
	_update_coin_glint(cycle)


## O shader das moedas faz as que estão no facho brilharem (mais quanto mais escuro).
func _update_coin_glint(cycle: DayNight) -> void:
	var material := CoinVisuals.shared_mesh().surface_get_material(0) as ShaderMaterial
	if material == null:
		return
	var darkness := 1.0 - cycle.daylight if cycle != null else 0.0
	var glint := darkness if is_visible_in_tree() else 0.0
	material.set_shader_parameter(&"flash_glint", glint)
	if glint <= 0.0:
		return
	material.set_shader_parameter(&"flash_pos", global_position)
	material.set_shader_parameter(&"flash_dir", -global_basis.z)
	material.set_shader_parameter(&"flash_cos", cos(deg_to_rad(spot_angle)))
	material.set_shader_parameter(&"flash_range", spot_range)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"flashlight") and GameState.flashlight_range > 0.0:
		visible = not visible
		Sfx.play(&"click", 0.05, -8.0)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# O material das moedas é compartilhado: não deixa o brilho ligado sem lanterna.
	var material := CoinVisuals.shared_mesh().surface_get_material(0) as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"flash_glint", 0.0)
