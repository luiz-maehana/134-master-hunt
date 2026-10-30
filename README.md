# 134 Master Hunt

Simulador 3D em primeira pessoa (Godot 4.7, GDScript): junte **R$ 134.000.000,00 em moedas**
catando moeda por moeda pelo Eixo Monumental de Brasília, da Rodoviária ao Congresso Nacional.

## Jogar

- **No navegador:** https://luiz-maehana.github.io/134-master-hunt/ (clique na tela para controlar a câmera; a versão web começa com os gráficos no Baixo).
- **No PC:** abra o projeto no Godot (abaixo) ou exporte o executável.

## Rodando

1. Abra a pasta no Godot **4.7.x** (Project Manager → Import → `project.godot`).
2. F5 roda `scenes/ui/title_screen.tscn` (tela inicial: Continuar, Novo jogo, Opções, Créditos, Sair).

| Tecla | Ação |
|---|---|
| WASD / Mouse | Mover / olhar |
| Shift / Espaço | Correr / pular |
| Clique esquerdo | Usar a ferramenta equipada (vara: segure para mirar, solte para arremessar, clique de novo para recolher) |
| R / botão direito | Vara com ímã: recolher a linha / cancelar a mira |
| E | Interagir (depositar, abrir a loja) |
| F | Lanterna (liga e desliga; acende sozinha quando anoitece, se você tiver uma) |
| 1–4 / roda do mouse | Trocar ferramenta |
| Tab | Inventário: % recolhido de cada bairro, robôs ("Trazer para cá"), variantes das ferramentas |
| F11 | Tela cheia |
| M | Mapa: bairros abertos e fechados, pontos de coleta, lojas, robôs e você em tempo real |
| K | Conquistas: progresso da meta, moedas, dinheiro, cidade, equipamentos e os segredos já achados |
| Esc | Menu (Continuar, Recomeçar, Menu inicial, Sair), com abas: **Controles** (sensibilidade e troca de qualquer tecla, incluindo predefinição para canhotos), **Vídeo** (predefinições Baixa a Ultra, detalhe das moedas, distância de visão, resolução 3D com FSR 2, VSync, limite de FPS, campo de visão, tamanho da interface, HUD mínimo) e **Áudio** (volume) |

Teclas padrão; todas (menos Esc) podem ser trocadas no menu de pausa e ficam salvas.

**Como jogar:** R$ 134 milhões em moedas já estão espalhados pela cidade, de seis valores (1, 5,
10, 25 e 50 centavos e R$ 1); quanto mais rico o bairro, mais valiosas. A meta é o valor
encontrado (a quantidade de moedas, ~150 milhões, aparece só como curiosidade), e o bolso conta
moedas de qualquer valor. Comece de mãos
vazias na Rodoviária: pegue moedas (clique) e deposite no **ponto de coleta** verde (E)
— só então elas contam para a meta e viram dinheiro. Na **Ferragem do Seu Zé** (banca azul,
ao lado de cada ponto de coleta) compre luvas, pás (recolhem de perto), ímãs (puxam de longe), varas com ímã (arremessam
o ímã a até 40 m e trazem as moedas de volta), pochete/mochila/carrinho e as **licenças** que abrem as cercas dos bairros mais
ricos: Setor Cultural, Esplanada dos Ministérios e Congresso Nacional, onde o chão é um mar de pilhas de 25, 50 centavos e R$ 1.
Com o carrinho, a Ferragem passa a vender **robôs** (aspiradores robôs: o de casa, o industrial e o gigante):
você os deixa num lugar e eles recolhem sozinhos ao redor, depositando direto. Quando a área
acaba, eles avisam; traga-os para perto pelo inventário (Tab). A cidade também esconde segredos (e conquistas) para quem anda com atenção. Com o **Contrato dos portais**, o portal ao lado de cada loja leva
você para qualquer outra loja dos bairros liberados (E no portal, escolha o destino). O HUD mostra quanto de cada
bairro já foi recolhido. As moedas não voltam: o mapa vai ficando limpo. O progresso é salvo
automaticamente. Pelas contas do balanceamento, zerar leva por volta de 7 a 8 horas.

Balanceamento e premissas: [docs/BALANCE.md](docs/BALANCE.md).

## Testes

```sh
godot --headless --path . --import                            # primeira vez (gera .godot/)
godot --headless --path . --script res://tests/run_tests.gd   # código de saída 0 = OK
godot --headless --path . --script res://tests/balance_report.gd   # relatório de economia
godot --headless --path . --script res://tools/build_coin_textures.gd   # regera as texturas da moeda
```

Os testes nunca tocam no save real (`save_enabled = false`).

## Executável (Windows)

```sh
godot --headless --path . --export-release "Windows Desktop" "build/windows/134 Master Hunt.exe"
```

Precisa dos export templates 4.7.2 e de um `export_presets.cfg` local (fora do git).

O `.exe` não tem assinatura, e o Controle Inteligente de Aplicativos do Windows pode bloqueá-lo.
Nesse caso, exporte só o pacote e rode com o Godot instalado (que é assinado):

```sh
godot --headless --path . --export-pack "Windows Desktop" "build/windows/134 Master Hunt.pck"
godot --main-pack "build/windows/134 Master Hunt.pck"
```

## Estrutura

```
addons/basic_fps_controller/   controlador FPS de terceiros (MIT), sem modificações
assets/key_art/                artes de capa
assets/source/                 arte-fonte em alta resolução (não importada pelo Godot)
assets/textures/               texturas próprias otimizadas (moeda)
assets/third_party/            modelos e texturas de terceiros, com suas licenças
data/                          balanceamento: ferramentas, loja, cidade e bairros (.tres)
scenes/                        main, player, tools, world (cidade), ui
scripts/                       core, player, interaction, tools, coins, shop, automation, world, ui
tests/                         executor + testes unitários e de integração
tools/                         pipeline de assets, capturas, benchmark e check_publish.sh (não vão para o executável)
docs/ARCHITECTURE.md           sistemas e como estender
docs/ASSET_RESEARCH.md         assets avaliados e decisões
ASSET_CREDITS.md               inventário de assets de terceiros incluídos
```

## Repositório público: o que nunca deve ser commitado

O `.gitignore` já bloqueia os casos comuns, mas revise `git diff --cached` antes de cada commit.

- `export_presets.cfg` e `.godot/` (caminhos locais, senhas de keystore, chaves de criptografia).
- Arquivos `.env`, keystores (`*.keystore`, `*.jks`), certificados e chaves (`*.pem`, `*.p12`, `*.key`).
- Builds exportados (`/build/`, `*.exe`, `*.pck`).
- Tokens de API, e-mails ou dados pessoais em scripts e configurações.
- Assets sem licença verificada e registrada no [ASSET_CREDITS.md](ASSET_CREDITS.md).

Preferências e saves ficam em `user://` (no Windows, `%APPDATA%\Godot\app_userdata\134 Master Hunt\`), fora da pasta do projeto.

### Antes de publicar (checklist)

Automático:

```sh
sh tools/check_publish.sh                                       # arquivos proibidos, caminhos locais, e-mails, segredos, arquivos > 10 MB, licenças de terceiros
godot --headless --path . --script res://tests/run_tests.gd     # todos os testes passando
```

Manual:

- [ ] `git status` e `git diff --cached`: só entra o que você quer publicar.
- [ ] Todo asset novo de terceiros está no [ASSET_CREDITS.md](ASSET_CREDITS.md), com a licença ao lado dos arquivos;
      os CC BY também estão nos créditos do jogo (`scripts/ui/credits_screen.gd`) e na seção Créditos abaixo.
- [ ] `application/config/version` no `project.godot` atualizada.
- [ ] Build exportado e aberto uma vez (ver "Executável").
- [ ] Arquivo `LICENSE` (MIT, só o código) presente.

## Créditos

Modelos, texturas, interface e fonte de terceiros: Kenney (CC0), Quaternius (CC0), Poly Haven (CC0),
modelos CC BY 3.0 via Poly Pizza (Poly by Google, Michael Ruddy, KolosStudios, Jarlan Perez, Bruno Oliveira,
Robert Ramsay, joney_lol), Fredoka (OFL 1.1) e Basic FPS Controller (MIT).
Os créditos também aparecem no jogo (botão Créditos na tela inicial e no menu). Detalhes e links: [ASSET_CREDITS.md](ASSET_CREDITS.md).

## Licença

O código (scripts, cenas, shaders, testes e ferramentas) está sob a licença MIT ([LICENSE](LICENSE)).
A arte de capa e as imagens das moedas (que reproduzem o desenho das moedas de real) não fazem parte da licença MIT.
Os assets de terceiros mantêm suas próprias licenças (ver [ASSET_CREDITS.md](ASSET_CREDITS.md)).
