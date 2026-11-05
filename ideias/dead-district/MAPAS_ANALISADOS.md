# Mapas analisados
(vazio)
## Cataclysm DDA — organização do mapa grande (overmap) — RELATORIOS/cdda/mapa.md (nomes conferidos em src/overmap.cpp)
- FATO: mapa em camadas de células (overmap); primeiro natureza por ruído (florestas, pântanos, várzea), depois cidades como âncoras,
  depois estradas ligando a cidade mais perto (`place_roads`, `connect_closest_points`), depois prédios especiais com regra de onde cabem
  (`place_special` / `can_place_special`), estradas continuam na borda do vizinho.
- ADAPTAR para DEAD DISTRICT: nossa cidade (cidade_v2.py) já é "ruas à mão + lotes por regra"; ganho: lugares especiais com regra de
  colocação (perto de rua grande, longe de outro igual) e mapa maior em pedaços ligados pela borda (expansão futura sem refazer).
- Limite: recorte de 30 KB; bairros (city_buildings) ficaram de fora.
