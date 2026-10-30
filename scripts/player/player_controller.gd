class_name PlayerController
extends "res://addons/basic_fps_controller/scripts/fps_controller.gd"
## Estende o controlador do addon (sem modificá-lo) com:
## - aceleração e desaceleração (o original muda a velocidade instantaneamente);
## - sensibilidade do mouse vinda de Settings e velocidade vinda das melhorias (GameState);
## - captura do mouse compatível com o menu de pausa (Esc é tratado pelo PauseMenu).

@export_group("Acceleration")
@export var ground_acceleration := 30.0
@export var ground_deceleration := 40.0
@export var air_acceleration := 6.0

## Distância entre dois passos (m), andando.
const STEP_LENGTH := 1.6

var _base_h_sensitivity := 0.0
var _base_v_sensitivity := 0.0
var _base_walk_speed := 0.0
var _base_sprint_speed := 0.0
var _step_distance := 0.0


func _ready() -> void:
	super()
	_base_h_sensitivity = horizontal_mouse_sensitivity
	_base_v_sensitivity = vertical_mouse_sensitivity
	_base_walk_speed = walk_speed
	_base_sprint_speed = sprint_speed
	Settings.changed.connect(_apply_settings)
	GameState.stats_changed.connect(_apply_stats)
	_apply_stats()
	_apply_settings()


func _unhandled_input(event: InputEvent) -> void:
	# Com uma tela aberta o mouse é dela (o jogo continua rodando por trás).
	if GameState.screen_open:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# O clique que recaptura o mouse não deve usar a ferramenta.
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		super(event)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var controls := not GameState.screen_open
	if controls and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if controls else Vector2.ZERO
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var sprinting := controls and sprint_enabled and Input.is_action_pressed("sprint")
	var target := direction * (sprint_speed if sprinting else walk_speed)

	var rate := air_acceleration
	if is_on_floor():
		rate = ground_acceleration if direction != Vector3.ZERO else ground_deceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	move_and_slide()
	_step_sounds(horizontal.length(), delta)

	info_label.visible = debug
	if debug:
		info_label.text = "fps: %d\nspeed: %.2f\npos: %s" % [
			Engine.get_frames_per_second(), horizontal.length(), global_position.snapped(Vector3.ONE * 0.01)]


## Passos: um a cada STEP_LENGTH metros andados no chão (correndo, o passo é mais longo).
func _step_sounds(speed: float, delta: float) -> void:
	if not is_on_floor() or speed < 0.5:
		_step_distance = 0.0
		return
	_step_distance += speed * delta
	var length := STEP_LENGTH * (1.35 if speed > walk_speed * 1.2 else 1.0)
	if _step_distance >= length:
		_step_distance -= length
		Sfx.play(&"step", 0.12, -16.0)


func _apply_settings() -> void:
	horizontal_mouse_sensitivity = _base_h_sensitivity * Settings.mouse_sensitivity
	vertical_mouse_sensitivity = _base_v_sensitivity * Settings.mouse_sensitivity
	var camera := get_node_or_null(^"Head/Camera3D") as Camera3D
	if camera != null:
		camera.fov = Settings.fov


func _apply_stats() -> void:
	walk_speed = _base_walk_speed * GameState.move_speed_multiplier
	sprint_speed = _base_sprint_speed * GameState.move_speed_multiplier
