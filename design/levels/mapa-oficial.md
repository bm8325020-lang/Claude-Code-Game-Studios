# Mapa oficial — Ilha de Cinzarra

> Status: **proposta, aguardando aprovação do dono do jogo** (2026-10-21).
> Dados: `prototypes/souls3d-concept/map/official_map.json` (a mesma fonte alimenta o desenho e o construtor do mundo).
> Desenho: `design/levels/mapa-oficial.png` (gerado por `prototypes/souls3d-concept/tools/draw_map.py`).

![Mapa](mapa-oficial.png)

## Visão

Um RPG clássico e enorme no estilo souls: uma ilha única de **2 km × 2 km** (cerca de 20 vezes a ilha atual), com
9 regiões ligadas por estradas, atalhos que voltam para a vila, e uma ilhota secreta. O mundo é aberto desde o início,
mas o **nível de perigo** de cada região guia a ordem natural, e dois portões travam o caminho principal.

## Ordem da aventura (caminho principal)

1. **Praia das Cinzas** (perigo 1). Você acorda no naufrágio e aprende o combate. Chefe: **Cavaleiro Afogado**.
   Recompensa: Semente do Fogo e a chave da ponte levadiça do castelo.
2. **Vila de Brasalume** (segura). É a base: ferreiro, mercador, curandeira, Guardiã das Fogueiras, quadro de missões.
3. Duas regiões de perigo 2, em qualquer ordem:
   - **Floresta Morta**, com lobos e a cabana da bruxa. Chefe **Alfa da Cinza**, Semente do Raio.
   - **Pântano Enegrecido**, com água que envenena e passarelas. Chefe **Mãe-Lodo**, Semente do Veneno.
4. **Ruínas do Guardião** (perigo 3). O castelo no centro da ilha; a ponte levadiça abre com a chave da praia.
   Chefe **Dragão Guardião**, Semente do Dragão.
5. **Cemitério dos Juramentados** e as Catacumbas, a primeira masmorra (perigo 3). Chefe **Rei dos Juramentados**,
   Semente da Sombra.
6. Duas regiões de perigo 4:
   - **Minas de Ferro Vivo**, com elevadores, trilhos e golens. Chefe **Golem de Ferro Vivo**, Semente da Terra.
   - **Picos Gelados**, com nevasca e um mosteiro. Chefe **Cavaleira do Gelo Eterno**, Semente do Gelo.
7. **Portão das Sementes**: só abre com as 7 Sementes.
8. **Pico do Dragão** (perigo 6): lava e rocha negra. Chefe final **Wyrm Ancião**.
9. Segredo: **Ilha do Farol** (perigo 5). Chega-se por um barco escondido no Pântano. Superchefe **O Faroleiro**.

## Regiões

| Região | Perigo | Mecânica própria | Inimigos | Fogueiras |
|---|---|---|---|---|
| Praia das Cinzas | 1 | Maré: a areia molhada deixa você mais lento | caranguejos de osso, afogados | Praia, Destroços do Navio |
| Vila de Brasalume | 0 | Lojas, missões, melhorar armas no ferreiro | nenhum | Vila |
| Floresta Morta | 2 | Névoa que esconde inimigos; lobos caçam em bando | lobos, esqueletos, bruxa | Trilha da Floresta, Cabana da Bruxa |
| Pântano Enegrecido | 2 | Água rasa envenena (barra de veneno); passarelas estreitas | sapos-lodo, afogados | Passarelas, Aldeia Afundada |
| Ruínas do Guardião | 3 | Castelo com andares, ponte levadiça e atalhos | guerreiros, besteiros, magos | Portões do Castelo, Salão do Trono |
| Cemitério + Catacumbas | 3 | Masmorra escura: só a tocha ilumina; mortos que ressurgem | esqueletos de todos os tipos | Capela, Catacumbas |
| Minas de Ferro Vivo | 4 | Elevadores e carrinhos de mina; túneis escuros | golens, mineiros mortos | Elevador, Fundo da Mina |
| Picos Gelados | 4 | Frio: sem fogueira por perto, a estamina cai; nevasca esconde o caminho | cavaleiros de gelo, lobos brancos | Mosteiro, Passo da Nevasca |
| Pico do Dragão | 6 | Chão de lava, chuva de fogo do Wyrm | dragonetes, cultistas | Portão das Sementes, Cratera |
| Ilha do Farol | 5 | Luz giratória do farol revela inimigos invisíveis | sombras | Farol |

## Regras de desenho

- **Toda região tem:** 2 fogueiras, um chefe, uma Semente (menos a Vila, o Pico e o Farol), um atalho que volta para
  a estrada principal, e pelo menos um segredo (baú, NPC ou parede falsa).
- **Estradas** ligam as fogueiras. Fora delas ficam os tesouros e os perigos maiores.
- **Marcos visíveis de longe** para orientar sem bússola: o castelo no centro, o farol, o vulcão do Pico,
  o mosteiro nos Picos e a torre da mina.
- **Viagem rápida** entre fogueiras acesas, como já funciona hoje.
- **Clássico, sem transformação em dragão:** os dragões são só inimigos e chefes. A força do jogador vem do nível,
  do equipamento e das 7 Sementes de poder.

## Plano técnico (celular)

- **Terreno em pedaços (chunks)** de 250 m × 250 m (8 × 8). Só os pedaços em volta do jogador ficam carregados,
  com menos detalhe quanto mais longe.
- **Objetos espalhados** em MultiMesh por pedaço, com distância de visão de até 110 m (a névoa esconde o resto).
- **Limites por quadro no celular:** até 200 mil triângulos, 250 chamadas de desenho e 12 luzes ligadas
  (a otimização de 2026-10-21 já chegou a 161 mil, 239 e 18).
- **Inimigos** só existem nos pedaços carregados e voltam a nascer ao descansar na fogueira.

## Ordem de construção proposta

1. Terreno de 2 km em pedaços, a partir deste arquivo de dados: costa, relevo por região, estradas e fogueiras.
2. Cada região ganha o seu bioma (cor do chão, árvores ou pedras próprias, céu e névoa) e os seus marcos.
3. Vila de Brasalume com os NPCs e as lojas.
4. Uma região completa por vez, na ordem da aventura: inimigos, chefe, Semente e segredo.
