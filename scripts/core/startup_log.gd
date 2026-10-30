class_name StartupLog
extends RefCounted
## Linha do tempo do carregamento, só na versão web (console do navegador): quanto cada etapa
## segurou a página. Lá não há threads, e uma etapa longa demais faz o navegador oferecer
## "fechar a página".

static var _last := 0


static func mark(step: String) -> void:
	if not OS.has_feature("web"):
		return
	var now := Time.get_ticks_msec()
	print("[carga] %s: %d ms (t=%.1f s)" % [step, now - _last if _last > 0 else 0, now / 1000.0])
	_last = now
