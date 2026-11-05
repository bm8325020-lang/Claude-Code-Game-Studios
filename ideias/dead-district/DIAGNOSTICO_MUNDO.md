# Diagnóstico do mundo (Etapa A do MASTER PROMPT ABSOLUTO, 05/11)

Inspecionado no código e nos arquivos (não suposição). Motor: Godot 4.7.2, renderer GL Compatibility (Android).

## Como o mundo é feito hoje
| # | Pergunta | Resposta (arquivo) |
|---|---|---|
| 1 | Mapa | `tools/mapa/raven_creek.py` gera `assets/mapa/cidade.json` (ruas, lotes, props); `scripts/bairro.gd` + `planta.gd` montam tudo ao criar a sala |
| 2 | Casas | Feitas por script no Blender: `tools/blender/casas_us.py` (Raven Creek), `ruinas.py`/`cidade.py` (lojas, públicos). Paredes, janelas, telhado = caixas (`caixa()`) |
| 3 | Modelos 3D prontos usados | Poly Haven CC0: 25 móveis (`assets/moveis`), 164 no catálogo do modo construção; Kenney CC0 (catálogo); Majadroid CC0 (capital ao longe); Sketchfab CC BY: zumbis, pistola, facão |
| 4 | Primitivas | TODAS as construções e a maior parte dos móveis (bancada, pia, vaso, banheira, máquinas, mesa de centro, tapete, porta, janela, vidro) são caixas |
| 5 | Móveis | Compositor por regras (`tools/blender/interiores.py`) põe caixas no lugar certo; no jogo `scripts/moveis.gd` troca 15 tipos de caixa por modelo Poly Haven esticado para caber na caixa |
| 6 | Texturas | Projeção triplanar no mundo (`Bairro._mat`): não seguem a peça; 512 px; várias feitas por código (siding, telha, carpete) |
| 7 | Materiais | `StandardMaterial3D` com cor + normal; sem roughness/AO por textura; vidro = placa escura ou alfa simples |
| 8 | Vegetação | 3 árvores low-poly feitas no Blender + tufos em MultiMesh (`enfeites.gd`); sem vento; nenhuma árvore pronta de qualidade |
| 9 | Luz | Sol direcional + céu procedural (`main.gd` CEU) + névoa; sombras opcionais; nada pré-calculado dentro das casas (GL Compatibility não tem GI, SSAO, SSR) |
| 10 | Som | `som_ambiente.gd`: vento, sustos ao longe, passos por chão, eco em casa, gemidos; sem zonas (cidade/floresta) nem camadas |
| 11 | Carregamento | A cidade inteira é montada no começo (sem setores); só `visibility_range` e junção por pedaço de 125 m (HLOD) |
| 12 | Colisão | Do glb (nome "-col": caixas); malha de navegação pronta em 16 pedaços ligados por NavigationLink3D |
| 13 | Limites | Celular: ~400-900 chamadas de desenho por vista no centro; 527 prédios na memória; disco desta máquina ~1,4 GB livre |
| 14 | Aproveitável | Sistemas (zumbi, loot por cômodo, gavetas, portas, rede, horda, clima, ciclo), compositor de interiores, malha em pedaços, catálogo Poly Haven/Kenney |

## Diagnóstico honesto
| Problema | Causa técnica encontrada | Solução proposta |
|---|---|---|
| Casas ruins | Geradas por mim com caixas no Blender: sem chanfro, sem moldura de verdade, sem detalhe de telhado; textura triplanar de 512 px que não segue a peça | Trocar por modelos prontos de casa (Sketchfab CC0/CC BY, Poly Haven) ou kit modular pronto com textura PBR (ambientCG/Poly Haven CC0); manter só a lógica (portas, loot, cômodos) |
| Móveis ruins | Caixas; e os 25 do Poly Haven são esticados para caber na caixa (`moveis.gd`) | Biblioteca de móveis prontos por cômodo (Poly Haven CC0 + Sketchfab), posição pelo compositor sem esticar (escala uniforme) |
| Cidade genérica | 6 casas repetidas (variação só de cor); lojas iguais com letreiro diferente | Pelo menos 12-20 modelos de casa diferentes, lojas com fachada própria |
| Vegetação artificial | 3 árvores low-poly feitas por código, tufos iguais | Árvores, arbustos e mato prontos (Poly Haven CC0, Quaternius CC0), sombra de vento no shader |
| Falta de atmosfera | Pouco abandono composto (carros, lixo, barricadas espalhados por sorteio); som sem zonas | Conjuntos de cena (acidente, evacuação, saque) com modelos prontos; som por zona |
| Falta de profundidade | Fachadas planas, sem varal, poste quebrado, fio caído; luz sem contraste dentro | Modelos com relevo, decalques, luz por fora das janelas (cor de vértice), névoa por distância |
| Poucos pontos de interesse | Só raids (delegacia, hospital, mercado, igreja) e marcos | POIs: posto, oficina, acampamento, cabana, floresta com trilhas (Fase 5) |

## Plano (ordem do prompt, Fase 15)
- A — este diagnóstico. FEITO.
- B — biblioteca: buscar, baixar, importar e testar no Godot (com licença registrada em `jogo/assets/LICENCAS_MUNDO.md`): casas
  (Sketchfab CC0/CC BY, baixo polígono para celular), móveis e objetos (Poly Haven CC0), texturas PBR (ambientCG CC0),
  vegetação (Poly Haven / Quaternius CC0), veículos. Pasta organizada como o prompt pede (`assets/mundo/...`).
- C — uma casa de demonstração completa com modelos prontos; fotos de fora, de cada cômodo e da planta.
- D — um quarteirão de demonstração. Só depois a cidade toda, a floresta e a estrada (Fase 5).
Limite real: disco (~1,4 GB livre) e celular (memória). Cada asset entra com medida de tamanho e polígonos.
