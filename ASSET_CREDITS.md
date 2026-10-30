# Créditos de assets de terceiros — 134 Master Hunt

Inventário dos recursos de terceiros **efetivamente incluídos** no repositório.
Recursos apenas avaliados estão em [docs/ASSET_RESEARCH.md](docs/ASSET_RESEARCH.md).

Regra: nenhum asset entra no projeto sem uma linha nesta tabela com licença verificada.
Arquivos de licença originais são mantidos junto aos assets.

## Código

| Recurso | Autor | Licença | Fonte | Local no projeto | Atribuição obrigatória |
|---|---|---|---|---|---|
| Basic FPS Controller for Godot 4 v1.0.0 (commit `7f50a91`) | Arjun Bhumula (`ar-bh`) | MIT | https://github.com/ar-bh/basic-fps-controller-godot · [Asset Library #5421](https://godotengine.org/asset-library/asset/5421) | `addons/basic_fps_controller/` | Sim — manter o aviso de copyright e a licença ([LICENSE.txt](addons/basic_fps_controller/LICENSE.txt)) |

### Adaptações

O addon foi copiado **sem modificações**. A personalização é feita fora dele:

- `scenes/player/player.tscn` herda `fps_controller.tscn`: desliga o HUD de debug, oculta a malha da cápsula, adiciona o `Interactor`, o `ToolHolder` (ferramentas) e o prompt de interação.
- `scripts/player/player_controller.gd` **estende** `fps_controller.gd` (herança, sem editar o original): substitui `_physics_process` para ter aceleração/desaceleração, aplica a sensibilidade de `Settings` e deixa o Esc para o menu de pausa.
- As ações de input exigidas pelo addon (`move_*`, `jump`, `sprint`) foram definidas no `project.godot` do jogo; nenhum `project.godot` de template foi copiado.
- O plugin do editor (`plugin.cfg`) **não** está habilitado — não é necessário para usar a cena.

## Modelos 3D

Os GLBs ficam em `assets/third_party/` com a licença original. A cidade os desenha por
MultiMesh (`scripts/world/city_builder.gd`), com colisões simples separadas do visual:
trocar um modelo só exige mudar o caminho no construtor.

| Recurso | Autor | Licença | Fonte | Arquivos usados | Atribuição obrigatória |
|---|---|---|---|---|---|
| City Kit (Roads) 2.2 | Kenney | CC0 1.0 ([License.txt](assets/third_party/kenney/city-kit-roads/License.txt)) | https://kenney.nl/assets/city-kit-roads | construction-barrier (cercas dos bairros), light-curved (postes), traffic-light, road-sign-stop, dumpster, construction-cone | Não (crédito opcional) |
| City Kit (Suburban) 2.0 | Kenney | CC0 1.0 ([License.txt](assets/third_party/kenney/city-kit-suburban/License.txt)) | https://kenney.nl/assets/city-kit-suburban | tree-large, tree-small (árvores), planter (floreiras) | Não (crédito opcional) |
| Car Kit 3.1 | Kenney | CC0 1.0 ([License.txt](assets/third_party/kenney/car-kit/License.txt)) | https://kenney.nl/assets/car-kit | sedan, hatchback-sports, suv, taxi, van (carros estacionados) | Não (crédito opcional) |
| Survival Kit 2.0 | Kenney | CC0 1.0 ([License.txt](assets/third_party/kenney/survival-kit/License.txt)) | https://kenney.nl/assets/survival-kit | tool-shovel (pá pequena), tool-shovel-upgraded (pás média e grande), `Textures/colormap.png` | Não (crédito opcional) |
| Glove | Quaternius | CC0 1.0 ([LICENSE.md](assets/third_party/quaternius/LICENSE.md)) | https://poly.pizza/m/l1zv4LaA4I | `quaternius/glove.glb` (só os ícones das luvas; a mão no jogo é montada em código) | Não |
| Fishing Rod | Quaternius | CC0 1.0 ([LICENSE.md](assets/third_party/quaternius/LICENSE.md)) | https://poly.pizza/m/aOabqWh68m | `quaternius/fishing_rod.glb` (varas com ímã; carretel pintado por variante) | Não |
| Magnet | Poly by Google | **CC BY 3.0** ([LICENSE.md](assets/third_party/poly_by_google/LICENSE.md)) | https://poly.pizza/m/7dHLjQ8eZhu | `poly_by_google/magnet.glb` + textura (ímãs P/M/G) | **Sim**: "Magnet" by Poly by Google [CC-BY 3.0] via Poly Pizza |
| Ícones dos itens da loja (pochete, mochila, tênis, carrinho, carrinho motorizado, caçamba, licenças, baterias, central, lanternas) | Quaternius (CC0); Poly by Google, Michael Ruddy, KolosStudios, Jarlan Perez, Bruno Oliveira, Robert Ramsay, joney_lol (**CC BY 3.0**) | ver [LICENSE.md](assets/source/item_models/LICENSE.md) | Poly Pizza (links no LICENSE.md) | `assets/source/item_models/*.glb`, só para gerar `assets/ui/item_icons/` (`tools/build_item_icons.gd`); não vão para o jogo exportado | **Sim** para os CC BY (feito no LICENSE.md, aqui e na aba Créditos) |

## Texturas

| Recurso | Autor | Licença | Fonte | Arquivos | Atribuição obrigatória |
|---|---|---|---|---|---|
| Worn Asphalt | Amal Kumar | CC0 1.0 | https://polyhaven.com/a/worn_asphalt | `assets/third_party/polyhaven/worn_asphalt/` (diff, nor_gl, rough — 1k) | Não |
| Concrete Pavement 03 | Charlotte Baglioni | CC0 1.0 | https://polyhaven.com/a/concrete_pavement_03 | `assets/third_party/polyhaven/concrete_pavement_03/` (diff, nor_gl, rough — 1k) | Não |

Licença: https://polyhaven.com/license (resumo em [LICENSE.md](assets/third_party/polyhaven/LICENSE.md)).

## Interface, ícones, fonte e som de clique

Tema global gerado por `tools/build_ui_theme.gd` (`assets/ui/game_theme.tres`, registrado em
`project.godot` › `gui/theme/custom`). Só os arquivos usados foram copiados, com a licença junto.

| Recurso | Autor | Licença | Fonte | Arquivos usados | Atribuição obrigatória |
|---|---|---|---|---|---|
| UI Pack 2.0 | Kenney (www.kenney.nl) | CC0 1.0 | https://kenney.nl/assets/ui-pack | `assets/third_party/kenney/ui-pack/` (botões, caixas de seleção, puxador do slider em amarelo, cinza, verde e azul; `click-a.ogg`; [License.txt](assets/third_party/kenney/ui-pack/License.txt)) | Não (crédito opcional) |
| Game Icons | Kenney (www.kenney.nl) | CC0 1.0 | https://kenney.nl/assets/game-icons | `assets/third_party/kenney/game-icons/` (17 ícones brancos 2x; [License.txt](assets/third_party/kenney/game-icons/License.txt)) | Não (crédito opcional) |
| Fredoka (fonte variável) | The Fredoka Project Authors | SIL Open Font License 1.1 | https://github.com/google/fonts/tree/main/ofl/fredoka | `assets/third_party/fonts/fredoka/Fredoka.ttf` ([OFL.txt](assets/third_party/fonts/fredoka/OFL.txt)) | Manter o aviso de copyright e a licença junto da fonte; não vender a fonte sozinha |

## Arte embutida no addon do controlador

| Recurso | Autor | Licença | Fonte | Arquivos | Atribuição obrigatória |
|---|---|---|---|---|---|
| Crosshair Pack | Kenney | CC0 1.0 | https://kenney.nl/assets/crosshair-pack | `addons/basic_fps_controller/assets/crosshair.png` | Não (crédito opcional) |
| Prototype Textures | Kenney | CC0 1.0 | https://godotengine.org/asset-library/asset/781 | `addons/basic_fps_controller/assets/GodotPrototype*.png` (usadas só na cena de demo do addon) | Não (crédito opcional) |

Origem dessas duas linhas: seção *Credits* do README do addon. Kenney declara todos os assets
das suas páginas como CC0 (https://kenney.nl/support).

## Arte própria do projeto

| Arquivo | Origem | Observação |
|---|---|---|
| `icon.svg` | Criado para o projeto | — |
| `assets/key_art/landscape.png`, `assets/key_art/portait.png` | Arte de capa gerada com ChatGPT (gpt-image), conforme o manifesto C2PA embutido (2026-10-28) | Metadados C2PA não contêm dados pessoais. Termos de uso de imagens geradas: conforme a política da OpenAI |
| `assets/source/coin_1_centavo_source.png` | Frente e verso da moeda de 1 centavo gerados com ChatGPT (gpt-image), conforme o manifesto C2PA embutido (2026-10-28) | Arte-fonte; não é importada nem exportada (`.gdignore`). Metadados C2PA sem dados pessoais. Retrata o desenho da moeda brasileira de 1 centavo |
| `assets/source/coin_5_centavos_source.png`, `coin_10_centavos_source.png`, `coin_25_centavos_source.png`, `coin_50_centavos_source.png`, `coin_1_real_source.png` | Frente e verso das moedas de 5, 10, 25 e 50 centavos e de R$ 1, gerados com ChatGPT (gpt-image), conforme o manifesto C2PA embutido em cada arquivo (2026-10-29) | Arte-fonte; mesmas condições da de 1 centavo. Retratam os desenhos das moedas brasileiras |
| `assets/textures/coin/coin_albedo.jpg`, `coin_normal.png`, `coin_material.tres`; `assets/textures/city/*.tres` (materiais de asfalto e concreto) | Derivados da arte-fonte por `tools/build_coin_textures.gd` (recorte de cada disco, atlas 512×1536 com uma linha por valor, normal map 256×768) | Para refazer: `godot --headless --path . --script res://tools/build_coin_textures.gd` |
| Malha da moeda, monte de moedas e textura de "tapete" | Gerados em código (`CoinVisuals`) | — |
| Chão, calçadas, prédios, braço do jogador, ímã da ponta da vara, cercas | Primitivas do Godot (Mesh), geradas pelo traçado da cidade | — |
| Fachadas dos prédios (janelas, andares, lojas), faixas de rua, detalhes de telhado, cofre do ponto de coleta e mercadoria da Ferragem | Gerados em código (`assets/shaders/building.gdshader`, `CityBuilder`, `DepositPoint`, `ShopKiosk`) | — |
| Gramado (manchas, faixas de corte e granulado) | Calculado no shader `assets/shaders/lawn.gdshader`, sem textura | — |
| Ícone de sol e lua do relógio | Desenhado em código (`scripts/ui/sky_icon.gd`) | — |
| Efeitos sonoros (moedas, depósito, compra, ímã, aviso, motor dos aspiradores) | Sintetizados em código ao iniciar (`scripts/core/sfx.gd`) | Exceto o clique dos botões (Kenney UI Pack, acima) |
| Ícone da moeda no HUD (`assets/ui/coin_icon.png`) | Recorte da moeda de R$ 1 do atlas, feito por `tools/build_ui_theme.gd` | Mesmas condições da arte-fonte das moedas |
| Ícones das ferramentas (`assets/ui/tool_icons/*.png`) | Fotografados dos próprios modelos das ferramentas por `tools/build_tool_icons.gd` (precisa de placa de vídeo: `godot --path . --script res://tools/build_tool_icons.gd`) | — |
