class_name ItemIcons
extends RefCounted
## Ícone de qualquer item da loja: ferramentas (tools/build_tool_icons.gd) e os demais
## (tools/build_item_icons.gd). Null se o item não tiver ícone.

const DIRS := ["res://assets/ui/tool_icons/", "res://assets/ui/item_icons/"]


static func of(id: StringName) -> Texture2D:
	for dir: String in DIRS:
		var path := dir + "%s.png" % id
		if ResourceLoader.exists(path):
			return load(path)
	return null
