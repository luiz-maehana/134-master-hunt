class_name Achievements
extends RefCounted
## Conquistas dos segredos da cidade (sátira: personagens, partidos e manchetes são fictícios).
## id -> [título, como conseguir]. As ainda não conseguidas aparecem como "???" no inventário.

const LIST := {
	&"legendary_coin": ["Agora só faltam 133.999.999", "Achar a moeda lendária de 1 centavo."],
	&"democracy_loop": ["Democracia em Loop", "Votar 10 vezes na urna das promessas."],
	&"newsroom": ["Leitor de errata", "Ler as três versões de uma mesma manchete."],
	&"popcorn": ["Orçamento da pipoca", "Comprar pipoca com 1 centavo no cinema do Dark Horse."],
	&"complex_structure": ["Estrutura muito complexa", "Encontrar o Senhor V. três vezes."],
	&"three_hundred_pages": ["Contrato de 300 páginas", "Pedir a melhoria do Senhor V."],
	&"accountability": ["A prestação de contas", "Encontrar os R$ 134 milhões."],
}


static func title_of(id: StringName) -> String:
	return LIST[id][0] if LIST.has(id) else String(id)
