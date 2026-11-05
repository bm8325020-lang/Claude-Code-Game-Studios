# Dying Light 2: cidade e predios
modelo: auto/coding:fast

# Relatório de engenharia reversa — construção da cidade

**Escopo:** somente *Dying Light 2 Stay Human* — Villedor, Old Villedor e Central Loop — salvo quando a fonte menciona explicitamente o primeiro *Dying Light*, associado a Harran. Não há, nas fontes fornecidas, descrição específica da construção urbana de Harran.

## 1. Planejamento urbano baseado em referências reais

- **Trecho:** “we wanted to create a believable city by following real-life references” e “We looked very closely at their urban structures and architecture.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **APROVEITAR**
- **Aplicação:** estudar referências de cidades brasileiras para definir ruas, lotes, fachadas e marcos urbanos antes da modelagem.
- **Godot 4:** viabilidade alta; é um processo de planejamento e produção de conteúdo.
- **Android:** custo baixo em execução; o custo principal é artístico.
- **Complexidade:** média.

## 2. Distritos com identidade arquitetônica e funcional

- **Trecho:** “Central Loop is a very different district in terms of architecture and pre-apo function. It's a modern area full of offices, shops, and apartments.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **ADAPTAR**
- **Aplicação:** separar a cidade em distritos com regras visuais e usos diferentes, sem tratar todo o mapa como um único conjunto.
- **Godot 4:** viabilidade alta usando cenas, materiais e conjuntos de construção por distrito.
- **Android:** custo médio, dependendo da quantidade de materiais e geometrias distintas.
- **Complexidade:** média.

## 3. Cidade planejada simultaneamente para aparência e parkour

- **Trecho:** “Every building that you see in the game was created in cooperation with the Level Design Team” e os prédios precisavam garantir que “climbing and running on the rooftops is fun and satisfying.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **APROVEITAR**
- **Aplicação:** criar o layout jogável antes de finalizar fachadas e detalhes, validando rotas de escalada e travessia.
- **Godot 4:** viabilidade alta com blocos de protótipo, colisões e cenas substituíveis.
- **Android:** custo baixo durante o protótipo; custo final depende da geometria.
- **Complexidade:** média/alta.

## 4. Gray box com dimensões definidas

- **Trecho:** “we participate in their creative process literally from the gray box phase” e os artistas recebiam “prototypes with set dimensions that needed visual solutions.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **APROVEITAR**
- **Aplicação:** estabelecer dimensões jogáveis para ruas, prédios, bordas e apoios antes de produzir a arte final.
- **Godot 4:** viabilidade alta usando cenas-protótipo e substituição posterior de meshes.
- **Android:** custo muito baixo no protótipo.
- **Complexidade:** baixa/média.

## 5. Mapa montado por peças de papel

- **Trecho:** “we even built an actual map on paper” e a equipe “move pieces of paper that represented buildings around.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **ADAPTAR**
- **Aplicação:** usar um mapa físico ou editor simples para testar posições de prédios, rotas, marcos e necessidades de diferentes departamentos antes do 3D.
- **Godot 4:** viabilidade alta; pode ser uma ferramenta externa ou um editor interno simples.
- **Android:** custo nulo em execução.
- **Complexidade:** baixa para a versão física; média para uma ferramenta digital.

## 6. Ruas com formas naturais, mas subordinadas ao gameplay

- **Trecho:** “level design needs things that usually don’t look like a city” e a solução era modificar o protótipo para que “the shapes of streets are natural and real, the buildings are correct sizes etc.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **APROVEITAR**
- **Aplicação:** não desenhar quarteirões apenas como corredores de gameplay; ajustar o protótipo para preservar aparência urbana plausível.
- **Godot 4:** viabilidade alta.
- **Android:** impacto baixo direto; geometria e quantidade de objetos são os riscos posteriores.
- **Complexidade:** alta no planejamento.

## 7. Rooftops como segundo nível urbano

- **Trecho:** “Rooftops became the new ground and place where people seek shelter and safety.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **APROVEITAR**
- **Aplicação:** tratar telhados como percurso principal, com assentamentos, agricultura e conexões entre prédios.
- **Godot 4:** viabilidade alta com rotas de navegação e colisões em múltiplas alturas.
- **Android:** custo médio; exige mais geometria navegável e testes de visibilidade.
- **Complexidade:** alta.

## 8. Vegetação e sobrevivência concentradas nos telhados

- **Trecho:** “there are farms, small fields, and bakeries to produce food” e “the vegetation on the ground level is very scarce.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **ADAPTAR**
- **Aplicação:** diferenciar visualmente o térreo morto dos telhados habitados e produtivos.
- **Godot 4:** viabilidade alta com conjuntos de props e materiais por altura.
- **Android:** custo baixo/médio; vegetação pode ser onerosa se houver muitos elementos individuais.
- **Complexidade:** média.

## 9. Elementos de orientação integrados à cidade

- **Trecho:** “at the end of the street, there’s always something that you see”, como “monuments, interesting buildings, churches”; também existem “parkour helpers.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **APROVEITAR**
- **Aplicação:** planejar marcos visíveis no fim ou ao longo das ruas e usar rampas, objetos e soluções visuais para indicar caminhos.
- **Godot 4:** viabilidade alta com marcadores, meshes e regras de posicionamento.
- **Android:** custo baixo/médio.
- **Complexidade:** média.

## 10. Contraste entre térreo e telhados

- **Trecho:** no térreo há cores menos vivas, sons diferentes e perigo; também foram usados “pointy, hard edges on the bottom and soft, round shapes on the top.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **ADAPTAR**
- **Aplicação:** usar forma, cor, iluminação e áudio para comunicar que o jogador deve subir.
- **Godot 4:** viabilidade alta com ambientes, iluminação e áudio por área.
- **Android:** custo médio se houver iluminação dinâmica e muitos efeitos simultâneos.
- **Complexidade:** média.

## 11. Interiores e áreas escuras orientados pela legibilidade

- **Trecho:** “we design everything from buildings, interiors, and skylines” e, nas Dark Zones, o jogador deveria entender o espaço “with only a flashlight”; foram usados “small light points to help with navigation.”
- **Classificação:** **FATO OBSERVADO**
- **Ação:** **ADAPTAR**
- **Aplicação:** construir interiores com leitura espacial por lanterna e pontos luminosos de orientação.
- **Godot 4:** viabilidade alta; exige controle de iluminação, sombras e sinalização.
- **Android:** custo médio/alto, especialmente com sombras e iluminação dinâmica.
- **Complexidade:** média/alta.

## 12. Modularidade, reaproveitamento, densidade e otimização

- **Trechos relevantes:** a fonte menciona “assets”, “objects and solutions” e “makeshift” — objetos reaproveitados no mundo ficcional, como “old laundry basket” e “pieces of tarp billboard”. Porém, não descreve um sistema técnico de peças modulares, reutilização de meshes, streaming, LOD, culling, limite de densidade ou orçamento de memória.
- **Classificação:** **NÃO CONFIRMADO**
- **Ação:** **INVESTIGAR**
- **Aplicação:** não assumir que a cidade usa módulos, ferramentas procedurais ou técnicas específicas de otimização apenas com base nesses trechos.
- **Godot 4:** modularidade, instancing, LOD e culling são viáveis, mas não são confirmados pela fonte.
- **Android:** esses sistemas seriam importantes para custo e memória, porém o impacto real depende de testes.
- **Complexidade:** média/alta.

# RELATÓRIO

1. A cidade foi orientada por referências urbanas reais.  
2. Os distritos possuem funções e identidades arquitetônicas diferentes.  
3. Arte e level design foram desenvolvidos em conjunto.  
4. O processo partiu de gray boxes com dimensões definidas.  
5. O mapa foi planejado visualmente com peças representando prédios.  
6. As ruas precisavam parecer naturais apesar das exigências de gameplay.  
7. Os telhados funcionam como nível urbano habitável e percorrível.  
8. Agricultura e vegetação foram concentradas nos telhados.  
9. Marcos urbanos e parkour helpers guiam o jogador.  
10. Forma, cor, áudio e iluminação distinguem térreo e telhados.  
11. Interiores escuros usam lanterna e pequenos pontos de luz para navegação.  
12. Modularidade técnica, reaproveitamento de assets e otimização de cidade grande não foram confirmados.

**RELATÓRIO — o que fez:** separou os achados por fonte, citou os trechos, distinguiu Villedor de Harran, classificou cada item e avaliou Godot 4, Android e complexidade.  
**O que não fez:** não inventou números, sistemas técnicos, nomes de ferramentas ou técnicas de otimização não presentes nas fontes.  
**Riscos:** transformar inferências de produção em fatos; extrapolar o método de *Dying Light 2* diretamente para uma cidade brasileira ou para Android sem protótipos e medições.
