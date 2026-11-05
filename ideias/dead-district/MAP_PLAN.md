# MAP PLAN — RAVEN CREEK (05/11)

Base: o projeto existente (Godot 4.7.2). Nada de projeto novo. São Jorge fica salvo no commit `8693847c`.

| Etapa | O que | Estado |
|---|---|---|
| 1 Auditoria | status, arquitetura, assets, backup | FEITO (PROJECT_STATUS, ARCHITECTURE, ASSET_CATALOG) |
| 2 Planejamento urbano | bairros, ruas, zonas (CITY_LAYOUT.md) | FEITO (tools/mapa/raven_creek.py) |
| 3 Infraestrutura | ruas em grade, calçada, meio-fio, faixas, postes, pontes, estacionamentos | FEITO o básico; FALTA placas (STOP), semáforos, bueiros, lombadas |
| 4 Construções | casas americanas (6 modelos, garagem, varanda); lojas de tijolo com letreiro em inglês | EM ANDAMENTO; FALTA casa de 2 andares, bombeiros, prefeitura, biblioteca, lanchonete com estacionamento |
| 5 Interiores | compositor com regras (interiores.py) nas casas | FEITO nas casas; FALTA lojas/hospital/delegacia/escola com o compositor |
| 6 Ambientação | gramados, cercas, terrenos baldios, mata, carros, bloqueios | PARCIAL; FALTA lixo por região, acampamentos, sinais de evacuação |
| 7 Otimização | LOD por grupo, HLOD por pedaço, alcance de interior | PARCIAL; FALTA carregar/descarregar por região (1 km² pesa no celular) |
| 8 Auditoria final | testes, fotos, desempenho | A FAZER |

Riscos: memória e tempo de carregamento no celular com ~520 prédios; malha de navegação de 1 km² (tempo de assar e
tamanho); testes que dependiam do desenho de São Jorge (relevo, telhados, raid) precisam de ajuste.
