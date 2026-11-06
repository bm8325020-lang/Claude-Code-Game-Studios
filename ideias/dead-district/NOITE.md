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
- [ ] A4 APK de teste "anti-travamento".

## B. Cidade nova com cara de terror
- [ ] B1 Noite mais longa e escura, lanterna importante; dia nublado e cinza; névoa que fecha a visão.
- [ ] B2 Cidade abandonada de verdade: carros batidos atravessados, cercas caídas, barricadas, sangue, corpos, fogo.
- [ ] B3 Luzes que piscam (postes queimando), rádio chiando, sons de terror ao longe (grito, porta batendo).
- [ ] B4 Lugares de medo: hospital escuro, igreja com velas, porão; menos casas, mais vazio e silêncio.
- [ ] B5 Sobreviventes inimigos (saqueadores "Os Corvos" no mercado).
- [ ] B6 APK final + resumo para o dono.
