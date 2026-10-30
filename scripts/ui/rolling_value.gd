class_name RollingValue
extends RefCounted
## Número exibido que "sobe" (ou desce) até o valor real em vez de pular: cada mudança é
## percorrida em DURATION segundos, em ritmo constante. O primeiro valor aparece direto.

const DURATION := 0.5

var target := 0
var shown := 0.0
var _rate := 0.0
var _started := false


func set_target(value: int) -> void:
	if not _started:
		_started = true
		shown = value
	target = value
	_rate = absf(target - shown) / DURATION


## Avança `delta` segundos. Retorna true se o valor exibido mudou.
func step(delta: float) -> bool:
	if shown == target:
		return false
	shown = move_toward(shown, target, maxf(_rate * delta, 1.0))
	return true


func value() -> int:
	return roundi(shown)
