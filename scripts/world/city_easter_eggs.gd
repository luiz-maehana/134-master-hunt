class_name CityEasterEggs
extends Node3D
## Segredos da cidade em tom de sátira política: a moeda lendária, jornais que mudam de versão,
## cartazes de partidos inventados, a urna das promessas, o cartaz do filme sem fim e o Senhor V.
## Tudo fictício (nenhum nome real) e fora do sorteio das moedas: bloqueiam o jogador, não as
## moedas, então a assinatura do mundo não muda. Estado (lidos, votos...) em GameState.extras.

const GOLD := Color(1.0, 0.78, 0.2)
## Partidos fictícios dos cartazes: [sigla, nome, slogan, cor do fundo].
const PARTIES := [
	["PCP", "Partido do Centavo Perdido", "Um centavo no chão,\num milhão na promessa!", Color(0.75, 0.15, 0.15)],
	["APMA", "Aliança Pela Moeda Achada", "Vote em mim: vou achar\no dinheiro que você perdeu!", Color(0.12, 0.35, 0.75)],
	["MTJ", "Movimento Troco Já", "Não prometo dinheiro. Prometo\numa auditoria da promessa.", Color(0.1, 0.55, 0.3)],
	["UBF", "União dos Bolsos Furados", "Transparência total: dá para\nver através do nosso cofre.", Color(0.55, 0.25, 0.65)],
	["PDC", "Partido da Comissão", "Uma comissão para investigar\nquem investiga a comissão.", Color(0.85, 0.5, 0.1)],
]
## Manchetes que mudam a cada visita ao mesmo jornal (uma série por jornal).
const HEADLINES := [
	["Dinheiro desaparece misteriosamente", "Dinheiro não desapareceu, afirma especialista", "Especialista não foi localizado"],
	["Filme recebe investimento milionário", "Investimento é questionado", "Produtora promete apresentar documentos"],
	["Candidato garante que ficará no país", "Paradeiro ainda é desconhecido", "Assessoria informa que ele está indisponível"],
	["Comissão vai investigar o caso", "Investigação precisa de mais recursos", "Recursos da investigação serão investigados"],
]
## O que a urna mostra a cada voto.
const PROMISES := [
	"A) Vou acabar com a corrupção.",
	"B) Vou investigar a corrupção.",
	"C) Vou criar uma comissão para investigar quem investigará a corrupção.",
]
const VOTES_FOR_LOOP := 10
## Respostas do Senhor V. (nunca à pergunta).
const EVASIONS := [
	"O dinheiro está numa estrutura muito complexa.",
	"Você precisa conversar com o intermediário.",
	"Esse valor não foi perdido; está em outra categoria contábil.",
	"Não posso comentar um processo em andamento.",
]
## Onde o Senhor V. aparece, em quarteirões (ele troca de lugar a cada conversa).
const MR_V_BLOCKS := [Vector2i(14, 0), Vector2i(21, 6), Vector2i(29, 0), Vector2i(36, 6)]

var layout: CityLayout
var _mr_v: Node3D
var _legendary: Node3D


func setup(city_layout: CityLayout) -> void:
	layout = city_layout


func _ready() -> void:
	_build_posters()
	_build_newspapers()
	_build_ballot_box()
	_build_cinema()
	_build_legendary_coin()
	_build_mr_v()


# --- A moeda lendária --------------------------------------------------------------------

## Uma moeda de 1 centavo dourada, girando ao pé do mastro da bandeira. Não conta para a meta
## (a soma do mundo é exata): vale R$ 0,01 na carteira e uma conquista.
func _build_legendary_coin() -> void:
	if GameState.has_achievement(&"legendary_coin"):
		return
	var flag := _landmark(&"flag")
	if flag.is_empty():
		return
	var center: Vector2 = (flag.area as Rect2).get_center()
	var at := Vector3(center.x + 3.0, layout.ground_height(center.x + 3.0, center.y), center.y)
	_legendary = EasterEggKit.interactive(self, "LegendaryCoin", at, Vector3(0.6, 1.2, 0.6), "Pegar a moeda lendária", _take_legendary)
	var coin := MeshInstance3D.new()
	coin.mesh = CoinVisuals.shared_mesh()
	CoinVisuals.set_denomination(coin, 0)
	coin.scale = Vector3.ONE * 9.0
	coin.rotation = Vector3(PI * 0.5, 0, 0)
	coin.position.y = 0.6
	coin.set_meta(&"spin", true)
	_legendary.add_child(coin)
	if WebPlatform.active():
		return
	var light := OmniLight3D.new()
	light.light_color = GOLD
	light.light_energy = 2.0
	light.omni_range = 3.0
	light.position.y = 0.8
	_legendary.add_child(light)


func _take_legendary() -> void:
	if GameState.has_achievement(&"legendary_coin"):
		return
	EasterEggKit.give_cents(1)
	GameState.notify("A moeda lendária de 1 centavo! Agora só faltam 133.999.999.")
	GameState.unlock(&"legendary_coin")
	_legendary.queue_free()


# --- Jornais -----------------------------------------------------------------------------

## Uma pilha de jornais em cada ponto de serviço. A manchete muda a cada leitura.
func _build_newspapers() -> void:
	for i in layout.hubs.size():
		var hub: Dictionary = layout.hubs[i]
		var deposit: Vector3 = hub.deposit
		var at := deposit + Vector3(-2.4, 0, 0.3)
		var paper := EasterEggKit.interactive(self, "Newspaper_%d" % i, at, Vector3(0.5, 0.25, 0.4), "Ler o jornal", _read_paper.bind(i))
		EasterEggKit.box(paper, Vector3(0.48, 0.16, 0.34), Vector3(0, 0.08, 0), EasterEggKit.material(Color(0.88, 0.86, 0.8)))
		EasterEggKit.box(paper, Vector3(0.4, 0.01, 0.07), Vector3(0, 0.165, -0.1), EasterEggKit.material(Color(0.15, 0.15, 0.15)))


func _read_paper(index: int) -> void:
	var series: Array = HEADLINES[index % HEADLINES.size()]
	var visits := GameState.bump("paper_%d" % index)
	var headline: String = series[(visits - 1) % series.size()]
	GameState.notify("Jornal: “%s”" % headline)
	if visits >= series.size():
		GameState.unlock(&"newsroom")


# --- Cartazes ----------------------------------------------------------------------------

## Cartazes de partidos inventados nos muros norte e sul, a cada três quarteirões.
func _build_posters() -> void:
	var size := layout.definition.block_size
	var index := 0
	for column in range(1, layout.definition.blocks_x, 3):
		var x := -layout.half_x + (column + 0.5) * size
		for north: bool in [true, false]:
			var party: Array = PARTIES[index % PARTIES.size()]
			index += 1
			var z := -layout.half_z + 0.06 if north else layout.half_z - 0.06
			var poster := Node3D.new()
			poster.position = Vector3(x, 0, z)
			poster.rotation.y = 0.0 if north else PI
			add_child(poster)
			EasterEggKit.box(poster, Vector3(6.0, 3.2, 0.08), Vector3(0, 3.0, 0.04), EasterEggKit.material(party[3]))
			EasterEggKit.box(poster, Vector3(6.2, 0.15, 0.1), Vector3(0, 4.65, 0.05), EasterEggKit.material(Color(0.95, 0.95, 0.92)))
			EasterEggKit.label(poster, "%s  %s" % [party[0], party[1]], Vector3(0, 4.15, 0.1), 0.0042, Color.WHITE)
			EasterEggKit.label(poster, party[2], Vector3(0, 2.85, 0.1), 0.0055, Color(1, 0.95, 0.6))
			EasterEggKit.label(poster, "VOTE %s" % party[0], Vector3(0, 1.75, 0.1), 0.004, Color.WHITE)


# --- Urna --------------------------------------------------------------------------------

## A urna das promessas, num canto atrás de um ministério da Esplanada.
func _build_ballot_box() -> void:
	var lot := layout.lot_rect(Vector2i(19, 0))
	var spot := lot.position + Vector2(3.0, 3.0)
	var at := Vector3(spot.x, layout.ground_height(spot.x, spot.y), spot.y)
	var urn := EasterEggKit.interactive(self, "BallotBox", at, Vector3(0.9, 1.3, 0.7), "Votar na urna das promessas", _vote)
	urn.rotation.y = PI * 0.25
	EasterEggKit.box(urn, Vector3(0.12, 0.8, 0.12), Vector3(0, 0.4, 0), EasterEggKit.material(Color(0.3, 0.3, 0.32)))
	EasterEggKit.box(urn, Vector3(0.8, 0.45, 0.55), Vector3(0, 1.0, 0), EasterEggKit.material(Color(0.85, 0.85, 0.82)))
	EasterEggKit.box(urn, Vector3(0.36, 0.22, 0.02), Vector3(-0.15, 1.08, 0.28), EasterEggKit.material(Color(0.1, 0.25, 0.15)))
	for row in 3:
		for column in 3:
			EasterEggKit.box(urn, Vector3(0.06, 0.04, 0.02), Vector3(0.12 + column * 0.08, 1.14 - row * 0.07, 0.28), EasterEggKit.material(Color(0.15, 0.15, 0.15)))
	EasterEggKit.box(urn, Vector3(0.14, 0.05, 0.02), Vector3(0.2, 0.9, 0.28), EasterEggKit.material(Color(0.2, 0.6, 0.25)))
	# Entulho em volta (só enfeite).
	var rubble := EasterEggKit.material(Color(0.55, 0.5, 0.45))
	for offset: Vector3 in [Vector3(-0.9, 0.2, 0.3), Vector3(0.8, 0.15, -0.5), Vector3(-0.5, 0.12, -0.8)]:
		EasterEggKit.box(urn, Vector3(0.6, 0.4, 0.5), offset, rubble)


func _vote() -> void:
	var votes := GameState.bump("votes")
	GameState.notify("Você votou: “%s” Promessa registrada. Moedas não encontradas." % PROMISES[(votes - 1) % PROMISES.size()])
	Sfx.play(&"click", 0.0, -4.0)
	if votes >= VOTES_FOR_LOOP:
		GameState.unlock(&"democracy_loop")


# --- Cinema ------------------------------------------------------------------------------

## O cartaz do filme sem fim no muro norte do Setor Cultural, com a placa da prestação de contas
## e a máquina de pipoca que só aceita 1 centavo.
func _build_cinema() -> void:
	var x := -layout.half_x + 7.5 * layout.definition.block_size
	var wall := Node3D.new()
	wall.position = Vector3(x, 0, -layout.half_z + 0.06)
	add_child(wall)
	EasterEggKit.box(wall, Vector3(9.0, 5.0, 0.1), Vector3(0, 3.3, 0.05), EasterEggKit.material(Color(0.32, 0.22, 0.45)))
	EasterEggKit.box(wall, Vector3(9.3, 0.18, 0.12), Vector3(0, 5.85, 0.06), EasterEggKit.material(GOLD))
	EasterEggKit.label(wall, "DARK HORSE", Vector3(0, 5.1, 0.12), 0.012, GOLD)
	EasterEggKit.label(wall, "THE UNTOLD BUDGET", Vector3(0, 4.45, 0.12), 0.0055, Color(0.95, 0.9, 0.8))
	EasterEggKit.label(wall, "ESTREIA EM BREVE", Vector3(0, 1.3, 0.12), 0.006, Color(1, 0.4, 0.35))
	_horse(wall, Vector3(0, 2.2, 0.15))
	EasterEggKit.box(wall, Vector3(4.2, 0.9, 0.06), Vector3(-6.8, 1.6, 0.03), EasterEggKit.material(Color(0.85, 0.82, 0.74)))
	EasterEggKit.label(wall, "100% do orçamento destinado à produção.\nO orçamento da prestação de\ncontas não está incluído.", Vector3(-6.8, 1.6, 0.08), 0.0028, Color(0.15, 0.12, 0.1))
	var machine := EasterEggKit.interactive(self, "Popcorn", Vector3(x + 6.0, 0.0, -layout.half_z + 1.2), Vector3(0.8, 1.6, 0.7),
		"Comprar pipoca (R$ 0,01)", _buy_popcorn)
	EasterEggKit.box(machine, Vector3(0.7, 0.8, 0.6), Vector3(0, 0.4, 0), EasterEggKit.material(Color(0.8, 0.12, 0.1)))
	var glass := EasterEggKit.material(Color(0.8, 0.9, 1.0, 0.35))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	EasterEggKit.box(machine, Vector3(0.66, 0.6, 0.56), Vector3(0, 1.1, 0), glass)
	EasterEggKit.box(machine, Vector3(0.56, 0.2, 0.46), Vector3(0, 0.9, 0), EasterEggKit.material(Color(1, 0.95, 0.75)))
	EasterEggKit.box(machine, Vector3(0.74, 0.12, 0.64), Vector3(0, 1.46, 0), EasterEggKit.material(Color(0.8, 0.12, 0.1)))
	EasterEggKit.label(machine, "SÓ 1 CENTAVO", Vector3(0, 0.55, 0.31), 0.0025, Color.WHITE)


## Cavalo de sombra de gravata (caixas pretas e a gravata vermelha).
func _horse(parent: Node3D, at: Vector3) -> void:
	var black := EasterEggKit.material(Color(0.02, 0.02, 0.03))
	EasterEggKit.box(parent, Vector3(1.8, 0.7, 0.05), at + Vector3(0, 0.3, 0), black)
	EasterEggKit.box(parent, Vector3(0.35, 0.9, 0.05), at + Vector3(0.95, 0.8, 0), black)
	EasterEggKit.box(parent, Vector3(0.7, 0.3, 0.05), at + Vector3(1.25, 1.2, 0), black)
	for leg: float in [-0.7, -0.4, 0.45, 0.75]:
		EasterEggKit.box(parent, Vector3(0.14, 0.8, 0.05), at + Vector3(leg, -0.4, 0), black)
	EasterEggKit.box(parent, Vector3(0.2, 0.08, 0.05), at + Vector3(-1.0, 0.45, 0), black)
	EasterEggKit.box(parent, Vector3(0.14, 0.45, 0.06), at + Vector3(1.0, 0.55, 0.02), EasterEggKit.material(Color(0.85, 0.1, 0.12)))


func _buy_popcorn() -> void:
	if not GameState.ledger.spend(1):
		GameState.notify("A máquina só aceita moedas de 1 centavo. Sua carteira está vazia.")
		return
	GameState.economy_changed.emit()
	GameState.notify("Pipoca comprada por R$ 0,01. Nota fiscal: em produção.")
	GameState.unlock(&"popcorn")


# --- Senhor V. ---------------------------------------------------------------------------

## O banqueiro de terno impecável que nunca responde. Larga um centavo e some para outro beco.
func _build_mr_v() -> void:
	_mr_v = EasterEggKit.interactive(self, "SenhorV", Vector3.ZERO, Vector3(0.6, 1.9, 0.5), "Perguntar ao Senhor V. sobre as moedas", _talk_mr_v)
	EasterEggKit.person(_mr_v, Color(0.1, 0.12, 0.2), Color(0.75, 0.1, 0.12))
	_place_mr_v()


func _place_mr_v() -> void:
	var meetings := int(GameState.extras.get("mr_v", 0))
	var block: Vector2i = MR_V_BLOCKS[meetings % MR_V_BLOCKS.size()]
	var lot := layout.lot_rect(block)
	# Encostado no muro (beco entre o lote e o muro do limite).
	var north := block.y == 0
	var z := -layout.half_z + 1.5 if north else layout.half_z - 1.5
	_mr_v.position = Vector3(lot.position.x + 4.0, 0.0, z)
	_mr_v.rotation.y = 0.0 if north else PI


func _talk_mr_v() -> void:
	var meetings := GameState.bump("mr_v")
	if meetings <= EVASIONS.size():
		GameState.notify("Senhor V.: “%s” (deixou cair um centavo)" % EVASIONS[meetings - 1])
		EasterEggKit.give_cents(1)
	else:
		GameState.notify("Senhor V.: “Tenho uma melhoria para o seu ímã. É só assinar: 300 páginas. A página 1 diz ‘ver página 2’.”")
		GameState.unlock(&"three_hundred_pages")
	if meetings >= 3:
		GameState.unlock(&"complex_structure")
	EasterEggKit.puff(self, _mr_v.global_position)
	Sfx.play(&"whoosh", 0.0, -6.0)
	_place_mr_v()



# --- Utilidades --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _legendary != null and is_instance_valid(_legendary):
		for child in _legendary.get_children():
			if child.has_meta(&"spin"):
				(child as Node3D).rotate_y(delta * 1.5)



func _landmark(kind: StringName) -> Dictionary:
	for landmark in layout.landmarks:
		if landmark.kind == kind:
			return landmark
	return {}

