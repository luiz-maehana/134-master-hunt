class_name DirectionArrow
extends Control
## Seta de bússola: aponta para um alvo em relação para onde o jogador está olhando.
## `angle` = 0 aponta para cima (em frente); positivo gira no sentido horário (à direita).

@export var color := Color(0.45, 1.0, 0.55)

var angle := 0.0:
	set(value):
		angle = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Ângulo de `target` visto de `body` (só no plano).
static func bearing(body: Node3D, target: Vector3) -> float:
	var local := body.global_basis.inverse() * (target - body.global_position)
	return atan2(local.x, -local.z)


func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var points := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, r * 0.75), Vector2(0, r * 0.35), Vector2(-r * 0.7, r * 0.75)])
	var rotated := PackedVector2Array()
	for p in points:
		rotated.append(center + p.rotated(angle))
	draw_colored_polygon(rotated, color)
	draw_polyline(rotated + PackedVector2Array([rotated[0]]), Color(0, 0, 0, 0.6), 2.0, true)
