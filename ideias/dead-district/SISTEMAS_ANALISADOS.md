# Sistemas analisados
(vazio)
## Loot (Cataclysm DDA) — RELATORIOS/cdda/loot.md
- APROVEITAR: grupos "coleção" (cada item com chance própria) e "distribuição" (um item por peso); grupos dentro de grupos; trava contra recursão; quantidade separada do peso.
- ADAPTAR: raridade por faixas (comum/raro) por cima dos pesos; contêineres.
- INVESTIGAR: quem escolhe o grupo pelo lugar (mapgen), eventos.
- DEAD DISTRICT hoje: Loot.TABELA/sorteia (scripts/loot.gd) já é parecido; ganho: grupos por lugar (farmácia, açougue...).

## IA dos zumbis (Cataclysm) — RELATORIOS/cdda/ia_zumbis.md (nomes conferidos em src/monmove.cpp)
- APROVEITAR: `monster::plan` escolhe alvo por nota (`rate_target`) e troca de alvo; memória do alvo por turnos (`turns_since_target`);
  visão diferente de dia e de noite (vision_day/night); `will_move_to` testa o terreno antes de andar; bando (SWARMS) segue os vizinhos.
- DEAD DISTRICT hoje: Zumbi já vê/ouve/persegue/procura; ganho: nota de alvo e memória de quanto tempo sem ver; visão menor à noite.
## Som (Cataclysm) — RELATORIOS/cdda/som.md (nomes conferidos em src/sounds.cpp)
- APROVEITAR: sons do turno juntados em grupos (`cluster_sounds`) antes de avisar os monstros (economiza CPU); som "provocativo" (`is_provocative`) atrai, outros não;
  horda longe recebe sinal resumido (`get_signal_for_hordes`); marcadores de som para o jogador (`process_sound_markers`).
- DEAD DISTRICT hoje: Zumbi.barulho por evento; ganho: juntar barulhos do mesmo segundo (menos CPU no celular) e horda de longe só "atraída".
## Efeitos (Cataclysm) — RELATORIOS/cdda/efeitos.md (campos conferidos em data/json/effects.json)
- APROVEITAR: efeito como dado (id, duração máxima, intensidade com acúmulo e queda `int_decay_step`, dano periódico com chance `hurt_chance`, efeitos que removem outros).
- ADAPTAR: infecção/sangramento/mordida (o recorte não tinha; investigar outros JSON).
- DEAD DISTRICT hoje: infecção e mordida em código; ganho: tabela de efeitos (sangrando, fraturado, infectado) em dado, fácil de equilibrar.
