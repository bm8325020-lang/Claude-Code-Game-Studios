# Efeitos: fome, sede, infeccao, ferimentos
modelo: auto/coding:reliable

## Descobertas

**Escopo da evidência:** análise apenas do recorte de `effects.json`. Ele termina no efeito `no_power_leg`; portanto, sangramento, ferimentos corporais, mordidas, dor persistente, infecção médica e rotinas C++ de aplicação/remoção não estão necessariamente representados. Não foram fornecidos arquivos `.cpp/.h`, então não há funções de origem observáveis.

### 1. Efeito é uma definição declarativa identificada por `id`

- **Origem:** campo `type`, campo `id`, por exemplo `effect_type`/`staggered`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** cada efeito possui um identificador e propriedades opcionais: nome, descrição, duração, intensidade, modificadores, flags e mensagens.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** muito viável com `Resource`, `Dictionary` ou `class EffectDefinition`.
- **Android:** impacto mínimo; carregar definições uma vez consome pouca memória.
- **Complexidade:** baixa.

### 2. Duração é limitada por `max_duration`

- **Origem:** `max_duration`, observável em `staggered`, `winded`, `venom_player1`, `milked` e outros.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** a definição estabelece um limite temporal, aceitando segundos ou unidades textuais como `"30 s"`, `"15 m"` e `"1 d"`. O recorte não mostra o contador runtime nem o código que reduz a duração.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** usar segundos em `float`, evitando parsing durante o jogo.
- **Android:** custo desprezível se os efeitos ativos forem atualizados apenas em entidades existentes.
- **Complexidade:** baixa.

### 3. Intensidade permite acumulação e limite

- **Origem:** `max_intensity`, `int_add_val`, `int_decay_step`; exemplos `frenzy`, `catch_up`, `eyebot_assisted`, `grown_of_fuse`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** aplicações podem aumentar a intensidade por um valor definido; `max_intensity` limita o valor. `int_decay_step: 0` em `grown_of_fuse` indica, por inferência, que não há redução automática dessa intensidade.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** campos inteiros em uma instância `ActiveEffect`.
- **Android:** baixo custo; usar inteiros e não criar objetos por “stack”.
- **Complexidade:** baixa/média.

### 4. Evolução por intensidade usando `base_mods` e `scaling_mods`

- **Origem:** `base_mods`, `scaling_mods`; exemplos `frenzy` e `grown_of_fuse`.
- **Evidência:** **FATO OBSERVADO no código** para a existência dos campos; **INFERÊNCIA TÉCNICA** para a fórmula exata.
- **Mecanismo:** `base_mods` define o efeito inicial; `scaling_mods` aparenta acrescentar modificadores proporcionalmente à intensidade. Em `frenzy`, velocidade, acerto e esquiva escalam; em `grown_of_fuse`, resistência, regeneração e velocidade dependem da intensidade.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** cálculo centralizado em um agregador de modificadores, recalculado quando a intensidade muda.
- **Android:** baixo impacto se recalculado por evento; evitar recalcular todos os efeitos a cada frame.
- **Complexidade:** média.

### 5. Dano periódico possui quantidade, mínimo e chance

- **Origem:** `hurt_amount`, `hurt_min`, `hurt_chance`; exemplos `venom_player1` e `venom_player2`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** o veneno declara dano periódico com quantidade, dano mínimo e chance. Os comentários indicam dano médio e faixa estimada, mas o algoritmo que sorteia e aplica o dano não está no recorte.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** componente de dano temporal com intervalo fixo ou baseado em turnos.
- **Android:** custo baixo; timer por entidade ou atualização em lote é preferível a um `Timer` por efeito.
- **Complexidade:** média.

### 6. Modificadores podem alterar atributos, dano e funções de combate

- **Origem:** `base_mods`, `limb_score_mods`, `enchantments`, `incoming_damage_mod`, `values`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** efeitos alteram velocidade, força, destreza, dor, percepção, pontuação de membros, dano recebido e valores como `SPEED` ou `REGEN_HP`. `photophobia` aumenta danos recebidos; `grown_of_fuse` reduz certos danos e concede regeneração.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** usar um sistema de modificadores tipado, em vez de interpretar strings em tempo real.
- **Android:** impacto baixo com poucos efeitos; expressões matemáticas genéricas podem consumir CPU se avaliadas continuamente.
- **Complexidade:** média/alta.

### 7. Condições e flags controlam comportamento especial

- **Origem:** `condition`, `u_has_effect`, `flags`, `immune_flags`; exemplos `grown_of_fuse`, `maimed_wings`, `venom_player2`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** um efeito pode depender de outro efeito, conceder imunidade ou ativar comportamento especial. `DISABLE_FLIGHT`, por exemplo, não é apenas um modificador numérico; deve ser consultado pelo sistema de movimento.
- **Classificação:** **APROVEITAR** para flags simples; **INVESTIGAR** para condições complexas.
- **Godot 4:** flags como enumeração ou bitmask; condições como recursos previamente compilados.
- **Android:** bitmask é barato; evitar consultas recursivas entre muitos efeitos.
- **Complexidade:** média.

### 8. Cura, remoção e conflito aparecem como operações distintas

- **Origem:** `removes_effects`, `remove_message`, ausência de `max_duration` em alguns efeitos; exemplo `staggered`.
- **Evidência:** **FATO OBSERVADO** para os campos; **HIPÓTESE** sobre a implementação completa de cura.
- **Mecanismo:** um efeito pode remover outros ao ser aplicado, como `staggered` removendo efeitos de agarramento. `remove_message` representa comunicação ao jogador. O recorte não mostra itens, tratamentos, resistência, redução gradual ou funções explícitas de cura.
- **Classificação:** **ADAPTAR**; **INVESTIGAR** para a cura médica.
- **Godot 4:** separar `expire_effect()`, `remove_effect()` e `cure_effect()`, pois cura pode ter regras próprias.
- **Android:** baixo impacto.
- **Complexidade:** média.

### 9. “Infection” no recorte não representa necessariamente doença

- **Origem:** `id: "infection"`, `base_mods.speed_mod: [-80]`.
- **Evidência:** **FATO OBSERVADO**; **INFERÊNCIA TÉCNICA** sobre o significado.
- **Mecanismo:** aqui é descrito como tag de IA para uma missão de NPC infectado, com penalidade de velocidade. Não há duração, progressão, transmissão ou cura declaradas nesse objeto.
- **Classificação:** **INVESTIGAR**, não reutilizar diretamente como infecção de zumbi.
- **Godot 4:** viável, mas deve ser separado de um modelo médico.
- **Android:** irrelevante/baixo.
- **Complexidade:** média se forem adicionadas fases e transmissão.

### 10. Sangramento e mordida não estão comprovados no recorte

- **Origem:** nenhuma definição fornecida para `bleeding`, `bite`, ferimento ou equivalente.
- **Evidência:** **FATO OBSERVADO** sobre a ausência no recorte; não prova ausência no projeto inteiro.
- **Mecanismo:** não é possível determinar intensidade, duração, evolução ou cura desses efeitos a partir dos arquivos enviados.
- **Classificação:** **INVESTIGAR**.
- **Godot 4:** presumivelmente viável, mas seria especulação implementar a partir deste recorte.
- **Android:** ainda não mensurável.
- **Complexidade:** indeterminada.

## RELATÓRIO — 12 itens

1. **Objetivo:** descobrir como efeitos de dano, doença, incapacitação e recuperação são definidos.
2. **Jogo e versão:** Cataclysm: Dark Days Ahead, código aberto CC BY-SA 3.0; o pedido informa versão master atual, mas isso não foi verificado independentemente. Destino: DEAD DISTRICT em Godot 4.7 para Android.
3. **Ferramentas:** inspeção textual/estrutural do recorte JSON fornecido; nenhuma compilação ou execução.
4. **Método:** identificar campos declarativos e relacioná-los a duração, intensidade, modificadores, condições e remoção.
5. **Evidências:** `max_duration`, `max_intensity`, `int_add_val`, `base_mods`, `scaling_mods`, `hurt_*`, `enchantments`, `flags`, `immune_flags` e `removes_effects`.
6. **Funcionamento:** efeitos são definições por ID aplicadas a entidades, com modificadores e regras opcionais.
7. **Inferências:** intensidade provavelmente participa dos modificadores escaláveis; duração e dano periódico são processados fora do JSON.
8. **Hipóteses:** a atualização ocorre em um sistema runtime de efeitos; a cura provavelmente remove ou reduz instâncias, mas isso não foi demonstrado.
9. **Limitações:** faltam C++, demais JSON, definições de ataques, corpo/membros, itens médicos e rotinas de atualização.
10. **Classificação:** aproveitar o modelo declarativo; adaptar o agregador de modificadores; investigar cura, mordida, sangramento e infecção; descartar cópia literal.
11. **Relevância para DEAD DISTRICT:** usar efeitos com duração, stacks, dano temporal, penalidades e flags, simplificados para o ciclo de jogo do Android.
12. **Próximas investigações:** localizar `effect`/`effect_type` em C++, definições de sangramento e mordida, aplicação por ataques, decremento temporal, tratamento médico, resistência/imunidade e serialização de efeitos.

### O que ficou de fora do recorte

O arquivo termina no meio da definição de `no_power_leg`. Não foram analisados efeitos posteriores, possíveis definições específicas de sangramento, feridas, mordidas, dor, infecção progressiva, medicamentos, funções C++ de aplicação/atualização/remoção nem regras de salvamento.

**Riscos:** implementar a fórmula de escala, cura ou infecção apenas com este recorte pode produzir comportamento incompatível; expressões genéricas e timers por efeito podem causar custo desnecessário no Android.
