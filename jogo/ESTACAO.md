# DEAD DISTRICT — Estação Halverson (plano da virada, 14/11)

Pedido do dono: pegar as mecânicas do prompt de terror e virar o DEAD DISTRICT. Do prompt ficam:
- itens espalhados para abrir a saída;
- uma criatura que odeia luz e caça você;
- esconderijos;
- um mapa que guia, tem progressão e mistura áreas seguras e perigosas.

Ideia escolhida pelo dono: **Estação de Pesquisa**, no lugar do hospício. Não é modo novo nem jogo separado: o jogo
muda e a floresta continua.

A história já existia no jogo:
- a Febre Cinzenta é um fungo que veio do milho da Hollis Feed;
- a Halverson Agro testava algo ali;
- a Dra. Okafor gravou tudo em fitas.

Agora o lugar de tudo isso aparece: a estação no meio da mata.

---

## 1. Conceito

**Resumo.** No meio da floresta fica a **Estação de Pesquisa Halverson**: laboratório de campo onde o fungo da Febre
Cinzenta foi "melhorado". O surto começou ali. O exército fechou a região, e a única saída é o **túnel de evacuação no
bunker** debaixo da estação. A porta do bunker só abre com os **4 cartões de acesso** (verde, azul, amarelo, vermelho),
espalhados pela estação e pela mata. Enquanto você procura, o **Paciente Zero**, primeiro infectado e o que mais
mudou, te caça. A luz normal irrita o Paciente Zero; **luz ultravioleta queima o fungo dele**.

**Proposta.** Sobrevivência e terror em primeira pessoa (a terceira continua nas configurações). O objetivo cabe numa
linha: "4 cartões, uma porta". Cada cartão abre a área do próximo, então o mapa se abre aos poucos.

**Diferencial.**
- **A luz UV é escudo, não arma.** Ela queima o Paciente Zero, mas gasta muita bateria, esquenta e falha. Mirar errado
  é o pior momento do jogo.
- **Progressão por cartão.** O verde abre o laboratório, onde está o azul, que abre o subsolo... O mundo cresce junto
  com o medo.
- **Tudo que já existe ganha motivo:**
  - os zumbis são os infectados;
  - o fungo explica a Lívida, que agora é o Paciente Zero;
  - a base vira refúgio iluminado;
  - as fitas da Okafor contam o que aconteceu;
  - o rádio é a voz de outro sobrevivente.

---

## 2. Gameplay loop

1. **Explorar com cuidado.**
   - A lanterna gasta pilha e o barulho chama.
   - Agachado é silencioso; correr faz barulho.
2. **Achar o cartão da vez.**
   - Ele fica onde a arquitetura aponta: luz de emergência, porta forçada, fio arrastado, sangue.
   - Pegar o cartão dispara um alarme curto da estação. O Paciente Zero ouve.
3. **Sobreviver.** Diante dele você tem três saídas:
   - fugir;
   - esconder;
   - queimar com UV, o que ganha tempo mas não resolve.
4. **Abrir a área nova com o cartão.**
   - Cada leitor de cartão leva 2 s parado, e dá para ser pego no meio.
   - Cada área aberta acende os corredores dela, criando novas áreas seguras.
   - O Paciente Zero fica mais nervoso e mais rápido a cada cartão.
5. **Abrir a porta do bunker com os 4 cartões (90 s).**
   - O alarme de contenção toca e o Paciente Zero entra em fúria e chama os infectados.
   - Você aguenta perto da porta até ela abrir e desce no túnel. Isso é o clímax.
6. **Fim.** Tela de fuga com tempo, mortes e fitas achadas. Depois vem o Novo Jogo+, que já existe (`Tarefas.ng`): ele
   troca os cartões de lugar e deixa o Paciente Zero mais forte.

**Progresso.**
- Cartão usado no leitor fica valendo (área aberta) e vai no save da base.
- Cartão na mochila não se perde ao morrer: ele é seu, como a arma.

---

## 3. Mecânicas principais

| Mecânica | Como funciona | Código |
|---|---|---|
| Exploração | Primeira pessoa padrão. Agachar silencia o passo. Correr faz barulho num raio de 18 m; andar, 6 m. O minimapa só mostra o que você já viu. | `jogador.gd`, `minimapa.gd`, `Zumbi.barulho` → `PacienteZero.ouve` |
| Cartões | Itens `cartao_verde/azul/amarelo/vermelho`. Pegar dispara um alarme de 15 m. Leitor de cartão: 2 s parado. | `item.gd`, `mochila.gd`, `leitor.gd` (novo) |
| Áreas trancadas | Portas da estação por cor (`Porta.trava = "azul"`). O cartão abre para todos na sala. | `porta.gd` (já existe) + cor |
| Porta do bunker | 4 encaixes; com os 4, abre em 90 s com alarme de contenção. Lá dentro, o túnel = vitória. | `bunker.gd` (novo) |
| Lanterna | Luz normal: cone de 28°, 14 m. Na cara do Paciente Zero ele vira o rosto 1 s, irritado. **Filtro UV** (achado no laboratório, com o cartão verde): botão alterna branca/UV. UV queima (seção 4) e gasta 3× a pilha. Esquenta: 3 queimas em 40 s e falha por 2 s. | `jogador.gd` (`_lanterna`, `carga`) |
| Esconderijo | Armário dos alojamentos, debaixo do beliche, atrás da cortina da enfermaria, dentro do freezer de amostras (vazio), duto de ventilação, tronco oco na mata. Explicado abaixo. | `esconderijo.gd` (novo) |
| Perseguição | Ele corre mais que você no escuro e menos na luz. Portas da estação fecham sozinhas (molas). Atalhos destrancam por dentro. | `paciente_zero.gd`, `porta.gd` |
| Morte | Agarrado = morte (2 golpes no fácil, por `Config.dificuldade`). Volta no último refúgio aceso, barraca ou cabana. | `jogador.renasce`, `main.ponto_nascer` |

**Esconderijo, detalhado.**
- Entrar e sair leva 0,6 s, com barulho.
- Se ele viu você entrar, abre e pega.
- Se não viu, ele fareja perto e você ouve a respiração dele.
- Segurar o fôlego (botão) zera seu barulho por até 8 s; soltar faz você ofegar alto.
- Cada esconderijo só funciona 2 vezes seguidas: na 3ª ele checa. Isso impede ficar acampado no mesmo armário.

**Armas.**
- As armas continuam, mas o tiro chama tudo.
- No Paciente Zero, a bala só faz ele tropeçar 1 s. Só a UV machuca.
- Os infectados (zumbis) morrem normal.

---

## 4. IA do Paciente Zero

O servidor decide; todos veem pela rede, como o `Bicho`.

| Estado | Entra quando | Faz | Sai para |
|---|---|---|---|
| **PATRULHA** | começo ou desistiu de procurar | anda entre pontos da área onde o jogador está (fica perto, sem ser injusto), para e escuta | INVESTIGA (ouviu), CAÇA (viu de relance) |
| **INVESTIGA** | barulho (tiro, correr, porta, alarme de cartão) | vai rápido ao ponto, fareja 6 s e abre esconderijo perto com 30% de chance | CAÇA (viu), BUSCA (nada) |
| **CAÇA** | viu de relance | anda curvado na direção, para e escuta; sabe a sala, não o lugar | PERSEGUE (visão firme 0,5 s) |
| **PERSEGUE** | visão firme | corre direto. No escuro é 1,3× o seu correr; na luz, 0,8× | RECUA (UV), BUSCA (perdeu de vista por 4 s) |
| **RECUA** | UV na cara (abaixo) | grita, cobre o rosto, o fungo fumega e ele foge para o escuro mais perto por 5 a 7 s; depois desorientado 2 s. **O grito acorda os infectados em 25 m.** | BUSCA |
| **BUSCA** | perdeu o alvo | vai à última posição vista e checa 3 pontos em volta (esconderijos, salas do lado). Dura 25 s | PATRULHA, PERSEGUE |

**Visão.**
- Cone de 110° e alcance de 22 m.
- No escuro ele vê até 30 m: com lanterna acesa ele vê você de longe.
- Na luz forte ele vê só 12 m.
- Agachado e sem lanterna, o alcance cai pela metade.

**Escuro.**
- No escuro: +30% de velocidade, enxerga mais e ataca mais rápido.
- Na luz forte (área aberta com cartão, refúgio, fogueira): −20%, e ele evita entrar.
- O refúgio é seguro, mas com limite: na 3ª noite no mesmo refúgio, ele quebra a lâmpada.

**UV (o centro do jogo).**
- **Para queimar:**
  - a cabeça dele tem que estar dentro de 8° do centro do cone;
  - a distância tem que ser 10 m ou menos (a UV alcança menos que a branca);
  - a luz tem que ficar 0,6 s seguidos nele;
  - a pilha tem que estar acima de 10%.
- **Efeito:** RECUA. O fungo das costas chia e solta fumaça; os veios brilham em roxo sob a UV (é assim que se vê que
  pegou).
- **Custo:**
  - cada queima gasta 15% de pilha;
  - 3 queimas em 40 s fazem a lanterna esquentar e falhar por 2 s.
- **Resistência:**
  - **Cooldown:** depois de queimado, fica 8 s imune e volta pela lateral.
  - **Fúria final:** ele só recua 2 s.
- **Mira errada:** UV no corpo irrita e faz ele correr 10% mais. A luz branca na cara só faz ele virar o rosto 1 s.

**Som.**
- Ele reage ao `Zumbi.barulho`, que já existe.
- Sons novos que chamam ele:
  - correr;
  - porta;
  - alarme de cartão;
  - sair do esconderijo;
  - ofegar.

**Ataque.** Alcance de 1,6 m. Agarra e puxa contra o fungo.

---

## 5. Level design

### Mapa (1 km × 1 km; a vila vira a Estação, as raids viram pontos da estação na mata)

```
                       TORRE DE RÁDIO (refúgio aceso; rádio do outro sobrevivente)
                              │
   ESTUFA EXPERIMENTAL ── trilha ── HELIPONTO (helicóptero caído: CARTÃO AMARELO no piloto)
                              │
   ┌──────────────── ESTAÇÃO HALVERSON (prédio principal) ────────────────┐
   │ PORTARIA/GUARITA │ ALOJAMENTOS (beliches, armários)  │ REFEITÓRIO      │
   │ (entrada, mapa)  │ CARTÃO VERDE (quarto da Okafor)   │ (cozinha fria)  │
   │──────── corredor principal (luz piscando, portas com mola) ───────────│
   │ ENFERMARIA/QUARENTENA │ [porta VERDE] LABORATÓRIO: tanques, freezers  │
   │ (macas, cortinas)     │ de amostras, sala de necropsia, FILTRO UV,    │
   │                       │ CARTÃO AZUL (cofre da diretora)               │
   │ SEGURANÇA/ARQUIVO     │ [porta AZUL] escada ↓                         │
   └───────────────────────┴──────────────────┬────────────────────────────┘
                                              ↓
          SUBSOLO (escuro total): biotério (jaulas), câmara de contenção do Paciente Zero
          (o NINHO: fungo nas paredes, CARTÃO VERMELHO), casa das máquinas,
          [porta AMARELA] gerador → PORTA DO BUNKER (4 encaixes) → túnel de evacuação = FIM
   mata ── ACAMPAMENTO (começo) ── trilha ── POSTO DE COLETA DO RIO (bilhete, pilhas, primeira vista dele)
```

O que já existe e muda de nome:
- a vila vira a Estação;
- o helicóptero caído vira o heliponto;
- o posto florestal vira a torre de rádio;
- o acampamento militar vira o posto de coleta.

### Progressão por cartão

| Fase | Onde | Ensina | Pressão |
|---|---|---|---|
| **Começo** (0–10 min) | acampamento → posto de coleta → portaria → alojamentos (**verde**) | bilhete e rádio ("a estação tem um bunker"); você vê o Paciente Zero **de longe, parado na beira da mata, de costas**, e ele some | baixa: ele só observa |
| **Meio** (10–30 min) | laboratório (porta verde): **filtro UV** + **azul** no cofre | 1º encontro de perto no laboratório (sala pequena, freezer do lado para esconder, UV recém-achada); portas com mola | média: ele patrulha a estação |
| **Fora** (30–40 min) | heliponto na mata (**amarelo**, no piloto morto) | a noite na mata com UV e pouca pilha; infectados em volta do helicóptero | média e alta à noite |
| **Fundo** (40–50 min) | subsolo (porta azul), ninho dele (**vermelho**), gerador (porta amarela) | escuro total; o ninho é a casa dele (ele volta para lá) | alta |
| **Fim** | porta do bunker | 90 s de alarme, ele em fúria e infectados chamados; as luzes de contenção são ilhas de 2 s | máxima |

### Cartões e o "jeito" de cada um

1. **Verde (alojamentos):** no quarto da Dra. Okafor, com a fita 1 e o diário. A porta do quarto tranca por dentro: tem
   que sair pela janela, um atalho para o pátio.
2. **Azul (laboratório):** no cofre da diretora. A senha está anotada no quadro branco de outra sala (procurar, não
   adivinhar). Abrir o cofre faz barulho de 20 m.
3. **Amarelo (heliponto):** no crachá do piloto morto. O helicóptero está rodeado de infectados deitados (tocaia, já
   existe).
4. **Vermelho (ninho, subsolo):** preso no fungo da parede. Arrancar leva 3 s e faz barulho; ele **sempre** vem. É a
   corrida mais tensa do jogo.

**Novo Jogo+:** cada cartão tem 2 lugares possíveis na mesma área, sorteados.

### Esconderijos, atalhos e perigo

- **Esconderijos:**
  - armários e debaixo dos beliches (alojamentos);
  - cortinas (enfermaria);
  - freezer vazio (laboratório);
  - duto de ventilação (corredor para o lab);
  - jaula vazia (biotério);
  - na mata, troncos ocos e moitas (só de dia).
- **Quantos:** pelo menos 1 esconderijo a cada 15 m dentro do prédio. Toda sala de cartão tem 1 esconderijo a menos de
  5 m, mas nunca na linha da porta.
- **Atalhos** (abrem por dentro):
  - janela do quarto da Okafor para o pátio;
  - duto do lab para a enfermaria;
  - escada de serviço do subsolo para a portaria;
  - portão dos fundos para a trilha do heliponto.
- **Seguro (iluminado):**
  - portaria;
  - torre de rádio;
  - áreas já abertas por cartão;
  - refúgios que o jogador monta (a base continua).
- **Perigoso:**
  - subsolo;
  - biotério;
  - ninho;
  - corredor principal (portas com mola batendo, luz piscando: ele aparece no fim);
  - mata de noite.

### Guiar sem missão

O lugar mostra o caminho, sem seta na tela:
- a fita de cor no chão e na parede leva até a porta daquela cor, como faixa de hospital;
- luz de emergência vermelha nas salas de cartão;
- o fio do alarme corre pelo teto até o bunker.

---

## 6. Direção de arte

- **Estilo:** o estilizado que já está aprovado (cor lisa, sombra macia), mas sujo e frio. Detalhe vem de forma e luz.
- **Paleta:**
  - **Estação:** branco-gelo sujo (#d6d8d2), cinza-laboratório (#8c949a), verde-hospital (#7f9a86), faixas de cor das
    portas (verde #3fae5a, azul #3a78d0, amarelo #e6c22e, vermelho #d23a2a).
  - **Fungo:** cinza com brilho roxo-UV.
  - **Luz fria:** fluorescente verde-azulada (#9fd8c8).
  - **Emergência:** vermelha.
  - **UV:** violeta (#7a3cff).
- **Materiais:**
  - azulejo de laboratório;
  - piso vinílico gasto;
  - aço inox nas bancadas e freezers;
  - vidro rachado nos tanques;
  - concreto molhado no subsolo;
  - **fungo** (manchas cinzas que crescem para o subsolo, e de perto viram fiapos).
- **Luz:**
  - pouca e com muito contraste;
  - fluorescentes piscando (`postes_piscam.gd` já existe);
  - emergência girando;
  - luz dos tanques de amostra (verde fraca);
  - no subsolo, só a lanterna.
  - Com UV ligada, o fungo e os rastros dele brilham roxo, o que vira **pista** de por onde ele passou.
- **Composição:** corredor longo com uma porta batendo na mola; bancada com amostras quebradas; maca com cinto
  rasgado; quadro branco com fórmulas e uma senha; jaulas abertas; freezers com uma porta aberta e luz piscando dentro.

---

## 7. Lista de assets

| Grupo | Itens | Como vem |
|---|---|---|
| Cenário modular (grade de 3 m) | parede reta, com porta, com janela, com visor de vidro; canto; chão vinílico e de concreto; teto com luminária; escada; duto de ventilação; porta de cofre do bunker | código (`estacao.gd`, blocos como o `Porao`) |
| Props | bancada de laboratório, tanque de amostra (vidro com algo dentro), freezer, centrífuga, microscópio, maca, cortina, beliche, armário de metal, mesa de necropsia, jaula do biotério, gerador, canos, quadro elétrico, quadro branco, arquivo, cadeira de escritório virada | Sketchfab CC (pipeline `natureza2.py`) + código |
| Portas | porta com faixa de cor e leitor de cartão, porta com mola, porta do bunker (redonda, aço), portão dos fundos | código + `porta.gd` |
| Interativos | 4 cartões (com cor e crachá), leitor de cartão (luz vermelha/verde), cofre com teclado, filtro UV, pilhas, fitas, bilhetes | código |
| Criatura | modelo com esqueleto (Sketchfab CC, alto e magro com crescimentos) ou o corpo do zumbi esticado + fungo em código (protótipo) | `tools/assets/` |
| Animações | andar curvado, correr de quatro, parar e ouvir, farejar, abrir armário/freezer, agarrar, recuar cobrindo o rosto, grito, desorientado | Mixamo/UAL (pipeline que já existe) |
| Sons | ver a seção 8 e a lista de áudio no fim | Freesound/OpenGameArt CC0 + gerados |

---

## 8. O Paciente Zero

**História curta.** O Dr. Elias Varga, chefe do projeto, injetou em si mesmo a cepa "melhorada" do fungo quando a
Halverson mandou destruir as amostras. Não morreu. O fungo tomou o corpo e cresceu para dentro dos ossos. A Dra.
Okafor trancou ele na câmara de contenção e gravou tudo nas fitas. A câmara abriu quando a energia caiu. Ele ainda usa o
crachá.

**Visual.**
- **Corpo:** 2,5 m quando se levanta. Magro, pele cinza-esbranquiçada quase transparente, com os veios escuros do
  fungo aparecendo.
- **Costas e ombros:** cobertos de crescimentos de fungo, placas e "orelhas" de cogumelo cinza.
- **Braços:** longos, com o acesso do soro ainda preso e tubos pendurados.
- **Cabeça:**
  - o fungo abriu a mandíbula ao meio, como uma flor;
  - os olhos ficaram leitosos;
  - os restos dos óculos estão grudados no rosto.
- **Roupa:** jaleco rasgado e sujo, com o crachá "DR. E. VARGA — NÍVEL 4" no peito.
- **Silhueta:** alto, curvado, ombros largos de fungo e braços pendendo. De longe é uma sombra torta com uma "coroa" de
  cogumelos.

**Movimento.**
- Parado: imóvel, só a cabeça gira em trancos (como os espasmos do zumbi que já existem) e esporos caem.
- Andando: devagar e curvado.
- Correndo: de quatro, com estalo de osso.
- Na UV: fica em pé e cobre o rosto.

**Ataque.** Avança, agarra e puxa contra a boca aberta, com a tela escurecendo e esporos. Morte rápida, sem gore
pesado.

**VFX.**
- Esporos caindo sempre, em partículas cinza leves.
- Na UV: veios brilham roxo, fumaça branca chiando sai do fungo, faíscas roxas.
- Deixa rastro de fungo no chão que só aparece com UV.

**Sons.**
- Respiração com chiado (esporos no pulmão, perto, 8 m).
- Estalo de osso ao correr.
- Unha arrastando no inox (aviso de que ele está no corredor).
- Grito de queimado: agudo e com estalo.
- Murmúrio quando fareja: repete a voz dele das fitas ("...nível quatro... nível quatro...").

---

## 9. Implementação técnica (Godot 4.7, no código atual)

```
scripts/
  estacao.gd          # novo: monta o prédio + subsolo a partir de cidade.json "estacao" (salas, portas de cor, luzes, esconderijos)
  paciente_zero.gd    # novo: estados da seção 4; rede igual ao Bicho
  jogador.gd          # lanterna: modo UV (filtro na mochila), cone + mira na cabeça -> paciente_zero.queima(quem); superaquecer
  leitor.gd           # novo: leitor de cartão por cor; abre as portas daquela cor (servidor), salva
  bunker.gd           # novo: 4 encaixes, 90 s de alarme, fúria, túnel = vitória
  esconderijo.gd      # novo: Area3D + câmera presa + fôlego; ele checa
  porta.gd            # já existe: + trava por cor e mola
  defesa.gd           # a noite: ele mais forte, infectados acordando perto da base
tools/mapa/senoia.py   # FLORESTA: a vila vira o terreno da Estação; raids viram heliponto/torre/posto/estufa
tests/test_estacao.gd
```

**Rede.**
- O servidor decide: Paciente Zero, portas abertas, cartões usados, esconderijo ocupado, bunker.
- Os clientes pedem ações por RPC, como `_pede_peca` e `_pede_golpe`.

**Save.**
- O `user://base_floresta.cfg` ganha `cartoes_usados`.
- Checkpoint é o refúgio aceso mais perto, a barraca ou a cabana.

**Vitória e derrota.**
- Bunker aberto e você no túnel: tela de fuga e depois NG+.
- Morte: renasce no checkpoint.
- Todos mortos no multiplayer: ele volta ao ninho, e as portas abertas continuam abertas.

**Navegação.** O prédio entra no `cidade.json`, então a malha de navegação é assada de novo
(`tools/assa_navegacao.gd`). O subsolo fica 40 m abaixo, como o `Porao`, com escada que teleporta e malha própria.

---

## 10. Roteiro de produção

| # | Etapa | Entrega |
|---|---|---|
| 1 | **Núcleo jogável (MVP)** | seção 11 |
| 2 | Mapa completo | estação inteira, subsolo, ninho, heliponto, torre e posto; malha de navegação |
| 3 | Polimento de jogo | busca, checar esconderijo, fúria, infectados acordando com o grito, NG+ sorteado, cofre com senha |
| 4 | Arte final | modelo do Paciente Zero (Sketchfab com esqueleto + animações), props prontos, fungo crescendo, luzes por área |
| 5 | Som | ambiência, criatura, UV, alarmes, silêncios |
| 6 | Balanceamento | tempos de UV, pilha, velocidade e visão; medir no Moto G84 |

Cada etapa termina com fotos, testes, commit e APK.

---

## 11. Versão mínima jogável (etapa 1)

**Entra:**
- O prédio térreo da estação no lugar da vila: portaria, alojamentos, corredor principal, enfermaria e laboratório.
  Montado em código.
- 3 portas de cor e 3 cartões: verde, azul e amarelo.
- A porta do bunker no laboratório, por enquanto: com os 3 cartões, abre e você vence.
- O Paciente Zero com os 6 estados, visão, audição e escuro/luz. O corpo é o do zumbi esticado, com fungo em blocos.
- A lanterna com modo UV que queima (mira na cabeça, gasto e superaquecimento).
- Esconderijos: armário e debaixo do beliche.
- Morte, checkpoint e vitória.

**Fica para depois:** subsolo, ninho e cartão vermelho; heliponto como lugar de cartão; modelo final; cofre com senha;
segurar o fôlego; NG+ sorteado; sons próprios.

**O que muda no jogo atual:**
- **Infectados (zumbis):** bem menos, perto da estação e dos lugares de cartão.
- **Hordas:** desligadas.
- **Defesa da base:** vira a noite do Paciente Zero.
- **Continuam:** a base, o loot, as armas, os eventos e o rádio. O jogo novo usa eles.

---

## Lista de áudio

| Camada | Sons |
|---|---|
| Ambiência | zumbido de fluorescente, ventilação ligando e desligando, porta com mola batendo longe, gotejar no subsolo, máquinas do gerador, bip de equipamento morrendo, rádio chiando |
| Jogador | passos por chão (vinil, concreto, folha, grade), respiração que acelera perto dele, coração, ofegar, clique da lanterna e zumbido da UV, lanterna falhando |
| Paciente Zero | respiração com chiado, estalo de osso, unha no inox, grito de queimado, murmúrio "nível quatro", esporos estalando |
| Mundo | leitor de cartão (bip vermelho e verde), alarme curto ao pegar cartão, alarme de contenção do bunker, porta do bunker girando, fitas da Okafor |
| Silêncio | no esconderijo, a música e a ambiência caem para 20%: só respiração e passos dele |
