class_name EscapeEasterEggs
extends Node3D
## Segundo lote de segredos satíricos, nos muros da cidade (tudo fictício, nenhum nome real):
## o aeroporto da "Última Saída" (painel que muda, guichê, político de óculos escuros, mala que
## anda sozinha e as pegadas até o passaporte), a fuga com o esconderijo de malas, o Banco Central
## de Tudo e a Produções Milionárias. Bloqueiam o jogador, não as moedas.

const K := preload("res://scripts/world/easter_egg_kit.gd")
const GOLD := Color(1.0, 0.78, 0.2)
## Colunas (quarteirões) onde cada cena fica encostada no muro.
const AIRPORT_COLUMN := 45.5     # muro sul, Praça dos Três Poderes
const ESCAPE_COLUMN := 45.5      # muro norte
const BANK_COLUMN := 20.5        # muro norte, Esplanada
const STUDIO_COLUMN := 11.5      # muro norte, fim do Setor Cultural
## Painel de partidas: [destino, situação], um conjunto por olhada.
const DEPARTURES := [
	[["MIAMI", "EMBARQUE"], ["BUENOS AIRES", "ATRASADO"], ["NÃO CONSTA NO SISTEMA", "CONFIRMADO"]],
	[["BUENOS AIRES", "PORTÃO ALTERADO"], ["NÃO CONSTA NO SISTEMA", "EMBARQUE"], ["MIAMI", "CANCELADO"]],
	[["NÃO CONSTA NO SISTEMA", "DECOLOU"], ["MIAMI", "SEM PREVISÃO"], ["BUENOS AIRES", "SIGILOSO"]],
]
const DESTINATIONS := ["Miami", "Buenos Aires", "Não consta no sistema"]
const POLITICIAN := [
	"Não vou sair do país. Só estou verificando os portões de embarque.",
	"Essa mala não é minha. É de um amigo do intermediário.",
	"Estou em agenda oficial. A agenda é que está em outro fuso.",
]
const TELLER := [
	"Seu saldo está disponível, mas não pode ser movimentado.",
	"Seu dinheiro está seguro. A localização dele é confidencial.",
	"Para consultar o saldo, pague uma taxa de consulta.",
	"Sua solicitação foi encaminhada ao setor responsável.",
]
const SUITCASES := 3

var layout: CityLayout
var _board_rows: Array[Label3D] = []
var _walking_case: Node3D
var _time := 0.0


func setup(city_layout: CityLayout) -> void:
	layout = city_layout


func _ready() -> void:
	_build_airport()
	_build_escape()
	_build_bank()
	_build_studio()


func _process(delta: float) -> void:
	_time += delta
	# A mala executiva atravessa o saguão sozinha, de um lado para o outro.
	if _walking_case != null:
		_walking_case.position.x = 8.0 * sin(_time * 0.35)
		_walking_case.rotation.y = PI * 0.5 if cos(_time * 0.35) > 0.0 else -PI * 0.5


## Nó encostado no muro da coluna `column`: +z local aponta para dentro da cidade.
func _wall_anchor(node_name: String, column: float, north: bool) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = node_name
	var x := -layout.half_x + column * layout.definition.block_size
	anchor.position = Vector3(x, 0, -layout.half_z + 0.06 if north else layout.half_z - 0.06)
	anchor.rotation.y = 0.0 if north else PI
	add_child(anchor)
	return anchor


## Fachada no muro: painel colorido, faixa de cima e o letreiro.
func _facade(anchor: Node3D, width: float, color: Color, title: String, subtitle: String) -> void:
	K.box(anchor, Vector3(width, 6.4, 0.1), Vector3(0, 3.2, 0.05), K.material(color))
	K.box(anchor, Vector3(width + 0.4, 0.3, 0.3), Vector3(0, 6.5, 0.15), K.material(Color(0.95, 0.95, 0.92)))
	K.label(anchor, title, Vector3(0, 5.6, 0.12), 0.009, GOLD)
	if subtitle != "":
		K.label(anchor, subtitle, Vector3(0, 4.95, 0.12), 0.0045, Color(0.95, 0.93, 0.88))


# --- A Última Saída ----------------------------------------------------------------------

func _build_airport() -> void:
	var airport := _wall_anchor("Airport", AIRPORT_COLUMN, false)
	_facade(airport, 22.0, Color(0.55, 0.6, 0.68), "AEROPORTO INTERNACIONAL DO EIXO", "Terminal A Última Saída")
	# Painel de partidas: olhar de novo muda tudo.
	var board := K.interactive(airport, "DeparturesBoard", Vector3(-5.0, 0.6, 0.4), Vector3(5.0, 2.6, 0.4), "Olhar o painel de partidas", _look_board)
	K.box(board, Vector3(5.0, 2.4, 0.15), Vector3(0, 1.3, 0), K.material(Color(0.05, 0.06, 0.08)))
	K.label(board, "PARTIDAS", Vector3(0, 2.2, 0.09), 0.004, GOLD)
	for row in 3:
		var line := K.label(board, "", Vector3(0, 1.65 - row * 0.45, 0.09), 0.0034, Color(1, 0.85, 0.3))
		_board_rows.append(line)
	_show_board(int(GameState.extras.get("board", 0)))
	# Guichê: "Destino final?"
	var desk := K.interactive(airport, "CheckIn", Vector3(4.0, 0, 3.0), Vector3(2.4, 1.1, 0.8), "Falar com o guichê", _check_in)
	K.box(desk, Vector3(2.4, 1.1, 0.8), Vector3(0, 0.55, 0), K.material(Color(0.2, 0.3, 0.55)))
	K.label(desk, "CHECK-IN", Vector3(0, 0.75, 0.41), 0.003, Color.WHITE)
	# O político fictício que "só está verificando os portões".
	var politician := K.interactive(airport, "Politician", Vector3(8.0, 0, 4.0), Vector3(0.6, 1.9, 0.5), "Falar com o homem de óculos escuros", _talk_politician)
	politician.rotation.y = -0.6
	K.person(politician, Color(0.15, 0.15, 0.17), Color(0.1, 0.35, 0.75))
	_walking_case = K.suitcase(airport, Vector3(0, 0, 6.0), Color(0.2, 0.12, 0.06))
	# Pegadas do guichê até a lixeira (a ponta da trilha, uns 30 m adiante).
	var mud := K.material(Color(0.16, 0.12, 0.1))
	for step in 34:
		var side := 0.18 if step % 2 == 0 else -0.18
		K.box(airport, Vector3(0.13, 0.012, 0.28), Vector3(-6.5 - step * 0.75, 0.13, 3.6 + side), mud)
	var bin := K.interactive(airport, "PassportBin", Vector3(-33.0, 0, 3.6), Vector3(0.6, 0.9, 0.6), "Revirar a lixeira", _search_bin)
	K.box(bin, Vector3(0.55, 0.85, 0.55), Vector3(0, 0.43, 0), K.material(Color(0.2, 0.45, 0.27)))
	if not GameState.has_achievement(&"not_in_system"):
		K.box(bin, Vector3(0.14, 0.02, 0.2), Vector3(0.05, 0.87, 0.05), K.material(Color(0.1, 0.2, 0.45)))


func _look_board() -> void:
	_show_board(GameState.bump("board"))


func _show_board(turn: int) -> void:
	var rows: Array = DEPARTURES[turn % DEPARTURES.size()]
	for i in _board_rows.size():
		_board_rows[i].text = "%-22s %s" % [rows[i][0], rows[i][1]]


func _check_in() -> void:
	var turn := GameState.bump("check_in")
	GameState.notify("Guichê: “Destino final?” Opção do sistema: %s." % DESTINATIONS[(turn - 1) % DESTINATIONS.size()])


func _talk_politician() -> void:
	var turn := GameState.bump("politician")
	GameState.notify("Homem de óculos escuros: “%s”" % POLITICIAN[(turn - 1) % POLITICIAN.size()])


func _search_bin() -> void:
	if GameState.has_achievement(&"not_in_system"):
		GameState.notify("Só papel amassado. O passaporte já foi encontrado.")
		return
	K.give_cents(1)
	GameState.notify("Na lixeira: um passaporte sem nome nenhum e uma moeda de 1 centavo.")
	GameState.unlock(&"not_in_system")


# --- A fuga ------------------------------------------------------------------------------

func _build_escape() -> void:
	var escape := _wall_anchor("Escape", ESCAPE_COLUMN, true)
	# Placa com os três caminhos.
	var signpost := Node3D.new()
	signpost.position = Vector3(0, 0, 4.5)
	escape.add_child(signpost)
	K.box(signpost, Vector3(0.12, 2.6, 0.12), Vector3(0, 1.3, 0), K.material(Color(0.35, 0.25, 0.15)))
	var arrows := [["FRONTEIRA TERRESTRE  →", -0.25, 2.3], ["←  AEROPORTO PARTICULAR", 0.2, 1.85], ["ROTA ALTERNATIVA  ↓", -0.1, 1.4]]
	for arrow: Array in arrows:
		var plank := Node3D.new()
		plank.position = Vector3(0, arrow[2], 0.08)
		plank.rotation.y = arrow[1]
		signpost.add_child(plank)
		K.box(plank, Vector3(2.2, 0.32, 0.05), Vector3.ZERO, K.material(Color(0.85, 0.75, 0.5)))
		K.label(plank, arrow[0], Vector3(0, 0, 0.04), 0.0026, Color(0.2, 0.12, 0.05))
	# Carro de luxo abandonado, porta-malas aberto e moedas espalhadas.
	var car: Node3D = (load("res://assets/third_party/kenney/car-kit/sedan.glb") as PackedScene).instantiate()
	car.position = Vector3(-10.0, 0, 4.0)
	car.rotation.y = 0.4
	car.scale = Vector3.ONE * 1.25
	escape.add_child(car)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.05, 0.06)
	black.metallic = 0.6
	black.roughness = 0.25
	for node in car.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = black
	var open_case := K.suitcase(escape, Vector3(-7.0, 0, 6.2), Color(0.25, 0.15, 0.08))
	K.box(open_case, Vector3(0.7, 0.04, 0.5), Vector3(0, 0.62, -0.2), K.material(Color(0.25, 0.15, 0.08)))
	var npc := K.interactive(escape, "SunglassesMan", Vector3(5.0, 0, 3.5), Vector3(0.6, 1.9, 0.5), "Falar com o homem de óculos escuros", _talk_escape)
	K.person(npc, Color(0.3, 0.25, 0.2), Color(0.9, 0.7, 0.1), true, false)
	# O esconderijo: malas encostadas no muro (só papel e centavos).
	for i in SUITCASES:
		var case_body := K.interactive(escape, "HiddenCase_%d" % i, Vector3(9.0 + i * 1.1, 0, 1.0), Vector3(0.8, 0.6, 0.4), "Abrir a mala", _open_case.bind(i))
		K.suitcase(case_body, Vector3.ZERO, [Color(0.1, 0.1, 0.12), Color(0.35, 0.1, 0.1), Color(0.15, 0.2, 0.35)][i])


func _talk_escape() -> void:
	GameState.notify("Homem de óculos escuros: “Eu não estou fugindo. Estou fazendo uma mudança temporária de endereço.”")


func _open_case(index: int) -> void:
	var key := "case_%d" % index
	if int(GameState.extras.get(key, 0)) > 0:
		GameState.notify("Mala aberta: só documentos e contratos. O centavo você já pegou.")
		return
	GameState.bump(key)
	K.give_cents(1)
	GameState.notify("Mala aberta: documentos, contratos de 300 páginas e uma moeda de 1 centavo.")
	var opened := 0
	for i in SUITCASES:
		opened += 1 if int(GameState.extras.get("case_%d" % i, 0)) > 0 else 0
	if opened >= SUITCASES:
		GameState.unlock(&"investigative_tourism")


# --- Banco Central de Tudo ---------------------------------------------------------------

func _build_bank() -> void:
	var bank := _wall_anchor("Bank", BANK_COLUMN, true)
	_facade(bank, 20.0, Color(0.78, 0.74, 0.66), "BANCO CENTRAL DE TUDO", "Seu dinheiro em boas mãos (quais, não sabemos)")
	for x: float in [-8.5, -4.5, 4.5, 8.5]:
		K.box(bank, Vector3(0.7, 4.4, 0.7), Vector3(x, 2.2, 0.4), K.material(Color(0.93, 0.92, 0.88)))
	# Porta fechada e a vitrine com o cofre cheio de moedas por trás do vidro.
	K.box(bank, Vector3(2.4, 3.0, 0.15), Vector3(0, 1.5, 0.1), K.material(Color(0.25, 0.18, 0.12)))
	K.box(bank, Vector3(4.4, 2.2, 0.5), Vector3(-6.5, 1.6, 0.25), K.material(Color(0.2, 0.18, 0.1)))
	for i in 9:
		var coin := MeshInstance3D.new()
		coin.mesh = CoinVisuals.shared_mesh()
		CoinVisuals.set_denomination(coin, 0)
		coin.scale = Vector3.ONE * 5.0
		coin.position = Vector3(-7.8 + (i % 5) * 0.65, 0.9 + floori(i / 5.0) * 0.12, 0.35)
		coin.rotation = Vector3(0, i * 0.7, 0)
		bank.add_child(coin)
	K.box(bank, Vector3(4.6, 2.4, 0.04), Vector3(-6.5, 1.6, 0.55), K.material(Color(0.7, 0.85, 1.0, 0.3)))
	var guard := K.interactive(bank, "Guard", Vector3(1.8, 0, 1.0), Vector3(0.6, 1.9, 0.5), "Pedir para entrar no banco", _ask_guard)
	K.person(guard, Color(0.12, 0.15, 0.3), Color(0.12, 0.15, 0.3), true, false)
	K.box(guard, Vector3(0.34, 0.1, 0.36), Vector3(0, 2.0, 0.02), K.material(Color(0.12, 0.15, 0.3)))
	var teller := K.interactive(bank, "Teller", Vector3(6.5, 0, 0.6), Vector3(1.6, 1.4, 0.6), "Falar com o caixa", _ask_teller)
	K.box(teller, Vector3(1.6, 1.1, 0.5), Vector3(0, 0.55, 0), K.material(Color(0.6, 0.55, 0.45)))
	K.label(teller, "CAIXA", Vector3(0, 0.8, 0.26), 0.003, Color(0.15, 0.1, 0.05))


func _ask_guard() -> void:
	GameState.notify("Segurança: “Com essa roupa suja de catar moeda, não entra. Pela janela pode olhar.”")


func _ask_teller() -> void:
	var turn := GameState.bump("teller")
	if turn <= TELLER.size():
		GameState.notify("Caixa: “%s”" % TELLER[turn - 1])
		return
	GameState.notify("O gerente entrega um documento: “Saldo confirmado: R$ 1,34. Saldo disponível para saque: R$ 0,00.”")
	GameState.unlock(&"unavailable_balance")


# --- Produções Milionárias ---------------------------------------------------------------

func _build_studio() -> void:
	var studio := _wall_anchor("Studio", STUDIO_COLUMN, true)
	_facade(studio, 18.0, Color(0.15, 0.1, 0.2), "PRODUÇÕES MILIONÁRIAS", "Grandes histórias, orçamentos maiores")
	var chair := K.interactive(studio, "DirectorChair", Vector3(-5.0, 0, 2.0), Vector3(0.8, 1.2, 0.7), "Ver a cadeira de diretor", _look_chair)
	var wood := K.material(Color(0.45, 0.3, 0.15))
	for x: float in [-0.3, 0.3]:
		K.box(chair, Vector3(0.06, 1.1, 0.06), Vector3(x, 0.55, 0.25), wood)
		K.box(chair, Vector3(0.06, 1.1, 0.06), Vector3(x, 0.55, -0.25), wood)
	K.box(chair, Vector3(0.62, 0.05, 0.5), Vector3(0, 0.6, 0), K.material(Color(0.1, 0.1, 0.1)))
	K.box(chair, Vector3(0.62, 0.3, 0.04), Vector3(0, 1.0, -0.26), K.material(Color(0.1, 0.1, 0.1)))
	K.label(chair, "DIRETOR", Vector3(0, 1.0, -0.23), 0.0022, Color.WHITE)
	var dressing := K.interactive(studio, "DressingRoom", Vector3(0, 0, 0.3), Vector3(1.4, 2.4, 0.5), "Abrir o camarim", _open_dressing_room)
	K.box(dressing, Vector3(1.3, 2.3, 0.1), Vector3(0, 1.15, 0), K.material(Color(0.6, 0.15, 0.2)))
	K.label(dressing, "★ CAMARIM ★", Vector3(0, 1.9, 0.06), 0.003, GOLD)
	var staff := K.interactive(studio, "Producer", Vector3(4.0, 0, 2.2), Vector3(0.6, 1.9, 0.5), "Perguntar sobre o orçamento", _ask_producer)
	staff.rotation.y = 0.4
	K.person(staff, Color(0.55, 0.5, 0.42), Color(0.2, 0.2, 0.2), false, true)
	# Cartaz do próximo lançamento.
	K.box(studio, Vector3(3.2, 4.2, 0.08), Vector3(7.2, 2.6, 0.1), K.material(Color(0.1, 0.25, 0.3)))
	K.label(studio, "A ORIGEM DO\nORÇAMENTO 2", Vector3(7.2, 3.4, 0.16), 0.0045, GOLD)
	K.label(studio, "Agora em 3D.\nO dinheiro, em 2D.", Vector3(7.2, 1.7, 0.16), 0.003, Color.WHITE)


func _look_chair() -> void:
	GameState.notify("Cadeira de diretor: R$ 4.800.000,00. Custa mais que todos os seus equipamentos iniciais juntos.")


func _open_dressing_room() -> void:
	if int(GameState.extras.get("dressing_room", 0)) > 0:
		GameState.notify("O camarim está vazio. Até o espelho foi para a prestação de contas.")
		return
	GameState.bump("dressing_room")
	K.give_cents(1)
	GameState.notify("No camarim de luxo: uma única moeda de 1 centavo.")


func _ask_producer() -> void:
	GameState.notify("Produtor: “O filme está quase pronto. Estamos finalizando os créditos, o making of e o documentário sobre a produção do documentário.”")
	GameState.unlock(&"almost_done")
