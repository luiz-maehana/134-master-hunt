extends SceneTree
## Gera build/windows/134 Master Hunt.ico (ícone do atalho "Jogar") a partir do icon.svg.
## ICO com PNG dentro (aceito pelo Windows desde o Vista).
##   godot --headless --path . --script res://tools/build_launcher_icon.gd

const OUT := "res://build/windows/134 Master Hunt.ico"


func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://icon.svg"))
	image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	var png := image.save_png_to_buffer()
	var ico := PackedByteArray()
	ico.resize(22)
	ico.encode_u16(0, 0)       # reservado
	ico.encode_u16(2, 1)       # tipo: ícone
	ico.encode_u16(4, 1)       # uma imagem
	ico.encode_u8(6, 0)        # largura 256 (0)
	ico.encode_u8(7, 0)        # altura 256 (0)
	ico.encode_u8(8, 0)
	ico.encode_u8(9, 0)
	ico.encode_u16(10, 1)      # planos
	ico.encode_u16(12, 32)     # bits por pixel
	ico.encode_u32(14, png.size())
	ico.encode_u32(18, 22)     # onde começa o PNG
	ico.append_array(png)
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	file.store_buffer(ico)
	file.close()
	print("Ícone salvo em %s" % OUT)
	quit()
