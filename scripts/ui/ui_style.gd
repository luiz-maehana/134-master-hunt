class_name UiStyle
## Tokens da identidade visual (ver docs/STYLE_GUIDE.md): paleta, grade de espaçamentos, raios e
## os nomes das variações do tema. Os estilos em si (StyleBox) ficam só no tema, gerado por
## tools/build_ui_theme.gd a partir destes valores; cenas e scripts usam `theme_type_variation`.

# --- Paleta --------------------------------------------------------------------------------
## Fundo dos painéis (quase preto azulado) e das linhas/abas, um tom acima.
const INK := Color(0.07, 0.08, 0.1)
const INK_RAISED := Color(0.12, 0.13, 0.16)
## Dourado da marca: títulos, bordas, destaques, barra da meta.
const GOLD := Color(1, 0.78, 0.2)
const GOLD_SOFT := Color(1, 0.78, 0.2, 0.55)
const GOLD_FAINT := Color(1, 0.78, 0.2, 0.3)
## Marrom do texto sobre os botões amarelos.
const DARK_TEXT := Color(0.28, 0.18, 0.04)
## Texto secundário (legendas, rodapés).
const MUTED := Color(1, 1, 1, 0.7)
## Estados: bom (dinheiro, efeito), atenção, ruim (bolso cheio, requisito faltando).
const GOOD := Color(0.45, 0.9, 0.5)
const WARN := Color(1.0, 0.8, 0.25)
const BAD := Color(1.0, 0.38, 0.32)
## Cores das barras de progresso: marco (cobre) e bairro (azul).
const COPPER := Color(0.85, 0.5, 0.3)
const SKY := Color(0.55, 0.85, 1)

# --- Grade de espaçamentos (px na tela de 1080 de altura) ----------------------------------
const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 16
const SPACE_L := 24
const SPACE_XL := 32

# --- Raios ---------------------------------------------------------------------------------
const RADIUS_S := 4
const RADIUS_M := 8
const RADIUS_L := 12
const RADIUS_PILL := 20

# --- Variações do tema ---------------------------------------------------------------------
## PanelContainer.
const CARD := &"Card"                ## cartões do HUD
const PILL := &"Pill"                ## relógio, dica de ação
const WINDOW := &"WindowPanel"       ## loja, inventário, menu, mapa, tela inicial
const WINDOW_GOLD := &"WindowGold"   ## vitória
const ROW := &"Row"                  ## linha de lista nas telas
const ROW_HIGHLIGHT := &"RowHighlight"
const TOAST := &"Toast"              ## avisos no canto
const SLOT := &"Slot"                ## caixa da barra de ferramentas
const SLOT_ACTIVE := &"SlotActive"
## ProgressBar.
const BAR_GOLD := &"BarGold"
const BAR_COPPER := &"BarCopper"
const BAR_SKY := &"BarSky"
const BAR_GOOD := &"BarGood"
const BAR_WARN := &"BarWarn"
const BAR_BAD := &"BarBad"
