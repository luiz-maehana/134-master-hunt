class_name CoinChunk
extends RefCounted
## Um bloco de moedas: as pilhas (posição, quantidade, valor) e, quando está perto do
## jogador, o desenho delas num MultiMesh. Gerado pelo ChunkGenerator; o CoinWorld decide
## quando ganha ou perde o desenho.

var key: Vector2i
var positions := PackedVector3Array()
var original := PackedByteArray()
var remaining := PackedByteArray()
var yaw := PackedFloat32Array()
## Valor de cada pilha (índice de Denomination).
var denom := PackedByteArray()
## 1 = de coroa (virada).
var flip := PackedByteArray()
## Pilhas por célula de busca (CoinWorld.CELL_SIZE).
var cells: Array[PackedInt32Array] = []
var multimesh: MultiMesh
## Cópia do buffer do MultiMesh (16 números por pilha), editada aqui e reenviada inteira.
var buffer := PackedFloat32Array()
var node: Node3D


## Cria o desenho dentro de `parent`, com a malha `mesh` (detalhe conforme a distância).
func build_visuals(parent: Node3D, mesh: Mesh) -> void:
	node = Node3D.new()
	node.name = "Chunk_%d_%d" % [key.x, key.y]
	node.top_level = true
	parent.add_child(node)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	var count := original.size()
	multimesh.instance_count = count
	if count == 0:
		return
	# Tudo de uma vez pelo buffer (12 números da transformação + 4 do dado customizado).
	buffer.resize(count * 16)
	for i in count:
		write_stack(i)
		buffer[i * 16 + 12] = denom[i] / 10.0
	multimesh.buffer = buffer
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(instance)


## Some com o desenho (os dados ficam).
func free_visuals() -> void:
	if node != null:
		node.queue_free()
	node = null
	multimesh = null


## Troca a malha (perto, meio ou longe), só se mudou.
func set_mesh(mesh: Mesh) -> void:
	if multimesh != null and multimesh.mesh != mesh:
		multimesh.mesh = mesh


## Reenvia o buffer inteiro (ver CoinWorld._update_visual).
func upload() -> void:
	if node != null:
		multimesh.buffer = buffer


## Grava a transformação da pilha no buffer do bloco (12 números; o dado customizado fica).
func write_stack(index: int) -> void:
	var xform := stack_transform(index)
	var b := xform.basis
	var o := index * 16
	buffer[o] = b.x.x; buffer[o + 1] = b.y.x; buffer[o + 2] = b.z.x; buffer[o + 3] = xform.origin.x
	buffer[o + 4] = b.x.y; buffer[o + 5] = b.y.y; buffer[o + 6] = b.z.y; buffer[o + 7] = xform.origin.y
	buffer[o + 8] = b.x.z; buffer[o + 9] = b.y.z; buffer[o + 10] = b.z.z; buffer[o + 11] = xform.origin.z


## Pilha de `remaining` moedas: altura cresce com a quantidade; o tamanho, com o valor.
func stack_transform(index: int) -> Transform3D:
	var amount := remaining[index]
	var pos := positions[index]
	if amount <= 0:
		return Transform3D(Basis().scaled(Vector3.ZERO), pos)
	var size := Denomination.scale_of(denom[index])
	var rot := Basis(Vector3.UP, yaw[index])
	if flip[index] == 1:
		rot = rot * Basis(Vector3.RIGHT, PI)
	var stack := Vector3(size, size * amount, size)
	return Transform3D(rot * Basis.from_scale(stack), pos + Vector3.UP * CoinVisuals.COIN_HEIGHT * stack.y * 0.5)


## Valor (centavos) das pilhas como estão agora.
func value_left() -> int:
	var total := 0
	for i in remaining.size():
		total += remaining[i] * Denomination.value_of(denom[i])
	return total


## Moedas (quantidade) das pilhas como estão agora.
func coins_left() -> int:
	var total := 0
	for amount in remaining:
		total += amount
	return total
