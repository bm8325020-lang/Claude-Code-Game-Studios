# DEAD DISTRICT — Sanatório (plano da virada, 14/11)

Pedido do dono: pegar o prompt do jogo de terror (necrotério + hospício, fusíveis, criatura que odeia luz) e virar o
DEAD DISTRICT nele. Não é modo novo nem jogo separado: o jogo inteiro muda, e a floresta continua. Este arquivo manda
nas decisões; o código segue ele. As referências em imagem não chegaram: a arte sai das descrições do prompt.

---

## 1. Conceito

**Resumo.** A floresta é o terreno murado do **Sanatório Santa Lúcia**: hospício e necrotério do estado, fechado
depois do "Tratamento de Escuridão". Você acorda no acampamento destruído (já existe) e descobre que está preso: o muro
e o portão de ferro fecham o terreno, e o portão só abre com energia. Para fugir, ache os **6 fusíveis**, ponha no
**painel da Casa de Força** e saia pelo **Portão Norte**. Enquanto isso, **a Lívida** te caça.

**Proposta.** Terror de exploração em primeira pessoa (a terceira continua nas configurações), com um objetivo que se
entende em 10 s ("6 fusíveis, um portão") e uma execução que dá medo: escuro, som e um monstro que aprende onde você
está.

**Diferencial.**
- **A luz é escudo, não arma.** A lanterna na cara queima a Lívida, mas custa bateria, esquenta e falha. Errar a mira
  é o pior momento do jogo.
- **Mundo aberto de terror.** O medo não fica preso num corredor: a mata, as alas e o subsolo formam um lugar só, e o
  dia e a noite mudam as regras.
- **Tudo que já existe vira terror:**
  - zumbis viram internos;
  - a base vira refúgio iluminado;
  - o rádio vira a voz de outro preso;
  - os eventos viram sustos.

---

## 2. Gameplay loop

1. **Explorar com cuidado.**
   - A lanterna gasta pilha e o barulho chama.
   - Andar agachado é silencioso; correr faz barulho.
2. **Achar um fusível.**
   - Ele fica num lugar marcado pela arquitetura: luz de emergência, porta aberta, trilha de sangue.
   - Pegar o fusível faz barulho. A Lívida ouve e vem investigar.
3. **Sobreviver.** Diante da Lívida você tem três saídas:
   - fugir;
   - esconder;
   - queimar a cara dela com a lanterna, o que ganha tempo mas não resolve.
4. **Voltar com o fusível até o painel.**
   - Carregar fusível deixa você mais lento: ele é pesado, como uma bateria de carro.
   - Só dá para carregar um por vez. Isso força a ida e volta com tensão.
5. **Pôr o fusível no painel.**
   - Cada fusível acende uma parte do terreno: postes, a ala, o subsolo.
   - Áreas acesas ficam mais seguras.
   - A Lívida fica mais nervosa e mais rápida a cada fusível.
6. **Com os 6 no painel, o portão começa a abrir (90 s).**
   - A sirene toca e a Lívida entra em fúria.
   - Você tem que aguentar perto do portão até ele abrir e sair. Isso é o clímax.
7. **Fim.** Tela de vitória com tempo, mortes e fusíveis. Depois vem o "Novo Jogo+", que já existe
   (`Tarefas.ng`): ele mexe os fusíveis de lugar e deixa a Lívida mais forte.

**Progresso.**
- Fusível posto no painel não se perde e fica salvo com a base.
- Fusível na mão cai no chão se você morrer e fica marcado no mapa.

---

## 3. Mecânicas principais

| Mecânica | Como funciona | Código |
|---|---|---|
| Exploração | Primeira pessoa padrão. Agachar silencia o passo. Correr faz barulho num raio de 18 m; andar, 6 m. O minimapa só mostra o que você já viu, e as salas ficam escuras no mapa até você entrar. | `jogador.gd`, `minimapa.gd`, `Zumbi.barulho` → `Criatura.ouve` |
| Fusível | Item `fusivel`, um por vez na mão (`Mochila.LIMITE` 1). Andar fica 20% mais lento. Pegar e soltar fazem barulho de 12 m. | `item.gd`, `mochila.gd` |
| Painel / Portão | Painel na Casa de Força com 6 encaixes. Pôr um fusível leva 3 s parado (dá para ser pego no meio). Cada um acende um setor. Com os 6, o portão abre em 90 s. | `painel.gd` (novo), `portao.gd` (novo) |
| Lanterna | Cone de 28° e alcance de 14 m. Ver a seção 4: queima a Lívida. Gasta pilha (já existe). Esquenta: 3 queimas seguidas e ela pisca e falha por 2 s. | `jogador.gd` (`_lanterna`, `carga`) |
| Esconderijo | Armário, debaixo da maca, atrás da cortina, gaveta do necrotério. A tela escurece pelas frestas, a respiração aparece e dá para segurar o fôlego. Ver abaixo. | `esconderijo.gd` (novo) |
| Perseguição | A Lívida corre mais que você no escuro e menos na luz. Portas fecham atrás de você (porta só abre por um lado). Atalhos destrancam por dentro. | `criatura.gd`, `porta.gd` (já existe) |
| Morte | Pega = morte (o golpe tem animação, mas não tem chance de escapar). Você volta no último refúgio: a barraca, a cabana ou o posto de luz. O fusível que estava na mão cai onde você morreu. | `jogador.renasce`, `main.ponto_nascer` |

**Esconderijo, detalhado.**
- Entrar e sair leva 0,6 s, com barulho.
- Se a Lívida viu você entrar, ela abre o esconderijo e você morre.
- Se ela não viu, ela farejar perto e você ouve a respiração dela.
- Segurar o fôlego (botão) zera seu barulho por até 8 s; soltar faz você ofegar alto.
- Cada esconderijo só funciona 2 vezes seguidas: na 3ª ela checa. Isso impede ficar acampado no mesmo armário.

**Armas.**
- As armas continuam, mas o tiro faz um barulho enorme.
- Na Lívida, a bala só faz ela tropeçar por 1 s. Ela não morre.
- Os zumbis (internos) morrem normalmente.

---

## 4. IA da Lívida

Estados (`criatura.gd`, servidor decide, todos veem pela rede como o `Bicho`):

| Estado | Entra quando | Faz | Sai para |
|---|---|---|---|
| **PATRULHA** | começo ou desistiu de buscar | anda devagar entre pontos de patrulha da área onde o jogador está (fica perto, sem ser injusta) e para para ouvir | INVESTIGA (ouviu), CAÇA (viu de relance) |
| **INVESTIGA** | barulho (tiro, correr, porta, fusível) | vai rápido até o ponto, fareja 6 s e abre esconderijos próximos com 30% de chance | CAÇA (viu), BUSCA (nada) |
| **CAÇA** | viu o jogador de relance (fora do cone de visão firme) | anda curvada na direção, para e escuta; ela sabe a sala, mas não o lugar exato | PERSEGUE (visão firme 0,5 s) |
| **PERSEGUE** | visão firme | corre direto. No escuro é 1,3× o seu correr; na luz, 0,8× | RECUA (queimada), BUSCA (perdeu de vista por 4 s) |
| **RECUA** | lanterna na cara (seção abaixo) | grita, cobre o rosto e foge para o escuro mais perto por 5 a 7 s; depois desorientada por 2 s | BUSCA (volta pela última posição) |
| **BUSCA** | perdeu o alvo | vai à última posição vista e checa 3 pontos em volta: esconderijos, salas laterais. Dura 25 s | PATRULHA (achou nada), PERSEGUE (achou) |

**Visão.**
- Cone de 110° e alcance de 22 m.
- No escuro ela vê até 30 m: com lanterna acesa ela vê você de longe.
- Na luz forte ela vê só 12 m.
- Agachado e sem lanterna, o alcance cai pela metade.

**Escuro.**
- A Lívida mede a luz onde está: luz da área (setor energizado, poste aceso, fogueira) mais a hora do dia.
- No escuro: +30% de velocidade, enxerga mais e ataca mais rápido.
- Na luz forte: −20%, e ela evita entrar. Os refúgios iluminados funcionam como zona segura, mas com limite: a 3ª noite
  seguida no mesmo refúgio, ela apaga a luz, porque quebra a lâmpada.

**Reação à lanterna (o centro do jogo).**
- **Para queimar:**
  - a cabeça dela tem que estar dentro de 8° do centro do cone;
  - a distância tem que ser 14 m ou menos;
  - a luz tem que ficar 0,6 s seguidos nela;
  - a pilha tem que estar acima de 10%.
- **Efeito:** RECUA, com grito agudo, fumaça saindo da pele e a cabeça brilhando.
- **Custo:**
  - cada queima gasta 15% de pilha;
  - a lanterna esquenta; 3 queimas em 40 s fazem ela piscar e falhar por 2 s, sem luz. Esse é o momento de pânico.
- **Resistência:**
  - **Cooldown:** depois de queimada, ela fica 8 s imune. Ela volta pela lateral, não de frente.
  - **Fúria final:** ela só recua 2 s.
- **Mira errada:** luz no corpo e não na cabeça não queima, só irrita e faz ela correr 10% mais.

**Som (como ela ouve).**
- Ela reage ao `Zumbi.barulho`, que já existe e é usado por tiro, carro, sirene e latas.
- Outros sons novos que chamam a Lívida:
  - correr;
  - porta;
  - pegar fusível;
  - sair do esconderijo;
  - ofegar.

**Ataque.**
- Alcance de 1,6 m. Ela agarra e mata.
- No modo fácil, 2 golpes, como zumbi forte.
- A dificuldade das configurações (`Config.dificuldade`) muda isso.

---

## 5. Level design

### Mapa (1 km × 1 km; o centro do terreno vira o Sanatório)

```
                 PORTÃO NORTE (saída, energizado)
                        ║
   CAPELA ─ trilha ─ CASA DE FORÇA (painel 6 fusíveis, refúgio aceso)
     (F5)                │
                         │  pátio (postes que acendem por setor)
   ┌───────────────── SANATÓRIO SANTA LÚCIA ─────────────────┐
   │ ALA B (celas)    │ RECEPÇÃO │  ADMINISTRAÇÃO/ARQUIVO     │
   │ contenção (F2)   │ (entrada)│  segurança (mapa, chave)   │
   │──── corredor longo em L (luz piscando) ──────────────────│
   │ ENFERMARIA        │ ESCADA ↓ │  NECROTÉRIO: câmara fria  │
   │ (macas, cortinas) │          │  gavetas + AUTÓPSIA (F1)  │
   └───────────────────┴────┬─────┴───────────────────────────┘
                            ↓
                 SUBSOLO (escuro total): caldeira, lavanderia,
                 SALA ELÉTRICA (F3), túnel até o CREMATÓRIO
                                                 (F4, saída na mata)
   mata ── ACAMPAMENTO (começo) ── trilha ── CASA DO ZELADOR (F6)
```

O que já existe e muda de nome:
- a vila vira o Sanatório (prédios no mesmo lugar);
- as raids da mata viram os pontos dos fusíveis de fora: capela, crematório, zelador;
- o muro do terreno é a borda do mapa.

### Progressão

| Fase | Onde | Ensina | Pressão |
|---|---|---|---|
| **Começo** (0–10 min) | acampamento → trilha → Casa do Zelador (F6, fácil e de dia) → Casa de Força | O bilhete e o rádio explicam o portão. O 1º fusível no painel acende o pátio. Você vê a Lívida pela primeira vez **de longe, na beira da mata, olhando**, e ela some. | baixa: ela só observa |
| **Meio** (10–35 min) | Sanatório: Ala B, enfermaria, necrotério e autópsia (F1, F2) | Esconderijos, lanterna na cara (1º encontro numa sala pequena com armário do lado) e portas que só abrem por um lado | média: ela patrulha dentro |
| **Fundo** (35–50 min) | Subsolo (F3) → túnel → crematório (F4) e capela (F5) | Escuro total, mais rápida e pouca pilha (precisa achar pilha antes) | alta |
| **Fim** | Casa de Força → Portão | 90 s de sirene em fúria. Os postes acesos são ilhas seguras de 2 s. | máxima |

### Fusíveis (6), cada um com o seu "jeito"

1. **Autópsia:** em cima da mesa, debaixo do lençol, com alguém por baixo. Pegar faz a gaveta do lado abrir.
2. **Contenção (Ala B):** dentro da cela acolchoada. A porta tranca atrás de você: sai pela grade do teto, um atalho
   para o corredor.
3. **Sala elétrica (subsolo):** no meio da sala, com água no chão. A lanterna liga reflexos e a Lívida vê de longe.
4. **Crematório:** dentro do forno, numa sala cheia de cinza. Correr levanta pó e faz barulho.
5. **Capela:** no altar. De noite, as velas se apagam uma a uma quando ela chega, e isso serve de aviso.
6. **Casa do Zelador:** no armário de ferramentas, de dia. É o tutorial.

**Novo Jogo+:** cada fusível tem 2 lugares possíveis por área, sorteados por partida.

### Esconderijos, atalhos e perigo

- **Esconderijos:**
  - armários na Ala B e na administração;
  - debaixo das macas na enfermaria;
  - cortinas na enfermaria;
  - gavetas na câmara fria (só as vazias);
  - nichos escuros no subsolo;
  - na mata, troncos ocos e moitas (só de dia).
- **Quantos:** pelo menos 1 esconderijo a cada 15 m dentro do prédio. Toda sala de fusível tem 1 esconderijo a menos
  de 5 m, mas nunca na linha da porta.
- **Atalhos** (destrancam por dentro):
  - grade do teto da contenção para o corredor;
  - porta da autópsia para o pátio;
  - túnel do subsolo para o crematório;
  - escada de serviço da enfermaria.
- **Seguro (iluminado):**
  - Casa de Força;
  - refúgios que o jogador monta (a base continua);
  - recepção, depois do 2º fusível.
- **Perigoso:**
  - subsolo;
  - câmara fria (você só vê pelas gavetas);
  - mata de noite;
  - corredor em L (2 portas, luz piscando: ela aparece no fim).

### Guiar sem missão

O jogador é guiado pelo próprio lugar, nunca por seta na tela:
- luz de emergência vermelha nas portas que levam a fusível;
- fiação exposta no teto que corre até o painel (siga o fio);
- som de zumbido nos quadros de luz.

---

## 6. Direção de arte

- **Estilo:** o estilizado que já está aprovado (cor lisa e sombra macia), mas sujo e frio. Detalhe vem de forma e
  luz, não de textura fotográfica (leve no celular).
- **Paleta:**
  - **Interior:** verde-hospital desbotado (#7f9a86), azulejo branco-sujo (#cfcfc0), ferrugem (#7a4a2a), preto-azulado
    nas sombras.
  - **Luz fria:** verde-azulada (#9fd8c8).
  - **Emergência:** vermelho (#ff3020).
  - **Exterior:** a floresta escura que já foi aprovada.
- **Materiais (cor lisa + desgaste nas cores dos vértices):**
  - azulejo até meia parede, tinta descascada em cima;
  - concreto molhado no subsolo;
  - aço escovado nas gavetas e portas;
  - madeira podre na capela.
- **Luz:**
  - poucas luzes, muito contraste;
  - lâmpadas fluorescentes piscando (o `postes_piscam.gd` já existe);
  - luz de emergência girando;
  - feixe de luz pelas janelas gradeadas de dia;
  - no escuro total, só a lanterna.
- **Clima:** névoa baixa dentro do subsolo, pó no ar nas salas iluminadas, respingos na parede da autópsia.
- **Composição:** corredores longos com uma porta aberta no fim; portas de aço com visor; macas encostadas tortas;
  cadeira de rodas virada; fichas no chão; cortinas meio abertas; gavetas do necrotério com uma aberta.

---

## 7. Lista de assets

| Grupo | Itens | Como vem |
|---|---|---|
| Cenário modular (grade de 3 m) | parede reta, parede com porta, parede com janela gradeada, canto, chão de azulejo, chão de concreto, teto com luminária, escada, grade de teto, cela acolchoada | código (`sanatorio.gd`, blocos como o `Porao`) |
| Props | maca, cadeira de rodas, mesa de autópsia, carrinho de instrumentos, bandeja, armário clínico, arquivo de aço, fichas, gaveteiro de corpos (6 por 2), forno do crematório, caldeira, canos, quadro elétrico, cama de ferro, camisa de força pendurada, cortina de hospital, banco da capela, altar com velas | Sketchfab CC (pipeline `natureza2.py`) + código para os simples |
| Portas | porta de aço com visor, porta de cela, porta dupla da ala, grade, portão norte | código + `porta.gd` |
| Interativos | fusível (grande, amarelo e preto), painel com 6 encaixes e luzes, gavetas, armários, cortinas, pilha, bilhetes | código |
| Criatura | modelo com esqueleto (Sketchfab CC, magra e alta) ou o corpo do zumbi esticado (protótipo) | `tools/assets/` |
| Animações | andar curvada, correr de quatro, parar e ouvir (cabeça girando), farejar, abrir armário, agarrar, recuar cobrindo o rosto, grito, desorientada | Mixamo/UAL (pipeline que já existe) |
| Sons | ver a seção 8 e a lista de áudio no fim | Freesound/OpenGameArt CC0 + gerados (como o tiro e o ronco do avião) |

---

## 8. A Lívida

**Lore curta.** A paciente 117, internada em 1961, foi a primeira do "Tratamento de Escuridão": meses numa gaveta da
câmara fria "para curar a mania". Ela foi dada como morta e levada à autópsia. Acordou no meio dela. Desde então não
suporta luz e vive no escuro do Santa Lúcia, juntando "pacientes" novos.

**Visual.**
- **Corpo:** 2,6 m quando se levanta. Magra até o osso, com costelas e vértebras saltando. Pele cinza-azulada de
  cadáver, com manchas roxas.
- **Braços:** longos até o joelho, dedos compridos e unhas pretas.
- **Torso:** corte em Y da autópsia, costurado mal e meio aberto.
- **Cabeça:** enrolada em gaze cirúrgica velha, com um furo onde ficaria a boca, dentes à mostra. Os olhos não
  aparecem: só o brilho fraco de duas pupilas sob a gaze no escuro.
- **Pé:** etiqueta de necrotério no dedão ("117").
- **Silhueta:** curvada, cabeça baixa à frente dos ombros, braços pendendo. De longe é um "risco" alto e torto que
  ninguém confunde com zumbi.

**Movimento.**
- Parada: imóvel, só a cabeça gira em trancos, como os espasmos do zumbi que já existem.
- Andando: devagar, curvada e silenciosa.
- Correndo: de quatro, estalando ossos.
- Na luz: fica em pé e cobre o rosto com os braços longos.

**Ataque.** Avança, agarra pelos ombros e puxa para a gaze, com a tela escurecendo. Morte rápida, sem gore pesado.

**VFX.**
- Ao ser queimada: fumaça branca saindo da pele, a gaze chamuscando e uma luz alaranjada fraca no rosto.
- Pisca quando entra na luz das lâmpadas, como o "glitch" das lâmpadas falhando.

**Sons.**
- Respiração molhada lenta (perto, 8 m).
- Estalos de osso ao correr.
- Arrastar de unhas no metal (aviso de que ela está no corredor).
- Grito de queimada: agudo, cortado.
- Murmúrio quando fareja: conta números ("…cento e dezessete…").

---

## 9. Implementação técnica (Godot 4.7, no código atual)

```
scripts/
  sanatorio.gd      # novo: monta o prédio a partir de cidade.json "sanatorio" (salas, portas, luzes, esconderijos)
  criatura.gd       # novo: a Lívida (CharacterBody3D) — estados da seção 4, rede igual ao Bicho
  lanterna_queima   # dentro de jogador.gd: cone + mira na cabeça -> criatura.queima(quem)
  fusivel           # Item "fusivel" (item.gd/mochila.gd), barulho ao pegar/largar
  painel.gd         # novo: 6 encaixes, acende setores (grupo "setor_<n>"), salva no save da base
  portao.gd         # novo: abre com a energia cheia, contagem de 90 s, fúria, vitória
  esconderijo.gd    # novo: Area3D + câmera presa, fôlego; a criatura checa
  defesa.gd         # vira "noite do sanatório": a onda vira a Lívida mais forte e os internos acordando
tools/mapa/senoia.py # FLORESTA: a vila vira o terreno do Sanatório (prédio, Casa de Força, capela, crematório, zelador, muro)
tests/test_sanatorio.gd
```

**Rede.**
- O servidor decide criatura, fusíveis no painel, portão e esconderijos ocupados.
- Os clientes pedem ações por RPC, como `_pede_peca` e `_pede_golpe`.
- A criatura sincroniza posição, rotação e estado, como o `Bicho`.

**Save.**
- O `user://base_floresta.cfg` ganha `fusiveis_no_painel` e `onde_cairam`.
- Checkpoint é o refúgio mais perto aceso, mais a barraca e a cabana.

**Vitória e derrota.**
- Portão aberto e jogador atravessando: tela de vitória com tempo, mortes e fusíveis, e depois NG+.
- Morte: renasce no checkpoint.
- Todos mortos no multiplayer: a Lívida volta a patrulhar e os fusíveis ficam onde caíram.

**Navegação.** O prédio entra no mapa (`cidade.json`), então a malha de navegação é assada de novo
(`tools/assa_navegacao.gd`). A Lívida anda dentro com `NavigationAgent3D`, como os zumbis.

---

## 10. Roteiro de produção

| # | Etapa | Entrega |
|---|---|---|
| 1 | **Núcleo jogável (MVP)** | seção 11 |
| 2 | Mapa completo | Sanatório com as alas, subsolo, capela, crematório, Casa de Força e muro; malha de navegação nova |
| 3 | Polimento de jogo | busca inteligente, esconderijo checado, fúria final, internos (zumbis) no prédio, NG+ com fusíveis sorteados |
| 4 | Arte final | modelo da Lívida (Sketchfab com esqueleto + animações), props prontos, materiais sujos, luzes piscando por setor |
| 5 | Som | ambiência, criatura, lanterna, sirene, silêncios (seção 8 e lista abaixo) |
| 6 | Balanceamento | tempos de queima, pilha, velocidade e visão; medir no Moto G84 (30–60 quadros) |

Cada etapa termina com fotos, testes, commit e APK.

---

## 11. Versão mínima jogável (etapa 1)

**Entra:**
- O Sanatório térreo: recepção, corredor em L, 4 celas, enfermaria, necrotério com gavetas e autópsia. Montado em
  código no lugar da vila.
- Casa de Força com painel e Portão Norte na borda do mapa.
- 4 fusíveis (não 6) para o primeiro teste.
- A Lívida com 6 estados, visão, audição e escuro/luz. O corpo é o do zumbi esticado e escurecido.
- A lanterna queima com mira na cabeça, gasto de pilha e superaquecimento.
- Esconderijos: armário e debaixo da maca.
- Morte, checkpoint e vitória.

**Fica para depois:** subsolo, capela e crematório; modelo final; cortina e gaveta como esconderijo; segurar o fôlego;
NG+ sorteado; sons próprios (no MVP entram sons gerados e os que já existem).

**O que muda no jogo atual:**
- **Zumbis:** bem menos e só "internos" (dentro do prédio e perto dele).
- **Hordas:** desligadas.
- **Defesa da base:** vira a noite da Lívida.
- **Raids de loot:** viram os lugares dos fusíveis.
- **Continuam:** a base, o loot, as armas e os eventos. O jogo novo usa eles.

---

## Lista de áudio

| Camada | Sons |
|---|---|
| Ambiência | zumbido de fluorescente (loop, posicional), gotejar no subsolo, vento nas janelas gradeadas, rangido de prédio velho, metal distante (sorteado de 20 a 60 s), rádio chiando |
| Jogador | passos por chão (azulejo, concreto, folha, água), respiração que acelera perto dela, coração, ofegar ao sair do esconderijo, clique e zumbido da lanterna, lanterna falhando |
| Lívida | respiração molhada, estalo de osso, unha no metal, grito de queimada, murmúrio de números, porta de armário sendo aberta devagar |
| Mundo | fusível encaixando (estalo grave e luz acendendo), sirene do portão, portão de ferro abrindo, gaveta de necrotério deslizando |
| Silêncio | ao entrar no esconderijo, a música e a ambiência caem para 20%: só respiração e passos dela |
