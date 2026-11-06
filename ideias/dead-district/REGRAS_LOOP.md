# Regras do loop automático (dono, 07/11) — ler TODA rodada antes de mexer em qualquer coisa

Pedido do dono, palavra por palavra: "mudar a estrutura inteira da cidade; adicionar coisas novas; mecânicas novas;
novas construções; uma cara completamente diferente pro jogo e tirar essa cara de morto e genérico do jogo e os lags;
em vez de criar, pegar pronto (só criar quando for muito necessário); trocar o que você criou por modelos já prontos;
aprimorar o grupo Os Corvos; super operação no jogo inteiro; fazer tudo funcionar; jogo pronto pra postar."

## As 10 regras (nenhuma pode ser pulada)
1. CIDADE: toda seção do plano tem itens que mudam a ESTRUTURA da cidade (zonas, ruas, quarteirões, marcos), não só
   enfeite. Mudou a planta (tools/mapa/senoia.py): regerar planta + minimapa + malha de navegação (salva_nav).
2. COISAS NOVAS: cada rodada deixa algo novo que o jogador VÊ ou USA no mundo.
3. MECÂNICAS NOVAS: toda seção tem pelo menos 1 mecânica nova jogável (com teste próprio).
4. CONSTRUÇÕES NOVAS: prédios/lugares novos na cidade (com interior ou motivo para entrar: loot, perigo, atalho).
5. CARA NOVA: nada de cinza genérico e "morto". Identidade visual própria (paleta, luz, céu, interface, menu, ícone,
   tela de carregamento). Foto antes/depois em toda mudança visual; se ficou genérico, refazer.
6. SEM LAG: medir toda rodada que mexe no mundo: tools/peso_render.gd (DD_QUALIDADE=1) e tools/peso_cpu.gd (relógio
   de parede). Não pode piorar mais que 10%; se piorar, otimizar antes de seguir. Celular (Moto G84) é o alvo.
7. PRONTO > FEITO À MÃO: procurar modelo/som/textura pronto PRIMEIRO (Sketchfab CC0/CC BY via tools/assets/sketchfab.py,
   Poly Haven, ambientCG, Kenney, Quaternius, OpenGameArt). Criar no Blender só se não existir pronto que sirva, e
   anotar o porquê. Trocar aos poucos o que foi feito à mão (casas/prédios de ruinas.py/casas_us.py/cidade.py, caixas
   do porão, props) por modelos prontos. Só licença livre (CC0/CC BY) com crédito em tools/assets/creditos.py;
   nunca copiar asset de jogo/mod proprietário.
8. OS CORVOS: toda seção melhora a facção (acampamentos, patrulhas, emboscadas, líder, voz, recompensa, reação ao jogador).
9. FUNCIONAR: cada item com teste da área passando + foto quando visual; nada quebrado no log (SCRIPT ERROR = parar e
   corrigir). Multiplayer: mudou rede/RPC -> subir Rede.VERSAO e rodar test_rede.
10. PRONTO PRA POSTAR: no fim de cada seção, APK que instala e roda limpo, com resumo curto ao dono (pt-BR). A última
   seção da operação fecha: ícone do app, tela inicial, créditos, sem erro no export. Loja (Play Store/AAB): NÃO
   (dono 07/11: "deixa isso pra lá"); "postar" = APK pronto e limpo.

## Segurança (sempre)
Nunca commitar export_presets.cfg, assets/mixamo/, chaves. Commit com o trailer da sessão. Não passar segredo no chat.
Disco cheio: apagar só sobras próprias (APK já enviado, temporários de exportação).

## 11. Ideias do Claude (aprovadas para o loop; encaixar nas seções seguintes, sempre com as regras 1-10)
- Música e som que reagem: trilha tensa que sobe quando um zumbi te vê, silêncio pesado quando está seguro.
- Sirene da cidade à noite chamando horda (aviso no rádio antes): evento que muda o jeito de jogar a noite.
- Mapa grande (tela cheia) com marcadores: casas revistadas, porões, acampamentos dos Corvos, chamados do rádio.
- Salvar e continuar no solo (fecha o app e volta onde estava, com a mochila).
- Dificuldade (fácil/normal/difícil) e "primeira hora" guiada com objetivo claro (achar o rádio, chegar ao abrigo).
- Vibração do celular ao levar dano/mordida (desligável nas configurações).
- Conquistas simples (primeiro porão, matar o líder dos Corvos, sobreviver 3 noites) para dar motivo de voltar.
- Diário do jogador: bilhetes e fitas achados contam a história da Febre Cinzenta (liga com a jornalista Dana Price).

## 12. Mais 20 ideias (dono 07/11: "adicione mais umas 20 coisas"; mesmas regras 1-10, pronto antes de feito à mão)
1. Zumbi que sai de dentro de carro/lixeira/porta-malas quando você passa (susto pronto).
2. Zumbi gordo que explode em gás e cega por uns segundos; zumbi com colete à prova de bala (só morre na cabeça).
3. Cachorros zumbis em matilha, rápidos, à noite nos quintais.
4. Moto e bicicleta dirigíveis (bicicleta silenciosa, moto rápida e barulhenta).
5. Gerador a gasolina para ligar luz de uma casa (atrai zumbi pelo barulho).
6. Barricar porta e janela da casa onde você está com tábuas achadas no loot (sem modo construção: só no lugar certo).
7. Armadilhas: garrafa com lata (alarme), molotov, mina caseira.
8. Arco e besta silenciosos (flecha recuperável).
9. Lanterna com pilha que acaba; sinalizador vermelho que ilumina e atrai zumbi.
10. Ferimento sangrando (curar com bandagem), perna quebrada (anda devagar) além da infecção.
11. Sono e cansaço: dormir na cama de casa segura passa a noite (com risco de ataque).
12. Cozinhar no fogão/fogueira: comida crua faz mal, cozida rende mais.
13. Ciclo de lua e noites de neblina vermelha com zumbis mais agressivos (evento raro).
14. NPCs sobreviventes amigos que pedem escolta até o abrigo e viram vendedores lá.
15. Comerciante que aparece de tempo em tempo num ponto do mapa (troca, sem dinheiro de verdade).
16. Corvos: trégua paga (pedágio) ou guerra; se você matar muitos, eles caçam você à noite.
17. Câmeras de segurança de loja: TV que mostra o que tem lá dentro antes de entrar.
18. Elevador quebrado e escada de incêndio em prédios altos; telhados ligados por tábuas para fugir pelo alto.
19. Fotos/polaroids pela cidade que viram cartas colecionáveis no diário.
20. Final da história: helicóptero de resgate no topo do hospital depois de juntar peças do rádio (fim do jogo, crédito).
