# Mapa: organizacao da cidade
modelo: auto/coding:reliable

## Descobertas

### 1. Estrutura espacial do overmap
- **Origem:** `overmap::populate`, `ter()`, `ter_set()`, tipos `tripoint_om_omt`, `point_om_omt`, constantes `OMAPX`, `OMAPY`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** o mapa é uma grade de células OMT, com coordenadas `x`, `y` e profundidade `z`. A geração altera o terreno armazenado em cada célula por `ter_set`.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** viável com uma matriz/chunk de dados; `Resource` ou estruturas próprias para células.
- **Android:** memória proporcional ao número de células carregadas. Recomenda-se armazenar apenas dados compactos e carregar regiões próximas.
- **Complexidade:** baixa para a estrutura; média para persistência e streaming.

### 2. Cidades como âncoras de conexão
- **Origem:** campo `cities`; `city::pos`, `city::size`; `overmap::get_nearest_city`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** as cidades são uma coleção de posições e tamanhos. A cidade mais próxima é encontrada por varredura linear e distância. Estradas e ferrovias usam as cidades como pontos-alvo.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** simples; `Array<CityData>` ou dicionário espacial.
- **Android:** a busca linear é barata enquanto houver poucas cidades; pode exigir particionamento se o mundo for muito grande.
- **Complexidade:** baixa.

### 3. Estradas interurbanas
- **Origem:** `overmap::place_roads`, `connections_out`, `overmap_connection::inter_city_road_connection`, `connect_closest_points`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** o algoritmo reúne saídas do overmap e centros de cidades. Se não houver cidade, cria um ponto central aleatório como destino. Depois conecta os pontos mais próximos usando o tipo de conexão rodoviária.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** viável com grafo de pontos e algoritmo de conexão; o desenho posterior pode usar tiles, segmentos ou curvas.
- **Android:** geração é pontual e barata; evite recalcular todo o grafo durante a movimentação.
- **Complexidade:** média.

### 4. Continuidade entre overmaps
- **Origem:** `populate_connections_out_from_neighbors`, `place_roads`, `place_railroads`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** conexões que chegam pela borda de um overmap vizinho são copiadas para a borda oposta do mapa atual. Para mapas ainda não gerados, são escolhidos pontos de saída aleatórios, evitando rios e as extremidades dos cantos.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** muito viável; exige coordenadas globais estáveis e geração determinística por seed.
- **Android:** baixo custo; guardar apenas pontos de fronteira reduz memória.
- **Complexidade:** média.

### 5. Ferrovias
- **Origem:** `overmap::place_railroads`, `railroads_out`, `rail_connection`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** funciona como as estradas, mas cada cidade contribui com um ponto aleatório dentro de um raio proporcional ao tamanho da cidade. Esses pontos são conectados por ferrovias.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** viável usando o mesmo sistema de conexões das estradas, com regras de terreno diferentes.
- **Android:** custo semelhante ao das estradas; a aleatoriedade deve ser baseada em seed para não gerar divergências.
- **Complexidade:** média.

### 6. Tipos de bairro ou subdivisão urbana
- **Origem:** não presente no recorte.
- **Evidência:** **HIPÓTESE** apenas como necessidade de investigação.
- **Mecanismo:** o trecho mostra cidades como pontos com tamanho, mas não mostra divisão interna em bairros, ruas locais ou zoneamento urbano.
- **Classificação:** **INVESTIGAR**.
- **Godot 4:** viável, mas depende do modelo desejado: grade de zonas, grafo viário ou máscaras de densidade.
- **Android:** bairros pré-gerados ou baseados em sementes são mais baratos que simulação em tempo real.
- **Complexidade:** média a alta.

### 7. Prédios especiais
- **Origem:** `city_buildings::load`, `overmap::populate`, `place_special_forced`, `place_special`, `can_place_special`, `overmap_special_id`.
- **Evidência:** **FATO OBSERVADO no código** sobre filtro e colocação; detalhes de seleção não estão no recorte.
- **Mecanismo:** prédios ou locais especiais são carregados como definições de “specials”. A população filtra essas definições por listas de flags permitidas ou proibidas. Alguns podem ser colocados forçadamente ou condicionados à posição, direção e vizinhança.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** adequado para `Resource`/JSON com tags, regras de encaixe e orientação.
- **Android:** carregar apenas metadados no overmap; detalhes do prédio devem ser adiados até o jogador aproximar-se.
- **Complexidade:** média a alta.

### 8. Trilhas florestais e cabeças de trilha
- **Origem:** `place_forest_trails`, `place_forest_trailheads`, `connect_closest_points`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** regiões florestais contíguas são encontradas por preenchimento em quatro direções. Se forem grandes o bastante, escolhem-se centro, pontos aleatórios e possíveis pontos de borda; esses pontos são conectados. Cabeças de trilha podem receber especiais próximos a estradas.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** viável com flood fill e grafo simplificado.
- **Android:** custo proporcional à área florestal; executar somente na geração e armazenar o resultado.
- **Complexidade:** média.

### 9. Florestas e pântanos
- **Origem:** `place_forests`, `place_swamps`, `om_noise_layer_forest`, `om_noise_layer_floodplain`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** ruído determinístico transforma terreno padrão em floresta. Pântanos combinam distância/área de influência de rios, ruído e terreno florestal existente.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** `FastNoiseLite` ou ruído próprio com seed global.
- **Android:** baixo custo se calculado por chunk; evitar avaliar células fora do raio de geração.
- **Complexidade:** baixa a média.

### 10. Ravinas
- **Origem:** `place_ravines`, `pf::greedy_path`, `rift_points`, `ter_set`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** caminhos entre origem e destino são gerados por busca gulosa. A largura é aplicada ao redor do caminho, e o terreno é propagado verticalmente até a profundidade configurada, distinguindo interior e borda.
- **Classificação:** **ADAPTAR**.
- **Godot 4:** viável em dados de mapa; a geometria visual pode ser produzida por tiles ou malhas.
- **Android:** busca e pintura são aceitáveis na geração; não devem rodar continuamente.
- **Complexidade:** média.

### 11. Regras de conexão e desenho lógico
- **Origem:** `lay_out_connection`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** cada célula recebe custo conforme o subtipo de conexão. Terreno incompatível é rejeitado; conexões existentes são preferidas; cruzamentos perpendiculares, curvas e áreas já exploradas obedecem regras específicas.
- **Classificação:** **APROVEITAR**.
- **Godot 4:** implementar como A* ou busca gulosa com custos e validações.
- **Android:** custo médio; limitar tentativas e usar cache de caminhos.
- **Complexidade:** média a alta.

### 12. O que é gerado versus desenhado
- **Origem:** `ter_set`, `connections_out`, `place_roads`, `place_forests`, `place_ravines`.
- **Evidência:** **FATO OBSERVADO no código**.
- **Mecanismo:** o recorte gera dados: tipos de terreno, pontos de conexão, especiais e caminhos. Não há código de renderização, sprites, tiles, malhas ou câmera.
- **Classificação:** **DESCARTAR** como modelo visual direto; **APROVEITAR** como modelo de dados.
- **Godot 4:** separar geração lógica da apresentação visual.
- **Android:** excelente para streaming e nível de detalhe.
- **Complexidade:** média.

## RELATÓRIO — 12 itens

1. **Objetivo:** entender como um mapa grande organiza cidades, estradas, bairros, prédios especiais e conexões, distinguindo geração de dados e desenho visual.

2. **Jogo e versão:** Cataclysm: Dark Days Ahead, código aberto, licença CC BY-SA 3.0, branch master atual conforme informado pelo solicitante. A versão exata não foi verificada no recorte.

3. **Ferramentas:** inspeção estática do trecho fornecido de `overmap.cpp`; nenhuma execução, compilação ou comparação visual foi realizada.

4. **Método:** rastreamento de funções, campos, estruturas de coordenadas, condições de geração, uso de aleatoriedade, conexões de borda e alterações feitas por `ter_set`.

5. **Evidências:** cidades armazenadas em `cities`; conexões em `connections_out`; terrenos em células OMT; especiais filtrados por flags; caminhos construídos por funções de conexão e busca.

6. **Funcionamento:** cidades e saídas de mapas formam pontos de destino; estradas e ferrovias conectam esses pontos; terrenos naturais são modificados por ruído, rios e caminhos.

7. **Inferências:** o overmap funciona como camada lógica persistente, provavelmente independente da renderização detalhada do mapa local.

8. **Hipóteses:** bairros, ruas internas e distribuição completa de prédios dependem de funções e arquivos não incluídos.

9. **Limitações:** o recorte não contém `connect_closest_points`, `place_special`, carregamento de JSON de especiais, geração de cidades, regras de bairros, renderização nem conversão para mapas locais.

10. **Classificação:** aproveitar a separação entre dados e visualização, conexões de fronteira, ruído e regras de especiais; adaptar algoritmos e formatos; investigar bairros e geração urbana; não copiar código.

11. **Relevância para DEAD DISTRICT:** alta para geração determinística por chunks, cidades conectadas, estradas contínuas, especiais orientados e streaming Android.

12. **Próximas investigações:** examinar a geração de cidades e `city_size`, `connect_closest_points`, `place_special`, definições de `overmap_special`, `overmap_connection`, conversão OMT→submap e o sistema de renderização.

### RELATÓRIO curto
- **O que fiz:** descrevi os mecanismos observáveis, classifiquei evidências, adaptação, viabilidade, impacto Android e complexidade.
- **O que não fiz:** não copiei código, não analisei arquivos ausentes e não atribuí renderização ao trecho sem evidência.
- **Riscos:** diferenças de versão do master, dependências não exibidas e custos reais de geração podem alterar as conclusões.
