class_name Interactable
extends Node
## Componente que torna interativo o corpo físico pai (StaticBody3D, RigidBody3D, Area3D...).
##
## Não depende de nenhum modelo 3D: trocar o visual do objeto não afeta a interação.
## Outros sistemas (coleta, economia, inventário) reagem ao sinal `interacted`.

signal interacted(by: Node)

## Texto exibido no prompt de interação.
@export var prompt_text := "Interagir"
@export var enabled := true
## Remove o objeto pai da cena após a interação (útil para coletáveis simples).
@export var free_parent_on_interact := false


func interact(by: Node) -> void:
	if not enabled:
		return
	interacted.emit(by)
	if free_parent_on_interact:
		get_parent().queue_free()


## Retorna o Interactable filho direto de `node`, ou null.
static func find_on(node: Object) -> Interactable:
	if not node is Node:
		return null
	for child in (node as Node).get_children():
		if child is Interactable:
			return child
	return null
