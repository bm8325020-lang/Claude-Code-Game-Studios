# Mapas analisados
(vazio)
## Cataclysm DDA — organização do mapa grande (overmap) — RELATORIOS/cdda/mapa.md (nomes conferidos em src/overmap.cpp)
- FATO: mapa em camadas de células (overmap); primeiro natureza por ruído (florestas, pântanos, várzea), depois cidades como âncoras,
  depois estradas ligando a cidade mais perto (`place_roads`, `connect_closest_points`), depois prédios especiais com regra de onde cabem
  (`place_special` / `can_place_special`), estradas continuam na borda do vizinho.
- ADAPTAR para DEAD DISTRICT: nossa cidade (cidade_v2.py) já é "ruas à mão + lotes por regra"; ganho: lugares especiais com regra de
  colocação (perto de rua grande, longe de outro igual) e mapa maior em pedaços ligados pela borda (expansão futura sem refazer).
- Limite: recorte de 30 KB; bairros (city_buildings) ficaram de fora.

## Project Zomboid (Build 42) — fonte: github.com/Unjammer/PZ_Vanilla_map_b42 (README de projeto público que reconstrói o mapa oficial para os editores)
- FATO (dito no README): mapa compilado em arquivos `.lotheader`/`.lotpack` por célula; 4.065 células de origem; 156.100 "RoomDefs"
  (cada cômodo definido à parte, um arquivo por cômodo); 9.546 prédios montados juntando cômodos pelo id; 37.367 objetos em `objects.lua`;
  413 tilesets; vários andares (níveis Z); editores WorldEd (mundo) + TileZed/BuildingEd (prédios).
- NÃO CONFIRMADO: "TMX 2556x256" (parece erro de digitação no README; célula costuma ser 256x256 tiles no B42).
- INFERÊNCIA: a cidade é feita de PRÉDIOS = conjunto de CÔMODOS com nome; o nome do cômodo é o que define o loot (cozinha, banheiro...).
- ADAPTAR p/ DEAD DISTRICT: nossos modelos já nomeiam móveis por cômodo ("sofa_sala1"); falta o cômodo como dado (loot por cômodo, zumbi
  por cômodo). Barato no Android (só dados).
- Fontes bloqueadas (403): brainbound.blog (guia do editor), pzwiki.net, blog da Indie Stone — tentar depois por outra via.

## 7 Days to Die — RELATORIOS/cidades/7dtd_rwg.md (fonte: wiki.7d2d.net, guia de RWG; 14/17 citações conferidas, 3 com pontuação diferente)
- FATO: mundo inteiro sai de uma semente; cidades ("hubs") montadas com peças de quarteirão (tiles) por distrito; prédios (POIs/prefabs)
  escolhidos por regra de bairro/bioma/tamanho; estradas em hierarquia; lugares isolados fora das cidades; espaçamento pequeno entre
  hubs dá "cara de cidade" mas pesa no servidor (mais POIs perto do jogador); mapa gerado é salvo e reaproveitado.
## Dying Light 2 — RELATORIOS/cidades/dl2_cidade_predios.md + dl2_navegacao.md (fontes: Techland blog, 80.lv, Game Developer)
- FATO: Villedor planejada em PAPEL primeiro (prédios em pedaços de papel mexidos na mesa) e "gray box" com medidas; ferramenta
  "City Builder" monta km de mapa com peças pré-fabricadas e os lugares importantes são feitos/modificados à mão; cada prédio feito junto
  com o level design para o telhado ser divertido; "parkour helpers" (objetos que mostram o caminho); térreo perigoso/pobre e telhados
  como 2º nível da cidade; distritos com identidade; ruas de forma natural mas a serviço do jogo.
## The Last of Us Part I — RELATORIOS/cidades/tlou_daysgone.md (fontes: 80.lv)
- FATO: prédios montados com conjuntos de peças modulares (tilesets) feitos no Maya; "all the buildings in the game share many instances";
  wireframes mostram o nível de detalhe mais alto (há outros níveis = LOD).
## Days Gone — mesma fonte (gamingbolt)
- FATO: mundo aberto desenhado por 5-6 pessoas de design; foco em sistemas que interagem (mundo "dinâmico") em vez de muito conteúdo à mão.

## SÍNTESE CIDADES (chefe) — o que DEAD DISTRICT (São Jorge, tools/mapa/cidade_v2.py) já faz e o que falta
| Técnica | Quem usa | Nós hoje | Classificação | Custo Android |
|---|---|---|---|---|
| Ruas à mão + lotes por regra, semente fixa | 7DTD, DL2 | SIM | — | — |
| Hierarquia de ruas | 7DTD | SIM (avenida/rua/viela) | — | — |
| Prédios especiais com regra de lugar | 7DTD, CDDA | parcial (marcos à mão) | ADAPTAR | baixo |
| Planejar pelos TRAJETOS entre objetivos (papel/gray box) | DL2 | NÃO | APROVEITAR | zero |
| Telhados como 2º nível ligado (rede de percurso) | DL2 | só tábuas em 3 prédios | APROVEITAR | baixo |
| "Ajudantes" que mostram o caminho (escada, caçamba, andaime) | DL2 | quase nada | APROVEITAR | baixo |
| Peças MODULARES com instâncias compartilhadas (parede, janela, porta, canto) | TLOU, DL2 | NÃO (cada prédio é um modelo inteiro) | ADAPTAR (grande) | REDUZ memória/APK, + variedade |
| Cômodo como dado (loot/zumbi por cômodo) | Project Zomboid | NÃO (só nome do móvel) | APROVEITAR | zero |
| Mapa em setores que carregam/descarregam | 7DTD | NÃO (500 m tudo carregado) | INVESTIGAR (só se o mapa crescer) | reduz memória |
| Lugares isolados fora da cidade | 7DTD | SIM (posto, helicóptero, quarentena) | — | — |
| Poucas pessoas, muitos sistemas | Days Gone | é o nosso caso | APROVEITAR | — |
