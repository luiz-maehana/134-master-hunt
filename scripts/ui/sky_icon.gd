class_name SkyIcon
extends Control
## Ícone do relógio do HUD, desenhado em código: sol amarelo com raios de dia, sol laranja
## baixo (meio escondido) no amanhecer e no pôr do sol, e lua crescente com estrelas à noite.

enum Phase { DAY, DUSK, NIGHT }

const SUN := Color(1, 0.82, 0.25)
const DUSK_SUN := Color(1, 0.55, 0.25)
const MOON := Color(0.85, 0.9, 1.0)

var phase := Phase.DAY:
	set(value):
		if value != phase:
			phase = value
			queue_redraw()


## Fase pela hora do dia (0 = meia-noite, 0.5 = meio-dia).
static func phase_at(time_of_day: float) -> Phase:
	if time_of_day < 0.22 or time_of_day >= 0.8:
		return Phase.NIGHT
	if time_of_day < 0.3 or time_of_day >= 0.72:
		return Phase.DUSK
	return Phase.DAY


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	match phase:
		Phase.DAY:
			for i in 8:
				var direction := Vector2.RIGHT.rotated(TAU * i / 8.0)
				draw_line(center + direction * radius * 0.62, center + direction * radius * 0.95, SUN, 2.5, true)
			draw_circle(center, radius * 0.45, SUN)
		Phase.DUSK:
			# Sol baixo cortado pela linha do horizonte.
			var horizon := center.y + radius * 0.25
			for i in range(-2, 3):
				var direction := Vector2.UP.rotated(i * 0.6)
				var base := Vector2(center.x, horizon)
				draw_line(base + direction * radius * 0.62, base + direction * radius * 0.92, DUSK_SUN, 2.5, true)
			draw_arc(Vector2(center.x, horizon), radius * 0.45, PI, TAU, 16, DUSK_SUN, radius * 0.9 * 0.5)
			draw_line(Vector2(center.x - radius, horizon), Vector2(center.x + radius, horizon), DUSK_SUN, 2.0, true)
		Phase.NIGHT:
			# Lua crescente: disco claro com um disco da cor do fundo deslocado por cima.
			draw_circle(center, radius * 0.6, MOON)
			draw_circle(center + Vector2(radius * 0.32, -radius * 0.2), radius * 0.5, Color(0.07, 0.08, 0.1))
			for star: Vector2 in [Vector2(0.7, -0.65), Vector2(0.85, 0.2), Vector2(0.45, 0.75)]:
				draw_circle(center + star * radius, 1.5, MOON)
