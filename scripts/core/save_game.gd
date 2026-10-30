class_name SaveGame
extends RefCounted
## Leitura e escrita do save local (JSON em user://, fora do repositório).
## A validação do conteúdo fica em GameState.apply_save(); aqui só se garante que um
## arquivo ausente, gigante ou corrompido nunca impeça o jogo de iniciar.
##
## Cada gravação guarda o save anterior em `<save>.bak`. Se o principal estiver ilegível
## (ex.: o jogo fechou no meio da gravação), a leitura usa a cópia.

const DEFAULT_PATH := "user://save.json"
const VERSION := 4
## Um save real tem poucos MB; acima disso o arquivo é tratado como inválido.
const MAX_BYTES := 64 * 1024 * 1024


static func backup_path(path: String) -> String:
	return path + ".bak"


## Grava num temporário e troca: o save válido anterior vira a cópia de segurança.
static func write(path: String, data: Dictionary) -> bool:
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível salvar em %s (erro %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var backup := backup_path(path)
	if FileAccess.file_exists(path) and not _read_file(path).is_empty():
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		DirAccess.rename_absolute(path, backup)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temp_path, path) == OK


## Conteúdo do save, ou da cópia de segurança se o principal estiver ilegível; {} se nenhum.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(backup_path(path)):
		return {}
	var data := _read_file(path)
	if data.is_empty():
		data = _read_file(backup_path(path))
		if not data.is_empty():
			push_warning("Save principal ilegível; usando a cópia de segurança.")
	return data


static func delete(path: String) -> void:
	for target in [path, backup_path(path), path + ".tmp"]:
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)


static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		push_warning("Save ausente ou grande demais em %s; ignorado." % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Save inválido em %s." % path)
		return {}
	return parsed
