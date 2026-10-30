# Pesquisa de assets gratuitos — 134 Master Hunt

Pesquisa feita em 2026-10-28, com Godot **4.7.2-stable** instalado.
Licenças conferidas nas páginas oficiais citadas. *Pendente* significa que não foi verificado
diretamente (por exemplo, o conteúdo exato de um pacote antes de baixá-lo).

## Resumo das decisões

| Recurso | Categoria | Benefício | Compatibilidade | Licença | Decisão |
|---|---|---|---|---|---|
| Basic FPS Controller (ar-bh) | Controlador | WASD, mouse, corrida, pulo, colisão, sensibilidade exportada; ~90 linhas | **Verificada** (testado no 4.7.2) | MIT (LICENSE.txt conferido) | **Integrado** |
| Simple State Machine FP Controller (Jeheno) | Controlador | Completo: FSM, agachar, head bob, FOV, multi-jump | Declarada 4.4–4.7 (não testada) | MIT (LICENSE conferido) | Descartado: ~1000 linhas, recursos que o jogo não usa |
| Simple First Person Controller (E1480) | Controlador | Leve, com interação | Feito para 4.3 | MIT (conforme a listagem) | Descartado: redundante |
| Kenney City Kit (Roads) | Modelos urbanos | Postes, cones, barreira, caçamba, placa; v2.2 | **Verificada** (GLB, testado no 4.7.2) | CC0 (License.txt conferido) | **Integrado** (5 modelos) |
| Kenney City Kit (Suburban) | Modelos urbanos | Árvores, floreira; v2.0 | **Verificada** (GLB) | CC0 (License.txt conferido) | **Integrado** (3 modelos) |
| Kenney Car Kit | Carros estacionados | Carros e caixa; v3.1 | **Verificada** (GLB) | CC0 (License.txt conferido) | **Integrado** (6 modelos) |
| Kenney Survival Kit | Ferramentas, caixas | 80 arquivos, v2.0 | Pendente (conteúdo não listado) | CC0 | Testar (verificar se há pá) |
| Kenney Furniture Kit | Lixeiras, caixas, bancos | 140 arquivos | Pendente | CC0 | Avaliar |
| Quaternius — Modular Streets / Downtown City MegaKit / Cars Pack | Modelos urbanos | Alternativa com outro estilo | Pendente | CC0 (FAQ) | Reserva: não misturar estilos com Kenney sem decisão de arte |
| Poly Pizza | Modelos avulsos | Itens isolados (luva, ímã etc.) | Pendente | **Por modelo** (CC0 ou CC-BY) | Usar caso a caso, conferindo a licença de cada modelo |
| Poly Haven (texturas) | Materiais PBR | Asfalto, concreto, terra, ferrugem | **Verificada** (JPG 1k, triplanar) | CC0 | **Integrado**: worn_asphalt, concrete_pavement_03 |
| ambientCG | Materiais PBR | Alternativa/complemento ao Poly Haven | PNG padrão | CC0 1.0 | Testar |
| Kenney Impact Sounds | Sons | 130 arquivos de impacto/foley | OGG (pendente) | CC0 | **Testar** |
| Kenney Interface Sounds | Sons de UI | 100 arquivos | OGG (versão WAV do Calinou no GitHub) | CC0 | Testar |
| Kenney RPG Audio | Passos, foley | 50 arquivos (tags: footstep) | Pendente | CC0 | Testar |
| Freesound — vassoura | Varrição | Sem pacote CC0 confirmado | — | Misto (CC0/CC-BY por arquivo) | Pendente: buscar arquivo a arquivo com filtro CC0 |
| GUT 9.7.1 | Testes | Framework de testes unitários | Release para 4.7.x | MIT | Adiado: um executor próprio de ~50 linhas (`tests/run_tests.gd`) cobre a Etapa 1 sem dependência. Reavaliar se os testes crescerem muito |
| GdUnit4 6.2.x | Testes | Alternativa ao GUT | 4.5–4.7.1 | MIT | Descartado: redundante |

## Observações de integração

- Escala: os pacotes Kenney não usam metros. Fatores aplicados nos wrappers: Roads 5–9×, Suburban 3,5–8×, carros 1,25×.
- Estilo: **low poly** é a direção de arte (decidido em 2026-10-28), compatível com os pacotes Kenney.
- Downloads brutos ficam em `_downloads/` (ignorado pelo git e pelo Godot via `.gdignore`); só os arquivos usados vão para `assets/third_party/`.

## Itens sem fonte pronta → primitivas provisórias

Lógicas exclusivas do jogo (atração magnética, arremesso e recolhimento da vara, economia)
serão implementadas no próprio projeto. Visuais sem modelo adequado começam como primitivas:

- Moeda de 1 centavo: malha própria com atlas frente/verso (arte do autor do projeto) via MultiMesh (`scripts/coins/coin_field.gd`).
- Mãos e vassoura: primitivas (`scenes/tools/`).
- Folhas, terra, papel e entulho: primitivas geradas por `DebrisPile`.
- Ímã, vara de pesca magnética, corda e luvas: pendentes (Poly Pizza por modelo ou primitivas).

## Fontes consultadas

- https://godotengine.org/asset-library/asset/5421 · https://github.com/ar-bh/basic-fps-controller-godot
- https://godotengine.org/asset-library/asset/3890 · https://github.com/Jeh3no/Godot-Simple-State-Machine-First-Person-Controller
- https://kenney.nl/support · https://kenney.nl/assets/city-kit-roads · https://kenney.nl/assets/city-kit-suburban
- https://kenney.nl/assets/car-kit · https://kenney.nl/assets/survival-kit · https://kenney.nl/assets/furniture-kit
- https://kenney.nl/assets/impact-sounds · https://kenney.nl/assets/interface-sounds · https://kenney.nl/assets/rpg-audio
- https://quaternius.com/faq.html
- https://polyhaven.com/license · https://docs.ambientcg.com/license/
- https://github.com/bitwes/Gut · https://github.com/godot-gdunit-labs/gdUnit4
- https://freesound.org/people/Thimblerig/sounds/629650/
