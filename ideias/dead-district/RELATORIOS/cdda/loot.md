# Loot e distribuicao de itens
modelo: auto/coding:reliable

## Descobertas

### 1. Dois modos principais de grupo
- **Origem:** `Item_group::create`, `Item_group::create_single`, campo `type`, enum `G_COLLECTION`/`G_DISTRIBUTION`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Funcionamento:**  
  - `collection`: avalia cada entrada independentemente; várias podem aparecer.  
  - `distribution`: escolhe uma única entrada ponderada pelo campo `prob`.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** muito viável com `Resource` ou `Dictionary` tipado.
- **Android:** baixo custo; poucas rolagens e iterações.
- **Complexidade:** baixa.

### 2. Sorteio ponderado da distribuição
- **Origem:** `Item_group::pick_distribution_entry`, `sum_prob`, `cached_cum_prob`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Funcionamento:** soma os pesos das entradas, sorteia inteiro entre `1` e `sum_prob` e localiza a entrada pelo primeiro acumulado maior ou igual ao valor. A chance efetiva é `prob / soma_dos_probs`; não é uma porcentagem absoluta.
- **Exemplo:** em `produce`, `apple` tem peso 70, mas sua probabilidade é `70 / soma de todos os pesos`, não 70%.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** `PackedInt32Array` com busca linear ou binária; o acumulado pode ser cacheado.
- **Android:** custo mínimo; cache reduz CPU em grupos grandes.
- **Complexidade:** baixa/média.

### 3. Entradas de grupo podem apontar para outros grupos
- **Origem:** `Single_item_creator::create_single_without_container`, `Single_item_creator::create`, `add_group_entry`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Funcionamento:** uma entrada pode gerar um item direto ou delegar a outro grupo. Isso permite construir loot hierárquico, como `dry_goods` escolhendo `flour_various`.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** viável com referências por ID e registro global de grupos.
- **Android:** baixo impacto; cuidado com resolução repetida de IDs.
- **Complexidade:** média.

### 4. Proteção contra recursão
- **Origem:** `RecursionList`, `Single_item_creator::create*`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Funcionamento:** IDs já ativos são registrados. Se um grupo tentar chamar a si mesmo, a geração é interrompida e retorna item nulo ou a lista parcial.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** usar `Array[StringName]`, `Dictionary` ou conjunto equivalente.
- **Android:** impacto desprezível.
- **Complexidade:** baixa.

### 5. Collection faz rolagens independentes
- **Origem:** `Item_group::create`, ramo `G_COLLECTION`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Funcionamento:** para cada entrada, sorteia `rng(0,99) >= prob`; se falhar, não gera. Assim, `prob` funciona como chance independente por entrada. O grupo pode gerar zero, um ou vários resultados.
- **Exemplo:** `food_vendor_cart_kitchen` possui várias entradas com `count: [0,3]`; cada uma pode contribuir separadamente.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** simples com `randf()` ou `randi_range`.
- **Android:** custo proporcional ao número de entradas; normalmente baixo.
- **Complexidade:** baixa.

### 6. `create_single` não equivale exatamente a `create`
- **Origem:** `Item_group::create_single`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Funcionamento:** em `collection`, percorre as entradas e retorna imediatamente o primeiro resultado bem-sucedido. Portanto, produz no máximo um item, ao contrário de `create`, que percorre todas.
- **Inferência técnica:** a ordem das entradas passa a influenciar o resultado nesse caminho.
- **Classificação:** **INVESTIGAR**.
- **Godot 4:** viável, mas deve haver API explícita para “um item” versus “lista de loot”.
- **Android:** irrelevante em CPU.
- **Complexidade:** baixa.

### 7. Quantidade é controlada por `count`
- **Origem:** `Single_item_creator::create`, campo `modifier->count`; `create_single_without_container`.
- **Evidência:** **FATO OBSERVADO no código**, com detalhe incompleto no recorte.
- **Funcionamento:** quantidade fixa usa esse valor; intervalo usa sorteio entre mínimo e máximo. Com `spawn_flags::maximized`, é usado o máximo. Exemplos: `count: 3`, `[1,3]`, `[0,3]`.
- **Limitação do recorte:** a leitura JSON e a implementação completa de `modifier` não foram incluídas; portanto, a interação exata entre `count`, `charges` e o contêiner não está totalmente demonstrada.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** `Vector2i(min,max)` ou estrutura própria.
- **Android:** baixo impacto.
- **Complexidade:** média.

### 8. Quantidade pode ser independente do número de entradas
- **Origem:** `Single_item_creator::create`, `modifier->count`; `create_single_without_container`.
- **Evidência:** **INFERÊNCIA TÉCNICA**.
- **Funcionamento:** uma entrada pode ser sorteada uma vez e gerar várias unidades, como `carrot` com `count: 6`, ou repetir a criação conforme o contador do modificador. Não se deve confundir “peso de escolha” com “quantidade produzida”.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** direto.
- **Android:** baixo impacto.
- **Complexidade:** baixa.

### 9. “Raridade” não é um sistema separado no recorte
- **Origem:** `pick_distribution_entry`, `get_probability`, dados JSON `prob`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Funcionamento:** raridade emerge de pesos menores dentro de uma distribuição. Não há campo explícito de raridade, tiers ou garantia de itens raros.
- **Hipótese:** DEAD DISTRICT pode adicionar tiers (`comum`, `raro`, `lendário`), mas isso mudaria o mecanismo original.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** muito viável.
- **Android:** sem impacto relevante.
- **Complexidade:** baixa/média.

### 10. Lugar não é resolvido por `Item_group`
- **Origem:** somente os grupos JSON e funções fornecidas.
- **Evidência:** **FATO OBSERVADO no código**.
- **Funcionamento:** os recortes mostram grupos temáticos (`fast_food`, `fish_market_stall`, `honey_market_stall`), mas não mostram quem escolhe o grupo conforme mapa, prédio, móvel ou zona.
- **Classificação:** **INVESTIGAR**.
- **Godot 4:** viável com tabela `local -> grupo`.
- **Android:** baixo custo; cache por tipo de ponto de loot é recomendado.
- **Complexidade:** média.

### 11. Contêineres e metadados são aplicados após a geração
- **Origem:** `put_into_container`, `Single_item_creator::create`, `create_single`, `guess_pocket_for`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Funcionamento:** o grupo pode gerar itens e depois colocá-los em contêineres; também há regras para mods, carregadores e armazenamento eletrônico. `sealed`, variante e comportamento de overflow participam dessa etapa.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** viável, mas exige modelo de inventário robusto.
- **Android:** memória maior se cada item for objeto complexo; usar dados compactos até a instanciação.
- **Complexidade:** média/alta.

### 12. Eventos alteram a disponibilidade, não necessariamente o peso
- **Origem:** `Item_spawn_data::get_probability`, `pick_distribution_entry`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Funcionamento:** entradas de evento podem ficar com probabilidade efetiva zero conforme configuração e data. Em distribuição, a posição continua reservada no total original; cair nessa faixa pode gerar nada, sem “passar” para outra entrada.
- **Classificação:** **INVESTIGAR**.
- **Godot 4:** viável, mas documentar se o comportamento desejado é “falha” ou redistribuição.
- **Android:** insignificante.
- **Complexidade:** média.

## RELATÓRIO

1. **Objetivo:** entender sorteio por lugar, chance, quantidade e raridade para DEAD DISTRICT.  
2. **Jogo e versão:** Cataclysm: Dark Days Ahead, código aberto, master atual conforme material fornecido; DEAD DISTRICT em Godot 4.7 para Android.  
3. **Ferramentas:** inspeção textual de `item_group.cpp` e JSON de `data/json/itemgroups/Food/food.json`.  
4. **Método:** rastreamento das funções de criação, seleção, recursão, quantidade e contêiner.  
5. **Evidências:** funções e campos citados em cada descoberta; exemplos dos grupos alimentares.  
6. **Funcionamento:** `distribution` escolhe uma entrada ponderada; `collection` testa entradas independentemente.  
7. **Inferências:** pesos menores representam raridade relativa; quantidade é separada do peso.  
8. **Hipóteses:** um sistema de raridade por tiers pode ser adicionado ao DEAD DISTRICT.  
9. **Limitações:** não foram fornecidos carregamento JSON completo, `Item_spawn_data`, `modifier`, `put_into_container` nem chamadores responsáveis por associar grupo ao lugar.  
10. **Classificação:** aproveitar seleção ponderada, collections, recursão e grupos aninhados; adaptar quantidade, contêineres e raridade; investigar lugar e eventos.  
11. **Relevância para DEAD DISTRICT:** mecanismo adequado para loot de prédios, móveis, zonas e pontos temáticos, com baixo custo para Android.  
12. **Próximas investigações:** localizar o chamador que escolhe grupos por mapa; confirmar semântica completa de `count`/`charges`; medir distribuição real; definir se eventos inativos devem consumir ou redistribuir peso.
