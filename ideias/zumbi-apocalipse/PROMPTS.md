# Prompts do loop — um sistema por vez

Cada iteração do loop pega o **primeiro item com `Status: pendente`**, executa o prompt dele por inteiro, e só
então marca `Status: feito (APK x.yy / commit abc1234)`. Ordem = dependência (um sistema usa o anterior).
Regras de sempre (valem para TODOS os prompts, não repetidas abaixo):

- Ler `jogo/CLAUDE.md` antes de abrir arquivos. Uma mecânica por vez, o mais perfeita possível, sem cara de IA
  (nada de brilho/giro em item, nada de texto robótico na tela, sons e números críveis).
- **O servidor decide** (zumbis, loot, dinheiro, dano, baús, casas); o cliente só pede por RPC e o servidor
  confere distância, vida e posse antes de aceitar. Nunca confiar no cliente para dinheiro/itens.
- Mudou o que vai pela rede → subir `Rede.VERSAO`. Pensar no custo no servidor grátis (Render 0,1 CPU):
  nada por quadro que possa ser por evento; sincronia a 10–20 Hz; nada animado no servidor sem tela.
- Teste automático novo em `jogo/tests/` para a regra principal (e ver o teste falhar sem o código novo).
  Rodar todos os testes da tabela do CLAUDE.md antes do commit. Robô `tools/bot.gd` para olhar animação nova.
- Valores provisórios em `const` com comentário "provisório"; textos da tela em pt-BR curto e natural.
- Ao terminar: commit (trailer da sessão), push, publicar servidor (`publica.sh wss://zumbi-servidor.onrender.com/jogo`),
  APK novo assinado, atualizar `NOTAS.md` (status) e `CLAUDE.md` (mapa), resumo curto em pt-BR para o dono.
- Economia de créditos: sem agentes, poucas fotos (folha de contato), testes curtos.
- **Estilo das telas (referência do dono: jogo Decay, prints de 2026-10-29):** tudo pelo `UiTema` — letra
  condensada (Oswald) e títulos em Bebas Neue MAIÚSCULOS e espaçados ("I N F O R M A Ç Õ E S"); painéis escuros
  meio transparentes de cantos retos; botão redondo de voltar com seta no canto de cima à esquerda; avisos numa
  faixa no alto com barrinha colorida à esquerda (laranja aviso, vermelho perigo, azul informação);
  vida/fome/sede embaixo no meio com ícone e número dentro da barra; botões de toque redondos e escuros
  (com ícone desenhado em vez de texto, quando der). **Inventário:** grade de quadrados cinza (6 colunas),
  **barra rápida 1–6** embaixo (selecionado em azul, quantidade "X3" no canto), personagem e fome/sede à
  esquerda, painel do item à direita (nome, QUANTIDADE, descrição curta, botões LARGAR e DIVIDIR), botão
  FABRICAR no alto. **Fabricação:** abas de categoria no alto (COMUM, ARMAS, ÚTEIS, SAÚDE, TRAJES, BASE,
  RECURSOS), lista de receitas (ícone, nome, X1) com a selecionada destacada, painel INFORMAÇÕES (ícone, nome,
  descrição, peças necessárias em vermelho quando faltam "10X PANO (X3)"), seletor de quantidade (− xN + MAX)
  e botão FABRICAR; FILA ao lado. **Carregando:** fundo com arte, linha fina de progresso e "DICA: ..." com
  dicas verdadeiras do jogo. Ícones dos itens: renderizar o próprio modelo 3D do item num SubViewport (sem
  desenho de IA).

---

## 0. Servidor online aguentando o máximo
Status: feito (APK 0.31). Render grátis: 4 jogadores 1,3 ms de física, 8 jogadores 30 quadros (quadro ~20 ms),
10 oscila 25–30 quadros (quadro 60–100 ms) → limite MAX=8. Feito: sem animação no servidor, 30 Hz, posição a
20/s, limite com aviso "servidor cheio", painel status.json, menu acorda o servidor antes de entrar.
Falta (vira item novo quando precisar de mais de 8): interesse por distância e zumbis dormindo longe.

Objetivo: o servidor do Render (0,1 CPU, 512 MB) aguentar o máximo de jogadores sem cair de 30 quadros, e o
APK conectar nele pela lista "Online".
1. Medir com `tools/carga.gd` (4, 8, 12 robôs) lendo `status.json`; registrar a tabela em NOTAS.md.
2. Se `fisica_ms` > 25 com 8: **interesse por distância** — cada cliente só recebe zumbis/jogadores a até
   ~60 m (MultiplayerSynchronizer `add_visibility_filter` / `set_visibility_for`), zumbis longe de todos os
   jogadores "dormem" (sem navegação nem raio, checam a cada 1 s), escolha de alvo e cerco a 3 Hz.
3. Ajustar `MAX` no Render (variável de ambiente) para o número que segura 30 quadros com folga de 20%.
4. Reconexão: se cair, o cliente volta ao menu com aviso claro ("O servidor caiu. Tente de novo.").
5. O Render dorme sem visita: o menu "Online" mostra "acordando o servidor (até 1 min)..." e tenta de novo.
Aceite: 2 celulares jogando juntos pela internet; tabela de capacidade anotada; APK novo.

## 0c. Interfaces (pedido do dono: adiantar as interfaces)
Status: feito (commit abaixo; foto em tools/foto_telas.gd)

Um visual só para todas as telas, sem cara de IA: painéis escuros meio transparentes, cantos retos, uma cor de
destaque (laranja ferrugem), letra legível e grande no celular, botões de toque com no mínimo 56 px, textos
curtos em pt-BR. Tema central (`ui_tema.gd`: cores, tamanhos, `painel()`, `botao()`, `rotulo()`) usado por
todas as telas, nada de estilo espalhado.
Telas: **menu inicial** (nome, JOGAR ONLINE, NO WI-FI, SOZINHO, CONFIGURAÇÕES), **lista online** com estado
("acordando o servidor...", "cheio", "versão diferente"), **Wi-Fi** (criar, lista, IP), **carregando/entrando**,
**pausa** (CONTINUAR, CONFIGURAÇÕES, SAIR DA PARTIDA; Esc/botão no canto), **morte** ("Você caiu" + contagem
para voltar), **avisos** (faixa no alto que some sozinha: servidor cheio, caiu a conexão, item pego) e **HUD**
reorganizado (vida/fome/sede agrupadas, munição perto do botão de tiro, relógio do dia discreto).
Aceite: foto de cada tela (folha de contato) no celular (paisagem 1280x720) e PC; nenhuma tela antiga com
estilo próprio; testes existentes passando.

## 0d. Configurações (sensibilidade e o resto)
Status: feito (APK 0.32)

Tela CONFIGURAÇÕES (do menu e da pausa), salva em `user://config.cfg` e aplicada na hora:
sensibilidade do olhar (geral), **sensibilidade mirando por arma** (pistola, futuras armas), inverter eixo Y,
campo de visão, volume geral/efeitos, qualidade (sombras, resolução 3D, 30/60 quadros), tamanho e transparência
dos botões de toque, cor da mira. Botão "voltar ao padrão". Classe `Config` com valores padrão e teste
(salvar, ler, aplicar, padrão).

## 0b. Primeira pessoa (decisão do dono: animação de terceira pessoa não fica com qualidade)
Status: feito (APK 0.33). Câmera nos olhos (CameraPrimeira), braços com animação de animador (Sketchfab 1Matzh:
pistola com sacar/tiro/recarga/andar/correr). Facão (APK 0.34, pedido do dono: parecia garra do Wolverine):
parado no canto de baixo à direita com a lâmina para cima, 3 cortes feitos em código (Maos.CORTES). Próprio
corpo só faz sombra; os outros veem o corpo animado. Lanterna sai de perto do olho. Falta (melhorar depois):
mão segurando o facão (hoje o cabo sai da tela); viewmodel pode atravessar parede quando encosta.

O jogo passa a ser em **primeira pessoa** (celular e PC). Os outros jogadores continuam vendo o corpo inteiro
com as animações de hoje (rede igual); só a visão do próprio jogador muda.
1. **Câmera nos olhos**: filha do Jogador na altura dos olhos (em pé ~1,62 m, agachado ~1,05 m, transição
   suave), mesma entrada de olhar (toque/mouse, sensibilidade igual), FOV ~75. O próprio corpo não aparece
   para quem joga (camada de render escondida só da própria câmera), mas continua fazendo sombra.
   Tirar a câmera de terceira pessoa e o "corpo segue a câmera" (o corpo agora sempre gira com o olhar).
2. **Braços e arma na tela (viewmodel)**: braços leves (procurar "fps arms"/"first person hands" grátis no
   Sketchfab CC BY ou CGTrader royalty free, logados; se não achar bom, luvas simples low poly feitas em código)
   segurando a pistola e o facão de verdade (modelos já baixados). Desenhar por cima do cenário (sem
   atravessar parede: camada própria ou câmera do viewmodel). Tudo **procedural, sem depender de animação
   pronta**: balanço ao andar (bob discreto), atraso ao virar (sway), queda ao pousar, abaixar ao correr,
   coice do tiro (arma sobe e volta, câmera sobe 1–2°), recarga (arma desce e gira, pente sai/entra por tween),
   golpes do facão como arcos rápidos com preparação (direita→esquerda, diagonal, de cima para baixo),
   pegar item (mão desce rápido), comer/beber (item vai à boca), lanterna na mão esquerda apontando junto.
3. **Mira**: sem mirar = ponto/mira pequena no centro e dispersão maior; MIRA = arma vai para o centro
   (alça e massa alinhadas), FOV cai para ~55, anda devagar. Tiro e golpe saem do centro da câmera
   (já é assim: conferir).
4. **Celular**: botões continuam; tirar o que só fazia sentido em terceira pessoa.
5. **Testes**: altura da câmera em pé/agachado; corpo próprio invisível só para a própria câmera; tiro acerta
   o que está no centro; golpe do facão acerta o boneco à frente; outros jogadores ainda veem o corpo animado
   (teste de rede). Atualizar `tools/bot.gd` para fotografar a visão em primeira pessoa (viewmodel) e olhar
   cada movimento: parado, andar, correr, pular, agachar, mirar, atirar, recarregar, 3 golpes, pegar, comer.
Aceite: jogar a pista inteira em primeira pessoa sem nada atravessando a tela; robô aprovado nas folhas; APK.

## 1. Mochila (inventário)
Status: feito (APK 0.35). Mochila de 24 espaços (barra 1–6), empilha, limites provisórios, largar (item vai
para o chão via spawner, some em 10 min), dividir, mover; telas no estilo Decay com ícones do modelo 3D.
Ainda do lado do dono do jogador (servidor dono da mochila fica para o prompt 16, junto com a conta).

Hoje munição/comida/água/lanterna são contadores soltos no Jogador. Criar a **mochila**: lista de espaços
(provisório 16) com itens empilháveis (munição 96 por pilha, comida/água 5) e não empilháveis (armas,
lanterna, receitas, peças). Classe `Mochila` (dados puros, testável sem cena) + tela de mochila (botão
MOCHILA / tecla Tab) com ícones simples desenhados (sem imagem de IA), arrastar para largar no chão.
Itens viram `Item` no chão ao largar (mesmo sistema do PEGAR). Servidor é dono da mochila de cada jogador;
cliente recebe a mochila dele por RPC quando muda (não sincronizar a mochila dos outros).
Aceite: pegar, largar, empilhar, cheio = "mochila cheia"; testes da classe Mochila (adicionar, tirar,
empilhar, cheia) e de rede (cliente pega item, servidor confirma).

## 2. Baús com loot
Status: feito (APK 0.36). 4 baús na pista (Bau_0 dentro da casinha, fácil), Loot.TABELA, tela do baú, reenche em 5 min.

Baú (modelo simples de caixa de madeira/metal) espalhado pela pista: abrir leva 1,5 s (barra), mostra a lista
do conteúdo, pegar item por item para a mochila. Conteúdo sorteado no servidor por **tabela de loot**
(`loot.gd`: item, chance, quantidade) com raridades comum/incomum/rara; o baú esvazia e **re-sorteia depois
de 5 min** (provisório). Baús da "cidade inicial" (região marcada) com mais chance de comum útil.
Aceite: dois jogadores veem o mesmo conteúdo; um pega, some para o outro; teste de distribuição da tabela
(10 000 sorteios dentro da margem).

## 3. Morte com loot no chão
Status: feito (APK 0.37). Saco = Bau com `saco` (spawner), revistar 1,5 s, some vazio/10 min; sair caído ou em luta (<10 s) larga a cópia da mochila que o dono manda a cada 5 s.

Ao morrer (vida 0 e sem resgate — o resgate vem no prompt 10), a mochila inteira vira um **saco no chão**
no lugar do corpo (qualquer um abre e pega), e o jogador renasce sem nada (só facão). O saco some em 10 min.
"Sair do jogo morrendo" (desconectar com vida 0 ou nos últimos 10 s após levar dano) também larga o saco.
Aceite: teste: jogador morre → saco com os itens; outro pega; desconectar caído larga o saco.

## 4. Armas brancas achadas no mapa
Status: feito (APK 0.38). Faca (cutelo), taco e machado (Sketchfab CC BY) em Armas.BRANCAS; mesmos 3 cortes na tela com a velocidade de cada uma; no chão (BRANCAS_MAPA) e nos baús.

Arma branca é obrigatória e só se acha no mapa (não vende na loja da facção). Além do facão: **faca**
(rápida, dano 18, alcance 1,4), **taco** (lento, 35, empurra), **machado** (lentíssimo, 50, cambaleia sempre).
Cada uma com combo próprio feito à mão em `golpes.gd` (poses-chave, arco visível de trás) e som de impacto
diferente. Ficam no chão/baús como item; trocar de arma branca pela mochila. Modelos: procurar grátis
(Sketchfab CC BY / CGTrader royalty free, logados) e creditar em LICENCAS.txt.
Aceite: robô `bot.gd` mostra o combo de cada uma; testes de dano/alcance por arma.

## 5. Peças de arma e drop de zumbi
Status: feito (APK 0.39). Loot.PECAS, Loot.DROP_ZUMBI (35%), chefe 2–3 com raras ×3; drop some em 3 min.

Itens novos: peças (cano, ferrolho, mola, gatilho, cabo, carregador) com raridade. Fontes: baú, chão e
**drop de zumbi** (importante): ao morrer, zumbi sorteia drop (tabela própria; chefe dropa mais e mais raro).
Drop aparece como item no chão onde o zumbi caiu (some em 3 min).
Aceite: teste de drop do zumbi e do chefe (chance dentro da margem em muitos sorteios).

## 6. Receitas e bancada andante
Status: feito (APK 0.40). Receitas.LISTA (pistola simples), item receita_pistola (baú/zumbi/chefe), Jogador.receitas, Bancada em PONTOS_BANCADA muda a cada 10 min com aviso, TelaBancada estilo Decay.

Receita é **item na mochila** (pode ser roubada se você morrer). Cada arma tem receita: lista de peças.
Desbloquear = usar a receita (some da mochila e fica aprendida na conta/personagem). **Bancada** (modelo de
mesa de trabalho) aparece em ponto aleatório da cidade e **muda a cada 10 min reais**, com aviso "A bancada
apareceu em outro lugar da cidade". Na bancada: lista das receitas aprendidas, peças que faltam em vermelho,
FABRICAR (3 s). Raridades: simples (receita em baú/zumbi comum), mediana (difícil), rara (muito difícil: baú
chance pequena, drop de zumbi, chefe chance maior). Pistola atual vira "arma simples" fabricável.
Aceite: testes: sem peças não fabrica; com peças consome e cria; bancada troca de lugar e avisa.

## 7. Arma automática com seletor
Status: feito (APK 0.41). Pistola.FOGO (smg: 30, 22 de dano, cadência 0,085, AUTO/SEMI), Jogador.smg/fogo(), entrada atirando/modo, viewmodel MP5 (ccransh), receita_smg mediana, rara em baú.

Uma submetralhadora (ou fuzil) com **seletor**: o jogador escolhe semi/automático num botão (só nessa arma).
Automático: segura ATIRAR e sai rajada com cadência, dispersão crescente e coice forte (câmera e braços,
igual ao coice da pistola). Mira manual, sem ajuda. Recarga própria. Fabricável (receita mediana) e rara
em baú. Animações do Mixamo (rifle) misturadas como as da pistola.
Aceite: teste de cadência/dispersão; robô mostra mira, rajada e recarga.

## 8. Dinheiro do jogo e lojista
Status: feito (APK 0.42). Zumbi paga $10 (chefe $300, noite ×1,5) a quem bateu por último, conta abates; Lojista na
pista (barraca + vendedor parado) vende munição/comida/água e compra tudo menos o facão (Lojista.VENDE/PAGA); TelaLoja.
Teste: tests/test_loja.gd (8). Troca entre jogadores fica para o 9 (grupos).

Dinheiro (moeda do jogo, sem dinheiro real): matar zumbi dá (provisório 10, chefe 300, noite +50%). HUD mostra
o saldo discreto. **Lojista** NPC (parado, numa barraca) compra qualquer item por um preço e vende munição,
comida e água. **Venda entre jogadores**: troca segura (os dois confirmam; servidor troca de uma vez).
Ideia a pensar (deixar desligada numa const): matar jogador pega metade do dinheiro dele.
Aceite: testes: matar zumbi soma; comprar sem dinheiro falha; troca entre dois jogadores atômica.

## 8b. Cara nova (pedido do dono: "HUD lixo, muito poluído, muito botão"; "cara completamente diferente")
Status: em andamento. Parte 1 feita (APK 0.42): HUD limpo — barras finas de vida/fome/sede no canto de cima,
dinheiro embaixo delas, relógio curto ("DIA 4:12"), munição pequena embaixo à direita; celular só com 4 botões de
ícone (ataque/tiro, mira, pular, agachar) e os de contexto (recarregar só com pente incompleto, pegar só perto de
algo, seletor só com a smg); correr = analógico no fim para a frente; trocar/comer/beber pela barra rápida discreta.
Prompt das próximas partes: atacar os pontos fracos, um por iteração, com foto antes/depois:
1. (feito, d363c78+) Luz e céu: céu de fim de tarde nublado (ProceduralSky/PhysicalSky com névoa leve de profundidade), sombra macia,
   cor fria e dessaturada (pós-processo barato no gl_compatibility: só ajustes do Environment), noite azulada.
2. (concreto em código feito; falta pôr modelos) Pista: trocar blocos cinza por modelos (muro, contêiner, carro velho, barricada) grátis e de licença aberta,
   chão de asfalto/terra com textura; manter colisão e malha de navegação (testes de zumbi passando).
3. (feito) Arma na tela não atravessa parede (encolher para perto/baixar quando há parede a < 0,6 m na frente).
4. Itens soltos no chão com o modelo 3D (o mesmo dos ícones), girando devagar, em vez de caixinhas.
5. Mão segurando o facão e as armas brancas.

## 8c. Personagens novos e editor de personagem (pedido do dono)
Status: em andamento. Parte 1 feita (APK 0.44): personagem fixo para todos (Mixamo "Survivor"), zumbis com 3 modelos
(policial, mulher, soldado), chefe com skin própria (parasita) e habilidade própria (pancada no chão: acerta todos a
4 m, até de costas, empurra, a cada 7 s, anel de poeira). Teste: tests/test_chefe.gd.
Parte 1b feita (APK 0.45): tipos de zumbi com status, andar e habilidade próprios — Corredora (70 vida, 10 dano,
×1,3, bote de 3–6,5 m a cada 6 s), Policial (100, 15, ×1, soco agarra: jogador lento 2 s), Soldado (180, 20, ×0,65,
blindado: leva 60%, só cambaleia com golpe forte). Teste: tests/test_tipos.gd.
Parte 2 (depois): editor de personagem — escolher entre alguns corpos do Mixamo + cor de roupa/pele, salvo na conta
(prompt 16), mandado pela rede como dado do jogador (só o nome do modelo e as cores; servidor confere a lista).

## 9. Grupos
Status: feito (APK 0.46). Grupos (dados, servidor decide), convite pelo nome na pausa (GRUPO), faixa ACEITAR/RECUSAR
(30 s), até 4, sair; nome + distância em cima dos amigos e seta na borda quando fora da tela. Ainda não há PvP:
`Grupos.mesmo(a, b)` fica pronto para tirar o fogo amigo quando vier. Teste: tests/test_grupos.gd (12) + test_rede.

Convidar por nick (aceitar/recusar), até 4 no grupo (provisório). Membros do grupo aparecem com nome e seta na
borda da tela; sem fogo amigo entre membros (PvP contra os outros continua). Sair do grupo.
Aceite: testes de convite/aceite/saída em rede; dano entre membros = 0.

## 10. Resgate com raid
Status: feito (APK 0.47). Caído no grupo pede ao servidor; com 2+ do grupo vivos a até 75 m nasce a raid (4–12
zumbis pelo valor da mochila e abates) em volta; matar todos levanta com 30 de vida e paga $60 + 35% de peça a
cada membro; tempo (90 s) acabando ou servidor negando = morte normal com saco. Teste: tests/test_resgate.gd (9);
robôs com 3 jogadores em rede ficaram para depois (teste no aparelho do servidor cobre a lógica).

Morreu com **2+ membros do grupo a até 75 m**: em vez de morrer, fica **caído 90 s**. Zumbis surgem em volta
do corpo (quantidade e força pelo valor da mochila do caído e quantos zumbis ele já matou). Se o grupo matar
todos: o caído levanta com 30 de vida e todos ganham recompensa (dinheiro + chance de peça). Se o tempo
acabar: morte normal (saco no chão, prompt 3). Contador de zumbis mortos por jogador (registro, sem nível).
Aceite: teste com 3 jogadores (robôs): resgate dá certo e dá errado.

## 11. Nascer em lugar aleatório
Status: feito (APK 0.50). Pontos na frente das casas do bairro, bom/ruim calculado (baú fácil a até 18 m e nenhum
ponto de zumbi a menos de 14 m), sorteio 75% bom, ao entrar e ao renascer. Casa de facção: prompt 13.
Teste: tests/test_nascer.gd (5).

Pontos de nascimento marcados como bom/ruim; sorteio com mais chance de bom (provisório 75%). "Bom" = perto de
baús fáceis, longe de horda. Quem tem casa de facção renasce nela (prompt 13).
Aceite: teste de distribuição do sorteio.

## 12. Facção: criar dominando uma casa
Status: feito (APK 0.51). Dono pediu **1 jogador** para criar (não 3). DOMINAR (bandeira; PC H) dentro de uma casa do
bairro, 6 min; todos saem = falha; anúncio para o servidor; facção "Facção de <nick>" com quem estava dentro; FACÇÃO
na pausa (membros, ADICIONAR, limite 10); facção existente redomina com 1 membro em 3 min; outro grupo tomar = perde
a área. Nome escolhido e aumentar o limite pagando: depois. Teste: tests/test_faccoes.gd (11).

Casas completas marcadas como domináveis. Criar facção: **3+ jogadores dentro da casa** apertam "Dominar"
e seguram **5–7 min** (provisório 6). Ao começar, **anúncio para o servidor**: "Alguém está tentando dominar
<nome da área>". Se sair gente e ficar menos de 3, o tempo pausa; se todos saírem ou morrerem, falha.
Ao dominar: facção criada (nome escolhido), botão **FACÇÃO** aparece (adicionar membro por nick, limite 10,
aumentar pagando muito dinheiro). Uma facção = uma casa. Facção já existente redomina com **1 membro, 3 min**.
Aceite: testes do relógio de domínio (pausa, falha, sucesso) e do anúncio.

## 13. Casa da facção e manutenção
Status: feito em parte (APK 0.52): renascer na casa, baú da facção (guardar/pegar, só membros), cama que cura,
manutenção ($20 mil do fundo da facção a cada 7 dias do jogo, aviso nos últimos 3 dias, sem fundo perde casa e baú),
fundo (DEPOSITAR na página FACÇÃO), todos saíram = casa liberada e o baú vai com a facção (volta na próxima casa;
quem perde a casa para outro grupo também leva o baú). Falta: armário pessoal, lojas de membros (15), garagem (18).
Teste: tests/test_casa_faccao.gd (11).

Benefícios: renascer na casa, **baú da facção**, **armário pessoal** por membro, **cama que cura**, loja de
munição e de comida/água ao lado (só membros compram), garagem. **Manutenção ~20 mil a cada 7 dias do jogo**
(conta só com a casa ativa), aviso "faltam X dias para perder a casa"; não pagou = perde casa e baú.
Todos os membros saíram do servidor = casa liberada e os itens do baú/armários **vão com a facção** (ficam
guardados para a próxima casa). Outro grupo dominou = perde a área, não a facção.
Aceite: testes de prazo, aviso, perda, liberação e devolução dos itens.

## 14. Lockpick no baú da casa
Status: pendente

Invasor usa **lockpick** (item) no baú da facção: leva tempo (provisório 40 s; fechadura reforçada 90 s),
precisa ficar perto e parado; **todos da facção recebem notificação** ("Estão arrombando o baú da casa!").
Lockpick também abre carros do mapa (prompt 18).
Aceite: teste: arrombar abre; sair de perto cancela; notificação chega a todos os membros.

## 15. Loja da facção
Status: pendente

Itens só para quem tem facção (ou roubando): **alarme/fio de armadilha**, **fechadura reforçada**, **porta e
barricadas reforçadas**, **localizador** (membros no mapa), **kit de reanimação** (resgate mais rápido),
**sinalizador** (marca ponto para o grupo), **armadilhas e minas**, **holofote com gerador**, **drone de vigia**,
**estandarte** (marca território), **câmera com dispositivo** (nome + senha; ver em tempo real). Fazer em
partes: 15a alarme+fechadura+barricada, 15b localizador+sinalizador+estandarte, 15c armadilhas+holofote,
15d drone+câmera, 15e kit de reanimação. Cada parte com teste.

## 16. Conta e progresso salvo
Status: pendente

Conta (nick + senha, ou ID do aparelho) num serviço grátis de dados (ex.: Supabase/Firebase sem cartão —
pesquisar e pedir ao dono para criar). Salva **mochila inteira**, dinheiro, receitas aprendidas, facção, zumbis
mortos. Sair vivo e em paz salva tudo; sair morrendo larga o saco (prompt 3) e salva sem loot. Chaves
nunca no git nem no APK com permissão de escrita (servidor do jogo é quem grava).
Aceite: entrar, sair, entrar de novo com a mesma mochila; teste do "sair morrendo".

## 17. Entrar com amigo e servidores
Status: pendente

Chamar amigo pelo nick para o mesmo servidor; sem convite, servidor aleatório com espaço. Servidor com 5 ou
menos jogadores manda todos para um com 7–10 (aviso antes) e pode desligar. Facção reconectada domina casa
nova no servidor novo (itens vão junto).
Aceite: teste com 2 servidores locais e robôs.

## 18. Carros do mapa
Status: pendente

Carro comum dirigível (VehicleBody3D), entrar/sair, motorista + passageiros, atropelar zumbi, combustível.
Carros espalhados e numa concessionária abandonada; **lockpick** para levar. Carro **blindado** do mapa
(aguenta menos tiro que o do passe). Carro do mapa nunca vai para outro servidor (fica onde foi deixado).
Controles de carro no celular e PC. Sincronia de veículo leve (o motorista manda, servidor confere).
Aceite: dirigir em rede sem tremer; testes de lockpick e combustível.

## 19. Voz
Status: pendente

**Voz por proximidade** (qualquer jogador perto ouve) e **rádio da facção** (só membros, qualquer distância).
Pesquisar serviço grátis (Epic Online Services voz) ou voz pelo próprio servidor (Opus, AudioEffectCapture).
Botão falar (segurar), silenciar jogador e denunciar (exigência da Play Store).

## 20. Destruição
Status: pendente

Paredes e portas quebráveis por tiro/golpe (vida por pedaço, troca para versão quebrada, escombros que
viram cobertura). Servidor decide e sincroniza o estado.

## 21. Mapa grande (depois — o dono pediu para deixar o mapa por último)
Status: em andamento (adiantado: 11–15, 18 e 20 precisam de lugar). Parte 4 feita (APK 0.56): casas de verdade (modelos com cômodos, texturas gastas), construções escaneadas
(galpão, casarão, galpão pichado, prédio velho, posto) e Qualidade gráfica (Batata/Média/Alta/Ultra). Parte 3 feita (APK 0.55): cidade refeita do
OpenStreetMap (centro real de Monroeville, Alabama, 500x500 m, ~110 prédios), texturas Poly Haven, janelas com
moldura/vidro, parede interna, barricadas do exército. Parte 2 feita (APK 0.53): cidade 3x3 com praça,
posto, mercado, casas abandonadas/arrombadas/destruídas com móveis e 3 mansões (só elas domináveis, pedido do dono).
Parte 1 feita (APK 0.48): bairro em código no
estilo da referência do dono (cidadezinha low-poly): 4 quarteirões, 12 casas com porta/baú/comida, prédio alto,
galpão, ruas com faixa, árvores, carros; malha dos zumbis; nasce lá. Próximas: crescer o bairro (mais quarteirões,
mercado, posto, hospital, delegacia), interior com móveis, entulho/barreiras baixados, pontos de nascer bons/ruins (11).

Cidade inicial (mais fácil) + outras cidades, escombros, lugares preservados, concessionária, casas
domináveis. Usar os modelos já baixados (Sketchfab) e pacotes grátis; dividir por áreas que carregam por
proximidade.

## 23. Modos de jogo: Sobrevivência (mundo aberto), PvP em salas e História cooperativa
Status: em andamento. PvP v1 feito (APK 0.57): salas públicas/privadas com código no servidor online, limite,
tempo, dono começa, só se vê e só se acerta na mesma sala, placar, renasce em 4 s sem perder nada, botão PVP no menu.
Falta: mapa de PvP próprio (cobertura), modo História cooperativa.

Menu com 3 modos:
- **Sobrevivência**: o que existe hoje (mundo aberto, facções, 40 por servidor).
- **PvP em salas**: criar sala pública (aparece na lista global) ou privada (entra por código), escolher mapa, tempo
  e número de jogadores; partida curta com fim e placar. Lista global precisa de um servidor de salas (matchmaking).
- **História cooperativa**: campanha própria (original, clima de terror e sobrevivência), sozinho ou com até 3
  amigos (4 no total). Capítulos com objetivos, cenas, chefes, puzzles simples, munição escassa e salvamento por
  capítulo. Quem cria a sala hospeda (4 jogadores pesa pouco no celular) ou usa o servidor.

## 22. Passe, loja visual e Play Store (por último)
Status: pendente

Passe mensal pelo servidor (versão grátis e paga), visuais sem vantagem (roupas, skins, pinturas, emblemas,
emotes), carros do passe (exceção aceita pelo dono). Publicação: conta Google Play (US$ 25), assinatura de
release, ficha da loja.
