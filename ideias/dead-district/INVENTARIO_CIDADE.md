# Inventário: as COISAS que a cidade usa (05/11) — engenharia reversa dos jogos de referência
Objetivo (dono): não "como planejam a cidade", e sim do que ela é feita: prédios, peças, objetos, materiais, vegetação,
destruição, loot, zumbis, otimização. Classe de evidência entre colchetes. Fontes em FONTES/ e EVIDENCIAS.md.

## 1. Objetos e móveis (o que existe e quanto aparece)
- Cataclysm DDA [FATO, contado por script em data/json]: 1.849 tipos de móvel/terreno. Mais variados: paredes 150, plantas/
  natureza 136, janelas 110, portas 99, pisos internos 97, ferramentas 80, armazenamento 63, cercas/portões 46, pisos externos 44,
  telhados 31, móveis médicos 28, eletrodomésticos 21, decoração 20, assentos 19. Nas 464 casas os mais frequentes: banquinho,
  balcão, pia, caixote, aquecedor de água, armário, mesa, planta de vaso, prateleira, caixa de papelão, sofá, chaminé,
  ar-condicionado, antena parabólica, ventilação de telhado, forno, geladeira, placa solar, caixa d'água; depois máquina de
  lavar/secar, chuveiro, lareira, aparelhos de academia. Lojas (18 mapas): pia, balcão, prateleira, armário, caixas, mesa,
  freezer, lixeira, caçamba, vitrine, manequim, cofre de armas. Terreno das casas: piso, linóleo, concreto, carpete (4 cores),
  calha + descida de água (gutter/downspout), grade de ventilação, cerca de arame + portão, telhado plano/telha/vidro,
  portas (comum, metal, vidro, trancada), escada, cerca de privacidade.
  [LIMITE: conta "quantos mapas citam" (paletas podem citar sem colocar).]
- State of Decay 2 [FATO, Game Developer]: recipientes de loot COLOCADOS À MÃO; o loot dentro é sorteado a cada mapa.
- Days Gone [FATO, 80.lv]: "cerca de quatro caçambas e mais de seis barris" com malha e textura próprias foram reduzidos para
  "no máximo dois barris", variando só a cor/material. Puxadores e dobradiças viraram peças pré-montadas compartilhadas.

## 2. Prédios: de que são feitos
- Days Gone [FATO]: kits modulares pequenos "no grid" (retas, cantos, rampas, escadas, em metros), com MATERIAIS QUE REPETEM
  (tiling) + mistura por cor de vértice (vert blend) + normais pesadas; peças únicas só onde o kit não serve (evita "asset bloat").
  Kit de Cloverdale e da faculdade feito por um artista [FATO, resumo de busca do portfólio; página bloqueada].
- Dying Light 2 [FATO, 80.lv]: "centenas de peças modulares de arquitetura" usadas pelo City Builder; o mesmo para caixas
  d'água e subestações; 4 "biomas de telhado" para cada região ter cara própria; texturas de escaneamento (Megascans/próprias)
  viradas em textura que repete.
- The Last of Us Part I [FATO, 80.lv]: prédios montados com conjuntos de peças modulares; "todos os prédios compartilham
  muitas instâncias"; há níveis de detalhe (LOD).
- Project Zomboid [FATO, README de terceiro]: 9.546 prédios feitos de 156.100 cômodos com nome.

## 3. Materiais, texturas e acabamento
- Days Gone [FATO]: trocaram texturas únicas por materiais que repetem (menos conjuntos de textura = mais leve).
- Dying Light 2 [FATO]: Substance Designer, Quixel Mixer, escaneamento; poucos triângulos e pouca área de textura por objeto.
- The Last of Us Part II [NÃO CONFIRMADO, só resumo de busca; ArtStation bloqueado]: carros com variações "musgo", "molhado",
  "neve" e decalques com relevo (parallax) para encaixar no ambiente.
- The Last of Us Part I [NÃO CONFIRMADO, idem]: pisos com "floaters" (peças finas por cima do piso) em vez de cortar o piso.

## 4. Vegetação, abandono e destruição
- Days Gone [FATO]: mundo "dois anos abandonado": "alguma vegetação", "muito lixo", ruas danificadas; 1 artista fez quase
  toda a vegetação; reduziram geometria e sobreposição de folhas transparentes (overdraw) por desempenho.
- Dying Light 2 [FATO]: vegetação nos telhados da cidade inteira foi o maior desafio técnico/artístico.

## 5. Coisas de gameplay espalhadas pela cidade
- State of Decay 2 [FATO]: loot "como baralho" (de 10 restaurantes, exatamente 7 têm comida; quais muda por mapa); garantias por
  tipo de lugar (obra sempre tem material, posto sempre tem galão); cota de armas por lugar; recipientes espalhados por cômodos
  diferentes antes de repetir cômodo; recipiente "reserva" (caixa de papelão grande); zumbis SEM ponto à mão, nascem em tempo
  de jogo fora da vista, atrás de "bloqueadores de visão" grandes colocados de propósito; áreas seguras marcadas.
- Dying Light 2 [FATO]: "ilhas de loot", "comboios perdidos", "contadores de história no telhado" (cenas montadas).
- Days Gone [FATO]: primeiro os objetos de COBERTURA (o jogador passa o combate atrás deles).

## 6. Desempenho (o que fizeram para caber)
- Days Gone [FATO]: menos objetos únicos e menos conjuntos de textura; LOD; streaming; muros de forte fechados (frestas faziam
  ver através e custavam caro); ferramentas de auto-povoar.
- Dying Light 2 [FATO]: poucos triângulos e pouca textura por objeto para gastar o orçamento onde importa.

## 7. DEAD DISTRICT hoje x referência (o que temos / o que falta)
| Coisa | Nós hoje | Falta (da referência) | Custo Android |
|---|---|---|---|
| Objetos da rua | postes+fios, árvores, ponto de ônibus, orelhão, banca, caçamba, hidrante, barril com fogo, lixo, carros | calha/descida d'água, ar-condicionado e antena em mais fachadas, cerca de arame + portão, cones/cavaletes, placas de rua | baixo (MultiMesh) |
| Variedade com pouco modelo | cada objeto 1 modelo | Days Gone: 1-2 modelos + cores/materiais diferentes | REDUZ |
| Prédios | modelo inteiro por prédio (54 modelos) | peças modulares compartilhadas (DG/DL2/TLOU) | REDUZ memória/APK |
| Material | 30 texturas Poly Haven que repetem + sombra nos vértices | mistura por cor de vértice (sujeira/umidade/musgo na base das paredes) | baixo |
| Decalques | só pichação 3D | rachadura, mancha, poça, sujeira escorrida (decal) | médio (overdraw) |
| Vegetação | árvores, mato no chão | trepadeira em parede, mato em telhado/rachadura | médio |
| Destruição | entulho, carro queimado, casa queimada | mais ruas danificadas, comboio perdido, cenas montadas | baixo |
| Loot | baú/gaveta sorteado; por cômodo (05/11) | "baralho" por tipo de lugar + garantias (SoD2) | zero |
| Zumbis | pontos fixos + bandos | nascer fora da vista atrás de bloqueadores (SoD2) | REDUZ (menos zumbis vivos) |
| Interiores | cômodos com móveis Poly Haven, azulejo, cerâmica | aquecedor, chuveiro, máquina de lavar, ventilador, mais caixas (CDDA) | baixo |
| Telhado | laje andável + escada + tábuas (05/11) | caixa d'água, antena, ventilação, vegetação, "cenas no telhado" (DL2) | baixo |

## 8. Lacunas da investigação (honesto)
- ArtStation, pzwiki, blog da Indie Stone, 7d2dmodding wiki, techraptor: bloqueiam leitura automática (403).
- Não assisti vídeos (não consigo). Sem iluminação noturna da cidade nas fontes lidas.
