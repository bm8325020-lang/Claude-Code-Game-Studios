# Casas analisadas (engenharia reversa: peças, cômodos, vidro, textura, montagem)

Pedido do dono (05/11): "engenharia reversa nas casas, interior, tudo... nos blocos, como a cidade é formada, vidro,
textura, tudo. E de todos os jogos". Regra: não copiar, só pegar como base. Nada entra na cidade antes desta investigação.

Classes de evidência: FATO (lido no código/dado/texto), INFERÊNCIA (dedução nossa), HIPÓTESE, NÃO CONFIRMADO.
Decisão por item: APROVEITAR / ADAPTAR / INVESTIGAR / DESCARTAR. Fontes em `FONTES/` e linhas E15-E22 de `EVIDENCIAS.md`.

## 1. Por jogo

### Cataclysm DDA (código aberto, tipo A) — FATO, confiança alta
Fonte: `FONTES/cdda_casas.txt`, `FONTES/cdda_janelas_portas.txt`.
- **Bloco:** 1 quadrado = 1 m. A casa é um desenho em letras + paleta (letra -> parede/piso/móvel). Paletas em cascata.
- **Medida de 249 casas térreas:** paredes de tijolo (159 casas), madeira (155), concreto (127), vidro (16).
  Piso: linóleo cinza (146), concreto fino (89), linóleo branco (26), carpete vermelho/amarelo/verde/roxo.
  ~16 janelas por casa. Portas: comum, trancada por dentro, metal, vidro, de tela, com olho mágico, com alarme.
- **Móveis por casa (média):** mesa, balcão, cadeira, pia, sofá, armário, cama, cômoda, abajur, guarda-roupa,
  escrivaninha, estante de TV, espelho, fogão, geladeira, poltrona, caixa de correio, banheira, mesinha, lavadora, secadora.
  Cada móvel tem o seu grupo de loot (balcão -> cozinha/remédio, armário -> louça/talher/panela, geladeira -> comida...).
  Limitação: alguns arquivos têm várias casas juntas, então "cama 9.2 por casa" está inflado.
- **Janela é máquina de estados:** vidro+cortina <-> aberta; cortina fecha (não se vê dentro); quebrar -> moldura com
  cacos (corta, passa pequeno, dá para pular) -> vazio. Tábuas: não se vê e reduz cheiro. Fita: opaca. Grade: o vidro
  quebra e a grade fica. Toda janela aceita tábuas.
- **Porta também:** fechada <-> aberta; trancada (gazua -> fechada); quebrar -> quebrada -> só batente -> nada.
  Força para quebrar: madeira 8-80, vidro 6-20, metal trancada 80-250.
- Decisão: **APROVEITAR** a ideia dos estados de janela/porta e móvel -> loot (já fizemos loot por cômodo).

### Project Zomboid (editor aberto TileZed, tipo A/B) — FATO, confiança alta
Fonte: `FONTES/pz_tilezed.txt`.
- **A casa é "estilo + cômodos":** o Template guarda o ESTILO (parede de fora, porta, batente, janela, cortina,
  veneziana, escada, 3 peças de telhado, sujeira) e uma lista de cômodos. Cada cômodo tem tipo (kitchen, bathroom,
  bedroom, livingroom, hall...), parede de dentro, rodapé/acabamento e piso, e sujeira de parede e de chão.
- **Quarto tem parede de outra cor** que o resto da casa (no modelo Old Suburban: 27 x 28; piso igual).
- **Peças da parede de fora:** cheia, com janela, com porta e peça de canto, por direção. Porta tem peça fechada e aberta.
- **Sujeira é camada por cima** (overlay grime), com peça de borda por direção e canto: escurece rodapé e cantos.
- **Cômodo:** 4 paredes + teto = cômodo; o móvel diz o tipo (geladeira = cozinha).
- Móveis catalogados por uso (assento, guarda, prateleira, mesa baixa/alta, luz, decoração de parede, pichação, lixo,
  planta) e por lugar (mercado, polícia, hospital, escola, igreja, bar, banco, escritório).
- Decisão: **APROVEITAR** "estilo + cômodos tipados" como o formato do nosso gerador de casa.

### DayZ (dado aberto do servidor + wiki de modding, tipo B) — FATO, confiança alta
Fonte: `FONTES/dayz_ce.txt` (licença proíbe usar os dados fora de Arma/DayZ: só números agregados), `FONTES/web_casas.txt`.
- **Prédio em camadas (LODs):** visual, colisão, tiro, visão, pontos (eixos de porta, sons), e "Roadway" = só onde se anda.
  Mesmo nome de peça em todas as camadas.
- **Porta 1,20 x 2,20 m** (maior que a real, para a câmera/jogabilidade). Abre ~80 graus. 50% de chance de nascer aberta.
  Porta tem vida (1000), tiro tira pouco.
- **Loot:** cada casa tem ~24 pontos de loot (até 62) mas só ~6 itens de cada vez. 3 tipos de ponto em TODA casa:
  chão (ferramenta, recipiente, roupa), prateleira (+ comida, livro) e arma. Cada ponto tem raio e altura livre.
- **Variação barata:** o mesmo modelo de casa com outra cor (_Yellow, _Brown). Casas de rua em peças: 1, 2, 3 e 5 andares,
  com **peça de esquina** própria.
- Decisão: **ADAPTAR** pontos de loot com altura (chão/prateleira) e variantes de cor do mesmo modelo.

### 7 Days to Die (wiki 3.0, tipo B) — FATO, confiança média (wiki de comunidade)
- Tudo é bloco de 1 m; 162 formatos novos de bloco na 1.0 (rampa, canto, meio-bloco...). Textura = "pintura" por face.
- Lotes padrão: 25, 42, 60, 100, 150 blocos. Frente para o norte como referência; o gerador gira.
- Cada prédio exporta uma **malha "imposter" para ver de longe** (igual ao nosso grupo "longe").
- Busca: zumbi dormindo em volume, acorda a 8 m; bloco "loot helper" sorteia o recipiente.
- Decisão: **APROVEITAR** lotes padrão e imposter por prédio (já temos o "longe").

### Days Gone (artigo do artista, tipo B) — FATO, confiança alta
- Kit no grid métrico: retas, cantos, rampas, escadas. **Kit pequeno**; o resto vem de material que repete (tiling),
  mistura por cor de vértice (vert blend) e normais por peso. Kit grande vira fardo; caso difícil = peça única.
- Ferragens (puxador, dobradiça) num texture set só: mudar a cor da madeira muda todos os móveis.
- Corte: 4 caçambas viraram 1; 6+ barris viraram 2 (variação por cor). Menos texturas únicas.
- **Fechar as frestas das paredes melhorou muito o desempenho** (não desenha o interior visto de fora).
- Kits modulares fizeram cidades inteiras (Cloverdale, faculdade); interior feito junto com o design.
- Decisão: **APROVEITAR** kit pequeno + tiling + cor de vértice; poucas texturas.

### Dying Light 1 e 2 (entrevistas Techland, tipo B) — FATO, confiança alta
- DL2: **centenas de peças modulares** montadas pelo **City Builder**: quarteirões poligonais entre ruas -> linha de
  prédios -> prefab montado; aparência configurável por prédio. Depois "congelaram" e acabaram à mão (histórias, loot).
- Interiores **acrescentados** em prédios para cortar caminho (atalho por dentro).
- 4 "biomas" de telhado; telhado plano para controlar o parkour; peça escalável em amarelo.
- Rua: cantos duros embaixo, formas redondas em cima; rua com cor menos saturada.
- Cidade dividida em quarteirões/regiões para LOD e streaming. DL1: mapa dividido em dois pelo limite do console.
- Decisão: **APROVEITAR** a ideia do City Builder (gerar e depois acabar à mão). Já fizemos telhados andáveis.

### The Last of Us Part I e II (artigos, portfólios, SIGGRAPH; tipo B) — FATO, confiança alta (II), média (I)
Fontes: `FONTES/web_casas.txt`, `FONTES/tlou_twd_gta.txt`.
- **Part I (Bill's Town, remake 2022):** refeito "from the ground up" com guia de estilo mais realista (arquitetura,
  assets, set dressing, vegetação). O artista fez arquitetura, tileset, props, colisão e UVs, e **pintou mistura por
  vértice (vertex blend) em quase todas as ruas** e em outros assets. Texturas e materiais vêm de uma **biblioteca
  compartilhada do estúdio**. Interiores: paredes, vitrines e lojas ganharam material de mundo real; placa impressa no
  lugar de parede de madeira (análise do remake).
- **Luz (SIGGRAPH 2013, Iwanicki, "old lightmaps - new tricks"):** luz pré-calculada em lightmap com termo ambiente +
  **direção dominante** por texel (o interior sem sol não fica chapado). Oclusão dos personagens calculada por
  esferas (barato). Part II (SIGGRAPH 2020): melhoraram o ambiente pré-calculado mantendo 30 fps e memória limitada.
- **Part II:** o que se vê é decidido no **blockmesh**; interior com sol/céu bloqueados e luz de área **fora** das
  janelas e portas; props contam quem morava; vidro quebrável gerado de textura + shader fractal; ~1000 objetos de
  física vivos no máximo; LOD automático (Simplygon); biblioteca de props com palavras-chave.
- **Guiar com luz:** luz fria de holofote = perigo, escuro = caminho seguro; luz dirigida ilumina passagem ou objeto;
  amarelo e vermelho marcam o que se usa e para onde ir.
- Decisão: **ADAPTAR** vertex blend nas ruas e paredes, luz de janela, e amarelo nas coisas de usar.
  **DESCARTAR** lightmap de verdade (pesa no celular); no lugar: cor de vértice pré-calculada (já temos AO por vértice).

### The Walking Dead: Saints & Sinners (portfólios, artigos, guias; tipo B) — FATO, confiança média
- **Casas do bairro Bywater:** feitas de um **kit modular de peças de fachada**; cada casa varia por dressing e por
  **cor e sujeira (grunge) por material**. Equipe de ambiente com 5-6 nomes no portfólio; prédios do French Quarter estilizados.
- **Estilo (concept artist):** "simple shapes", semi-realista com quinas duras de vez em quando, "simplified stylized
  texture style" por causa do VR. Unreal Engine 4.
- Fases do tamanho da caminhada confortável, verticais; mapa de calor de polígonos para cortar o pior primeiro.
- **Loot físico:** pega com a mão, mochila limitada; muito lixo de pouco valor que vira material ao desmontar
  (relógio, abajur, garrafa, travesseiro...). "Box of Stuff" por cor = pacote de materiais. Remédio some até o dia 5.
  Abertura com tábuas quebra com qualquer arma; cada tábua vira 4 madeira + 1 metal. Interior escuro demais
  foi criticado (análise).
- Decisão: **APROVEITAR** kit de fachada + cor/sujeira por casa (igual DayZ). **ADAPTAR** "lixo que desmonta em
  material" (combina com o nosso modo construção). Cuidado com interior escuro demais no celular.

### Mods de zumbi do GTA V ("GTA V Zomboid") — FATO sobre o que achamos; qual mod o dono quis: NÃO CONFIRMADO
Não existe mod com o nome exato "Zomboid" na busca. Os mais próximos:
- **Zombimod (Dracarys, gta5-mods):** saque em lojas (conveniência, armas, garagem, roupa), corredores de mercado,
  loot na natureza por chance do ambiente, carro quebrado conserta ou desmonta, avião caído com caixa rara.
  Bolso de 5 espaços (pilha 3), mochila em 5 níveis, baú com nível. Construção solta ou na grade, com reembolso.
  Zumbis: andador, corredor, chefe, cada um com audição/visão/velocidade. Fome esvazia em ~40 min, sede ~30 min.
  Até 3 eventos ao mesmo tempo; sobrevivente a cada 7 min; porta de casa abre e fecha.
  **Não fala de saquear casa por dentro**: o GTA V quase não tem interior aberto.
- **Simple Zombies (Reborn), Zombie Enhanced Edition, Left 4 Santos, The Dead Among Us:** fome/sede/estamina,
  zumbi preferindo ruas e cruzamentos, saque de corpos, conversão do mapa.
- Lição: cidade enorme e linda **sem interior** vira saque em loja e carro. Nosso diferencial é entrar nas casas.
- Decisão: **ADAPTAR** carro quebrado = desmontar para peças; "zumbi anda pelas ruas e cruzamentos". **DESCARTAR** o resto.

### State of Decay 2 (guias e artigo de loot, tipo B) — FATO, confiança média
- Toda casa entra; busca silenciosa x rápida (rápida faz barulho); local revistado fica riscado no mapa e mostra
  quanto falta. Recipientes postos à mão; loot por "baralho" (E14). Nada publicado sobre a arte das casas.
- Decisão: **INVESTIGAR** marcar casa revistada no mapa (sistema, não arte).

### Mission EVO (sem APK, só notícias, tipo D) — confiança baixa
- Unreal Engine 5 no celular; ilha; abrigo construído do zero ou invadido; NPCs armados nas ruínas. Nada sobre casas.
- Decisão: **DESCARTAR** como fonte de casa até o dono mandar vídeo de gameplay.

### Vidro falso: interior mapping (técnica pública) — FATO, confiança alta
- Artigo de van Dongen (CGI 2008): o shader traça um raio contra pisos/tetos/paredes **repetidos a cada X metros**;
  só 3 planos por pixel; a sala é uma caixa com textura; varia a profundidade e sorteia textura de um atlas.
  Usado em SimCity (2013), e provavelmente Spider-Man (não confirmado pela Insomniac). UE4 tem nativo.
- Dagor Engine (documentação aberta): some de 50 a 100 m; profundidade da sala; rotação aleatória por sala;
  3 estados de luz; luz **só à noite**; vidro levemente torto para cada janela refletir diferente.
- Decisão: **APROVEITAR** num shader nosso (escrito do zero) para prédios altos e vitrines vistos de longe.

## 2. O que todos fazem igual (síntese)

| # | Padrão | Quem | Classe |
|---|---|---|---|
| 1 | Grade métrica (1 m) e kit pequeno de peças: parede cheia / com janela / com porta / canto | CDDA, PZ, 7DTD, Days Gone, DL2 | FATO |
| 2 | Casa = **estilo** (fachada, janela, porta, telhado) + **cômodos com tipo** (piso, parede, móveis) | PZ (explícito), CDDA (paleta) | FATO |
| 3 | O móvel diz o cômodo e o loot | PZ, CDDA, DayZ | FATO |
| 4 | Janela e porta têm estados (inteira, aberta, quebrada, tábuas, trancada) e vida | CDDA, DayZ | FATO |
| 5 | Variação pela cor/material, não por modelo novo | DayZ (_Yellow), Days Gone (barris), PZ (paredes) | FATO |
| 6 | Sujeira como camada por cima (borda, canto, rodapé) | PZ (grime), TLOU (molhado/lama) | FATO |
| 7 | Textura que repete + cor de vértice; poucas texturas únicas | Days Gone, DL2, TLOU | FATO |
| 8 | De longe: malha simples (imposter) ou vidro falso com sala dentro | 7DTD, interior mapping, Dagor | FATO |
| 9 | Interior fechado não aparece de fora (desempenho) | Days Gone | FATO |
| 10 | Cidade: gerador monta, artista acaba à mão | DL2, 7DTD (RWG + POIs à mão) | FATO |
| 11 | Peças de esquina e casas de rua (geminadas) | DayZ HouseBlock | FATO |
| 12 | Luz do interior vem da janela | TLOU II | FATO |

## 3. Por que a nossa cidade está feia (diagnóstico do chefe) — INFERÊNCIA

Comparando com o que eles fazem:
1. Prédios são caixas lisas; falta o "trim": rodapé, batente, peitoril, moldura, friso de laje, calha, beiral (padrão 7).
2. Janelas são placas escuras coladas em parede cheia, sem fundo nem estado (padrões 4 e 8).
3. Vidro é opaco: placa escura com brilho metálico (`_vidro_janela`, cor 0.12) ou preto (0.05); nada se vê dentro.
4. Cor chapada sem sujeira: nenhuma marca de umidade na base, de escorrido sob a janela, de mão no batente (padrão 6).
5. Interior só em parte das casas e sem lógica de cômodo pela planta (padrão 2).
6. Quase nenhuma variação de casa para casa além da cor (padrões 2 e 5 usados pela metade).
7. Montagem da cidade 100% automática, sem passada à mão (padrão 10).

## 4. Proposta: KIT DA CASA NOVA (São Jorge, Brasil) — ADAPTAR

Nada aqui é copiado: são medidas de casa brasileira + os padrões acima.

**Medidas (decisão do chefe):** grade de 0,5 m; parede 0,15 m; pé-direito 2,8 m; laje 0,12 m.
Porta 1,0 x 2,2 m (maior que a real 0,8 x 2,1, como a do DayZ, para a câmera de celular). Janela 1,2 x 1,1 m,
peitoril a 1,0 m; banheiro: basculante 0,6 x 0,6 a 1,6 m. Lote 10 x 25 m (bairro) e 5-8 x 20 m (centro, geminado).

**Peças do kit (Blender, uma vez só):**
- Parede de fora: cheia, janela, porta, canto, meia-parede (muro), com reboco + barra escura de umidade embaixo.
- Trim: rodapé, batente, peitoril, verga, friso de laje, beiral, calha, cano de descida, grade de janela.
- Janela: 3 tipos (correr de alumínio, veneziana de madeira, basculante de ferro) x 5 estados
  (inteira, aberta, quebrada com cacos, tábuas, sem nada). Vidro de perto: fino, transparente, um pouco de reflexo.
- Porta: madeira, aço (fundos/loja), vidro (loja); estados fechada/aberta/arrombada/batente. Porta de enrolar na loja.
- Telhado: telha cerâmica 2 águas e 4 águas, fibrocimento, laje com caixa d'água.
- Piso: cerâmica (3 cores), taco de madeira (casa velha), cimentado/vermelhão (área e garagem), azulejo de banheiro.
- Parede de dentro: pintada (paleta de 8 cores, quarto com cor própria), azulejo até 1,5 m na cozinha/banheiro.

**Gerador de casa (formato do PZ):** estilo = {cor do reboco, janela, porta, telhado, muro, idade}
+ planta = {sala, cozinha, banheiro, 1-3 quartos, área de serviço com tanque, varanda/garagem}.
Cada cômodo: piso + parede + móveis da lista dele + pontos de loot de chão/prateleira (DayZ) no lugar dos móveis.
Variação: mesmo modelo com cor de instância (MultiMesh tem cor por instância: custo zero).

**Vidro:**
- Perto (< 25 m): vidro real fino; quebra virando a peça "quebrada" + cacos no chão (barato, sem física).
- Longe: shader nosso de interior mapping nas janelas de prédio alto e vitrine (sala falsa, sem luz: cidade sem energia;
  algumas com vela à noite).

**Sujeira:** cor de vértice (escurece base da parede, cantos e embaixo da janela) + poucos decalques (mancha, pichação).

**Montagem da cidade (formato DL2):** gerador põe quarteirões e lotes por zona; depois passada à mão
(praça, igreja, POIs, histórias em cômodos, carros batidos). Centro com sobrados geminados e peça de esquina (DayZ).

**Orçamento de 1 GB (decisão do chefe, pedido do dono):** o APK pode ir de 400 MB a 1 GB. O espaço extra vai para
o que mais aparece: texturas da cidade em 2048 (atlas de fachada, pisos, azulejo, telhado, trim, sujeira; ~3 MB cada
comprimida no celular), mais variações de casa e móvel, sons de ambiente. Tamanho do APK não é memória: a memória no
celular fica medida à parte e a qualidade Batata usa texturas menores.

**Desempenho (celular):** um material/atlas para todas as casas; peças repetidas em MultiMesh;
interior só perto (já temos "dentro" até 18-45 m); casa vira "longe" (imposter) de longe; nenhuma fresta para dentro.
Medir draw calls por vista antes e depois (vistas 0-13 de `tools/foto_cidade.gd`): não pode passar do atual (~1300 Média).

## 5. Ordem de trabalho (cidade nova)

1. Kit de peças + atlas de texturas (Blender reinstalar; ~400 MB de disco, temos 2,4 GB).
2. Gerador de casa (estilo + cômodos) e 1 casa de prova: fotos de dentro e de fora para o dono aprovar.
3. Janelas/portas com estados + vidro de perto; shader de vidro falso de longe.
4. City builder v3 (quarteirão -> lote -> casa) + passada à mão nos lugares importantes.
5. Navmesh, testes, medida de desempenho, fotos, APK.

## 6. Aplicado no jogo (05/11)
- Casas do bairro (casa_r1..r3, r5, r7..r14, `tools/blender/ruinas.py` `casa_real`): reboco colorido na fachada com barrado
  de cimento; dentro cerâmica com rodapé dela (taco nos quartos de casa velha), parede pintada com cor própria por quarto
  (PZ), azulejo 1,6 m na cozinha e 1,8 m no banheiro, basculante e box no banheiro, grade em 40% das janelas, tanque,
  calha e cano. Mesmas plantas e tamanhos (a cidade não mudou de lugar).
- Carros: porta-malas revistável e cacos de vidro no chão (mods do GTA V).
- Falta: vidro falso nos prédios de longe (interior mapping), janela que quebra no jogo, sujeira por cor de vértice,
  kit de peças novo para sobrados/aptos, City Builder com passada à mão.

