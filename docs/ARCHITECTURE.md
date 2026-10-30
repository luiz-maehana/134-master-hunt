# Arquitetura — 134 Master Hunt

Sistemas pequenos, comunicando-se por sinais. Regras de jogo ficam fora da interface e
fora dos modelos 3D; números de balanceamento ficam em arquivos `.tres` em `data/`.

## O mundo de moedas

Exatamente **R$ 134.000.000,00** em moedas estão no chão desde o início, espalhados por uma
versão caricata do Eixo Monumental de Brasília (49 × 7 quarteirões de 64 m, ~3,1 km × 0,45 km,
da Rodoviária ao Congresso; anda-se só entre a N2 e a S2, com muro e cenário além delas), e nunca reaparecem. Vencer = recolher tudo.
A unidade do mundo é o centavo: a quantidade de moedas (~170 milhões) sai do sorteio de cada
bloco e não é fixa.

```
CityLayout (puro, determinístico)  ── traçado: quarteirões, prédios, carros, árvores, bairros
        │
CoinWorld._allocate()              ── cada bloco de 16 m recebe uma fatia fixa do total:
        │                             peso = chão livre × riqueza do bairro; maiores restos
        │                             garantem soma EXATA de 13.400.000.000 centavos
        ▼
bloco perto do jogador  ──gera da semente──▶ pilhas (valor e tamanho pelo perfil do bairro;
                                             somam exatamente a fatia do bloco em centavos)
                         ──aplica──▶ GameState.world_state (o que já foi recolhido)
                         ──desenha──▶ um MultiMesh por bloco (pilhinhas de até 10)
bloco longe              ──▶ decalque de "tapete de moedas" com a densidade restante
```

- **Seis valores de moeda.** Cada pilha tem um valor (1, 5, 10, 25 ou 50 centavos ou R$ 1),
  sorteado da semente numa sequência à parte das posições (saves antigos continuam batendo).
  Contagem e valor andam juntos: `retirado do mundo` (moedas e centavos) = encontradas + bolso.
  Um shader desenha os seis com uma malha só: o valor vem do dado customizado do MultiMesh
  e escolhe a linha do atlas (`tools/build_coin_textures.gd`) e o tamanho da moeda.
- **Nenhum objeto por moeda.** Uma pilha é um número; perto do jogador ela é uma instância de
  MultiMesh: até 10 moedas do mesmo valor empilhadas (a maior pilha vale R$ 10). No Distrito
  Industrial são ~30 pilhas por m² (~300 mil carregadas ao redor do jogador, 160 FPS em
  1080p); a partir do segundo anel de blocos a moeda usa uma malha de 8 lados. Pilhas nascem
  numa grade de chão livre de 0,5 m (calculada uma vez por bloco) e buscas usam uma grade de
  2 m que para ao juntar moedas suficientes.
- **Streaming:** 7×7 blocos com pilhas ao redor do jogador (carregados aos poucos, 1 por
  quadro); até 19×19 com decalques; o resto não existe na memória.
- **Contagem única:** moedas só saem do mundo por `CoinWorld.take()`, que nunca devolve mais
  do que resta e registra a retirada no `GameState`. Invariante testada:
  `retirado do mundo = moedas encontradas + moedas no bolso`.
  A vara com ímã tira as moedas do mundo ao grudarem e só as põe no bolso quando volta; se o
  jogo salvar nesse meio-tempo, o save (bolso = retirado − encontrado) já as conta no bolso.
- **Save pequeno:** só os blocos tocados são salvos: `"cx,cz" → {r: moedas retiradas, v: valor,
  n: pilhas, b: restante de cada pilha}` (um byte por pilha, 255 = intocada, comprimido em zstd
  e base64; o save é a versão 3).
  Ao recarregar, o bloco é gerado de novo da semente e as retiradas são reaplicadas.

## Robôs e blocos frios

Robôs trabalham longe do jogador. Para isso o `CoinWorld` mantém blocos **frios**: pilhas
geradas da semente com o que já foi recolhido aplicado, sem desenho. Quando o jogador chega
perto, o mesmo bloco ganha desenho (não é gerado de novo), então o que aparece é exatamente
o que restou. `CoinWorld.take()` serve aos dois casos. Robôs depositam direto
(`GameState.collect_direct`), sem passar pelo bolso; a frota entrega a cada 0,5 s. Para não
engasgar, só um robô por quadro procura pilhas, e os blocos frios (7–15 ms cada num bairro
denso) são gerados numa thread do `WorkerThreadPool` (`CoinWorld.request_cold` → `ColdChunks`). A thread recebe
uma cópia das células livres e do que já foi recolhido do bloco e só lê dados imutáveis; o
resultado entra no quadro seguinte e é descartado se o bloco já existir por outro caminho ou se
algo foi recolhido dele depois da cópia, então a soma exata nunca depende da thread.

## Fluxo de uma moeda

```
CoinWorld (pilha) ──take(n)──▶ ferramenta ──▶ GameState.add_carried ──▶ bolso
Ponto de coleta ──▶ GameState.deposit ──▶ CoinLedger: total encontrado + dinheiro
```

## Responsabilidades

| Sistema | Arquivos | Papel |
|---|---|---|
| Economia | `scripts/core/coin_ledger.gd` | Regras puras com inteiros (centavos), sem nós. |
| Formatação | `scripts/core/money_format.gd` | `R$ 1.340.000,00`, `134.000.000`, `0,000001%`. |
| Estado da partida | `scripts/core/game_state.gd` (autoload) | Ledger, itens possuídos, estado do mundo, posição, save; sinais. |
| Salvamento | `scripts/core/save_game.gd` | JSON em `user://save.json` (versão 2), escrita atômica, validação campo a campo. |
| Preferências | `scripts/core/settings.gd` (autoload) | Sensibilidade, volume, tela cheia, antialiasing, qualidade gráfica (SSAO, brilho, sombras) e teclas remapeadas (só as diferentes do padrão vão para `user://settings.cfg`). |
| Teclas | `scripts/core/input_bindings.gd`, `scripts/ui/controls_panel.gd` | Lista das ações remapeáveis, nomes das teclas, troca com conflito (as duas ações trocam), predefinição canhoto. |
| Sons | `scripts/core/sfx.gd` (autoload) | Efeitos sintetizados em código ao iniciar; clique dos botões do Kenney UI Pack, ligado a todo botão que entra na árvore. |
| Tema da interface | `tools/build_ui_theme.gd` → `assets/ui/game_theme.tres` | Botões, abas, sliders e caixas do Kenney UI Pack, fonte Fredoka, variação `KeyButton` para a aba Controles. |
| Layout do HUD | `scripts/ui/hud.gd` (`_layout`), `scripts/core/settings.gd` (`apply_ui_scale`) | A interface segue a altura (1080 virtuais); a largura virtual varia com a proporção da tela e o rodapé se reorganiza. Testado em 7 resoluções (`test_ui_layout.gd`). |
| Opções de vídeo | `scripts/core/settings.gd` (PRESETS), `CoinWorld.configure`, `scripts/ui/options_panel.gd` | Predefinição ajusta efeitos, detalhe das moedas (malhas por número de lados, `CoinVisuals.mesh_with`), distância de visão e resolução 3D (FSR 2); medido por `tools/benchmark.gd`. |
| Carregamento | `scripts/ui/loading_screen.gd`, `CoinWorld.load_around_async` | Cena em thread, cidade, e as moedas em volta do jogador com 24 ms por quadro. Sem janela (testes), carrega tudo de uma vez. |
| Fachadas | `assets/shaders/building.gdshader` | Janelas, andares e térreo de loja procedurais nos prédios. |
| Dia e noite | `scripts/world/day_night.gd` | Ciclo de 20 min (GameState.time_of_day, salvo): sol/lua, céu, névoa, janelas e postes acesos (8 luzes reais nos postes mais próximos). Aplica a cada 0,5 s com o céu em modo incremental: mudar o céu a cada quadro custava ~16 ms. |
| Lanterna | `scripts/player/flashlight.gd` | SpotLight na câmera com o alcance da melhor lanterna comprada; passa posição e direção ao shader das moedas, que brilham dentro do facho. |
| Save | `scripts/core/save_game.gd`, `save_serializer.gd`, `world_record.gd` | Disco (com cópia `.bak` e limite de 64 MB), formato validado campo a campo, registro do que saiu do mundo. A assinatura da distribuição de moedas vai no save: se a cidade mudar, as moedas voltam ao chão e o jogador mantém dinheiro e itens. |
| Geração | `scripts/coins/chunk_generator.gd` | Parte pura do mundo de moedas: fatias exatas, chão livre e pilhas de cada bloco (determinística, roda em thread). |
| Traçado | `scripts/world/city_layout.gd`, `landmark_builder.gd`, `data/world/city.tres` | Eixo Monumental: gramado central sem ruas, avenidas N1/S1 largas, ministérios em lâminas de duas linhas, marcos em quarteirões fixos (`LANDMARKS`), bairros por retângulo ao longo do eixo e cercas nas bordas entre bairros. |
| Colisões dos marcos | `LandmarkBuilder._add_mesh_collisions` | Vértices de cada peça (já transformado), então nada atravessa a pirâmide, as colunas ou as cúpulas; só espelhos d'água e o pano da bandeira ficam sem colisão. |
| Vara (desenho) | `scripts/tools/rod_line.gd`, `rod_coin_effects.gd` | Linha, trajetória tracejada, moedas grudadas e voando, fora da lógica da vara. |
| Mundo | `scripts/world/world_definition.gd`, `district_definition.gd` + `data/world/city.tres` | Tamanho da cidade, total, bairros (densidade, pilhas, licença). |
| Traçado | `scripts/world/city_layout.gd` | Cidade determinística; chão livre (consulta e área). |
| Construção | `scripts/world/city_builder.gd` | Geometria por MultiMesh, um corpo físico por quarteirão, cercas, pontos de serviço. |
| Moedas | `scripts/coins/coin_world.gd` (fachada: busca, retirada, contas), `coin_chunk.gd` (pilhas de um bloco e o desenho delas), `chunk_streamer.gd` (o que carregar em volta do jogador), `cold_chunks.gd` (blocos frios dos robôs, em thread), `coin_carpet.gd` (tapete de longe), `district_tally.gd` (recolhido por bairro), `coin_visuals.gd` (malhas e textura) | Distribuição exata, streaming, busca e retirada. |
| Jogador | `scripts/player/player_controller.gd` | Estende o addon MIT: aceleração, sensibilidade, velocidade. |
| Interação (E) | `scripts/interaction/` | `Interactable` e `Interactor`. |
| Ferramentas | `scripts/tools/` + `data/tools/*.tres` | Mãos/luvas (mira), pás (área de perto), ímãs (cone de longe), vara com ímã (arremesso, atração no ponto de queda, recolhimento). |
| Loja | `scripts/shop/` + `data/shop/*.tres` | Itens, melhorias, licenças de bairro, regras puras de compra. |
| Portais | `scripts/world/portal.gd`, `scripts/ui/portal_menu.gd`, `assets/shaders/portal.gdshader` | Um arco por ponto de serviço (posição em `CityLayout.hubs[].portal`), ligado pelo item de efeito `PORTALS`; a tela lista as lojas dos bairros liberados e a viagem recarrega as moedas no destino. Não bloqueia moedas. |
| Automação | `scripts/automation/` + `data/automation/*.tres` | Robôs (várias unidades, preço crescente): recolhem num raio e depositam direto; a frota sincroniza com `GameState.robots` e entrega em lotes. |
| Interface | `scripts/ui/` + `scenes/ui/` | HUD (meta, marcos, bolso, seta até o depósito, % do bairro, frota), barra de ferramentas, pausa, loja, inventário. |
| Testes | `tests/` | Executor próprio, unitários e integração com a cidade real. |

## Desempenho (medido)

- Montar a cidade inteira: ~1,7 s (antes de usar um corpo físico por quarteirão eram ~30 s).
- Distribuir as 134 milhões entre 3.969 blocos: ~40 ms (área livre calculada geometricamente).
- Carregar os 49 blocos ao redor do jogador de uma vez (só ao iniciar ou teleportar): ~0,3 s
  na Rua do Começo, ~1,4 s no Distrito Industrial (~300 mil pilhas). Andando, um bloco novo
  por quadro (~7 ms no Industrial).
- Frota completa (22 robôs espalhados pela cidade): ~0,15 ms por quadro em média, pico de
  ~4 ms quando um robô procura uma área nova.

## Como estender

- **Nova versão de ferramenta**: novo `.tres` em `data/tools/` com o mesmo `slot_group`; incluir em
  `data/tools/catalog.tres` e, se vendida, em `data/shop/catalog.tres`.
- **Nova melhoria ou licença**: novo `UpgradeDefinition` em `data/shop/`.
- **Novo bairro / cidade maior**: editar `data/world/city.tres` (quarteirões, anéis, densidade,
  perfil de pilhas). O total continua exato.
