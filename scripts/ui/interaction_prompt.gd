extends Label
## Mostra "[Tecla] ação" quando o Interactor está mirando algo interativo.

@export var interactor: Interactor

var _target: Interactable


func _ready() -> void:
	visible = false
	if interactor != null:
		interactor.focus_changed.connect(_on_focus_changed)


func _process(_delta: float) -> void:
	# O texto pode mudar enquanto o alvo está em foco (ex.: "Depositar 12 moedas").
	if visible and is_instance_valid(_target):
		_update_text()


func _on_focus_changed(interactable: Interactable) -> void:
	_target = interactable
	visible = interactable != null
	if interactable != null:
		_update_text()


func _update_text() -> void:
	text = "[%s] %s" % [_action_key_label(interactor.interact_action), _target.prompt_text]


static func _action_key_label(action: StringName) -> String:
	return InputBindings.label_of(action)
