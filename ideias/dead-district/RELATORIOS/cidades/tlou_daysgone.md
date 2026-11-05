# TLOU Part I e Days Gone: modulos e equipe
modelo: auto/coding:fast

## The Last of Us Part I

1. **Peças modulares para montagem de edifícios**  
   **Fonte:** “modular tilesets created for University Depot Yard buildings”.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** APROVEITAR.  
   **Aplicação:** criar peças reutilizáveis de paredes, pisos, portas e estruturas para montar prédios brasileiros.  
   **Godot 4:** viabilidade alta; as peças podem ser cenas reutilizáveis, meshes ou componentes modulares.  
   **Android:** custo baixo a médio, dependendo da quantidade de objetos e materiais.  
   **Complexidade:** média.  
   **Limite da evidência:** a fonte não descreve ruas, quarteirões, interiores ou escala de cidade.

2. **Tilesets voltados à construção de edifícios específicos**  
   **Fonte:** “these modular pieces were created to assemble University Depot Yard buildings located in the University Depot Yard sub-level”.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** ADAPTAR.  
   **Aplicação:** organizar kits por contexto: casas, comércio, galpões e prédios públicos, sem presumir que um único kit sirva para toda a cidade.  
   **Godot 4:** viabilidade alta.  
   **Android:** custo controlável se houver reaproveitamento de meshes e materiais.  
   **Complexidade:** média.  
   **Não confirmado:** a fonte não informa se as peças também eram usadas em ruas, telhados ou interiores.

3. **Ferramenta de produção usada no trabalho original**  
   **Fonte:** “The pieces were made by Naughty Dog's Nestor Carpintero using Maya” e “the tilesets were created using Maya”.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** ADAPTAR.  
   **Aplicação:** usar uma ferramenta externa para modelar e exportar peças; não há base para reproduzir Maya como ferramenta de montagem dentro do jogo.  
   **Godot 4:** viabilidade alta para importar os assets e montar cenas.  
   **Android:** custo de execução não é determinado pela ferramenta de autoria, mas pelo resultado exportado.  
   **Complexidade:** média.

4. **Reaproveitamento de instâncias entre edifícios**  
   **Fonte:** “all the buildings in the game share many instances”.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** APROVEITAR.  
   **Aplicação:** compartilhar componentes arquitetônicos, fachadas, portas, janelas e elementos de acabamento.  
   **Godot 4:** viabilidade alta com cenas instanciadas e recursos compartilhados.  
   **Android:** potencialmente favorável para memória e produção, embora a fonte não apresente medições.  
   **Complexidade:** média.  
   **Inferência técnica:** maior reutilização tende a reduzir custo de conteúdo, mas não permite concluir o desempenho final.

5. **Wireframes como etapa de planejamento arquitetônico**  
   **Fonte:** “a behind-the-scenes look at wireframes for buildings” e o artista trabalhou com “architectural concept design” e “level modeling”.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** APROVEITAR.  
   **Aplicação:** planejar primeiro volumes, circulação, colisão e composição arquitetônica antes do detalhamento.  
   **Godot 4:** viabilidade alta usando protótipos simples, colisões e cenas temporárias.  
   **Android:** custo baixo durante o protótipo; o custo final depende dos assets.  
   **Complexidade:** baixa a média.

6. **Construção a partir de uma vertical slice**  
   **Fonte:** “worked on the game's vertical slice”, definida como uma porção jogável com assets finais e sistemas funcionando.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** ADAPTAR.  
   **Aplicação:** desenvolver primeiro um pequeno trecho urbano completo, com rua, edifícios, interiores e sistemas necessários, antes de expandir.  
   **Godot 4:** viabilidade alta.  
   **Android:** útil para testar memória e desempenho cedo, mas a fonte não confirma nenhuma técnica específica de otimização.  
   **Complexidade:** média.

7. **Geometria publicada representando o maior nível de detalhe**  
   **Fonte:** “the geometry on the renders he has published represents the highest level of detail”.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** INVESTIGAR.  
   **Aplicação:** não usar imagens de wireframe de alto detalhe como prova de que o jogo mantém esse nível em todo momento.  
   **Godot 4:** investigar LOD, simplificação de colisão e versões de mesh.  
   **Android:** potencialmente alto se o detalhe for mantido; o impacto exato não foi informado.  
   **Complexidade:** média a alta.  
   **Não confirmado:** a fonte não diz como o LOD foi aplicado em runtime.

## Days Gone

8. **Equipe pequena de design do mundo aberto**  
   **Fonte:** “the entire open world was designed by a team of just 5 people” e “5-6 people”.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** ADAPTAR.  
   **Aplicação:** definir regras claras de montagem e uma biblioteca reutilizável para permitir produção por equipe pequena.  
   **Godot 4:** viabilidade alta.  
   **Android:** custo direto baixo; organização reduz retrabalho, mas não garante desempenho.  
   **Complexidade:** média.

9. **Diversidade e dinamismo como objetivo de design**  
   **Fonte:** “how diverse and dynamic we were able to make the open world”.  
   **Classificação:** FATO OBSERVADO.  
   **Ação:** APROVEITAR.  
   **Aplicação:** variar fachadas, ocupação e situações urbanas sem exigir que cada edifício seja completamente único.  
   **Godot 4:** viabilidade alta, com cenas variantes e regras de composição.  
   **Android:** custo médio, pois variedade pode aumentar assets, memória e processamento.  
   **Complexidade:** média a alta.

10. **Decisões inteligentes e eficientes por limitação de mão de obra**  
    **Fonte:** “We had to think smart and efficient with all of our design choices knowing the man power limitations.”  
    **Classificação:** FATO OBSERVADO.  
    **Ação:** APROVEITAR.  
    **Aplicação:** priorizar módulos, regras de repetição e escopo controlado para a cidade.  
    **Godot 4:** viabilidade alta.  
    **Android:** favorável em produção; o benefício de runtime depende da implementação.  
    **Complexidade:** média.

11. **Sistemas interagindo e gameplay emergente**  
    **Fonte:** “so many systems interacting with each other at all times” e “an environment where emergent gameplay comes to life”.  
    **Classificação:** FATO OBSERVADO.  
    **Ação:** ADAPTAR.  
    **Aplicação:** conectar cidade, inimigos e eventos como sistemas; isso não especifica como ruas, prédios ou interiores foram construídos.  
    **Godot 4:** viabilidade alta, mas exige arquitetura de gameplay.  
    **Android:** custo potencialmente alto de CPU e memória.  
    **Complexidade:** alta.

12. **Ruas, quarteirões, fachadas, interiores, telhados e otimização urbana**  
    **Fonte:** nenhuma das três fontes descreve esses elementos para os jogos.  
    **Classificação:** NÃO CONFIRMADO.  
    **Ação:** INVESTIGAR.  
    **Aplicação:** não atribuir a TLOU Part I ou Days Gone técnicas específicas de planejamento urbano, percurso por telhados, streaming, culling, interiores ou montagem de quarteirões com base neste material.  
    **Godot 4:** qualquer solução é tecnicamente possível, mas não é sustentada pelas fontes fornecidas.  
    **Android:** custo e complexidade indeterminados.  
    **Risco:** transformar inferências de produção em fatos sobre os jogos.

## RELATÓRIO — 12 itens

1. TLOU confirma tilesets modulares para montar edifícios.  
2. O contexto confirmado é University Depot Yard, não uma cidade inteira.  
3. Maya foi usada na criação das peças.  
4. Edifícios compartilham muitas instâncias.  
5. Wireframes apoiaram arquitetura e modelagem.  
6. Uma vertical slice foi usada durante a produção.  
7. A geometria mostrada era o maior nível de detalhe.  
8. Days Gone teve mundo aberto desenhado por cinco a seis pessoas.  
9. Diversidade e dinamismo eram objetivos declarados.  
10. A equipe priorizou decisões inteligentes e eficientes.  
11. Sistemas interagentes favoreceram gameplay emergente.  
12. Não há confirmação sobre ruas, quarteirões, interiores, telhados ou otimização técnica.
