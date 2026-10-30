# Guia de estilo da interface — 134 Master Hunt

Como a interface deve parecer e onde cada coisa é definida. A regra principal: **estilos só no
tema**. Cenas e scripts escolhem uma variação pelo nome e nunca criam `StyleBox` próprio. O teste
`tests/unit/test_ui_style.gd` falha se alguém fizer isso.

## Onde fica cada coisa

| O quê | Onde |
|---|---|
| Cores, espaçamentos, raios e nomes das variações | `scripts/ui/ui_style.gd` (`UiStyle`) |
| Estilos (painéis, barras, botões, abas, sliders) | tema `assets/ui/game_theme.tres`, gerado por `tools/build_ui_theme.gd` |
| Aplicação global do tema | `project.godot` → `gui/theme/custom` |

Para mudar um estilo: altere `UiStyle` ou o gerador e refaça o tema:

```
godot --headless --path . --script res://tools/build_ui_theme.gd
```

O `.tres` gerado vai para o repositório; não edite à mão.

## Paleta

| Token | Cor | Uso |
|---|---|---|
| `INK` | `#12141A` | fundo dos painéis (com transparência de 0,85 a 0,95) |
| `INK_RAISED` | `#1F2129` | linhas de lista, conteúdo das abas |
| `GOLD` | `#FFC733` | marca: títulos, bordas fortes, barra da meta, item ativo |
| `GOLD_SOFT` / `GOLD_FAINT` | dourado a 55% / 30% | bordas dos painéis / das caixas inativas |
| `DARK_TEXT` | `#472E0A` | texto e ícones sobre os botões amarelos |
| `MUTED` | branco a 70% | legendas, rodapés, textos de apoio |
| `GOOD` | `#73E680` | dinheiro, efeitos de itens, bolso com espaço |
| `WARN` | `#FFCC40` | bolso quase cheio |
| `BAD` | `#FF6152` | bolso cheio, requisito que falta |
| `COPPER` / `SKY` | `#D98059` / `#8CD9FF` | barras do próximo marco / do bairro |

Dourado é a cor da marca e indica "o que importa agora". Use com moderação: um título por
painel e o item selecionado.

## Grade de espaçamentos

Tudo em múltiplos de 4 px, medidos na tela de 1080 px de altura (a interface escala pela
altura, então os números valem em qualquer resolução):

| Token | px | Uso típico |
|---|---|---|
| `SPACE_XS` | 4 | entre ícone e texto colados, borda de destaque |
| `SPACE_S` | 8 | entre linhas de um cartão, margem vertical de pílulas e avisos |
| `SPACE_M` | 16 | margem interna de cartões e linhas, entre elementos de uma tela |
| `SPACE_L` | 24 | margem vertical das janelas, distância entre grupos |
| `SPACE_XL` | 32 | margem horizontal das janelas |

A margem de segurança da tela é 24 px (`HUD.SAFE_MARGIN`).

## Raios

`RADIUS_S` 4 (barras) · `RADIUS_M` 8 (linhas, avisos) · `RADIUS_L` 12 (cartões, janelas,
caixas) · `RADIUS_PILL` 20 (relógio, dica).

## Tipografia

Fonte única: **Fredoka** (peso 500), tamanho padrão 20. Escala usada:

| Tamanho | Uso |
|---|---|
| 56 | título dos créditos |
| 30–34 | título de janela e seção |
| 26 | título de linha (item da loja), valor da Meta |
| 22–24 | botões principais, avisos |
| 18–20 | corpo de texto, descrições |
| 16 | mínimo absoluto (legendas, rodapés); o teste de layout reprova menos que isso |

## Componentes (variações do tema)

Todos com `theme_type_variation = &"<nome>"` (em código, as constantes de `UiStyle`).

| Variação | Base | Onde |
|---|---|---|
| `Card` | PanelContainer | cartões do HUD (Meta, Carteira, Equipamentos, bolso); com sombra |
| `Pill` | PanelContainer | relógio, dica de ação |
| `WindowPanel` | PanelContainer | loja, inventário, menu, mapa, menu da tela inicial, opções |
| `WindowGold` | PanelContainer | tela de vitória |
| `Row` / `RowHighlight` | PanelContainer | linha de lista nas telas; a destacada é a de item já possuído |
| `Toast` | PanelContainer | avisos no canto, com faixa dourada à esquerda |
| `Slot` / `SlotActive` | PanelContainer | caixas da barra de ferramentas |
| `BarGold`, `BarCopper`, `BarSky` | ProgressBar | meta, próximo marco, bairro (e carregamento) |
| `BarGood`, `BarWarn`, `BarBad` | ProgressBar | bolso: com espaço, quase cheio, cheio |
| `KeyButton` | Button | tecla na aba Controles |

Botões, abas, caixas de seleção e sliders já vêm prontos do tema (Kenney UI Pack): botão
amarelo com texto `DARK_TEXT`; desativado em cinza.

## Movimento e som

- Telas abrem e fecham com `ScreenTransition` (esmaecer de 0,14 s / 0,1 s e som de interface).
  Telas novas devem usar o mesmo.
- Números de dinheiro que mudam usam `RollingValue` (0,5 s até o valor novo).
- Sons de interface (clique, passar o mouse, abrir/fechar, erro) estão no autoload `Sfx`; todo
  botão ganha clique e passar o mouse automaticamente.

## O que ainda não segue o guia

- Tamanhos e cores de **texto** ainda são definidos por cena ou script
  (`theme_override_font_sizes`, `MenuScreen.make_label`). O próximo passo seria criar variações
  de `Label` (título, corpo, legenda) e trocar as cores soltas pelos tokens de `UiStyle`.
- O mapa (`MapMenu`) desenha com cores próprias (bairros, ruas), o que é esperado num desenho.
