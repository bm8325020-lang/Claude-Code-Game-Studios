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
