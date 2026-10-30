class_name AchievementsMenu
extends MenuScreen
## Conquistas (K, ou o botão no menu de pausa): por categoria, com o progresso de cada uma
## (moedas, reais, viagens...). Segredos ainda não achados aparecem como "???". Também é quem
## confere as conquistas de progresso enquanto se joga (Achievements.check).

const COLOR_DONE := Color(0.55, 0.95, 0.55)
const COLOR_INFO := Color(0.75, 0.75, 0.75)
const ICONS := "res://assets/third_party/kenney/game-icons/"
## Estatísticas mostradas em reais (o resto é contagem).
const MONEY_STATS := [Achievements.Stat.VALUE_FOUND, Achievements.Stat.MONEY, Achievements.Stat.SPENT]

static var current: AchievementsMenu

var _trophy: Texture2D
var _locked: Texture2D


func _ready() -> void:
	close_action = &"achievements"
	close_noun = "as conquistas"
	super()
	current = self
	_trophy = load(ICONS + "trophy.png")
	_locked = load(ICONS + "locked.png")
	for changed: Signal in [GameState.economy_changed, GameState.tools_changed, GameState.robots_changed]:
		changed.connect(Achievements.check)
	Achievements.check.call_deferred()


func _exit_tree() -> void:
	if current == self:
		current = null


func _unhandled_input(event: InputEvent) -> void:
	if not _open and event.is_action_pressed(&"achievements"):
		if open():
			get_viewport().set_input_as_handled()
		return
	super(event)


func refresh() -> void:
	super()
	var done := 0
	var secrets := 0
	var secrets_done := 0
	for id: StringName in Achievements.LIST:
		var unlocked := GameState.has_achievement(id)
		done += 1 if unlocked else 0
		if Achievements.is_secret(id):
			secrets += 1
			secrets_done += 1 if unlocked else 0
	summary_label.text = "%d de %d conquistas   ·   segredos da cidade: %d de %d" % [done, Achievements.LIST.size(), secrets_done, secrets]
	clear_items()
	for category: String in Achievements.CATEGORIES:
		items_box.add_child(make_label(category, 26, UiStyle.GOLD))
		for id: StringName in Achievements.LIST:
			if Achievements.category_of(id) == category:
				_add_row(id)


func _add_row(id: StringName) -> void:
	var entry: Array = Achievements.LIST[id]
	var unlocked := GameState.has_achievement(id)
	if Achievements.is_secret(id) and not unlocked:
		make_row("???", [["Um segredo da cidade. Ande com atenção.", COLOR_INFO]], "", false, false, _locked)
		return
	var lines := [[entry[2], COLOR_DONE if unlocked else COLOR_INFO]]
	if not Achievements.is_secret(id):
		var target := Achievements.target(id)
		var value := mini(Achievements.current(id), target)
		lines.append(["%s / %s" % [_format(entry[3], value), _format(entry[3], target)], COLOR_DONE if unlocked else COLOR_INFO])
	make_row(entry[1], lines, "", false, unlocked, _trophy if unlocked else _locked)


static func _format(stat: int, value: int) -> String:
	return MoneyFormat.brl(value) if stat in MONEY_STATS else MoneyFormat.group(value)
