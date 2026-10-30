# Spec — Revisão de qualidade, interface, identidade visual e desempenho

**Projeto:** 134 Master Hunt (Godot 4.7.2, GDScript)
**Data:** 2026-10-29
**Situação:** proposta para aprovação. Nada aqui foi implementado ainda.

O jogo está completo e divertido. O balanceamento fica em ~8 h e não muda nesta etapa. O objetivo
agora é deixá-lo com cara de produto: código revisado e seguro para o repositório público, interface
correta em qualquer resolução, uma identidade visual consistente e opções de desempenho que
funcionem também em computadores mais fracos.

A etapa tem cinco frentes, feitas nesta ordem:

1. Revisão de código: segurança, robustez e código limpo (feita).
2. Mapa novo do Eixo Monumental (seção 5): vem antes porque muda o que as próximas medem.
3. Interface e resoluções (seção 2).
4. Identidade visual e acabamento (seção 3).
5. Desempenho e opções de vídeo (seção 4).

Cada frente termina com testes passando, o build exportado (pacote + atalho "Jogar") e um
relatório curto antes de seguir para a próxima.

---

## 1. Revisão de código

### 1.1 Como será feita

- Leitura de todos os 51 scripts (~7.400 linhas), com atenção maior aos maiores:
  `coin_world.gd` (697), `magnet_rod_tool.gd` (593), `game_state.gd` (469), `city_builder.gd` (444),
  `hud.gd` (321).
- Checklist por arquivo:
  - entrada externa validada;
  - erros tratados sem travar o jogo;
  - uma responsabilidade por classe;
  - funções curtas;
  - sem código duplicado;
  - tipagem estática;
  - nomes claros;
  - comentários que explicam o porquê.
- Ativar os avisos do GDScript para variáveis sem tipo e retornos não usados, e corrigir todos.
- Cada achado vira uma correção pequena com teste, ou fica registrado como decisão consciente.

### 1.2 Segurança e robustez

O jogo é offline e para um jogador só. As únicas entradas externas são o save (`user://save.json`),
as preferências (`user://settings.cfg`) e os assets do repositório.

| # | Achado preliminar | Proposta |
|---|---|---|
| S1 | `SaveGame.read` lê o arquivo inteiro sem limite de tamanho; um save gigante ou corrompido pode estourar a memória. | Recusar saves acima de um limite (ex.: 64 MB) e começar partida nova com aviso. |
| S2 | A gravação apaga o save antigo antes de renomear o novo. Se o jogo fechar nesse instante, a partida se perde. | Manter `save.json.bak` do último save válido e recuperar dele se o principal falhar. |
| S3 | O save é um JSON editável à mão (dá para mudar o dinheiro). | Aceito: jogo single-player, sem ranking. Documentar. Os valores continuam validados (sem negativos nem itens inexistentes). |
| S4 | As teclas e preferências do `settings.cfg` já são validadas. | Confirmar com testes de arquivos malformados. |
| S5 | Repositório público: sem segredos, caminhos locais ou dados pessoais. Já há um `.gitignore` cuidadoso. | Varredura final de todos os arquivos versionáveis e checklist de "antes de publicar" no README. |
| S6 | Os modelos GLB baixados são lidos em tempo de execução só pelas ferramentas de ícones (`tools/`), nunca pelo jogo. | Manter assim e documentar. |

### 1.3 Código limpo e SOLID

| # | Achado preliminar | Proposta |
|---|---|---|
| C1 | `GameState` acumula economia, itens, registro do mundo, serialização do save, robôs, hora do dia e estado de telas. | Separar em peças menores, como `SaveSerializer`, `Inventory` (itens e variantes) e `WorldRecord` (o que saiu do mundo). O `GameState` vira só a fachada. |
| C2 | `CoinWorld` faz alocação, geração, streaming, desenho, buscas e threads. | Extrair `ChunkGenerator` (geração pura, testável) e `ChunkVisuals` (MultiMesh). |
| C3 | `magnet_rod_tool.gd` mistura máquina de estados, física, desenho da linha e animações. | Separar o desenho (linha, mira, anel) num nó auxiliar. |
| C4 | `_collect` é idêntico em `hands_tool.gd` e `shovel_tool.gd`. | Mover para `GameTool`. |
| C5 | Estilos de painel criados em código em vários lugares (mapa, barra de ferramentas, linhas de menu, avisos), além do tema. | Tudo como variações do tema (`tools/build_ui_theme.gd`). Ver seção 3. |
| C6 | Funções com mais de 45 linhas: `_generate_block`, `_build_blocks`, `_build_props`, `_build_decor`, `_generate`, `CollectorRobot.work` e outras. | Quebrar em passos nomeados. |
| C7 | Acesso global por `X.current` (`CoinWorld`, `RobotFleet`, `DayNight`) espalhado pelo código. | Aceitável num jogo deste porte. Documentar a regra e injetar referências onde for barato. |
| C8 | Textos da interface escritos direto nos scripts. | Fora do escopo traduzir. Só centralizar os textos repetidos (nomes de teclas, avisos). |

### 1.4 Critérios de aceite

- Nenhum arquivo acima de ~400 linhas e nenhuma função acima de ~40 linhas, salvo exceção justificada.
- Zero avisos do GDScript com os avisos de tipagem ligados.
- Testes novos para S1, S2 e S4; a suíte inteira passando.
- Comportamento do jogo idêntico: mesmas pilhas, mesmos valores e o mesmo save compatível.

---

## 2. Interface e resoluções

**Situação: feito** (2026-10-29). Interface pela altura da tela (1080 virtuais × "Tamanho da interface"
80–130%, aba Vídeo), rodapé que se reorganiza com a largura (barra centrada, à esquerda, encolhida
ou acima do bolso), equipamentos só com ícones, fonte mínima de 16 px, logo da capa sempre inteiro.
Teste `tests/integration/test_ui_layout.gd` (7 resoluções e 2 tamanhos) e capturas com
`tools/ui_screenshots.gd`. Não feito: grade de espaçamento única e "HUD mínimo" (vão para a frente 3).

### 2.1 Situação medida

Capturas de título, HUD, loja, inventário, mapa e menu em 1024×768 (4:3), 1280×720, 1920×1200
(16:10) e 2560×1080 (21:9):

| # | Problema | Onde |
|---|---|---|
| U1 | A interface foi desenhada para 1920×1080 e escala pela **largura**. Em 4:3 tudo fica com 53% do tamanho, e textos de 12–15 px viram 6–8 px. | Todas as telas em 4:3; mais leve em 1280×720 |
| U2 | A barra de ferramentas encosta no painel de status e cobre a linha de ajuda (teclas). | HUD em 4:3 e 1280×720 |
| U3 | Textos pequenos demais: nomes dos equipamentos (12 px), ajuda (15 px), legenda do mapa (15 px). | HUD, mapa |
| U4 | Em 4:3 a arte da capa é cortada e o logo perde o "1" e o "M". | Tela inicial |
| U5 | O painel de estatísticas cresce sem limite conforme os equipamentos aumentam. | HUD |
| U6 | Não há margem de segurança fixa: cada painel define as suas distâncias das bordas. | HUD |
| U7 | A janela mostra "(DEBUG)" no título quando aberta pelo atalho. | Janela |

### 2.2 Regras que passam a valer

- **Escala da interface pela altura da tela**, com base em 1080p, e sem encolher a menos de 0,75.
  Em telas estreitas os painéis se reorganizam em vez de encolher.
- **Opção "Tamanho da interface"** na aba Vídeo: 80% a 130%.
- **Margem de segurança** de 24 px (em 1080p) para todo o HUD, numa constante só.
- **Grade de espaçamento** de 4/8/16/24 px; nada de valores soltos.
- **Fonte mínima** de 16 px em 1080p, e corpo de texto de 18–20 px.
- **Zonas do HUD sem sobreposição:**
  - superior esquerda: progresso;
  - superior direita: avisos, no máximo 4 visíveis;
  - centro superior: nome do bairro;
  - centro inferior: dica e barra de ferramentas;
  - inferior direita: bolso e destino.

  A barra encolhe ou quebra antes de invadir outra zona.
- **Equipamentos** viram uma faixa compacta só de ícones, com o nome ao passar o mouse no inventário,
  ou uma linha rolável. O painel deixa de crescer.
- **Capa:** o logo fica sempre inteiro. A arte é ancorada no logo e as laterais são cortadas, não o logo.

### 2.3 Como verificar

- Script de captura automática (`tools/ui_screenshots.gd`) que abre cada tela em 1024×768, 1280×720,
  1366×768, 1920×1080, 1920×1200, 2560×1080 e 3840×2160, e salva tudo numa pasta.
- Teste automático que confere, em cada resolução: nenhum painel do HUD se sobrepõe, todos ficam
  dentro da tela e nenhum texto fica abaixo do tamanho mínimo.

### 2.4 Critérios de aceite

Todas as telas legíveis e sem sobreposição nas 7 resoluções, conferidas nas capturas e pelo teste.

---

## 3. Identidade visual e acabamento

O tema atual (Kenney UI Pack + Fredoka, painéis escuros com borda dourada) é a base. A proposta é
consolidá-lo num guia e aplicá-lo em tudo.

### 3.1 Guia de estilo (`docs/STYLE_GUIDE.md`)

- **Paleta com nome e papel:**
  - ouro `#FFC733`: destaque e ação;
  - verde: dinheiro e "ok";
  - azul: informação do bairro;
  - laranja: aviso;
  - vermelho: erro;
  - três tons de fundo.
- **Escala de tipos:** título, subtítulo, corpo, legenda, todos em Fredoka.
- **Componentes:** painel, botão primário, botão secundário (tecla), aviso, barra de progresso,
  linha de item, ícone. Cada um vira uma variação do tema, sem estilos criados em código.
- **Ícones:** um estilo só (Kenney Game Icons, brancos) para as interfaces, e os ícones 3D gerados para os itens.

### 3.2 Acabamento

| # | Item |
|---|---|
| P1 | Transições: telas entram e saem com um fade e um leve deslize (0,15 s); botões reagem ao passar o mouse. |
| P2 | Tela de carregamento ao entrar no jogo ou trocar de área. Hoje a carga inicial trava ~1 s com a tela parada. |
| P3 | Abertura curta com o logo antes do menu, que pode ser pulada. |
| P4 | Número da versão na tela inicial e nos créditos. |
| P5 | Números grandes animados ao mudar (o dinheiro "sobe" até o valor novo), sem atrasar a informação. |
| P6 | Sons de interface consistentes: passar o mouse, abrir e fechar tela, erro (ex.: compra sem dinheiro). |
| P7 | Opção "HUD mínimo", que deixa só o dinheiro, o bolso e a barra de ferramentas. |
| P8 | Créditos em formato de tela própria (rolagem e seções), não só texto corrido. |
| P9 | Revisão de todos os textos: tom, acentuação, singular/plural e números formatados. |

### 3.3 Critérios de aceite

- Nenhum estilo visual definido fora do tema.
- Todas as telas seguem o guia.
- Capturas de antes e depois de cada tela no relatório.

---

## 4. Desempenho e opções de vídeo

**Situação: feito** (2026-10-29). Predefinições Baixa/Média/Alta/Ultra; opções de detalhe das moedas
(10, 16 ou 24 lados de perto), distância de visão (3, 4 ou 5 blocos; nunca menos que o alcance do ímã e da vara), resolução 3D com FSR 2, VSync,
limite de FPS e campo de visão; tela de carregamento (cena em thread, moedas aos poucos); benchmark
em `tools/benchmark.gd` → `docs/BENCHMARK.md`. No Congresso, a Baixa desenha 2,2 mi de triângulos
contra 6,6 mi da Alta e 8,8 mi da Ultra. Fica um quadro de ~1,3 s montando a cidade, agora atrás da
tela de carregamento (dividir a montagem fica para depois).

### 4.1 Situação medida

Distrito Industrial, 1080p, RTX 5070, ~191 mil pilhas carregadas:

| Qualidade | FPS | Draw calls | Triângulos | VRAM | RAM |
|---|---|---|---|---|---|
| Baixa | 165 | 1.005 | 5,16 mi | 504 MB | 220 MB |
| Média | 169 | 984 | 5,15 mi | 555 MB | 220 MB |
| Alta | 147 | 1.222 | 5,17 mi | 645 MB | 220 MB |

Outras medidas:
- De noite, com postes e lanterna: ~140 FPS.
- Pior quadro: ~9 ms.
- Entrar no jogo ou se teletransportar trava ~1 s (`load_around`).

**Conclusão:** as qualidades atuais mudam só sombra de contato, brilho e sombras, e quase não mexem
no FPS. O custo real é a **geometria das moedas** (~5 milhões de triângulos por quadro), que nenhuma
opção controla hoje. Numa placa mais fraca ou num vídeo integrado, é isso que vai derrubar o jogo.

### 4.2 Otimizações

| # | Item | Efeito esperado |
|---|---|---|
| O1 | Níveis de detalhe das moedas: malha de 24 lados só bem perto, de 8 lados no meio e um "tapete" (decalque ou impostor) longe. | Menos triângulos |
| O2 | Alcance de visão das moedas ajustável (blocos carregados ao redor). | Menos pilhas, triângulos e memória |
| O3 | Pilhas de 1 moeda desenhadas mais simples que as altas. | Menos triângulos |
| O4 | Carregamento inicial e após teletransporte em segundo plano, com tela de carregamento (ver P2). | Sem a trava de ~1 s |
| O5 | Revisar sombras: só o que está perto do jogador projeta sombra das moedas. | Menos draw calls de sombra |
| O6 | Script de benchmark (`tools/benchmark.gd`): percurso fixo por todos os bairros, de dia e de noite, em cada predefinição. Grava FPS médio, pior quadro, draw calls, triângulos e memória num `.md`. | Medidas repetíveis antes e depois |

### 4.3 Opções de vídeo novas

A aba Vídeo ganha:

| Opção | Valores |
|---|---|
| Predefinição | Baixa / Média / Alta / Ultra / Personalizada (ajusta tudo abaixo de uma vez) |
| Escala de renderização | 50–100%, com AMD FSR 2.2 (ganho grande em placas fracas) |
| Detalhe das moedas | Baixo / Médio / Alto (O1, O3) |
| Distância de visão | Normal / Longa / Muito longa (O2; mínimo de 3 blocos) |
| Sombras | Desligadas / Baixas / Altas |
| Sombra de contato (SSAO) e brilho | Ligado / Desligado, separados |
| VSync | Ligado / Desligado |
| Limite de FPS | 30 / 60 / 120 / 144 / ilimitado |
| Campo de visão (FOV) | 70–100° |
| Tamanho da interface | 80–130% (ver seção 2) |

Todas ficam salvas e se aplicam na hora, sem reiniciar.

### 4.4 Metas

| Hardware | Predefinição | Meta |
|---|---|---|
| Placa intermediária (classe GTX 1650), 1080p | Média | 60 FPS no Distrito Industrial |
| Vídeo integrado, 720p | Baixa, escala 75% | 30 FPS jogável |
| RTX 5070, 1080p | Alta | ≥ 144 FPS |

Também:
- pior quadro abaixo de 25 ms em qualquer predefinição;
- sem trava visível ao entrar no jogo.

Sem acesso a placas mais fracas, a verificação será aproximada: escala de renderização reduzida,
limite de FPS e contagem de triângulos e draw calls, comparados com metas por predefinição.

---

## 5. Mapa novo: Eixo Monumental, da Rodoviária ao Congresso

**Situação: feito** (2026-10-29). Depois, ajustado pelo jogador com a vista de satélite: bairros em faixas de alto a
baixo (Rodoviária 2 colunas, Setor Cultural 10, Esplanada 15, Congresso 22), área andável só entre
a N2 e a S2 (barreira e cenário além delas), quarteirões de 64 m e densidade subindo para o leste. Conferido com fotos aéreas de referência da Wikimedia Commons (só
consulta, nenhuma imagem entra no projeto): ministérios como lâminas compridas de vidro verde com
pontas brancas, a fonte ao lado da Torre de TV, as torres coladas do Congresso.

Pedido do jogador (2026-10-29): trocar a cidade quadrada genérica por uma versão caricata, em low
poly, da **Esplanada dos Ministérios**. O mapa fica comprido e estreito, e o jogador avança de oeste
para leste até o Congresso Nacional, onde está o dinheiro. Tudo bem perder o progresso local: saves
antigos recomeçam com aviso (a assinatura da cidade muda; ver frente 1).

### 5.1 Traçado

| Trecho (oeste → leste) | Bairro do jogo | O que tem | Riqueza |
|---|---|---|---|
| Plataforma da Rodoviária e Torre de TV | Rua do Começo | Rodoviária, camelôs, ponto de ônibus; início da partida | Moedas miúdas |
| Setor Cultural | Centro | Catedral (hiperboloide de colunas), Museu Nacional (cúpula), Biblioteca, Teatro Nacional (pirâmide) | Baixa |
| Esplanada dos Ministérios | Ministérios | 17 blocos iguais de cada lado, gramado central largo, espelhos d'água | Média |
| Congresso e Praça dos Três Poderes | Congresso | Duas torres com as cúpulas (côncava e convexa), Itamaraty e Justiça (arcos e espelhos d'água), Planalto, STF, Panteão e bandeira | Alta: a maior parte do dinheiro |

- **Vias:** o Eixo Monumental com as duas pistas largas (N1 ao norte, S1 ao sul), o gramado central
  entre elas, as vias de acesso aos ministérios em "pente", o retorno em volta do Congresso e a
  passagem sob a plataforma da Rodoviária. As faixas, as calçadas e os postes seguem esse desenho.
- **Proporção:** cerca de 2,4 km × 0,6 km, numa escala comprimida (o real tem uns 2 km só da
  Rodoviária ao Congresso). As medidas finais saem do teste de caminhada e do balanceamento.
- **Licenças:** cercas atravessando o eixo de lado a lado (norte–sul), em vez de anéis.
- **Pontos de coleta e lojas:** distribuídos ao longo do eixo, mais densos nos trechos largos.
- **Arquitetura:** caricata e reconhecível, nunca cópia exata. Prédios feitos de primitivas com o
  shader de fachada; os marcos (Catedral, Congresso, Itamaraty, Planalto) ganham modelos próprios de
  baixa contagem de polígonos. Sem brasões ou logotipos oficiais.

### 5.2 O que muda no código

- `CityLayout` deixa de ser uma grade quadrada de anéis e passa a ler um traçado descrito em dados
  (`data/world/esplanada.tres`): trechos ao longo do eixo, faixas de vias, lotes e marcos.
- `CoinWorld` e `ChunkGenerator` passam a aceitar mundo retangular (blocos em x e z diferentes); a
  regra da soma exata de R$ 134 milhões continua igual.
- Bairros por trecho do eixo, e não por anel; mapa (M), cercas e "% recolhido" acompanham.
- O minimapa fica horizontal, no formato do eixo.
- Balanceamento: refazer a simulação para manter as ~8 h.

### 5.3 Critérios de aceite

- Reconhecível como a Esplanada numa vista aérea: eixo, gramado, ministérios em fila e Congresso
  no fim.
- Caminhar de ponta a ponta sem atravessar prédio nem cair do mapa; ruas com faixas e calçadas.
- Soma exata do dinheiro mantida (teste), saves antigos recomeçam com aviso.
- Desempenho igual ou melhor que o atual (benchmark da frente 4).

---

## 6. Correções encontradas jogando

| # | Problema | Situação |
|---|---|---|
| B1 | Vara com ímã: com o ímã no chão, o jogador podia andar para longe e a linha esticava sem limite. | **Corrigido** (frente 1): a linha tem até 1,25× o alcance da vara; passou disso, a vara recolhe sozinha (com o que grudou) e avisa. Teste em `test_magnet_rod.gd`. |
| B2 | Com a distância de visão "Curta" (2 blocos), o "tapete" de moedas desenhado além dos blocos carregados ficava ao alcance do ímã e da vara (40 m): moedas que apareciam no chão, piscando, e não podiam ser puxadas. | **Corrigido**: mínimo de 3 blocos (48 m), com teste que compara com o alcance da maior ferramenta. Moedas voando até o ímã também passaram a se apagar sozinhas se o ímã sumir (`CoinFlight`). |

---

## Fora do escopo

- Balanceamento: fica em ~8 h, como decidido.
- Mecânicas novas, conteúdo novo e tradução para outros idiomas.
- Arte de capa nova: a atual continua.
- Assinatura digital do executável. O jogo segue abrindo pelo atalho "Jogar", porque o Controle
  Inteligente de Aplicativos bloqueia executáveis sem assinatura.

## Entregáveis

1. Código revisado, com as correções de S1–S6 e C1–C8 e testes novos.
2. `tools/ui_screenshots.gd`, `tools/benchmark.gd` e o teste de layout em várias resoluções.
3. `docs/STYLE_GUIDE.md` e o tema atualizado.
4. Opções de vídeo novas e as otimizações O1–O6.
5. Um relatório por frente, com capturas e números de antes e depois.
6. Build exportado (pacote + atalho "Jogar") ao fim de cada frente.
