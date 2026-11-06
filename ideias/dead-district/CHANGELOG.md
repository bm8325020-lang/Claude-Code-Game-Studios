# CHANGELOG — mapa
- 05/11 (noite): ETAPA D vegetação pronta. 16 modelos do Sketchfab (CC BY / Free Standard) acertados por
  tools/assets/normaliza.py (metros reais, base no chão, uma malha, texturas WEBP, folha decimada e tronco no máximo
  metade); 4 recusados na foto (carvalhos de desenho, planta tropical, samambaia de 5 MB). scripts/vegetacao.gd
  (espécies, tinta, shader de vento, tronco com colisão); raven_creek.py troca as árvores feitas à mão por espécie da
  zona (rng próprio: a cidade não muda) + mato no pé, mata de coníferas em Raven Hill (700), beira do riacho.
  Medido (foto_cidade, Média, sem sombra): antes 1,46-2,31 mi triângulos, depois 1,46-2,32 mi; chamadas +5 a +35%.
  Minimapa estilo GTA V (tools/mapa/minimapa.py + scripts/minimapa.gd). Tela CRÉDITOS (tools/assets/creditos.py).
- 05/11: RAVEN CREEK começa. Casas americanas (casas_us.py), compositor de interiores (interiores.py), texturas
  americanas, letreiros em inglês, planta 1 km² (raven_creek.py), Bairro TAMANHO 1000 / ORIGEM (0,0,-550).
  São Jorge preservado no commit 8693847c (tools/mapa/cidade_v2.py continua no repositório).
- 05/11: (antes) casas brasileiras, sistemas dos mods do GTA V (horda, noturno, porta-malas, zumbi do saco).
- 06/11: SENOIA (cidade real). `CIDADE=senoia python3 tools/mapa/raven_creek.py` (padrão do pipeline) monta a cidade
  com as ruas e os prédios reais de Senoia, Geórgia (EUA; Woodbury de The Walking Dead), do OpenStreetMap
  (tools/mapa/osm/senoia.json, ODbL: "© colaboradores do OpenStreetMap"). 83 prédios reais no lugar e do tamanho deles
  (casa → casa americana, comércio → sobrado, igreja → igreja); os outros lotes preenchidos pelas regras; delegacia,
  hospital, mercado e escola no 1º lote livre. Raven Creek continua: sem CIDADE (ou CIDADE=raven) volta.
- 06/11: CAMPANHA ANTI-LAG. Medido (foto_cidade, Média, com sombra): triângulos 1,47-2,04 mi → 0,18-0,66 mi
  (−66% a −88%), chamadas −2% a −20%, sem mudar a vista de perto. Culpados achados: chão de 3 m projetando sombra
  (1,2 mi com as cascatas) → 6 m e sem sombra; corpo do zumbi comendo (cápsulas de 64 lados) → 8 lados e some a 45 m;
  esferas/cilindros padrão do Godot (64 lados) → 12; móveis Poly Haven (cama 50 mil) → 2500 (tools/assets/reduz.py);
  zumbis Sketchfab → 9 mil; capim 1200 → 500 e 25% dos tufos. Casa em 3 níveis: inteira perto, casca de fora no meio
  (Longe_* por pedaço, agora posicionado no meio do pedaço), "massinha" (caixa da cor da casa, Massa_*) longe.
  Árvores somem na névoa. Resolução dinâmica (main._resolucao_dinamica), shaders aquecidos atrás da tela de
  carregamento (main._aquece_shaders), zumbis vivos pela qualidade (Populacao.orcamento: 35/50/70).
- 06/11: HISTÓRIA E CHEGADA. HISTORIA.md (Febre Cinzenta, quarentena, Dia 31). Abertura (scripts/abertura.gd): tela
  preta, chiado, boletim da repórter Dana Price linha a linha, PULAR; tutorial "entre no carro" e "siga a estrada".
  Nasce na estrada do leste (Bairro.entrada_pos, `entrada` no cidade.json; 175 m sem casa, só mata) ao lado do carro,
  placa WELCOME TO SENOIA. Carro com o sedã pronto (MaG80, CC BY): rodas giram e esterçam, vidro estoura com tiro
  (Carro.leva_tiro, vai pela rede). Tentativa com VehicleBody3D (física de rodas) travava dentro da cidade: ficou o
  movimento antigo.
