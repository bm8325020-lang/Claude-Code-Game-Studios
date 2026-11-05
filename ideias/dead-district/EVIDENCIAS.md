# Evidências
| id | jogo/versão | plataforma | sistema | ferramenta | fonte | timestamp | evidência | classe | confiança | limitações |
|---|---|---|---|---|---|---|---|---|---|---|
| E1 | Cataclysm DDA master (05/11) | PC, código aberto | loot | git sparse + leitura | src/item_group.cpp:900 | — | collection: cada entrada sorteada à parte (rng 0..99 >= prob falha) | FATO OBSERVADO (conferido pelo chefe) | alta | — |
| E2 | Cataclysm DDA master (05/11) | PC, código aberto | loot | idem | src/item_group.cpp:905-945 | — | distribution: escolhe 1 entrada pelo peso acumulado (prob/soma) | FATO OBSERVADO (conferido) | alta | — |
| E3-E5 | Cataclysm DDA master | PC aberto | IA, som, efeitos | leitura + grep | monmove.cpp, sounds.cpp, effects.json | — | nomes de função/campo citados nos relatórios existem no código | FATO OBSERVADO (nomes conferidos; fórmulas não) | média | recortes de 30 KB |
