# Balanceamento — 134 Master Hunt

Gerado por `godot --headless --path . --script res://tests/balance_report.gd` a partir dos
arquivos de `data/`. Rode de novo depois de mudar preços ou parâmetros.

**É uma estimativa analítica, não uma medição.** Premissas: o jogador anda a 5 m/s, gasta
0,4 s reposicionando entre usos e 30 s de ida e volta até um ponto de coleta por bolso
cheio; ~80% do quarteirão é chão livre; robôs recolhem 80% do tempo (o resto é andar e
esperar o jogador levá-los a uma área nova). A partida simulada compra sempre o item
disponível mais barato. Jogando de verdade, conte com algo entre 1,5 e 2 vezes mais.

## Leitura rápida

- **Alvo: ~8 h para encontrar os R$ 134.000.000,00** (decidido pelo jogador). A simulação dá
  ~7,5 h no mapa do Eixo Monumental.
- **Riqueza por trecho do eixo (oeste → leste), densidade subindo:** Rodoviária (2 colunas)
  ~R$ 20 mil em moedinhas, 14 moedas/m²; Setor Cultural (10 colunas) ~R$ 1,3 milhão, 40/m²;
  Esplanada (15 colunas) ~R$ 31 milhões, 167/m²; Congresso e Praça dos Três Poderes (22 colunas)
  ~R$ 102 milhões, 221/m², 85% das moedas de R$ 1. A licença do Congresso pede R$ 6 milhões
  encontrados; itens acima de R$ 100 mil ficaram 1,5× mais caros.
- Primeira hora: mãos, luvas, pás, ímãs, licenças do Setor Cultural e da Esplanada e os primeiros
  robôs aspiradores (R$ 1 milhão em ~0,8 h).
- Meio (1–4 h): ímã e vara grandes, licença do Congresso, aspiradores industriais, carrinho
  motorizado, caçamba e o primeiro aspirador gigante (R$ 10 milhões em ~1,5 h).
- Fim (3–8 h): mais aspiradores gigantes (preço ×1,9 a cada unidade) e a Central de
  operações (R$ 50 milhões em ~3,6 h, R$ 100 milhões em ~6 h).
- Até o carrinho, o bolso limita a coleta manual. Depois, os robôs rendem cada vez mais,
  porque depositam sozinhos e não dependem do bolso.

## Parâmetros principais

| Onde | O quê |
|---|---|
| `data/world/city.tres` | valor total (centavos), tamanho da cidade, bairros (anéis, peso de riqueza, valores das moedas, perfil de pilhas, licença) |
| `data/tools/*.tres` | capacidade por uso, tempo, alcance, área, preço, requisitos |
| `data/automation/*.tres` | robôs: moedas/s, raio, unidades máximas, preço e crescimento do preço |
| `data/shop/*.tres` | preço, requisitos e efeito de melhorias, transporte e licenças |
| `scripts/core/game_state.gd` | `BASE_CARRY_CAPACITY` (bolso inicial) |
| `tests/balance_report.gd` | premissas da simulação (`ROBOT_EFFICIENCY`, `DEPOSIT_TRIP`...) |

## Relatório atual


## Bairros

| Bairro | Moedas | Área (m²) | Moedas/m² | Pilha média | Centavos por moeda |
|---|---|---|---|---|---|
| Rodoviária | 645.980 | 45.875 | 14.1 | 2 | 3.1 |
| Setor Cultural | 9.115.507 | 229.376 | 39.7 | 4 | 14.0 |
| Esplanada dos Ministérios | 57.561.397 | 344.064 | 167.3 | 7 | 53.8 |
| Congresso Nacional | 111.405.703 | 504.627 | 220.8 | 9 | 91.4 |

## Ritmo por ferramenta (moedas/min, já com viagens ao depósito)

| Ferramenta (bolso) | Rodoviária | Setor Cultural | Esplanada dos Ministérios | Congresso Nacional |
|---|---|---|---|---|
| Mãos vazias (100) | 52 | 52 | 52 | 52 |
| Luva de trabalho (500) | 280 | 468 | 468 | 468 |
| Luva grande (2.500) | 1.034 | 2.255 | 2.255 | 2.255 |
| Pá pequena (2.500) | 1.697 | 3.204 | 3.726 | 3.726 |
| Ímã pequeno (2.500) | 3.426 | 4.687 | 4.687 | 4.687 |
| Pá média (15.000) | 4.321 | 10.080 | 18.972 | 18.972 |
| Ímã médio (15.000) | 13.132 | 26.086 | 26.086 | 26.086 |
| Pá grande (15.000) | 6.767 | 14.372 | 29.508 | 29.508 |
| Ímã grande (15.000) | 20.304 | 28.844 | 33.802 | 33.802 |
| Vara com ímã pequeno (2.500) | 3.282 | 4.711 | 4.711 | 4.711 |
| Vara com ímã médio (15.000) | 9.659 | 18.552 | 24.489 | 24.489 |
| Vara com ímã grande (15.000) | 14.553 | 24.059 | 30.541 | 30.541 |

## Partida simulada (compra sempre o item disponível mais barato)

| Compra | Preço | Aos (h) | Moedas encontradas | Moedas/min depois |
|---|---|---|---|---|
| Luva de trabalho | R$ 1,00 | 0.01 | 37 | 127 |
| Pochete | R$ 2,50 | 0.03 | 133 | 272 |
| Tênis de corrida | R$ 7,50 | 0.04 | 405 | 291 |
| Luva grande | R$ 12,50 | 0.06 | 769 | 678 |
| Lanterna de bolso | R$ 30,00 | 0.09 | 1.787 | 678 |
| Licença: Setor Cultural | R$ 25,00 | 0.11 | 2.636 | 1.052 |
| Mochila | R$ 100,00 | 0.12 | 3.425 | 2.535 |
| Pá pequena | R$ 175,00 | 0.13 | 4.693 | 3.799 |
| Ímã pequeno | R$ 400,00 | 0.14 | 7.543 | 6.081 |
| Pá média | R$ 1.000,00 | 0.18 | 21.225 | 6.081 |
| Carrinho de transporte | R$ 2.000,00 | 0.21 | 31.867 | 15.328 |
| Robô aspirador #1 | R$ 1.750,00 | 0.22 | 43.364 | 16.288 |
| Licença: Esplanada dos Ministérios | R$ 2.000,00 | 0.24 | 59.652 | 27.312 |
| Lanterna tática | R$ 3.000,00 | 0.25 | 88.405 | 30.192 |
| Vara com ímã pequeno | R$ 7.000,00 | 0.28 | 128.546 | 33.072 |
| Robô aspirador #10 | R$ 13.038,52 | 0.30 | 188.344 | 35.952 |
| Ímã médio | R$ 15.000,00 | 0.32 | 215.309 | 52.024 |
| Carrinho motorizado | R$ 25.000,00 | 0.33 | 267.333 | 79.672 |
| Pá grande | R$ 35.000,00 | 0.35 | 327.088 | 111.366 |
| Baterias de lítio | R$ 50.000,00 | 0.36 | 438.454 | 116.166 |
| Vara com ímã médio | R$ 50.000,00 | 0.38 | 525.579 | 116.166 |
| Aspirador industrial #1 | R$ 90.000,00 | 0.40 | 699.830 | 122.286 |
| Ímã grande | R$ 330.000,00 | 0.64 | 2.653.556 | 226.132 |
| Holofote de capacete | R$ 450.000,00 | 0.80 | 4.922.604 | 238.372 |
| Aspirador industrial #8 | R$ 564.736,65 | 0.88 | 5.995.278 | 244.492 |
| Vara com ímã grande | R$ 1.350.000,00 | 1.05 | 8.501.322 | 244.492 |
| Licença: Congresso Nacional | R$ 450.000,00 | 1.23 | 11.251.858 | 244.492 |
| Caçamba sobre rodas | R$ 4.800.000,00 | 1.52 | 15.408.223 | 332.418 |
| Aspirador gigante #1 | R$ 13.500.000,00 | 2.26 | 30.200.837 | 340.338 |
| Central de operações | R$ 18.000.000,00 | 3.22 | 49.855.374 | 387.858 |

| Marco | Aos (h) |
|---|---|
| R$ 1.000.000,00 | 0.6 |
| R$ 10.000.000,00 | 1.5 |
| R$ 50.000.000,00 | 3.6 |
| R$ 100.000.000,00 | 5.9 |

**Tempo total para encontrar os R$ 134.000.000,00: ~7.5 h** (151.346.169 moedas; alvo: ~8 h).

