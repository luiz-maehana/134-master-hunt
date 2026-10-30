extends Node
## Efeitos sonoros (autoload "Sfx"). Os sons do jogo são sintetizados aqui ao iniciar,
## sem arquivos de áudio (batidinha suave ao pegar, cascata do depósito, sino da compra, zunido do ímã,
## aviso, motor dos aspiradores e os da interface: abrir/fechar tela, passar o mouse, erro).
## O clique dos botões vem do Kenney UI Pack (CC0).

const RATE := 22050
const UI_CLICK := "res://assets/third_party/kenney/ui-pack/click-a.ogg"
const VOICES := 10
## Intervalo mínimo entre dois sons de moedas pegas: espaçado para não virar um "tique" contínuo.
const PICK_INTERVAL := 0.16
## Volume dos sons de pegar (bem abaixo dos de depósito e compra).
const PICK_DB := -13.0
## Intervalo mínimo entre dois sons de passar o mouse (a lista da loja passa vários de uma vez).
const HOVER_INTERVAL := 0.05

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_pick := -1.0
var _rng := RandomNumberGenerator.new()
var _clinks: Array[PackedFloat32Array] = []
var _last_variant := -1
var _last_hover := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in 4:
		_clinks.append(_clink_samples(0.22, 2100.0 + i * 380.0, 0.0))
		_streams["clink%d" % i] = _wav(_clinks[i])
	# Sons de pegar: batidinha abafada e grave, seis variações (nunca a mesma duas vezes).
	for i in 6:
		_streams["pick%d" % i] = _wav(_soft_clink_samples(1050.0 + i * 140.0, 11 + i))
	_streams["pick_many"] = _wav(_soft_pour_samples())
	_streams["step"] = _wav(_step_samples())
	_streams["pour"] = _wav(_pour_samples(1.1, 34))
	_streams["chime"] = _wav(_chime_samples())
	_streams["whoosh"] = _wav(_whoosh_samples(0.38))
	_streams["click"] = _wav(_click_samples())
	_streams["buzz"] = _wav(_buzz_samples())
	_streams["hum"] = _wav(_hum_samples(), true)
	_streams["ui_open"] = _wav(_blip_samples(520.0, 880.0))
	_streams["ui_close"] = _wav(_blip_samples(760.0, 440.0))
	_streams["ui_hover"] = _wav(_tick_samples())
	_streams["ui_error"] = _wav(_error_samples())
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	GameState.coins_picked.connect(_on_coins_picked)
	GameState.deposited.connect(func(_amount: int) -> void: play(&"pour", 0.0, -2.0))
	GameState.purchased.connect(func(_id: StringName) -> void: play(&"chime", 0.0, -4.0))
	GameState.notified.connect(_on_notified)
	# Clique da Kenney (UI Pack, CC0) em todos os botões, inclusive os criados depois.
	_streams["ui_click"] = load(UI_CLICK)
	get_tree().node_added.connect(_on_node_added)


## Toca um som pelo nome. `jitter` varia a altura aleatoriamente (fração), `db` = volume.
func play(sound: StringName, jitter := 0.06, db := 0.0) -> void:
	var stream: AudioStream = _streams.get(String(sound))
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = db
	player.pitch_scale = 1.0 + _rng.randf_range(-jitter, jitter)
	player.play()


## Loop do motor dos aspiradores (usado pelos robôs em AudioStreamPlayer3D).
func hum_stream() -> AudioStream:
	return _streams["hum"]


var _last_buzz := -1.0


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.pressed.connect(play.bind(&"ui_click", 0.05, -4.0))
		button.mouse_entered.connect(_on_hover.bind(button))


func _on_hover(button: BaseButton) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if button.disabled or now - _last_hover < HOVER_INTERVAL:
		return
	_last_hover = now
	play(&"ui_hover", 0.04, -18.0)


func _on_notified(text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if text.begins_with("Bolsos cheios") and now - _last_buzz > 0.6:
		_last_buzz = now
		play(&"buzz", 0.0, -8.0)


func _on_coins_picked(amount: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_pick < PICK_INTERVAL:
		return
	_last_pick = now
	if amount >= 25:
		play(&"pick_many", 0.12, PICK_DB - 1.0)
		return
	var variant := _rng.randi_range(0, 5)
	if variant == _last_variant:
		variant = (variant + 1 + _rng.randi_range(0, 4)) % 6
	_last_variant = variant
	play(StringName("pick%d" % variant), 0.12, PICK_DB + _rng.randf_range(-2.0, 1.0))


# --- Síntese -----------------------------------------------------------------------------

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav


## Moeda batendo: parciais inarmônicas de metal com queda exponencial.
func _clink_samples(length: float, base: float, offset: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(length * RATE))
	_add_clink(samples, base, offset, 0.5)
	return samples


func _add_clink(samples: PackedFloat32Array, base: float, start: float, gain: float) -> void:
	var ratios := [1.0, 1.52, 2.34, 3.41]
	var amps := [1.0, 0.55, 0.35, 0.2]
	var decays := [16.0, 22.0, 30.0, 42.0]
	var first := int(start * RATE)
	# Depois de 0,25 s o som já sumiu.
	for i in range(first, mini(samples.size(), first + int(0.25 * RATE))):
		var t := float(i - first) / RATE
		var value := 0.0
		for p in ratios.size():
			value += amps[p] * sin(TAU * base * ratios[p] * t) * exp(-decays[p] * t)
		# Ataque de 1,5 ms para não estalar.
		samples[i] += value * gain * minf(t / 0.0015, 1.0)


## Moeda pega: duas parciais graves que somem rápido e um toque de ruído grave no começo
## (o "tlec" de tirar a moeda do chão), sem o brilho agudo do tilintar.
func _soft_clink_samples(base: float, noise_seed: int) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.16 * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var low := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var tone := sin(TAU * base * t) * exp(-32.0 * t) + 0.22 * sin(TAU * base * 2.7 * t) * exp(-55.0 * t)
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.08
		var thump := low * exp(-120.0 * t) * 1.6
		samples[i] = (tone * 0.32 + thump) * minf(t / 0.003, 1.0)
	return samples


## Passo no asfalto: ruído grave e curto, sem tom.
func _step_samples() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.09 * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var low := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.05
		samples[i] = low * 2.2 * exp(-45.0 * t) * minf(t / 0.004, 1.0)
	return samples


## Punhado de moedas (pá, ímã): poucas batidinhas suaves espalhadas.
func _soft_pour_samples() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.4 * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for c in 7:
		var clink := _soft_clink_samples(rng.randf_range(950.0, 1500.0), c)
		var first := int(pow(rng.randf(), 1.4) * 0.25 * RATE)
		var gain := rng.randf_range(0.35, 0.7)
		for i in mini(clink.size(), samples.size() - first):
			samples[first + i] += clink[i] * gain
	return samples


## Várias moedas caindo umas sobre as outras.
func _pour_samples(length: float, count: int) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(length * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = count
	for c in count:
		# Mais densas no começo.
		var start := pow(rng.randf(), 1.6) * (length - 0.2)
		# Mistura cópias das batidas prontas (sintetizar cada uma seria lento).
		var clink: PackedFloat32Array = _clinks[rng.randi() % _clinks.size()]
		var gain := rng.randf_range(0.25, 0.6)
		var first := int(start * RATE)
		for i in mini(clink.size(), samples.size() - first):
			samples[first + i] += clink[i] * gain
	return samples


## Sino de duas notas (compra).
func _chime_samples() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.9 * RATE))
	for note in [[0.0, 880.0], [0.12, 1318.5]]:
		var first := int(note[0] * RATE)
		for i in range(first, samples.size()):
			var t := float(i - first) / RATE
			var env := exp(-5.0 * t) * minf(t / 0.004, 1.0)
			samples[i] += (sin(TAU * note[1] * t) + 0.3 * sin(TAU * note[1] * 2.0 * t)) * env * 0.35
	return samples


## Zunido de ar (ímã, vara): ruído filtrado que sobe e desce.
func _whoosh_samples(length: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var count := int(length * RATE)
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	for i in count:
		var x := float(i) / count
		var cutoff := lerpf(0.04, 0.25, sin(x * PI))
		low += (rng.randf_range(-1.0, 1.0) - low) * cutoff
		samples[i] = low * sin(x * PI) * 0.9
	return samples


func _click_samples() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.05 * RATE))
	for i in samples.size():
		var t := float(i) / RATE
		samples[i] = sin(TAU * 1600.0 * t) * exp(-90.0 * t) * 0.4
	return samples


## Aviso (bolso cheio).
func _buzz_samples() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.22 * RATE))
	for i in samples.size():
		var t := float(i) / RATE
		var square := 1.0 if fmod(t * 160.0, 1.0) < 0.5 else -1.0
		samples[i] = square * 0.12 * minf(t / 0.01, 1.0) * minf((0.22 - t) / 0.03, 1.0)
	return samples


## Abrir/fechar tela: nota curta deslizando de `from` a `to` Hz (sobe ao abrir, desce ao fechar).
func _blip_samples(from: float, to: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.11 * RATE))
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(from, to, minf(t / 0.08, 1.0)) / RATE
		samples[i] = (sin(phase) + 0.25 * sin(phase * 2.0)) * minf(t / 0.005, 1.0) * exp(-28.0 * t) * 0.3
	return samples


## Passar o mouse num botão: tique bem curto e agudo.
func _tick_samples() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.025 * RATE))
	for i in samples.size():
		var t := float(i) / RATE
		samples[i] = sin(TAU * 2400.0 * t) * exp(-180.0 * t) * 0.35
	return samples


## Erro (ação recusada): duas notas graves descendo.
func _error_samples() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.26 * RATE))
	for note in [[0.0, 330.0], [0.11, 247.0]]:
		var first := int(note[0] * RATE)
		for i in range(first, mini(first + int(0.13 * RATE), samples.size())):
			var t := float(i - first) / RATE
			var triangle := absf(fmod(t * note[1], 1.0) * 4.0 - 2.0) - 1.0
			samples[i] += triangle * minf(t / 0.006, 1.0) * exp(-14.0 * t) * 0.28
	return samples


## Motor do aspirador: 1 s exato com frequências inteiras, então o loop não tem emenda.
func _hum_samples() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(RATE)
	for i in RATE:
		var t := float(i) / RATE
		var wobble := 1.0 + 0.15 * sin(TAU * 4.0 * t)
		samples[i] = (0.3 * sin(TAU * 120.0 * t) + 0.2 * sin(TAU * 240.0 * t)
			+ 0.08 * sin(TAU * 1260.0 * t)) * wobble * 0.5
	return samples
