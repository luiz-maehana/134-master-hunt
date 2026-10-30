extends TestSuite
## Salvamento: ida e volta, arquivo ausente, corrompido, valores inválidos e versão antiga.
## Usa um arquivo próprio de teste; o save real do jogador nunca é tocado.

const TEST_PATH := "user://test_save.json"

var _saved_enabled: bool
var _saved_path: String


func before_all() -> void:
	_saved_enabled = GameState.save_enabled
	_saved_path = GameState.save_path
	GameState.save_path = TEST_PATH
	GameState.save_enabled = true


func after_all() -> void:
	SaveGame.delete(TEST_PATH)
	GameState.save_enabled = _saved_enabled
	GameState.save_path = _saved_path
	GameState.reset()


func test_round_trip_preserves_progress() -> void:
	GameState.reset()
	var ledger := GameState.ledger
	# 1234 moedas recolhidas e depositadas + 37 no bolso (todas saíram do mundo).
	GameState.record_world_take(Vector2i(31, 30), 4, 0, 1234, -1, 200)
	ledger.register_found(1234)
	GameState.record_world_take(Vector2i(31, 31), 2, 3, 37, -1, 150)
	ledger.add_carried(37)
	GameState.purchase(&"glove")
	GameState.purchase(&"pouch")
	GameState.select_variant(&"hands")
	GameState.player_position = Vector3(1.5, 0.1, -20.25)
	GameState.save_game()
	var money := ledger.money_cents
	GameState.reset()
	check_eq(GameState.world_removed, 0, "reset limpa a memória")
	GameState.load_game()
	ledger = GameState.ledger
	check_eq(ledger.total_coins_found, 1234, "moedas encontradas")
	check_eq(ledger.money_cents, money, "dinheiro")
	check_eq(ledger.carried_coins, 37, "moedas no bolso")
	check_eq(GameState.world_removed, 1234 + 37, "retirado do mundo")
	var rem: PackedByteArray = GameState.world_entry(Vector2i(31, 31)).get("rem", PackedByteArray())
	check_eq(rem.size(), 150, "restante de todas as pilhas do bloco")
	check(rem.size() == 150 and rem[2] == 3 and rem[0] == 255, "pilha tocada guarda o restante; as outras, intocadas")
	check(GameState.owns(&"glove") and GameState.owns(&"pouch"), "itens possuídos")
	check_eq(ledger.carry_capacity, 600, "efeito da pochete reaplicado")
	check_eq(GameState.tool_for_group(&"hands").id, &"hands", "variante escolhida")
	check_eq(GameState.player_position, Vector3(1.5, 0.1, -20.25), "posição do jogador")


func test_missing_file_starts_fresh() -> void:
	SaveGame.delete(TEST_PATH)
	GameState.ledger.register_found(50)
	GameState.load_game()
	check_eq(GameState.ledger.total_coins_found, 0, "sem save, partida nova")
	check_eq(GameState.owned_items, [&"hands"] as Array[StringName], "só as mãos")


func test_corrupted_file_starts_fresh() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ isto não é json ")
	file.close()
	GameState.load_game()
	check_eq(GameState.ledger.total_coins_found, 0, "save corrompido não quebra o jogo")
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	GameState.load_game()
	check_eq(GameState.ledger.money_cents, 0, "JSON que não é objeto é ignorado")


func test_old_version_restarts_with_notice() -> void:
	SaveGame.write(TEST_PATH, {"version": 1, "coins_found": 5000, "money_cents": 5000})
	GameState.pending_notice = ""
	GameState.load_game()
	check_eq(GameState.ledger.total_coins_found, 0, "save do modelo antigo não é aplicado")
	check(GameState.pending_notice != "", "jogador é avisado")
	GameState.pending_notice = ""


func test_invalid_values_are_sanitized() -> void:
	SaveGame.write(TEST_PATH, {
		"version": SaveGame.VERSION,
		"coins_found": -10,
		"money_cents": "muito",
		"carried_coins": 999_999,
		"owned": ["hands", "item_inventado", 42, "glove", "glove"],
		"selected": {"hands": "big_glove"},
		"world": {
			"1,2": {"r": 5, "n": 3, "b": WorldRecord.encode_piles(PackedByteArray([3, 255, 255]))},
			"lixo": {"r": 9},
			"3,4": "texto",
			"5,6": {"r": -7, "n": 2, "b": WorldRecord.encode_piles(PackedByteArray([255, 255]))},
			"7,8": {"r": 4, "n": 2, "b": "isto não é base64"},
			"9,9": {"r": 1, "n": 2, "b": WorldRecord.encode_piles(PackedByteArray([200, 1]))},
			"9,8": {"r": 1, "n": 9, "b": WorldRecord.encode_piles(PackedByteArray([1, 1]))},
		},
		"player_position": [1, "a", 3],
	})
	GameState.load_game()
	var ledger := GameState.ledger
	check_eq(ledger.total_coins_found, 0, "negativo vira 0")
	check_eq(ledger.money_cents, 0, "texto vira 0")
	check_eq(ledger.carried_coins, 5, "bolso = retirado do mundo - encontradas (não o valor salvo)")
	check_eq(GameState.owned_items, [&"hands", &"glove"] as Array[StringName], "só ids válidos, sem repetição")
	check_eq(GameState.tool_for_group(&"hands").id, &"glove", "seleção de item não possuído ignorada")
	check_eq(GameState.world_state.keys(), ["1,2", "5,6"], "blocos inválidos descartados")
	check_eq(GameState.world_entry(Vector2i(1, 2)).rem, PackedByteArray([3, 255, 255]), "restante das pilhas volta")
	check_eq(GameState.world_removed, 5, "retirada negativa vira 0")
	check_eq(GameState.player_position, null, "posição inválida ignorada")


func test_backup_recovers_corrupted_save() -> void:
	SaveGame.delete(TEST_PATH)
	GameState.reset()
	GameState.ledger.register_found(10, 500)
	GameState.save_game()
	GameState.ledger.register_found(5, 100)
	GameState.save_game()
	check(FileAccess.file_exists(SaveGame.backup_path(TEST_PATH)), "a segunda gravação guarda a anterior")
	# Simula o jogo fechando no meio da gravação: principal truncado.
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ \"version\": 4, \"coins_fo")
	file.close()
	GameState.load_game()
	check_eq(GameState.ledger.total_coins_found, 10, "cópia de segurança recupera a partida")
	SaveGame.delete(TEST_PATH)
	check(not FileAccess.file_exists(SaveGame.backup_path(TEST_PATH)), "apagar o save apaga a cópia")


func test_oversized_save_is_ignored() -> void:
	SaveGame.delete(TEST_PATH)
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([123]))
	file.seek(SaveGame.MAX_BYTES + 16)
	file.store_8(125)
	file.close()
	GameState.ledger.register_found(50)
	GameState.load_game()
	check_eq(GameState.ledger.total_coins_found, 0, "save gigante não é lido")
	SaveGame.delete(TEST_PATH)


func test_malformed_settings_are_ignored() -> void:
	var path := Settings.settings_path
	var test_path := "user://test_settings_bad.cfg"
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string("[input]\nmouse_sensitivity=\"muito\"\n[display]\nmsaa_index=99\nquality_index=-4\n[audio]\nvolume=7\n[controls]\njump=\"k27\"\nuse_tool=\"zzz\"\nmap=\"m999\"\n")
	file.close()
	Settings.settings_path = test_path
	Settings.load_settings()
	check(Settings.mouse_sensitivity >= Settings.MIN_SENSITIVITY and Settings.mouse_sensitivity <= Settings.MAX_SENSITIVITY, "sensibilidade válida")
	check(Settings.msaa_index < Settings.MSAA_OPTIONS.size() and Settings.quality_index >= 0, "índices limitados")
	check(Settings.volume <= 1.0, "volume limitado")
	check(InputBindings.key_code(InputBindings.binding_of(&"jump")) != KEY_ESCAPE, "Esc não vira tecla de ação")
	check(InputBindings.binding_of(&"use_tool") != null, "tecla inválida mantém a anterior")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	Settings.settings_path = path
	Settings.reset_bindings()


func test_changed_city_resets_coins_but_keeps_items() -> void:
	GameState.reset()
	GameState.check_world_signature("cidade-a")
	GameState.record_world_take(Vector2i(1, 1), 0, 2, 3, 300, 10)
	GameState.ledger.register_found(3, 300)
	GameState.purchase(&"glove")
	var money := GameState.ledger.money_cents
	GameState.check_world_signature("cidade-a")
	check_eq(GameState.world_removed, 3, "mesma cidade: registro mantido")
	GameState.pending_notice = ""
	GameState.check_world_signature("cidade-b")
	check_eq(GameState.world_removed, 0, "cidade nova: moedas voltam ao chão")
	check_eq(GameState.ledger.total_value_found_cents, 0, "progresso da meta recomeça")
	check_eq(GameState.ledger.money_cents, money, "dinheiro mantido")
	check(GameState.owns(&"glove"), "itens mantidos")
	check(GameState.pending_notice.contains("cidade mudou"), "jogador é avisado")
	var data := GameState.to_save()
	GameState.reset()
	GameState.apply_save(data)
	check_eq(GameState.world_signature, "cidade-b", "assinatura vai no save")
	GameState.pending_notice = ""
	GameState.record_world_take(Vector2i(1, 1), 0, 2, 3, 300, 10)
	GameState.check_world_signature("cidade-b|pilhas-1", "cidade-b")
	check_eq(GameState.world_removed, 3, "save do formato antigo: atualiza sem zerar")
	GameState.check_world_signature("cidade-b|pilhas-2", "cidade-b")
	check_eq(GameState.world_removed, 0, "sorteio das pilhas mudou: moedas voltam ao chão (com aviso), não só alguns blocos")
	GameState.reset()
