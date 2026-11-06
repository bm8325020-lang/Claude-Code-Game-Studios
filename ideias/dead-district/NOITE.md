# Plano da noite (06/11, dono: "jogo injogável, muito travamento; renove a cidade; pegada de terror; algo muito
# diferente amanhã"). Cada rodada do loop: ler isto, fazer o próximo item [ ], marcar [x] com o resultado medido,
# commit + push. Poucos testes (dono pediu): só os da área mexida. APK no fim de cada bloco grande.

## A. Travamento (prioridade 1)
- [x] A1 Medido (tools/peso_cpu.gd): 137 mil nós, 20.880 corpos, 3.937 gavetas + 475 itens + 241 portas + 233 baús rodando
  _process todo quadro; rodadas isoladas: gavetas 4,4 ms de 12,6 ms, zumbis 5,5 ms de física, carros parados mexendo a física.
- [x] A2 Gaveta/item/porta/baú só rodam quando abertos/quebrados; zumbi do ambiente dorme longe; carro parado não mexe na
  física. Processo 12,6 → 8,8-9,6 ms, física 7,9 → 5,9 ms (este PC; o celular é ~5x mais lento).
- [x] A3 Celular: padrão Média e 30 FPS estáveis (60 irregular = travadinho), migra a config de quem já tinha; 1 zumbi por
  ponto fixo na Média/Batata.
- [x] A4 APK 0.98 mandado ao dono.

## B. Cidade nova com cara de terror
- [x] B1 Dia 420 s cinza de chumbo, noite 360 s quase preta (sol 0,16, ambiente 0,26), névoa 0,02-0,04, lanterna mais forte
  e trêmula (pilha velha). Foto: de noite só se vê o que a lanterna pega.
- [x] B2 26 acidentes (2-3 carros atravessados: carcaça pronta do Sketchfab, queimado, van) com zumbi em volta; 1 em
  3 queimados ainda arde; 110 sacos de corpo (eram 40).
- [x] B3 Postes velhos piscando de noite (4 luzes andam pelos postes vivos mais perto; metade queimou), rádio esquecido
  ligado em 1 de cada 7 casas (notícia da Febre + chiado), sustos novos: grito, porta batendo, explosão longe. test_som ok.
- [x] B4 Igreja com 24 velas no altar (luz que treme), hospital escuro com lâmpada fria falhando e 12 zumbis (eram 8);
  cidade mais vazia: 427 -> 355 prédios (1 em 4 casas do OSM some, 30% de terreno baldio). Malha refeita. Porão: ficou
  de fora (pede modelo novo no Blender). test_raid/test_bairro ok.
- [x] B5 Os Corvos: 5 saqueadores vivos no mercado (roupa preta, nome em cima), avisam ("SAI DAQUI!") 2,5 s antes de
  atirar, se escondem e fogem feridos; fogueira e pichação na frente; caveira no minimapa; ninguém nasce lá. Rede 47.
  test_raid 12/12. 07/11: andam, correm e miram com os clipes do jogador (Zumbi.HUMANO). Noite mais clara (luar).
- [x] B6 APK 0.99-terror (257 MB) mandado ao dono com resumo. Plano da noite completo.

## C. Travamento, 2ª rodada (07/11)
- [x] C1 Medida certa: Performance.TIME_PROCESS mentia no headless (50-400 ms aleatório); peso_cpu.gd agora mede o
  relógio de parede por quadro e cronometra cada script (DESLIGA, DESLIGA_CLASSE, DESLIGA_TUDO). Base: 11 ms/quadro.
- [x] C2 HUD: buscas "o que está perto" (~5000 gavetas/itens/portas) a cada 0,15 s em vez de todo quadro: 3,5 -> 1 ms.
  Zumbi: caminho só refeito quando o destino anda 1 m, raio de porta 5x/s, parado/morto no chão sem move_and_slide.
  Total 11 -> 5,7 ms por quadro neste PC. test_zumbi/portas/horda ok.
- [x] C3 Desenho (dono: "zumbis e o render travam"); medido com tools/peso_render.gd (DD_QUALIDADE=1, 4 pontos):
  Média 543 -> 386 chamadas, 671 -> 336 mil triângulos. Zumbi sem camada vermelha fixa (só no piscar), sem sombra e
  até 45 m na Média; mesh_lod_threshold pela qualidade (LODs do import); sombra do sol 1 fatia na Batata/Média;
  árvores grandes com versão de longe (normaliza.py *_lod, folhas rareadas) em quadrados de 50 m; casca dos prédios
  troca pela caixa mais cedo na Batata/Média.

## D. Próximos passos (loop automático a partir das 6:31 de 07/11; dono: "tá começando a ficar agradável")
Cada rodada: ler isto, fazer o próximo [ ], medir, poucos testes (só da área), commit + push, marcar [x].
- [x] D1 (07/11) main._resolucao_dinamica: FPS baixo encurta Zumbi.VE_ATE de 6 em 6 m até 24 m antes de baixar a
  resolução; folgou, volta. Zumbi invisível não anima (process do zumbi 0,7 -> 0,25 ms). test_zumbi/jeitos ok.
  Era: Zumbis que se ajustam ao aparelho: se o quadro passar do tempo (30 FPS), diminui sozinho a distância dos
  zumbis e o tanto que acordam juntos; volta quando folgar. Medir com peso_cpu/peso_render.
- [x] D2 (07/11) scripts/porao.gd: 1 em 8 casas com cozinha (~33 porões), alçapão aberto entre o balcão e o meio
  da casa -> sala 40 m abaixo (concreto, prateleira, caixas, escada, lâmpada fria falhando, baú raro, 1-2 zumbis que
  ficam mortos); pisar no pé da escada sobe. Ciclo: sem névoa de altura no subsolo (virava parede azul).
  test_porao 6/6, bairro/gavetas/raid ok. Era: Porão: em ~1 de cada 8 casas, alçapão no chão da cozinha -> escada -> porão escuro (só a lanterna), loot raro
  e 1-2 zumbis deitados (tocaia). Medo + motivo para explorar.
- [-] D3 (movido para E5) Corvos vivos de verdade: patrulha em dupla em volta do mercado, gritam o aviso com voz (som), fogem para dentro,
  baú do acampamento com loot de saqueador; matar todos libera o mercado (aviso no HUD).
- [-] D4 (movido para E6) APK + resumo curto para o dono.

## E. Cidade nova (dono 07/11: "o loop deve mudar a estrutura inteira da cidade e adicionar coisas novas")
Regra do loop: cada rodada muda a CIDADE (planta tools/mapa/senoia.py + Bairro/Planta) ou põe coisa NOVA no mundo;
mudou a planta -> regerar planta + minimapa e a malha (assa_navegacao.gd -- salva_nav), foto antes/depois, peso_render
(DD_QUALIDADE=1) não pode subir mais que 10%. Ao acabar a seção, escrever a próxima no mesmo espírito.
- [ ] E1 Zonas novas na planta: centro bombardeado (quarteirão com prédios desabados, crateras, entulho na rua),
  bairro incendiado (fileira de casas queimadas com fumaça), rodovia de entrada engarrafada (fila de carros dos que
  tentaram fugir), parque virou vala comum (covas rasas, cruzes, sacos).
- [ ] E2 Quarentena militar: muro de contêineres e cercas cortando a cidade em duas, portão com checkpoint
  (sacos de areia, holofote apagado, guarita), tendas médicas lá dentro com loot militar e zumbis soldados.
- [ ] E3 Lugares novos: posto de gasolina com loja de conveniência, escola barricada (refúgio que caiu), torre de água
  para subir e ver longe, ferro-velho.
- [ ] E4 Ruas que mudam: pontes/ruas bloqueadas por barricadas e ônibus tombados, obrigando a dar a volta; atalhos por
  dentro de prédios e quintais.
- [ ] E5 Corvos vivos de verdade (era D3): patrulha em dupla no mercado, voz no aviso, matar todos libera o mercado.
- [ ] E6 APK + resumo curto para o dono; escrever a seção F (mais cidade e coisas novas).
