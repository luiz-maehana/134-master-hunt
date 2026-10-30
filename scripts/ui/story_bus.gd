class_name StoryBus
extends Control
## Animação da história (StoryScreen): a Esplanada ao entardecer (Congresso, Catedral, ministérios,
## torre de TV, mastro da bandeira) e um ônibus passando com o bagageiro aberto, deixando cair
## moedas que quicam e ficam brilhando no chão. Outro ônibus passa de tempos em tempos (as moedas
## se acumulam). Tudo desenhado na hora: sem texturas nem shaders novos (na web não há o que compilar).

## Espaço do desenho: 300 unidades de altura, escalado pela altura do controle; a largura acompanha.
const HEIGHT := 300.0
const HORIZON := 190.0
## Topo e base da pista.
const ROAD := Vector2(236.0, 272.0)
## Faixa onde as moedas caem (na frente do ônibus, da pista ao gramado).
const COIN_GROUND := Vector2(266.0, 294.0)
const COIN_RADIUS := 5.5
const BUS_LENGTH := 150.0
## Base da carroceria do ônibus.
const BUS_BASE := 262.0
const WHEEL_RADIUS := 9.0
const FIRST_PASS := 0.8
const PASS_SECONDS := 6.5
const LOOP_SECONDS := 10.0
## Fração da travessia em que o bagageiro abre.
const HATCH_FROM := 0.18
const COINS_PER_SECOND := 45.0
const MAX_COINS := 420
const GRAVITY := 900.0
## [face, borda]: dourada, prateada e acobreada.
const COIN_COLORS := [
	[Color(0.98, 0.78, 0.25), Color(0.72, 0.5, 0.1)],
	[Color(0.88, 0.89, 0.92), Color(0.52, 0.53, 0.6)],
	[Color(0.92, 0.56, 0.3), Color(0.58, 0.3, 0.14)],
]
const SKY_TOP := Color(0.11, 0.13, 0.3)
const SKY_LOW := Color(0.98, 0.62, 0.36)
const SUN := Color(1.0, 0.84, 0.5)
const SILHOUETTE := Color(0.15, 0.15, 0.25)
const WINDOW_LIT := Color(1.0, 0.85, 0.45)
const LAWN_FAR := Color(0.2, 0.4, 0.18)
const LAWN_NEAR := Color(0.36, 0.58, 0.28)
const ASPHALT := Color(0.2, 0.2, 0.24)

class Coin:
	var pos: Vector2
	var vel: Vector2
	var ground: float
	var spin: float
	var spin_speed: float
	var colors: int
	var phase: float
	var resting := false
	var fade := 1.0

## Sem sons (avanço rápido das capturas de tela).
var muted := false
var _time := 0.0
var _width := 0.0
## Frente esquerda do ônibus em unidades do desenho; NAN quando não há ônibus na tela.
var _bus_x := NAN
var _hatch := 0.0
var _last_pass := -1
var _hatch_sounded := false
var _emit := 0.0
var _clink_wait := 0.0
var _coins: Array[Coin] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 134


func _process(delta: float) -> void:
	_step(delta)
	queue_redraw()


## Avança a animação sem tocar sons (para capturas de tela e testes).
func fast_forward(seconds: float) -> void:
	muted = true
	for i in roundi(seconds * 60.0):
		_step(1.0 / 60.0)
	muted = false
	queue_redraw()


func coin_count() -> int:
	return _coins.size()


func _step(delta: float) -> void:
	if size.y <= 0.0:
		return
	_width = size.x / (size.y / HEIGHT)
	_time += delta
	_clink_wait -= delta
	_drive(delta)
	_move_coins(delta)


func _drive(delta: float) -> void:
	var since := _time - FIRST_PASS
	_bus_x = NAN
	if since < 0.0:
		return
	var pass_index := floori(since / LOOP_SECONDS)
	var progress := (since - pass_index * LOOP_SECONDS) / PASS_SECONDS
	if progress >= 1.0:
		_hatch = 0.0
		return
	if pass_index != _last_pass:
		_last_pass = pass_index
		_hatch_sounded = false
		_play(&"whoosh", -10.0)
	var travel := _width + BUS_LENGTH + 40.0
	_bus_x = -BUS_LENGTH - 20.0 + progress * travel
	_hatch = clampf((progress - HATCH_FROM) * PASS_SECONDS / 0.15, 0.0, 1.0)
	if _hatch <= 0.0:
		return
	if not _hatch_sounded:
		_hatch_sounded = true
		_play(&"pour", -8.0)
	var speed := travel / PASS_SECONDS
	_emit += COINS_PER_SECOND * delta
	while _emit >= 1.0:
		_emit -= 1.0
		var coin := Coin.new()
		coin.pos = Vector2(_bus_x + 78.0 + _rng.randf_range(-14.0, 14.0), BUS_BASE - 2.0)
		coin.vel = Vector2(speed * _rng.randf_range(0.2, 0.6), _rng.randf_range(-220.0, -60.0))
		coin.ground = _rng.randf_range(COIN_GROUND.x, COIN_GROUND.y)
		coin.spin = _rng.randf() * TAU
		coin.spin_speed = _rng.randf_range(8.0, 20.0)
		coin.colors = _rng.randi() % COIN_COLORS.size()
		coin.phase = _rng.randf() * TAU
		_coins.append(coin)


func _move_coins(delta: float) -> void:
	for coin in _coins:
		if coin.resting:
			continue
		coin.vel.y += GRAVITY * delta
		coin.pos += coin.vel * delta
		coin.spin += coin.spin_speed * delta
		if coin.pos.y >= coin.ground and coin.vel.y > 0.0:
			coin.pos.y = coin.ground
			if coin.vel.y > 90.0:
				coin.vel *= Vector2(0.55, -0.38)
				coin.spin_speed *= 0.6
				_clink()
			else:
				coin.resting = true
	# Muitas moedas: as mais antigas somem devagar.
	for i in mini(_coins.size() - MAX_COINS, _coins.size()):
		_coins[i].fade -= delta * 1.5
	while not _coins.is_empty() and _coins[0].fade <= 0.0:
		_coins.pop_front()


func _clink() -> void:
	if _clink_wait > 0.0 or _rng.randf() > 0.35:
		return
	_clink_wait = 0.06
	_play(StringName("clink%d" % (_rng.randi() % 4)), -16.0)


func _play(sound: StringName, db: float) -> void:
	if not muted and is_visible_in_tree():
		Sfx.play(sound, 0.08, db)


func _draw() -> void:
	if size.y <= 0.0 or _width <= 0.0:
		return
	var s := size.y / HEIGHT
	var center := _width * 0.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	_draw_sky(center)
	_draw_skyline(center)
	_draw_ground()
	if not is_nan(_bus_x):
		_draw_bus(_bus_x)
	for coin in _coins:
		_draw_coin(coin, s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.GOLD_FAINT, false, 2.0)


## Elipse cheia em unidades do desenho.
func _oval(at: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 16:
		var angle := TAU * step / 16.0
		points.append(at + Vector2(cos(angle), sin(angle)) * radii)
	draw_colored_polygon(points, color)


func _draw_sky(center: float) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(_width, 0), Vector2(_width, HORIZON), Vector2(0, HORIZON)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	draw_circle(Vector2(center + 170.0, HORIZON - 22.0), 46.0, Color(SUN, 0.2))
	draw_circle(Vector2(center + 170.0, HORIZON - 22.0), 30.0, SUN)
	for i in 4:
		var x := fposmod(i * 310.0 + _time * (6.0 + i * 2.0), _width + 200.0) - 100.0
		_oval(Vector2(x, 36.0 + i * 22.0), Vector2(38.0, 9.0), Color(1.0, 0.85, 0.8, 0.3))


func _draw_skyline(center: float) -> void:
	# Torre de TV.
	var tower := center - 420.0
	draw_line(Vector2(tower, HORIZON), Vector2(tower, 60.0), SILHOUETTE, 4.0)
	draw_line(Vector2(tower, 60.0), Vector2(tower, 38.0), SILHOUETTE, 1.5)
	draw_rect(Rect2(tower - 8.0, 96.0, 16.0, 12.0), SILHOUETTE)
	# Ministérios: dois renques de blocos iguais, com algumas janelas acesas.
	for side in [center - 362.0, center + 118.0]:
		for i in 6:
			var x: float = side + i * 30.0
			draw_rect(Rect2(x, HORIZON - 40.0, 22.0, 40.0), SILHOUETTE)
			for row in 4:
				for column in 3:
					if (i * 7 + row * 5 + column * 3 + int(side)) % 4 == 0:
						draw_rect(Rect2(x + 3.0 + column * 6.0, HORIZON - 35.0 + row * 8.0, 3.0, 3.0), WINDOW_LIT)
	# Catedral: costelas curvas abrindo para cima.
	var cathedral := center - 150.0
	_oval(Vector2(cathedral, HORIZON - 2.0), Vector2(26.0, 3.0), SILHOUETTE)
	for k in range(-4, 5):
		var base := Vector2(cathedral + k * 5.0, HORIZON)
		var middle := Vector2(cathedral + k * 1.5, HORIZON - 24.0)
		var top := Vector2(cathedral + k * 7.5, HORIZON - 54.0)
		var points := PackedVector2Array()
		for step in 7:
			var t := step / 6.0
			points.append(base.lerp(middle, t).lerp(middle.lerp(top, t), t))
		draw_polyline(points, SILHOUETTE, 3.5)
	# Congresso: plataforma, as duas torres, a cúpula para cima (Câmara) e a para baixo (Senado).
	draw_rect(Rect2(center - 120.0, HORIZON - 14.0, 240.0, 14.0), SILHOUETTE)
	draw_rect(Rect2(center - 14.0, 92.0, 12.0, HORIZON - 106.0), SILHOUETTE)
	draw_rect(Rect2(center + 2.0, 92.0, 12.0, HORIZON - 106.0), SILHOUETTE)
	draw_rect(Rect2(center - 14.0, 128.0, 28.0, 5.0), SILHOUETTE)
	var bowl := PackedVector2Array()
	var dome := PackedVector2Array()
	for step in 17:
		var angle := PI * step / 16.0
		bowl.append(Vector2(center - 70.0 + 36.0 * cos(angle), HORIZON - 28.0 + 14.0 * sin(angle)))
		dome.append(Vector2(center + 70.0 + 26.0 * cos(angle), HORIZON - 14.0 - 18.0 * sin(angle)))
	draw_colored_polygon(bowl, SILHOUETTE)
	draw_colored_polygon(dome, SILHOUETTE)
	# Mastro da bandeira, com a bandeira tremulando.
	var mast := center + 340.0
	draw_line(Vector2(mast, HORIZON), Vector2(mast, 66.0), SILHOUETTE, 2.5)
	var wave := sin(_time * 3.0) * 2.0
	var flag := PackedVector2Array([Vector2(mast, 68.0), Vector2(mast + 30.0, 68.0 + wave),
		Vector2(mast + 30.0, 88.0 + wave), Vector2(mast, 88.0)])
	draw_colored_polygon(flag, Color(0.1, 0.55, 0.28))
	draw_colored_polygon(PackedVector2Array([Vector2(mast + 4.0, 78.0 + wave * 0.5), Vector2(mast + 15.0, 71.0 + wave * 0.5),
		Vector2(mast + 26.0, 78.0 + wave), Vector2(mast + 15.0, 85.0 + wave * 0.5)]), Color(1.0, 0.85, 0.15))
	draw_circle(Vector2(mast + 15.0, 78.0 + wave * 0.5), 3.5, Color(0.15, 0.25, 0.6))


func _draw_ground() -> void:
	draw_polygon(PackedVector2Array([Vector2(0, HORIZON), Vector2(_width, HORIZON), Vector2(_width, HEIGHT), Vector2(0, HEIGHT)]),
		PackedColorArray([LAWN_FAR, LAWN_FAR, LAWN_NEAR, LAWN_NEAR]))
	draw_rect(Rect2(0.0, ROAD.x, _width, ROAD.y - ROAD.x), ASPHALT)
	draw_line(Vector2(0.0, ROAD.x), Vector2(_width, ROAD.x), Color(0.75, 0.75, 0.7), 1.5)
	draw_line(Vector2(0.0, ROAD.y), Vector2(_width, ROAD.y), Color(0.75, 0.75, 0.7), 1.5)
	var x := 0.0
	while x < _width:
		draw_rect(Rect2(x, (ROAD.x + ROAD.y) * 0.5 - 1.0, 20.0, 2.5), Color(0.95, 0.9, 0.7, 0.8))
		x += 40.0


func _draw_bus(x: float) -> void:
	var bob := sin(_time * 16.0) * 0.7
	var top := BUS_BASE - 50.0 + bob
	var bottom := BUS_BASE + bob
	_oval(Vector2(x + BUS_LENGTH * 0.5, ROAD.y - 1.0), Vector2(80.0, 4.0), Color(0, 0, 0, 0.3))
	# Farol e seu facho na pista.
	draw_colored_polygon(PackedVector2Array([Vector2(x + 148.0, top + 42.0), Vector2(x + 230.0, top + 36.0), Vector2(x + 230.0, top + 58.0)]),
		Color(1.0, 0.95, 0.6, 0.15))
	draw_rect(Rect2(x + 4.0, top - 4.0, BUS_LENGTH - 8.0, 5.0), Color(0.85, 0.86, 0.84))
	draw_rect(Rect2(x, top, BUS_LENGTH, 50.0), Color(0.95, 0.95, 0.92))
	draw_rect(Rect2(x, top + 30.0, BUS_LENGTH, 6.0), Color(0.15, 0.4, 0.8))
	draw_rect(Rect2(x, top + 36.0, BUS_LENGTH, 2.0), UiStyle.GOLD)
	for i in 7:
		draw_rect(Rect2(x + 8.0 + i * 17.0, top + 8.0, 13.0, 15.0), Color(0.2, 0.3, 0.45))
		draw_line(Vector2(x + 10.0 + i * 17.0, top + 20.0), Vector2(x + 17.0 + i * 17.0, top + 10.0), Color(1, 1, 1, 0.25), 1.5)
	draw_rect(Rect2(x + 136.0, top + 6.0, 12.0, 24.0), Color(0.25, 0.38, 0.55))
	draw_rect(Rect2(x + 98.0, top + 1.0, 40.0, 6.0), Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(x + 101.0, top + 2.5, 34.0, 3.0), Color(1.0, 0.6, 0.15))
	draw_circle(Vector2(x + 147.0, top + 42.0), 3.0, Color(1.0, 0.95, 0.6))
	# Bagageiro: abre por baixo e fica balançando, pendurado.
	if _hatch > 0.0:
		draw_rect(Rect2(x + 56.0, bottom - 13.0, 44.0, 12.0), Color(0.08, 0.08, 0.1))
	var angle := _hatch * (2.2 + 0.25 * sin(_time * 20.0))
	var reach := 12.0 * cos(angle)
	var door := Rect2(x + 56.0, minf(bottom, bottom - reach), 44.0, maxf(absf(reach), 1.5))
	draw_rect(door, Color(0.84, 0.84, 0.8))
	draw_rect(door, Color(0.35, 0.35, 0.38), false, 1.0)
	for wheel_x in [x + 30.0, x + 120.0]:
		var hub := Vector2(wheel_x, bottom + 1.0)
		draw_circle(hub, WHEEL_RADIUS, Color(0.1, 0.1, 0.12))
		draw_circle(hub, 4.0, Color(0.6, 0.6, 0.65))
		for k in 3:
			var spoke := x / WHEEL_RADIUS + k * TAU / 3.0
			draw_line(hub, hub + Vector2(cos(spoke), sin(spoke)) * 6.5, Color(0.6, 0.6, 0.65), 1.5)


func _draw_coin(coin: Coin, s: float) -> void:
	var colors: Array = COIN_COLORS[coin.colors]
	var radius := COIN_RADIUS * lerpf(0.85, 1.2, inverse_lerp(COIN_GROUND.x, COIN_GROUND.y, coin.ground))
	var squash := Vector2(1.0, 0.38) if coin.resting else Vector2(maxf(absf(cos(coin.spin)), 0.18), 1.0)
	draw_set_transform(coin.pos * s, 0.0, squash * s)
	draw_circle(Vector2.ZERO, radius, Color(colors[1], coin.fade))
	draw_circle(Vector2(-0.4, -0.4), radius * 0.74, Color(colors[0], coin.fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	if coin.resting:
		var twinkle := sin(_time * 2.3 + coin.phase)
		if twinkle > 0.95:
			var arm := (twinkle - 0.95) / 0.05 * 6.0
			var shine := Color(1, 1, 0.9, coin.fade)
			draw_line(coin.pos - Vector2(arm, 0), coin.pos + Vector2(arm, 0), shine, 1.2)
			draw_line(coin.pos - Vector2(0, arm), coin.pos + Vector2(0, arm), shine, 1.2)
