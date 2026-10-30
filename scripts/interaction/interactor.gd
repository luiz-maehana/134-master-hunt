class_name Interactor
extends RayCast3D
## Raio a partir da câmera que detecta o Interactable sob a mira.

signal focus_changed(interactable: Interactable)

@export var interact_action: StringName = &"interact"

var current: Interactable


func _ready() -> void:
	if owner is CollisionObject3D:
		add_exception(owner)


func _physics_process(_delta: float) -> void:
	var found: Interactable = null
	if is_colliding():
		found = Interactable.find_on(get_collider())
		if found != null and not found.enabled:
			found = null
	_set_current(found)


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.screen_open and event.is_action_pressed(interact_action) and try_interact():
		get_viewport().set_input_as_handled()


## Interage com o objeto em foco. Retorna true se havia um alvo.
func try_interact() -> bool:
	if current == null or not is_instance_valid(current):
		_set_current(null)
		return false
	current.interact(owner)
	return true


func _set_current(value: Interactable) -> void:
	if value == current:
		return
	if is_instance_valid(current) and current.tree_exiting.is_connected(_on_current_exiting):
		current.tree_exiting.disconnect(_on_current_exiting)
	current = value
	# Um alvo removido da cena (ex.: moeda coletada) limpa o foco imediatamente.
	if current != null:
		current.tree_exiting.connect(_on_current_exiting)
	focus_changed.emit(current)


func _on_current_exiting() -> void:
	_set_current(null)
