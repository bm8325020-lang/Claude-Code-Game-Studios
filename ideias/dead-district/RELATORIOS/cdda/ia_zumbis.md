# IA dos zumbis: percepcao e perseguicao
modelo: auto/coding:reliable

## Descobertas

### 1. Percepção visual e aquisição do alvo
- **Origem:** `monster::plan()`, `sees()`, `vision_day`, `vision_night`, `get_inter_level_visibility()`.
- **Evidência:** **FATO OBSERVADO no código.**
- **Mecanismo:** o monstro verifica se o nível do alvo está visível e depois chama `sees()`. Se o jogador for visto, calcula sua avaliação por `rate_target()`, atualiza distância, medo, raiva e pode definir `aggro_character`.
- `monster_plan` define `max_sight_range` como o maior valor entre visão diurna e noturna. Com planejamento inteligente, a distância inicial usada para comparação é limitada a `8.6f`; caso contrário, usa o alcance máximo.
- **Classificação:** **APROVEITAR.**
- **Godot 4:** viabilidade alta usando `RayCast3D`, consultas de grid, `PhysicsDirectSpaceState3D` ou um sistema 2D equivalente.
- **Android:** custo de CPU potencialmente alto se cada zumbi fizer vários testes de linha de visão por frame. Usar atualização escalonada, distância máxima e cache.
- **Complexidade:** média.

### 2. Decisão e troca de alvo
- **Origem:** `monster::plan()`, `monster_plan`, `rate_target()`, `turns_since_target`, `PRIORITIZE_TARGETS`.
- **Evidência:** **FATO OBSERVADO no código.**
- **Mecanismo:** jogadores, NPCs e monstros hostis são avaliados por `rate_target()`. Alvos mais bem avaliados substituem o atual; em empates, há seleção aleatória entre candidatos. Hostilidade de facção, fuga, proximidade e estado do alvo influenciam a escolha.
- O alvo pode ser o jogador, NPC, monstro hostil ou motorista de veículo. Se não houver alvo, o monstro pode considerar veículos em movimento.
- **Classificação:** **ADAPTAR.**
- **Godot 4:** viabilidade alta com uma estrutura `TargetCandidate` contendo distância, ameaça, visibilidade, facção e estado.
- **Android:** enumerar todos os NPCs e zumbis é caro. Usar grupos espaciais, `Area2D`, grid de proximidade ou manager de percepção.
- **Complexidade:** média.

### 3. Agressividade, medo e comportamento de fuga
- **Origem:** `anger_hostile_seen()`, `anger_mating_season()`, `anger_cub_threatened()`, campos `anger`, `morale`, `aggro_character`, `is_fleeing()`.
- **Evidência:** **FATO OBSERVADO no código.**
- **Mecanismo:** ver um alvo não garante ataque imediato. A raiva é incrementada por proximidade, visão, fraqueza do alvo e gatilhos especiais; há probabilidades como `x_in_y( anger, 100 )`. Moral reduzida pode provocar fuga. Um alvo visto pode ser perseguido, evitado ou apenas influenciar o estado.
- **Classificação:** **APROVEITAR.**
- **Godot 4:** viabilidade alta com uma máquina de estados: `IDLE`, `ALERT`, `CHASE`, `FLEE`, `SEARCH`.
- **Android:** custo baixo; o risco principal é excesso de transições e recalculo de percepção.
- **Complexidade:** baixa a média.

### 4. Movimento permitido e restrições ambientais
- **Origem:** `monster::will_move_to()`, `can_move_to()`, flags de `ter_furn_flag` e `mon_flag`.
- **Evidência:** **FATO OBSERVADO no código.**
- **Mecanismo:** antes de mover, o monstro verifica campos bloqueadores, terreno estritamente evitado, água profunda, escavação, voo, natação, dimensões especiais, luz solar, passagens estreitas e imunidade a campos.
- `can_move_to()` combina alcançabilidade (`can_reach_to`) com validade ambiental (`will_move_to`).
- **Classificação:** **ADAPTAR.**
- **Godot 4:** viabilidade alta com camadas de navegação, custos por terreno e filtros por tipo de criatura. `NavigationRegion2D/3D` sozinho não cobre bem regras dinâmicas; um filtro adicional será necessário.
- **Android:** validar muitos vizinhos é barato; recalcular regiões de navegação dinamicamente pode ser caro.
- **Complexidade:** média.

### 5. Perseguição, navegação, grupo e ausência de rastro
- **Origem:** `set_dest()`, `move()`, `get_dest()`, `patrol_route`, `mon_flag_SWARMS`, `mon_flag_GROUP_MORALE`, `tracker.for_each_reachable()`.
- **Evidência:** **FATO OBSERVADO no código** para destino, grupo e navegação parcial; **HIPÓTESE** para perda de rastro.
- **Mecanismo observado:** `plan()` transforma o alvo em um destino absoluto. Sem alvo, pode seguir patrulha, leash, jogador amigo ou posição de enxame. Membros próximos da mesma facção aumentam moral; enxames procuram aliados mais distantes, exceto quando estão excessivamente aglomerados. A execução efetiva do próximo passo aparece apenas parcialmente em `move()`, que chama `can_move_to()`.
- O trecho não mostra a implementação de pathfinding, memória de última posição, cheiro ou audição. Portanto, não é possível afirmar como o monstro perde um rastro. **Inferência técnica:** provavelmente existe lógica adicional fora do recorte para sons, destinos expirados e recalculo de caminho.
- **Classificação:** **INVESTIGAR.**
- **Godot 4:** viabilidade alta com `AStarGrid2D`, `NavigationServer2D` ou pathfinding próprio; enxame deve usar steering simples, não um caminho completo por agente.
- **Android:** pathfinding individual para centenas de zumbis é o maior risco de CPU. Usar caminhos compartilhados, atualização em lotes, LOD de IA e destinos aproximados.
- **Complexidade:** alta.

### O que ficou de fora do recorte
Não foram demonstradas as implementações de `sees()`, `hear_sound()`, cheiro, `rate_target()`, `can_reach_to()`, `set_dest()`, cálculo completo do caminho, memória de última posição, ataque corpo a corpo e restante de `monster::move()`. Assim, visão é parcialmente observável; cheiro e som não podem ser confirmados neste material.

## RELATÓRIO — 12 itens

1. **Objetivo:** entender percepção, seleção de alvo, perseguição, perda de rastro, agrupamento e navegação para DEAD DISTRICT, sem copiar código.

2. **Jogo e versão:** Cataclysm: Dark Days Ahead, código aberto sob CC BY-SA 3.0, referência declarada como master atual. A análise concreta usa somente os recortes fornecidos.

3. **Ferramentas:** leitura estática dos trechos C++ fornecidos; análise conceitual de funções, campos, flags e fluxo de decisão. Nenhuma execução ou medição de desempenho foi realizada.

4. **Método:** separar fatos diretamente presentes no código de inferências e hipóteses; mapear cada mecanismo para alternativas em Godot 4 e Android.

5. **Evidências:** `monster::plan()`, `monster_plan`, `monster::will_move_to()`, `can_move_to()`, `anger_hostile_seen()`, `anger_cub_threatened()`, `move()`, flags de visão, facção, enxame e moral.

6. **Funcionamento:** percepção visual depende de nível visível e `sees()`. Alvos são classificados por `rate_target()`. Raiva, moral, medo e proximidade alteram ataque ou fuga. O destino é definido antes do movimento e validado pelo ambiente.

7. **Inferências:** o desenho separa planejamento de execução; filtros de movimento são independentes da escolha de alvo; agrupamento usa consultas a criaturas alcançáveis e avaliação de distância.

8. **Hipóteses:** som deve estar em função não incluída, possivelmente `hear_sound`; cheiro, memória de rastros e perda de alvo não aparecem. Não se deve implementar esses pontos como fatos confirmados.

9. **Limitações:** o recorte termina no meio de `move()`, não contém definições auxiliares nem dados JSON dos monstros. Não há confirmação do algoritmo de pathfinding ou dos custos reais.

10. **Classificação:** visão, moral e agressividade: **APROVEITAR**; seleção de alvo e filtros ambientais: **ADAPTAR**; som, cheiro, perda de rastro e pathfinding completo: **INVESTIGAR**; cópia literal de código ou arquitetura excessivamente geral: **DESCARTAR**.

11. **Relevância para DEAD DISTRICT:** implementar percepção em camadas, máquina de estados, memória curta da última posição, ruído propagado por eventos e navegação com atualização escalonada. O sistema de grupos deve favorecer direção geral e separação, evitando pathfinding completo por zumbi.

12. **Próximas investigações:** obter `sees()`, `hear_sound()`, `rate_target()`, `can_reach_to()`, `set_dest()`, o restante de `move()`, estruturas de som/cheiro e dados JSON de monstros; depois medir custo com 50, 200 e 500 agentes em Android.

### RELATÓRIO curto
- **Feito:** análise dos mecanismos visíveis no recorte, classificação das evidências e avaliação para Godot 4/Android.
- **Não feito:** confirmação de cheiro, som, perda de rastro e algoritmo completo de navegação, pois não estão presentes.
- **Riscos:** extrapolar funções ausentes; custo elevado de percepção e pathfinding em grandes hordas; uso inadequado de `NavigationServer` para regras ambientais dinâmicas.
