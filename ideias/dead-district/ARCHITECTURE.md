# ARCHITECTURE — como o mapa é feito hoje

```
tools/mapa/cidade_v2.py ──> assets/mapa/cidade.json ──┐
tools/blender/ruinas.py + cidade.py ──> assets/ruinas/*.glb ──> tools/mapa/mede_ruinas.gd ──> medidas.json
                                                       └──> scripts/bairro.gd (Bairro) + planta.gd (Planta)
                                                              ├─ ruas/calçadas/faixas: malhas juntas por pedaço de 125 m
                                                              ├─ prédios: _poe_modelo/_poe_ruina (glb, colisão "-col")
                                                              ├─ grupos do glb: ext / longe / detalhe / dentro (alcances)
                                                              ├─ _junta_longe: HLOD por pedaço
                                                              ├─ Gaveta (móvel -> loot), Moveis.troca (caixa -> modelo)
                                                              └─ malha de navegação pronta (main._assa, nav_*.res)
```
- Distância de desenho: `Config.qualidade().longe` (120-450 m) e `detalhe`; `_alcance` liga `visibility_range` por grupo.
- Não existe carregamento/descarregamento por região: a cidade toda fica na memória (com 1 km² vai precisar).
- Pipeline de regerar tudo: modelos -> import -> medidas -> planta -> malha -> testes (`pipeline.sh` no scratchpad;
  registrar em tools/ quando virar rotina).
