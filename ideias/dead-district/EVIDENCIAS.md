# Evidências
| id | jogo/versão | plataforma | sistema | ferramenta | fonte | timestamp | evidência | classe | confiança | limitações |
|---|---|---|---|---|---|---|---|---|---|---|
| E1 | Cataclysm DDA master (05/11) | PC, código aberto | loot | git sparse + leitura | src/item_group.cpp:900 | — | collection: cada entrada sorteada à parte (rng 0..99 >= prob falha) | FATO OBSERVADO (conferido pelo chefe) | alta | — |
| E2 | Cataclysm DDA master (05/11) | PC, código aberto | loot | idem | src/item_group.cpp:905-945 | — | distribution: escolhe 1 entrada pelo peso acumulado (prob/soma) | FATO OBSERVADO (conferido) | alta | — |
| E3-E5 | Cataclysm DDA master | PC aberto | IA, som, efeitos | leitura + grep | monmove.cpp, sounds.cpp, effects.json | — | nomes de função/campo citados nos relatórios existem no código | FATO OBSERVADO (nomes conferidos; fórmulas não) | média | recortes de 30 KB |
| E6 | Project Zomboid B42 | PC | mapa | WebFetch | github.com/Unjammer/PZ_Vanilla_map_b42 | — | 4065 células, 156100 cômodos, 9546 prédios, 37367 objetos | FATO (README de terceiro) | média | não é fonte oficial |
| E7 | 7 Days to Die (wiki 3.x) | PC | mapa | baixa.py + equipe | FONTES/7d_rwg.txt | — | tiles por distrito, hubs, POIs por regra, espaçamento x carga | FATO (14/17 citações exatas) | média | wiki de comunidade |
| E8 | Dying Light 2 | PC | mapa | idem | FONTES/dl_techland.txt, dl_80lv.txt, dl_gamedev.txt | — | papel/gray box, City Builder, telhados, parkour helpers | FATO (33/41 exatas; resto pontuação) | alta | entrevistas dos devs |
| E9 | The Last of Us Part I | PC | prédios | idem | FONTES/tlou_tiles.txt, tlou_wire.txt | — | peças modulares; prédios compartilham instâncias | FATO (13/14) | alta | artigos curtos |
| E10 | Days Gone | PC | mundo | idem | FONTES/dg_team.txt | — | equipe de 5-6 no design do mundo | FATO | alta | — |
| E11 | Cataclysm DDA | PC aberto | objetos da cidade | script (contagem) | FONTES/cdda_inventario.txt | — | 1849 tipos; frequência em 464 casas e 18 lojas | FATO | alta (contagem) | paletas citam sem colocar |
| E12 | Days Gone | PC | assets/otimização | WebFetch | 80.lv developing-content-huge-worlds-for-days-gone | — | kits no grid, tiling+vert blend, 2 barris, prefabs de ferragem, LOD/streaming | FATO | alta | — |
| E13 | Dying Light 2 | PC | assets | WebFetch | 80.lv the-development-process-behind-dying-light-2-s-environments | — | centenas de peças modulares, 4 biomas de telhado, scans, loot islands | FATO | alta | — |
| E14 | State of Decay 2 | PC | loot/zumbis | WebFetch | gamedeveloper.com procedurally-generating-...-state-of-decay-2 | — | recipientes à mão, loot por baralho, garantias, zumbi sem ponto fixo | FATO | alta | — |
| E15 | Cataclysm DDA master | PC aberto | casas | script (contagem) | FONTES/cdda_casas.txt | — | 249 casas: paredes, pisos, janelas, portas, móveis por casa | FATO | alta (contagem) | arquivos com várias casas inflam média |
| E16 | Cataclysm DDA master | PC aberto | janela/porta | script (json) | FONTES/cdda_janelas_portas.txt | — | estados: vidro/aberta/cortina/fita/tábuas/grade/moldura com cacos; porta trancada/quebrada/batente; força | FATO | alta | — |
| E17 | Project Zomboid (TileZed) | PC, editor aberto | casas | git sparse + leitura | FONTES/pz_tilezed.txt | — | Template = estilo + Rooms tipados (parede, piso, sujeira); quarto com outra parede; grime overlay | FATO | alta | editor, não o jogo |
| E18 | DayZ (Central Economy) | PC, dado do servidor | loot por prédio | script (xml) | FONTES/dayz_ce.txt | — | 49 casas: ~24 pontos, lootmax ~6, 3 tipos de ponto (chão/prateleira/arma); variante de cor | FATO | alta | licença: só números agregados |
| E19 | DayZ (wiki modding) | PC | portas/LODs | WebFetch | FONTES/web_casas.txt | — | porta 120x220 cm, ~80 graus, 50% nasce aberta, LODs visual/colisão/tiro/visão/pontos/roadway | FATO | média | wiki de comunidade |
| E20 | TLOU Part II | PS4 | interiores/vidro | WebFetch | FONTES/web_casas.txt (80.lv) | — | luz fora das janelas, vidro quebrável de textura, blockmesh decide o que se vê, ~1000 objetos de física | FATO | alta | — |
| E21 | 7DTD (wiki 3.0) | PC | POIs | WebFetch | FONTES/web_casas.txt | — | lotes 25/42/60/100/150, imposter por prédio, pintura por face | FATO | média | wiki de comunidade |
| E22 | Interior mapping (van Dongen 2008; Dagor docs) | — | vidro falso | WebFetch | FONTES/web_casas.txt | — | raio contra planos repetidos, atlas, fade 50-100 m, luz só à noite | FATO | alta | — |
| E23 | TLOU Part I | PS5/PC | casas/ruas | WebSearch (ArtStation 403) | FONTES/tlou_twd_gta.txt | — | vertex blend nas ruas, biblioteca compartilhada, remake do zero | FATO | média | resumo de busca |
| E24 | TLOU (2013) | PS3 | luz | WebSearch | history.siggraph.org Iwanicki 2013 | — | lightmap ambiente + direção dominante; oclusão por esferas | FATO | média | sem os slides |
| E25 | TWD Saints & Sinners | PC/VR | casas/loot | WebFetch + busca | FONTES/tlou_twd_gta.txt | — | kit de fachada + cor/grunge por material; formas simples; lixo desmonta em material | FATO | média | portfólios via busca |
| E26 | GTA V mods (Zombimod etc.) | PC | saque/sobrevivência | WebFetch | gta5-mods zombimod-ldracarys_ | — | saque em loja/carro, sem interior de casa; números de fome/sede/mochila | FATO | média | qual mod o dono quis: não confirmado |
