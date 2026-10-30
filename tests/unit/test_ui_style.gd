extends TestSuite
## Guarda do guia de estilo (docs/STYLE_GUIDE.md): painéis e barras vêm só do tema, por
## variação nomeada; nenhum StyleBox é criado em script ou cena de interface.

const THEME := "res://assets/ui/game_theme.tres"


func test_no_styles_outside_theme() -> void:
	for path in _files("res://scripts/ui", ".gd"):
		var text := FileAccess.get_file_as_string(path)
		check(not text.contains("StyleBoxFlat.new") and not text.contains("add_theme_stylebox_override"),
			"%s não cria estilo (usar theme_type_variation)" % path)
	for path in _files("res://scenes/ui", ".tscn"):
		var text := FileAccess.get_file_as_string(path)
		check(not text.contains("theme_override_styles/") and not text.contains("type=\"StyleBoxFlat\""),
			"%s não sobrepõe estilo (usar theme_type_variation)" % path)


func test_variations_exist() -> void:
	var theme: Theme = load(THEME)
	for pair in [[UiStyle.CARD, "panel"], [UiStyle.PILL, "panel"], [UiStyle.WINDOW, "panel"], [UiStyle.WINDOW_GOLD, "panel"],
			[UiStyle.ROW, "panel"], [UiStyle.ROW_HIGHLIGHT, "panel"], [UiStyle.TOAST, "panel"], [UiStyle.SLOT, "panel"],
			[UiStyle.SLOT_ACTIVE, "panel"], [UiStyle.BAR_GOLD, "fill"], [UiStyle.BAR_COPPER, "fill"], [UiStyle.BAR_SKY, "fill"],
			[UiStyle.BAR_GOOD, "fill"], [UiStyle.BAR_WARN, "fill"], [UiStyle.BAR_BAD, "fill"]]:
		check(theme.has_stylebox(pair[1], pair[0]), "tema tem a variação %s" % pair[0])


func test_spacing_grid() -> void:
	for value in [UiStyle.SPACE_XS, UiStyle.SPACE_S, UiStyle.SPACE_M, UiStyle.SPACE_L, UiStyle.SPACE_XL]:
		check_eq(value % 4, 0, "espaçamento %d na grade de 4 px" % value)
	# Cenas: espaçamentos só com os valores da grade (0 = colado).
	var allowed := [0, UiStyle.SPACE_XS, UiStyle.SPACE_S, UiStyle.SPACE_M, UiStyle.SPACE_L, UiStyle.SPACE_XL]
	var pattern := RegEx.create_from_string("theme_override_constants/(?:[hv]_)?separation = (-?\\d+)")
	for path in _files("res://scenes/ui", ".tscn"):
		for found in pattern.search_all(FileAccess.get_file_as_string(path)):
			var value := int(found.get_string(1))
			check(value in allowed, "%s: espaçamento %d fora da grade 4/8/16/24/32" % [path, value])
	# Scripts: espaçamento sempre pelos tokens do UiStyle, nunca número solto.
	var literal := RegEx.create_from_string("\"(?:[hv]_)?separation\", [1-9]")
	for path in _files("res://scripts/ui", ".gd"):
		check(literal.search(FileAccess.get_file_as_string(path)) == null,
			"%s: espaçamento por token do UiStyle" % path)


static func _files(dir: String, extension: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(extension):
			found.append(dir.path_join(file))
	return found
