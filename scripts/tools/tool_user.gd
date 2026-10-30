class_name ToolUser
extends Node3D
## Equipa as ferramentas possuídas e encaminha o botão de uso para a ferramenta atual.
## Fica preso à câmera; as cenas das ferramentas são instanciadas como filhas.
##
## Atalhos são por grupo (Mãos, Pá, Ímã...): cada grupo usa a variante escolhida no
## inventário (ou a melhor possuída). A ferramenta equipada recebe uma cópia da
## definição já com os bônus das melhorias.

signal equipped_changed(definition: ToolDefinition)

@export var camera: Camera3D
@export var body: CharacterBody3D

var equipped: GameTool
var _equipped_base: ToolDefinition


func _ready() -> void:
	GameState.tools_changed.connect(_on_tools_changed)
	GameState.stats_changed.connect(_on_stats_changed)
	GameState.tool_granted.connect(equip)
	equip_group(GameState.STARTING_ITEMS[0])


## Definição efetiva (com bônus) da ferramenta equipada.
func equipped_definition() -> ToolDefinition:
	return equipped.definition if equipped != null else null


## Grupos com alguma variante possuída, na ordem dos atalhos 1, 2, 3...
func slot_groups() -> Array[StringName]:
	var groups: Array[StringName] = []
	for group in ToolCatalog.get_default().groups():
		if GameState.tool_for_group(group) != null:
			groups.append(group)
	return groups


func equip_group(group: StringName) -> bool:
	var definition := GameState.tool_for_group(group)
	return definition != null and equip(definition.id)


func equip(id: StringName) -> bool:
	if equipped != null and equipped.busy:
		return false
	if _equipped_base != null and _equipped_base.id == id:
		return true
	var definition := ToolCatalog.get_default().find(id)
	if definition == null or definition.scene == null or not GameState.owns(id):
		return false
	if equipped != null:
		equipped.queue_free()
	_equipped_base = definition
	equipped = definition.scene.instantiate() as GameTool
	equipped.definition = GameState.effective_tool(definition)
	equipped.user = self
	add_child(equipped)
	equipped_changed.emit(equipped.definition)
	return true


## Usa a ferramenta equipada. Aguardável.
func use_equipped() -> bool:
	if equipped == null:
		return false
	return await equipped.try_use()


func get_hint() -> String:
	return equipped.get_hint() if equipped != null else ""


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if equipped != null and equipped.handle_input(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_tool"):
		use_equipped()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tool_next"):
		_cycle(1)
	elif event.is_action_pressed("tool_prev"):
		_cycle(-1)
	else:
		var groups := slot_groups()
		for slot in groups.size():
			var action := "tool_slot_%d" % (slot + 1)
			if InputMap.has_action(action) and event.is_action_pressed(action):
				equip_group(groups[slot])
				break


func _cycle(step: int) -> void:
	var groups := slot_groups()
	if groups.size() < 2 or _equipped_base == null:
		return
	var at := groups.find(_equipped_base.slot_group)
	equip_group(groups[posmod(at + step, groups.size())])


func _on_tools_changed() -> void:
	if _equipped_base == null or not GameState.owns(_equipped_base.id):
		_force_equip_group(GameState.STARTING_ITEMS[0])
		return
	# Troca de variante no inventário: equipa a escolhida se for do grupo atual.
	var wanted := GameState.tool_for_group(_equipped_base.slot_group)
	if wanted != null and wanted.id != _equipped_base.id:
		equip(wanted.id)


func _on_stats_changed() -> void:
	if equipped != null and _equipped_base != null:
		equipped.definition = GameState.effective_tool(_equipped_base)
		equipped_changed.emit(equipped.definition)


func _force_equip_group(group: StringName) -> void:
	if equipped != null:
		equipped.busy = false
	_equipped_base = null
	equip_group(group)
