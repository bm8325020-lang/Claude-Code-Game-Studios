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

## E. SUPER OPERAÇÃO (dono 07/11, enquanto dorme) — seguir ideias/dead-district/REGRAS_LOOP.md em TODA rodada
Ordem pensada: primeiro a cara e o pronto (muda o jogo inteiro), depois estrutura, construções, mecânicas, Corvos, loja.
- [x] E1 (07/11 6:31) Paleta própria no Ciclo: sol âmbar/luar petróleo, sombra fria, horizonte com brasa; nuvens
  de FOTO (HDRI CC0 Poly Haven kloofendal_overcast, assets/ceu, no shader do céu no lugar do ruído). Foto antes/depois
  4 lugares (dia neutro-quente, noite azul-petróleo; tirei o laranja forte que o dono já recusou). Render Média 406
  chamadas (+5%), 335 mil tri (=). test_clima/zumbi ok. Falta da ideia: chuva com poças (vai para a próxima seção).
  Era: CARA NOVA (regra 5): direção de arte própria — paleta (ferrugem/âmbar das luzes contra azul-petróleo da noite,
  não cinza), céu com nuvens prontas (HDRI Poly Haven CC0), névoa colorida, chuva/poças; foto antes/depois de 4 lugares.
- [x] E2 (07/11 7:31) Levantamento: feito à mão mais visto = 272 casas casa_us (interior, gavetas e porões presos a
  elas), 65 sobrados, veículos carro_r2/van_r1, ônibus, barricadas, postes. Trocados agora: queimado (Burned Car), van
  (Graffiti Van) e enferrujado novo (Car Wreck) do Sketchfab CC BY (créditos ok); dirigíveis já eram o sedã pronto.
  _veiculo acha o comprimento e a colisão pelo tamanho do modelo; tinta escura no queimado. Planta com o mesmo sorteio
  (cidade igual), malha refeita. Render Média 437 chamadas (+7,6%), 341 mil tri. test_bairro/carro/porta_malas ok.
- [x] E2b (07/11 8:31) 4 casas prontas do Sketchfab CC BY (normaliza -> tools/blender/casa_pronta.py -> ruína
  fechada assets/ruinas/casa_p1..4, materiais "pronto_*" que o Bairro não repinta); a planta troca 1 em 3 casas comuns
  depois do sorteio (87 casas prontas, cidade igual). Ônibus tombado e barreiras de concreto prontos. Malha refeita.
  Render Média 463 chamadas (+6%), 369 mil tri (+8%). test_bairro/porao/gavetas/nascer ok. Falta: lojas do centro
  prontas e girar a frente das casas prontas para a rua (algumas mostram o lado).
  Era: Casas e lojas prontas: achar kit de casas americanas CC0/CC BY com interior (ou fachadas prontas por cima do
  interior atual, mantendo os nomes de móvel que as gavetas usam); ônibus e barricadas prontos.
  Era: PRONTO NO LUGAR DO FEITO À MÃO (regra 7): levantar o que é feito à mão (casas_us, ruinas, cidade.py, porão,
  postes, barricadas); trocar os mais vistos por modelos prontos CC0/CC BY (começar pelas casas e lojas do centro).
- [x] E3 (07/11 9:31) senoia.py com sorteio próprio (resto da cidade igual): bairro incendiado (10 casas viram as
  queimadas que ardem), centro bombardeado (45 pilhas de entulho/tijolo prontas + carros queimados), rodovia de entrada
  engarrafada (18 carros na pista de saída; a de quem chega livre), vala comum (28 sacos de corpo prontos + cruzes, 4
  zumbis). Planta aceita enfeite pronto "mundo:" (assets/mundo/props). Malha refeita. Render Média 344 chamadas, 288 mil
  tri (abaixo do anterior); CPU 6,2 ms. test_bairro/nascer/carro/horda ok. Sem cratera pronta (não achei CC).
  Era: ESTRUTURA (regra 1): centro bombardeado (prédios desabados prontos, crateras, entulho), bairro incendiado,
  rodovia de entrada engarrafada, parque virado vala comum. Planta + minimapa + malha.
- [x] E4 (07/11 10:00, adiantado pelo dono) Muro de 46 contêineres prontos (Sketchfab CC BY) cortando a cidade em
  z=380 (hospital e mercado do lado de dentro), checkpoint na rua mais central com guarita, sacos de areia, holofotes e
  2 torres de vigia; PORTÃO (pedido do dono) = 4 folhas de grade (Porta: USAR abre/fecha, zumbi soca); 4 tendas
  militares com baú de loot raro e 8 zumbis soldados (pontos_raid). Planta: "quarentena" no JSON. Malha refeita.
  Render Média 367 chamadas, 313 mil tri. test_bairro/raid/nascer/portas ok.
  + (dono) portão BLINDADO: USAR não abre, zumbi não quebra; item novo BOMBA (C4 pronto CC BY; loot raro 0,5,
  loja 450): perto do portão arma, bipa, explode em 5 s (arromba as 4 folhas, fere perto, barulho 70 m chama zumbi);
  dentro: 8 saqueadores armados (Corvo) no lugar dos soldados. Rede.VERSAO 48. test_bomba 6/6; portas/raid/mochila/
  baus/loja ok; test_rede ok (1ª rodada falhou no tempo, 2ª passou).
  Era: QUARENTENA MILITAR (regras 1/4): muro de contêineres cortando a cidade, checkpoint (sacos de areia, guarita,
  holofote), tendas médicas com loot militar e zumbis soldados — modelos prontos.
- [x] E5 (07/11 10:31) Torre de água pronta (Sketchfab CC BY) que dá para subir (Subida: pé da escada sobe, beira
  lá em cima desce; vê a cidade de longe), ferro-velho cercado com grade (14 carcaças, 2 baús, 4 zumbis), escola
  virou refúgio caído (barreiras e sacos de areia na frente, baú, 5 zumbis), 3 bombas de gasolina prontas na estrada
  com baú. "lugares" no JSON. Malha refeita. test_porao 9/9 (subida), bairro/nascer ok. Render Média 421-443
  chamadas (medida varia ±30 com zumbi na vista; o mercado pesa pelos Corvos de 7 partes -> E9), 323-356 mil tri.
  FALTA: prédio do posto pronto (baixado, a colisão dele precisa ser feita à parte).
  Era: CONSTRUÇÕES NOVAS (regra 4): posto de gasolina com loja, escola barricada, torre de água (subir e ver longe),
  ferro-velho — prontos, com motivo para entrar.
- [ ] E6 MECÂNICA NOVA (regra 3): rádio com chamados (drop de suprimento, sobrevivente pedindo ajuda, Corvos
  vendendo/roubando): vai até o ponto no mapa, evento acontece, recompensa. Teste próprio.
- [ ] E7 MECÂNICA NOVA (regra 3): ruas que mudam — barricadas e ônibus tombados fecham caminhos, atalhos por dentro de
  prédios/quintais; e combustível nos carros (galão no loot, carro para sem gasolina). Teste próprio.
- [ ] E8 OS CORVOS (regra 8): facção completa — 3 acampamentos (mercado + 2 novos), patrulha em dupla, emboscada na
  estrada, líder com recompensa, voz no aviso, mercado liberado ao derrotar; modelos de humano prontos (CC BY/CC0).
- [ ] E9 SEM LAG (regra 6): medir tudo de novo (peso_cpu + peso_render), cortar o que subiu; meta Média <= 330 mil
  triângulos e <= 400 chamadas.
- [ ] E10 PRONTO PRA POSTAR (regras 9/10): ícone do app (o export reclama "No project icon"), tela inicial/menu com a
  cara nova, créditos atualizados, rodar TODOS os testes, APK limpo (sem loja/AAB: dono não quer), resumo.
- [x] (dono 07/11) Saqueadores/Corvos como jogador que mata para roubar: sem aviso (atira 0,4 s depois de ver), vê a
  48 m e atira até 26 m, mira 0,35 s e tiro a cada ~1,3 s, anda de lado entre os tiros e recua se o alvo cola
  (< 9 m), ferido corre para cobertura 2,5 s e volta (não foge de vez), sem alvo ronda 70 m em volta de casa caçando,
  vê saco de morto a 55 m, vai lá e rouba (devolve num saco quando morre). Minimapa: losango laranja até 160 m.
  Tirado o aviso falado (Rede.VERSAO 49). test_raid 14/14, test_zumbi 49/49, test_rede ok (2ª rodada).
- [x] (dono 07/11 "otimize tudo e mande APK") casa_pronta.py assa as casas com > 3 materiais numa textura só (atlas
  1024 no Cycles: casa_p2/p3/p4 de 6/10/12 materiais para 1); entulho 1536 -> 600 e tijolos 2000 -> 800 tri.
  Render Média 450 -> 370 chamadas, 371 -> 297 mil tri; CPU 6,0 ms. Malha refeita. test_bairro/porao ok. APK 1.03.
