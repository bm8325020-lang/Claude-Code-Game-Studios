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
