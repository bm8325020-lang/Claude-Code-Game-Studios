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
