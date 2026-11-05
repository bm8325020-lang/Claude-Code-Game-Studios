# Som e audicao
modelo: auto/coding:fast

## Descobertas

**Escopo da evidência:** análise somente dos recortes fornecidos de `sounds.cpp`. Eles não permitem confirmar que correspondem ao *master* atual nem descrever implementações chamadas, mas ausentes, como `hear_sound`, `get_signal_for_hordes` e `signal_hordes`.

1. **Registro do som — `sounds::sound`, `sounds::ambient_sound`, `sounds::add_footstep`**
   - **Evidência:** **FATO OBSERVADO** — sons positivos entram em `recent_sounds`, com volume e indicador `provocative`; eventos destinados ao processamento do jogador entram em `sounds_since_last_turn`. Passos têm categoria `movement` e são registrados nesse segundo fluxo.
   - **Classificação:** **ADAPTAR** — separar percepção de IA e apresentação ao jogador.
   - **Godot 4:** viável com eventos tipados e filas por turno.
   - **Android:** custo baixo; memória proporcional aos eventos acumulados.
   - **Complexidade:** baixa.

2. **Categorias provocativas — `is_provocative`**
   - **Evidência:** **FATO OBSERVADO** — fala, fala eletrônica, alertas e ordens são provocativos; várias outras categorias, inclusive combate e alarmes, retornam falso neste recorte.
   - **Classificação:** **INVESTIGAR** — verificar intenção e consequências em `hear_sound`; não assumir que “provocativo” significa “atrai hordas”.
   - **Godot 4:** viável como propriedade da categoria.
   - **Android:** custo desprezível.
   - **Complexidade:** baixa.

3. **Distância/atenuação — `sound_distance`**
   - **Evidência:** **FATO OBSERVADO** — calcula distância horizontal `rl_dist` mais penalidade vertical; níveis subterrâneos adicionam atenuação especial.
   - **Classificação:** **ADAPTAR** — calibrar para o mapa e o design de DEAD DISTRICT. O trecho não mostra propagação por paredes ou obstáculos.
   - **Godot 4:** viável como função de distância em coordenadas de jogo.
   - **Android:** custo baixo por cálculo; pode crescer ao avaliar muitos pares.
   - **Complexidade:** baixa a média.

4. **Agrupamento de eventos — `cluster_sounds`**
   - **Evidência:** **FATO OBSERVADO** — escolhe sementes aleatórias, associa sons a centróides próximos e usa posição ponderada pelo volume. Volume do centróide é o maior do grupo; o peso acumula e o indicador provocativo é combinado por OR. O comentário declara que a finalidade é reduzir custo com muitos monstros e sons.
   - **Classificação:** **ADAPTAR** — útil se medições mostrarem custo elevado; o resultado aproxima fontes distintas.
   - **Godot 4:** implementável em GDScript; considerar implementação otimizada se houver muitos eventos.
   - **Android:** reduz trabalho posterior da IA; agrupamento também consome CPU e aloca memória temporária.
   - **Complexidade:** média.

5. **Monstros e hordas — `sounds::process_sounds`**
   - **Evidência:** **FATO OBSERVADO** — subtrai a atenuação climática do volume do centróide; consulta `get_signal_for_hordes` e, se positivo, chama `overmap_buffer.signal_hordes`. Percorre todos os monstros e chama `hear_sound` quando `vol * 2 > dist`; processa também armadilhas sonoras. Limpa `recent_sounds` ao final.
   - **Classificação:** **ADAPTAR** — separar reação local de monstros e sinalização de hordas. **INVESTIGAR** — fórmula do sinal e comportamento de `hear_sound` não constam do recorte.
   - **Godot 4:** viável; usar busca espacial ou regiões para evitar varrer todos os monstros, se necessário.
   - **Android:** varredura global pode ser cara em mapas densos; agrupamento reduz chamadas. Memória baixa a moderada.
   - **Complexidade:** média; alta para hordas persistentes.

6. **Audição do jogador — `sounds::process_sound_markers`**
   - **Evidência:** **FATO OBSERVADO** — calcula volume sentido e ouvido com distância, capacidade auditiva, proteção auditiva e clima; trata surdez, dano auditivo, despertar, mensagens, distrações e pistas de direção. Sons altos podem causar surdez.
   - **Classificação:** **ADAPTAR** — priorizar escala de volume, surdez e pistas; efeitos de saúde dependem do design do jogo.
   - **Godot 4:** viável como simulação lógica independente do áudio reproduzido.
   - **Android:** custo proporcional aos eventos do turno; baixo em volume moderado de eventos.
   - **Complexidade:** média.

7. **Marcadores e apresentação — `describe_sound`, `sound_markers`, `sound_at`**
   - **Evidência:** **FATO OBSERVADO** — mensagens variam por categoria e visibilidade; para fontes não vistas, marcadores podem ser deslocados aleatoriamente conforme volume e distância. Sons visíveis geralmente não recebem marcador, com exceções.
   - **Classificação:** **ADAPTAR** — boa base para pistas de áudio sem revelar localização exata.
   - **Godot 4:** viável com UI e marcador temporário no mapa.
   - **Android:** custo baixo; controlar quantidade de marcadores e mensagens.
   - **Complexidade:** baixa a média.

8. **Áudio ambiental — `sfx::do_ambient`**
   - **Evidência:** **FATO OBSERVADO** — seleciona ambientes conforme hora, abrigo, subsolo, clima e audição; aplica fades e pode silenciar ao dormir. É apresentação de áudio, distinta do registro que afeta monstros.
   - **Classificação:** **APROVEITAR** como referência de organização, não como lógica de atração.
   - **Godot 4:** viável com `AudioStreamPlayer` e buses.
   - **Android:** uso de áudio/memória depende dos recursos carregados; usar streaming e limitar camadas simultâneas.
   - **Complexidade:** média.

### O que ficou de fora dos recortes

A fórmula completa de atração de hordas e seus efeitos persistentes; implementação de percepção e comportamento dos monstros em `hear_sound`; obstáculos, interiores ou outros fatores não visíveis em `sound_distance`; ciclo chamador e frequência de `process_sounds`; definições dos tipos e dados climáticos; implementação completa do backend de áudio. Não se conclui que o jogo transmite som físico por uma simulação de ondas.

## RELATÓRIO — 12 itens

1. **Objetivo:** descrever mecanismos observáveis de emissão, propagação, audição e atração de hordas.
2. **Jogo e versão:** Cataclysm: Dark Days Ahead; versão declarada pelo pedido: *master* atual. A versão não foi verificada independentemente.
3. **Ferramentas:** recorte textual de `sounds.cpp`; nenhuma ferramenta externa foi usada.
4. **Método:** leitura estática do trecho e separação entre fatos explícitos e interpretações.
5. **Evidências:** nomes de funções e campos indicados em cada descoberta; fonte limitada ao arquivo recortado.
6. **Funcionamento:** eventos são registrados em filas distintas; sons recentes são agrupados e avaliados para monstros, armadilhas e hordas; eventos também informam a percepção do jogador.
7. **Inferências:** agrupar fontes é uma otimização de custo; a distância apresentada é uma métrica de jogo, não prova de simulação acústica física.
8. **Hipóteses:** **nenhuma tratada como fato**; fórmulas internas de audição e sinalização de hordas permanecem desconhecidas.
9. **Limitações:** recortes parciais, sem validação da revisão do repositório e sem definições das funções chamadas.
10. **Classificação:** aproveitar organização de áudio ambiental; adaptar eventos, percepção e marcadores; investigar hordas e IA; não reproduzir sem necessidade os detalhes específicos de saúde auditiva.
11. **Relevância para DEAD DISTRICT:** fornece uma arquitetura transferível para sons de gameplay e pistas imperfeitas; o impacto de hordas depende de um sistema próprio de propagação/atração.
12. **Próximas investigações:** examinar `hear_sound`, `get_signal_for_hordes`, `overmap_buffer.signal_hordes`, o ciclo de chamadas e as regras de propagação por terreno.

**RELATÓRIO curto — o que fiz:** analisei os recortes e classifiquei mecanismos e custos. **O que não fiz:** não confirmei o *master* atual nem consultei os arquivos ausentes. **Riscos:** tratar inferências como fatos ou adotar a varredura global de monstros em Android sem perfil de desempenho.
