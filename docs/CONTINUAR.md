# Onde paramos — 134 Master Hunt

Resumo para retomar o desenvolvimento. Última atualização: 2026-10-30.

## Estado atual

- **Jogo completo e jogável:** meta de **R$ 134.000.000,00** em moedas, contados pelo valor (a
  quantidade de moedas é só curiosidade). A simulação de balanceamento dá ~7,5 h para zerar, e o
  alvo combinado é ~8 h. **Não reduzir as ferramentas** para alongar o jogo.
- **Mapa:** versão caricata do Eixo Monumental de Brasília, 49 × 7 quarteirões de 64 m. Anda-se só
  entre a N2 e a S2; há muro e cenário além delas.
- **Bairros em faixas de alto a baixo (oeste → leste):**

  | Bairro | Colunas | Densidade |
  |---|---|---|
  | Rodoviária | 2 | 14 moedas/m² |
  | Setor Cultural | 10 | 40/m² |
  | Esplanada dos Ministérios | 15 | 167/m² |
  | Congresso Nacional | 22 | 221/m² |

- **Testes:** 1018 verificações, 0 falhas.
  - Comando: `godot --headless --path . --script tests/run_tests.gd`
  - O teste de interface (`tests/integration/test_ui_layout.gd`) também deve ser rodado com
    janela de vez em quando.

## Como jogar o build

O Controle Inteligente de Aplicativos do Windows bloqueia o `.exe` exportado, porque ele não tem
assinatura. O jogo roda pelo atalho **"Jogar 134 Master Hunt"** (em `build/windows/` e na Área de
Trabalho), que abre o Godot instalado, que é assinado, com o pacote do jogo.

A cada ciclo de mudanças:

1. Exportar o pacote:
   `godot --headless --path . --export-pack "Windows Desktop" "build/windows/134 Master Hunt.pck"`
2. Abrir pelo atalho, conferir que roda, fechar.

## O que foi feito (spec `docs/SPEC_QUALIDADE.md`)

| Frente | Situação |
|---|---|
| 1. Revisão de código (segurança do save, código limpo) | Feita |
| 5. Mapa novo do Eixo Monumental | Feita, ajustada com a vista de satélite |
| 2. Interface e resoluções | Feita (escala pela altura, rodapé que se reorganiza, teste em 7 resoluções) |
| 4. Desempenho e opções de vídeo | Feita (predefinições, detalhe das moedas, distância de visão, FSR 2, VSync, limite de FPS, campo de visão, tela de carregamento, benchmark) |
| 6. Correções jogando | B1 (linha da vara sem limite) e B2 (moedas desenhadas ao alcance do ímã que não podiam ser puxadas) corrigidos |

Também feito depois da spec:
- HUD em cartões: Meta, Carteira, Equipamentos e o relógio com sol ou lua.
- Mão flutuante que fecha ao pegar moedas.
- Colisões dos marcos pelo formato real das peças.
- Gramado com shader procedural.
- Ímã de neodímio (4º ímã, passivo: puxa sozinho em volta enquanto equipado, alcance 16 m).
- Moedas "fantasma" com FSR 2 corrigidas: o MultiMesh das moedas é reenviado inteiro, nunca
  com `set_instance_transform` (com vetores de movimento só um dos dois buffers era atualizado).
- Assinatura do mundo inclui o sorteio das pilhas: blocos limpos nunca voltam cheios em silêncio
  numa atualização (save antigo é aceito sem zerar).

## O que falta

### Identidade visual e acabamento (frente 3 da spec)
- [x] Guia de estilo (`docs/STYLE_GUIDE.md`): todos os estilos no tema; teste `test_ui_style.gd` impede `StyleBox` em código.
- [x] Grade única de espaçamentos (4/8/16/24/32 px): cenas e scripts usam só os tokens do `UiStyle`; o teste reprova valor fora da grade.
- [x] Transições suaves ao abrir e fechar telas (`ScreenTransition`: esmaecer + som).
- [x] Abertura com o logo, que pode ser pulada (na tela inicial, só na primeira vez que o jogo abre; qualquer tecla ou clique pula).
- [x] Número da versão na tela inicial e nos créditos (`application/config/version` no `project.godot`).
- [x] Dinheiro "subindo" até o valor novo (`RollingValue`, meta e carteira do HUD).
- [x] Sons de interface: passar o mouse, abrir e fechar telas, erro (botão desativado ou compra recusada).
- [x] Opção "HUD mínimo" (Vídeo; só bolso, dica e avisos; a barra de ferramentas aparece ao trocar).
- [x] Créditos numa tela própria, com rolagem e seções (`CreditsScreen`, na tela inicial e no menu; os CC BY ficam lá).
- [x] Revisão dos textos: plural de "moeda" centralizado em `MoneyFormat.coins`, reticências "…", créditos em português, placeholder antigo "Rua do Começo" removido.

### Sobras técnicas
- [x] Montagem da cidade: a colisão dos marcos (casco convexo com limpeza do Godot) custava ~21 s com janela; sem a limpeza caiu para 0,12 s (`CityBuilder._ready` inteiro ~0,6 s). O que sobra é o primeiro desenho (~1,5 s, shaders e envio das malhas), atrás da tela de carregamento. Teste `test_landmarks_are_solid`.
- [x] `coin_world.gd` dividido (381 linhas): `CoinChunk`, `ChunkStreamer`, `ColdChunks`, `CoinCarpet`, `DistrictTally`.
- [x] Checklist "antes de publicar" no README + `tools/check_publish.sh` (varredura automática). Licença MIT adicionada; as imagens das moedas ficam (decisão do jogador, 2026-10-30).
- [x] Objetos que deixavam atravessar: placas de "Pare" e cones ganharam colisão (`THIN_PROP_RADII`, sem mudar o sorteio das moedas). O teste `test_every_street_object_is_solid` confere todo objeto de rua, árvore, carro e poste.
- [x] Traçado: marcos de vários quarteirões (Teatro, Museu, Catedral, Justiça, Itamaraty, Planalto, STF) ficam numa praça única, sem ruas internas entrando no prédio nem postes dentro (`CityLayout.merged_area`); pilares da Rodoviária só fora das pistas. Não muda o sorteio das moedas (assinatura do mundo igual; saves continuam valendo). Teste `test_landmarks_sit_on_plazas`.
- [x] Portais: um arco ao lado de cada loja (`Portal`, `CityLayout.PORTAL_OFFSET`), ligado pelo "Contrato dos portais" (R$ 5.000, efeito `PORTALS`); E abre `PortalMenu` com as lojas dos bairros liberados e a viagem tem esmaecer. Não bloqueia moedas (assinatura do mundo igual). Vitrine da Ferragem com os modelos reais das ferramentas.
- [x] Acabamento visual: ipês amarelos, roxos e brancos (~22% das árvores, escolhidos pela posição; `tree_tint.gdshader`), 368 bancos e 183 lixeiras nas beiras do gramado e nas praças (`CityLayout._add_furniture`, fora dos obstáculos de moeda), chuva de moedas no funil ao depositar (`CoinShower`) e faíscas nos portais ligados. Assinatura do mundo igual.
- [x] Otimização das moedas (GPU era o gargalo): malha indexada, terceiro nível de detalhe (4 lados a partir do 2º anel, `DISTANT_FROM`/`DISTANT_SIDES`) e malha detalhada só a poucos metros do jogador (distância real, `DETAIL_LEVELS[2]` em metros). Ultra no Congresso: 8,2 → 5,4 ms (122 → 184 FPS); triângulos 9,1 → 4,9 mi. `tools/benchmark.gd` agora mede sem VSync/limite e mostra GPU e CPU de desenho.
- [x] Mais detalhes: 18 pontos de ônibus nas avenidas, 89 hidrantes nas calçadas, metade das floreiras florida. Assinatura do mundo igual.
- [x] Menos chamadas de desenho: peças dos marcos juntadas por material (`LandmarkBuilder._merge_meshes`), detalhes das lojas e portais com distância de exibição (`HUB_VISIBLE`, `WARES_VISIBLE`), sem sombra para coisas rentes ao chão (`NO_SHADOW`). Rodoviária 1.026 → ~330 chamadas; CPU de desenho ~2 → ~1 ms.
- [x] Versão web e repositório público: https://github.com/luiz-maehana/134-master-hunt (commits com o e-mail privado do GitHub). Preset "Web" (Compatibility, sem threads), padrões leves no navegador (`Settings._web_defaults`), sem FSR 2 e sem botão Sair na web, blocos dos robôs gerados sem thread quando não há threads. `.github/workflows/build.yml`: testes → `check_publish.sh` → export Web → teste no navegador (`tests/web_smoke.js`, Playwright) → GitHub Pages (https://luiz-maehana.github.io/134-master-hunt/).
- [x] Segredos satíricos (`CityEasterEggs`, tudo fictício, nenhum nome real; fora do sorteio das moedas): moeda lendária ao pé do mastro, jornais que mudam de manchete em cada ponto de coleta, cartazes de 5 partidos inventados nos muros, urna das promessas (Esplanada), cartaz "Dark Horse: The Untold Budget" com máquina de pipoca de 1 centavo (muro norte do Setor Cultural), Senhor V. (banqueiro evasivo que muda de beco), final secreto da prancheta. 7 conquistas (`Achievements`, salvas em `GameState.extras`, lista no inventário). Segundo lote (`EscapeEasterEggs`, peças comuns em `EasterEggKit`): aeroporto "A Última Saída" (muro sul, Praça), fuga com esconderijo de malas (muro norte, Praça), Banco Central de Tudo (muro norte, Esplanada), Produções Milionárias (muro norte, Setor Cultural). Ímã de emendas: descartado pelo jogador. 11 conquistas.

### Para o jogador conferir jogando
- [ ] A mão fechando ao pegar (posição e inclinação).
- [ ] Os sons, que nunca foram ouvidos por quem os fez.
- [ ] O desempenho com a distância de visão mínima de 3 blocos na predefinição Baixa.
- [ ] O balanceamento real (a simulação dá ~7,5 h).

## Decisões que valem daqui para frente

- **Repositório público:** nunca versionar segredos, caminhos locais ou dados pessoais. Todo
  asset de terceiros entra em `ASSET_CREDITS.md`, com licença verificada. Os CC BY também vão na
  aba Créditos do jogo.
- **Arte:** low poly. A arte de capa atual fica.
- **Telas não pausam o jogo:** menu, loja, inventário e mapa só param o jogador
  (`GameState.screen_open`); robôs, HUD e relógio continuam.
- **Desempenho:** a distância de visão nunca fica abaixo do alcance da maior ferramenta
  (há teste para isso).
- **Ferramentas de apoio:**
  - `tools/ui_screenshots.gd`: capturas de todas as telas em várias resoluções.
  - `tools/benchmark.gd`: gera `docs/BENCHMARK.md`.
  - `tools/layout_plan.gd`: planta 2D do traçado (ruas, lotes, marcos, postes) para revisar a cidade.
  - `tools/check_publish.sh`: varredura antes de publicar.
  - `tests/balance_report.gd`: gera o relatório de `docs/BALANCE.md`.
  - `tools/build_*`: tema, ícones e texturas.

  As ferramentas de captura leem as preferências do jogador, como o Tamanho da interface.

## Documentos

- `README.md`: como jogar e rodar.
- `docs/ARCHITECTURE.md`: como o código está organizado.
- `docs/SPEC_QUALIDADE.md`: a spec desta etapa, com a situação de cada frente.
- `docs/BALANCE.md` e `docs/BENCHMARK.md`: números de balanceamento e desempenho.
- `ASSET_CREDITS.md`: créditos e licenças.
