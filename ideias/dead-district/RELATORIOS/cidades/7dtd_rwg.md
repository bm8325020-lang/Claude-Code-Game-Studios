# 7 Days to Die: geracao de cidades por tiles
modelo: auto/coding:reliable

A fonte descreve o **Random World Generator de 7 Days to Die**, não a implementação interna de DEAD DISTRICT. Portanto, os pontos abaixo são referências de arquitetura e adaptação, não confirmação de que DEAD DISTRICT use o mesmo sistema.

## RELATÓRIO — 12 achados

1. **Mapa determinístico por seed**  
   **Origem:** “builds a complete map [...] from a seed string”; “Same seed + same size = same map.”  
   **Classificação:** FATO OBSERVADO.  
   **Decisão:** **APROVEITAR.** Em Godot 4, usar seed fixa para gerar terreno, ruas e pontos de interesse reproduzíveis. Viabilidade: alta. Custo Android: baixo se a geração ocorrer antes do jogo. Complexidade: média.

2. **Mapa dividido em células**  
   **Origem:** “the map is broken into cells”; “Cell size is configured here too.”  
   **Classificação:** FATO OBSERVADO / INFERÊNCIA TÉCNICA.  
   **Decisão:** **APROVEITAR.** Implementar cidade em células ou setores para carregar, descarregar e gerar partes localmente. Viabilidade: alta em Godot 4. Custo Android: reduz memória, mas exige controle de streaming. Complexidade: média/alta.

3. **Cidades como hubs**  
   **Origem:** “Hub rules - towns and city placements: how many, how big, how far apart, what kinds of POIs live in them.”  
   **Classificação:** FATO OBSERVADO.  
   **Decisão:** **ADAPTAR.** Planejar primeiro os hubs urbanos: quantidade, tamanho, distância e categorias de edifícios. Viabilidade: alta. Custo Android: proporcional à quantidade de POIs ativos. Complexidade: média.

4. **Ruas conectando centros urbanos**  
   **Origem:** “Road generation - how main roads, dirt roads, and trails are laid out between hubs.”  
   **Classificação:** FATO OBSERVADO.  
   **Decisão:** **APROVEITAR.** Gerar uma hierarquia de vias: principais, estradas de terra e trilhas. Em Godot, curvas, splines ou segmentos modulares são viáveis. Custo Android: baixo a médio. Complexidade: média.

5. **Biomas influenciam a distribuição**  
   **Origem:** “Biome definitions - the set of biomes the generator can pick”; “biome weighting”.  
   **Classificação:** FATO OBSERVADO.  
   **Decisão:** **ADAPTAR.** Usar regras para variar vegetação, pavimentação, fachadas e densidade conforme o bioma. Viabilidade: alta. Custo Android: baixo se materiais e meshes forem reutilizados. Complexidade: média.

6. **POIs distribuídos por regras**  
   **Origem:** “Prefab rules - which prefabs (POI definitions) are eligible for which biome and which slot type.”  
   **Classificação:** FATO OBSERVADO.  
   **Decisão:** **APROVEITAR.** Criar edifícios e locais especiais como prefabs elegíveis por bairro, bioma ou posição. Viabilidade: alta em Godot 4. Custo Android: médio, dependendo da geometria. Complexidade: média.

7. **Conteúdo fora das cidades**  
   **Origem:** “Wilderness rules - POIs that spawn outside towns (gas stations, farmhouses, churches, traders).”  
   **Classificação:** FATO OBSERVADO.  
   **Decisão:** **ADAPTAR.** Prever construções isoladas além dos quarteirões, evitando que o mapa seja apenas uma malha urbana contínua. Viabilidade: alta. Custo Android: baixo/médio. Complexidade: baixa/média.

8. **Pool de prédios substituível**  
   **Origem:** “Custom prefab pool - drop in your own POIs (or remove vanilla ones) by editing the prefab rules.”  
   **Classificação:** FATO OBSERVADO.  
   **Decisão:** **APROVEITAR.** Manter catálogo de edifícios intercambiáveis e regras de seleção. Isso favorece reaproveitamento de assets, mas a fonte não confirma modularidade interna. Viabilidade: alta. Custo Android: controlável. Complexidade: média.

9. **Densidade urbana configurável**  
   **Origem:** “More towns / closer towns”; “Very small spacing produces a ‘city map’ feel but increases server load (more POIs to load near players).”  
   **Classificação:** FATO OBSERVADO / INFERÊNCIA TÉCNICA.  
   **Decisão:** **ADAPTAR.** Regular distância entre hubs e quantidade de POIs conforme a capacidade do Android. Viabilidade: alta. Custo Android: alto em áreas muito densas. Complexidade: média.

10. **Escala do mundo afeta geração e visualização**  
    **Origem:** “Larger maps take exponentially longer to generate and to render in client view-distance terms.”  
    **Classificação:** FATO OBSERVADO.  
    **Decisão:** **ADAPTAR.** Preferir mundo segmentado, distância de visão controlada e geração antecipada ou assíncrona. Viabilidade: alta. Custo Android: alto para mapas grandes. Complexidade: alta.

11. **Fachadas, interiores e telhados**  
    **Origem:** a fonte menciona “prefabs/POIs”, mas não descreve fachadas, interiores, peças modulares, telhados ou rotas sobre os edifícios.  
    **Classificação:** NÃO CONFIRMADO.  
    **Decisão:** **INVESTIGAR.** Não atribuir ao jogo uma estratégia de interiores, construção modular ou percurso por telhados com base neste texto. Em Godot, interiores separados e telhados simplificados seriam viáveis, mas o custo depende do número de áreas simultâneas. Complexidade: média/alta.

12. **Regeneração, cache e iteração**  
    **Origem:** “the result is written to GeneratedWorlds/...”; “the server loads from that folder rather than regenerating”; “each test requires a full world regen.”  
    **Classificação:** FATO OBSERVADO / INFERÊNCIA TÉCNICA.  
    **Decisão:** **APROVEITAR.** Salvar o mapa gerado e separar ferramentas de edição da execução Android. Testar com mapas pequenos antes de escalar. Viabilidade: alta. Custo Android: baixo durante o jogo; geração pode ser pesada. Complexidade: média.

**Resumo:** a fonte sustenta um modelo de cidade gerada por seed, células, hubs, regras de ruas, biomas e prefabs. Ela não confirma como DEAD DISTRICT constrói fachadas, interiores, modularidade, telhados ou otimização específica para Android.
