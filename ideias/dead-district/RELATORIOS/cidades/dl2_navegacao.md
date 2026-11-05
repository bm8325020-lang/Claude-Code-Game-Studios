# Dying Light 2: navegacao no mundo aberto
modelo: auto/coding:reliable

## Engenharia reversa por fonte pública — construção da cidade

**Fonte única:** entrevista com Piotr Pawlaczyk, lead level designer de *Dying Light 2*, publicada pela Game Developer. As conclusões abaixo não afirmam que *Dead District* usa essas técnicas; são referências para adaptação em Godot 4.7.

### RELATÓRIO — 12 itens

1. **Mapa gerado por ferramenta de montagem procedural**  
   **Origem:** “we used the ‘City Builder’ tool. It can generate kilometers of map in a procedural way.”  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** **ADAPTAR.** Criar uma ferramenta própria no editor Godot para montar ruas, quarteirões e elementos pré-fabricados.  
   **Godot 4:** viável com `@tool`, `EditorPlugin`, cenas reutilizáveis e recursos customizados.  
   **Android:** custo de execução baixo se a geração ocorrer no editor, não durante o jogo. Complexidade alta na ferramenta.

2. **Peças pré-fabricadas como base da cidade**  
   **Origem:** “build the open world out of prefabricated elements.”  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** **APROVEITAR.** Usar módulos de rua, calçada, esquinas, fachadas, telhados e volumes de prédios.  
   **Godot 4:** viabilidade alta com cenas reutilizáveis e `PackedScene`.  
   **Android:** custo baixo a médio; reutilização favorece memória, mas repetição visual precisa ser controlada. Complexidade média.

3. **Cooperação entre departamentos desde o início**  
   **Origem:** “constant cooperation between all teams (programming, level design, level art, 3D modeling, etc.)”.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** **APROVEITAR.** Definir contratos entre programação, design de níveis, arte, modelagem e world design antes da produção em escala.  
   **Godot 4:** viabilidade alta; depende mais de processo do que de tecnologia.  
   **Android:** custo indireto baixo; reduz retrabalho. Complexidade organizacional média.

4. **Ferramenta evoluindo junto com os assets**  
   **Origem:** “The tool evolved along with the creation of new elements, and each new element was immediately tested and corrected.”  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** **ADAPTAR.** Fazer cada novo módulo ser validado imediatamente no gerador e no percurso jogável.  
   **Godot 4:** viável com cenas de teste, validações no editor e geração automática.  
   **Android:** custo baixo durante o jogo; custo médio de desenvolvimento. Complexidade média.

5. **Evitar cidade procedural genérica e repetitiva**  
   **Origem:** “we needed to be careful and not create repetitive, generic spaces.”  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** **APROVEITAR.** Combinar montagem procedural com pontos autorais, variações de fachada e locais individuais.  
   **Godot 4:** viável usando regras de composição e substituição de módulos.  
   **Android:** custo médio se houver muitas variações; complexidade média.

6. **Locais individuais alterando os caminhos de parkour**  
   **Origem:** “many individual locations to expand and evolve the parkour paths leading between the main and side quest points.”  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** **ADAPTAR.** Planejar ruas, quarteirões e prédios a partir dos trajetos entre objetivos, não apenas da aparência urbana.  
   **Godot 4:** viabilidade alta; pode usar pontos de conexão, navegação e validação manual.  
   **Android:** custo médio, principalmente pela quantidade de geometria acessível. Complexidade alta no design.

7. **Cada área importante recebe trabalho manual**  
   **Origem:** “every individual location, environmental storytelling… were either built from scratch, or significantly modified.”  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** **APROVEITAR.** Usar geração para a base e reservar autoria manual para locais de missão, narrativa ambiental e combate.  
   **Godot 4:** viável com cenas-base herdadas ou variantes.  
   **Android:** custo médio; reduz a necessidade de customizar toda a cidade. Complexidade média/alta.

8. **Planejamento inicial em papel e miniatura do mapa**  
   **Origem:** “we started with ‘paper’”; depois “build a quick miniature of the entire map and put a story sketch and open-world activities on it”.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** **APROVEITAR.** Criar primeiro um mapa abstrato com ruas, áreas, atividades e mudanças narrativas antes da geometria final.  
   **Godot 4:** viabilidade alta; pode ser feito com um mapa 2D/editorial simples.  
   **Android:** custo praticamente nulo no jogo. Complexidade baixa.

9. **Teste de dependências no mapa simplificado**  
   **Origem:** “He tested all dependencies”; “working on such a simplified and ‘small’ layout allowed for quick changes and tests.”  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** **ADAPTAR.** Testar conexões entre missões, atividades, mudanças do mundo e rotas antes da construção detalhada.  
   **Godot 4:** viável com uma versão abstrata dos nós e estados do mapa.  
   **Android:** custo baixo se usado apenas em desenvolvimento. Complexidade média.

10. **Transferência da lógica para a geometria final**  
    **Origem:** “When the whole thing was stable, we started to transfer it to the target geometry”; “the whole thing was on the same map and operated by the same logic”.  
    **Classificação:** FATO OBSERVADO.  
    **Ação:** **ADAPTAR.** Separar dados de localização e lógica de missão da geometria visual, mantendo identificadores comuns entre protótipo e mapa final.  
    **Godot 4:** viabilidade alta com recursos, grupos, sinais e cenas substituíveis.  
    **Android:** custo baixo a médio; favorece manutenção. Complexidade alta na arquitetura inicial.

11. **Cidade orientada a telhados, ruas estreitas e travessia vertical**  
    **Origem:** “emphasize travel by way of rooftops, narrow streets, and more”; “the parkour system would let players go almost anywhere in the map.”  
    **Classificação:** FATO OBSERVADO.  
    **Ação:** **ADAPTAR**, se o jogo de destino tiver travessia semelhante. Planejar quarteirões, fachadas e telhados como rede de percurso.  
    **Godot 4:** viável, mas exige colisões, pontos de salto e validação de movimento.  
    **Android:** custo médio; mais colisões e geometria acessível aumentam processamento. Complexidade alta.

12. **Interiores, fachadas específicas, otimização e densidade não são descritos**  
    **Origem:** o texto menciona “locations”, “environmental storytelling”, “rooftops”, “narrow streets” e “target geometry”, mas não explica interiores, sistema de fachadas, telhados detalhados, streaming, LOD, instanciamento, orçamento de memória ou otimização para Android.  
    **Classificação:** NÃO CONFIRMADO.  
    **Ação:** **INVESTIGAR.** Não reproduzir essas partes como se fossem técnicas confirmadas pela fonte.  
    **Godot 4:** qualquer solução é tecnicamente possível, mas não pode ser atribuída a esta entrevista.  
    **Android:** custo potencialmente alto para cidade grande; complexidade alta. Sem dados, não há base para escolher uma implementação.

### Síntese

A fonte confirma um fluxo híbrido: **montagem procedural por peças pré-fabricadas + autoria manual dos locais relevantes + planejamento abstrato antes da geometria final + validação contínua entre equipes**. Ela não confirma técnicas concretas para interiores, fachadas modulares detalhadas, streaming, telhados técnicos, LOD ou otimização móvel.

## RELATÓRIO curto

- **Feito:** extraídos 12 achados diretamente do texto.
- **Feito:** cada achado recebeu fonte, classificação, ação, viabilidade em Godot 4, custo Android e complexidade.
- **Feito:** priorizado planejamento urbano, ruas, quarteirões, rotas, peças reutilizáveis e ferramenta de montagem.
- **Não feito:** não foram inventados números, nomes de ferramentas adicionais ou técnicas não mencionadas.
- **Não confirmado:** interiores, fachadas específicas, densidade, streaming, LOD, telhados detalhados e otimização de cidade grande.
- **Risco:** adaptar geração procedural sem validação manual pode produzir espaços repetitivos ou rotas ruins.
- **Risco:** tornar quase toda a cidade acessível aumenta custo de colisões, geometria e testes no Android.
- **Risco:** separar protótipo e mapa final sem lógica compartilhada gera retrabalho.
- **Recomendação:** começar pelo mapa abstrato e pelos módulos de rua/quarteirão.
- **Recomendação:** validar cada módulo em percurso jogável assim que for criado.
- **Recomendação:** manter locais de missão e narrativa como áreas autorais.
- **Conclusão:** a abordagem é viável em Godot 4.7, mas a ferramenta de montagem é a parte de maior complexidade.
