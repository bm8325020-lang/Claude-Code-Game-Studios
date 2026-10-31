# Jogo de zumbi — mapa rápido (ler isto antes de abrir arquivos)

Dono: não técnico, celular, pt-BR. Respostas curtas, economizar créditos (sem agentes, poucas fotos).
Plano e status das mecânicas: `../ideias/zumbi-apocalipse/NOTAS.md` (seção do plano, itens numerados).
Branch `zumbi-apocalipse`, worktree `/home/user/zumbi-notas`. Push: `git push -q origin zumbi-apocalipse`.
Nunca commitar: `export_presets.cfg` (senhas), `assets/mixamo/` (licença), chaves. Commit termina com o trailer da sessão.

## Comandos
```
G=/home/user/.local/godot/Godot_v4.7.2-stable_linux.x86_64
SP=/tmp/claude-0/-home-user/09449103-5068-5eff-93a6-3d4914815589/scratchpad
BT=/home/user/.local/android/build-tools/35.0.1
$G --headless --path . --import                       # depois de criar class_name nova
timeout 400 $G --headless --path . --fixed-fps 60 -s res://tests/<t>.gd   # t: test_movimento(60) test_zumbi(54) test_itens(19) test_mochila(16) test_config(8) test_portas(9)
# rede (2 processos): servidor em background, depois cliente; matar: for p in $(pgrep -x "Godot_v4.7.2-st"); do kill $p; done
(timeout 120 $G --headless --path . -s res://tests/test_rede.gd -- servidor > $SP/srv.log 2>&1 &); sleep 2; timeout 120 $G --headless --path . -s res://tests/test_rede.gd -- cliente
timeout 60 $G --headless --path . -s res://tests/test_busca.gd
# servidor dedicado: pck + "-- dedicado"; tests/test_dedicado.gd é o cliente
# APK: subir version/code e version/name em export_presets.cfg, depois:
timeout 600 $G --headless --path . --export-release "Android" "$SP/z.apk"; $BT/zipalign -f -p 4 "$SP/z.apk" "$SP/zumbi-X.apk" && $BT/apksigner sign --ks /root/.local/share/godot/keystores/debug.keystore --ks-key-alias androiddebugkey --ks-pass pass:android "$SP/zumbi-X.apk"; rm -f "$SP/z.apk"
GODOT=$G bash tools/servidor/publica.sh [ip]          # publica servidor.pck em partes de 90 MB (limite do GitHub) na branch servidor-build
# robô jogador (folhas de fotos de cada movimento; filtro e nº de fotos opcionais):
xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/bot.gd -- $SP/ [pulo,facão] [12]
# telas da interface: tools/foto_telas.gd -- saida.png (folha com menu, HUD, pausa, queda)
# foto: xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 -s res://tools/<f>.gd -- saida.png
```
Testes zeram o relógio: `main.ciclo.tempo = 0.0; main.ciclo.set_process(false)` e apagam zumbis que não usam.
Espera de rede em teste = tempo real (`OS.delay_msec(16)`); `process_frame` chega antes do `_process` dos nós (esperar 2).
`exclude_filter` do APK lista os .fbx de zumbi NÃO usados (regerar ao usar animação nova de zumbi).
Ao mudar o que vai pela rede (RPC/sincronia): subir `Rede.VERSAO`.

## Arquivos (scripts/)
- `main.gd` — pista de teste (blocos, rampas, túnel, prédio, casinha com `Porta_0`, carro), bonecos de treino, itens
  (`Item_0..3` munição, `Item_casa`, `Item_comida_k`/`Item_agua_k`), `PONTOS_ZUMBI`, `PONTOS_TOCAIA`, `PATRULHAS`, `PONTOS_CHEFE`, spawners
  (jogadores e zumbis), malha de navegação (grupo "cenario", raio 0.35), `iniciar_solo/criar_partida/entrar_partida/iniciar_servidor`.
- `bairro.gd` (Bairro) — SÃO JORGE (31/10, mapa definitivo; dono: "cidade completamente diferente, pra sempre"):
  `tools/mapa/cidade_v2.py` gera `assets/mapa/cidade.json` (ruas à mão + lotes por regra; usa `tools/mapa/medidas.json`
  de `tools/mapa/mede_ruinas.gd`). Cidade de interior brasileira: Praça da Matriz (coreto, árvores, banca, orelhão) com a
  Igreja; sobrados de comércio com letreiro (FARMÁCIA, PADARIA...) e prédios de apartamento no centro; quarteirão em
  ruínas (loja_r1/r2, predio_r1: telhados com tábua); Morro do Urubu (favela de barracos, subida reta = linha do
  test_relevo, antena no topo); casas com muro e portão; Escola + campinho; zona industrial; rio com 3 pontes; além do
  rio cemitério com capela, posto, helicóptero; quarentena; pórticos "BEM-VINDOS A SÃO JORGE"; capital destruída ao norte (o sul
  do muro é a pista de teste; Majadroid, só vista). Raids (`RAIDS`): Delegacia (policiais), Hospital, Supermercado, Igreja
  (`_monta_raid(no, titulo, tipo)`; `pontos_raid[].tipo`). Prédio com modelo: `predios[].modelo/c/frente` ->
  `_poe_modelo` (nome Casa_k / Mansao_k / Predio_k para os "fechados" = só fachada, marca "fechado"). No morro o lote sobe
  (`no.position.y`, alicerce do barraco). `planta.gd` (Planta.monta): `areas` (praça, estacionamento, terra), `faixas`
  (zebra), `muros` (malha junta + caixas de colisão, grade, pedaço caído), `props` (MultiMesh por modelo/pedaço:
  árvores, túmulos, coreto, ponto de ônibus, orelhão, banca, pórtico), `postes` (concreto, fiação em linhas; Enfeites
  não põe os de madeira: `postes_da_planta`), `veiculos`, `zumbis`, `longe`. Modelos novos: `tools/blender/cidade.py`
  (importa ruinas.py; letreiro/pichação em 3D, interior com reboco pintado, azulejo e cerâmica `por_dentro`).
  CELULAR (31/10): ruas/praça/muros em malhas juntas por material e pedaço de 125 m (`_faixa` segue o morro,
  `_junta_quad`, `_fecha_juntas`); ruinas.py `agrupa` junta cada prédio em ext/longe/detalhe/dentro (móveis soltos);
  `_junta_longe` junta ext+longe de todos os prédios por pedaço; `_alcance` e `_alcance_coisas` (baú, item, gaveta,
  porta, hidrante, carro somem de longe). Medir: tools/foto_cidade.gd -- saida.png [vistas] [qualidade] [sombras]
  (imprime chamadas de desenho). Centro na qualidade Média: ~1300 (a cidade velha tinha ~2100).
  ORIGEM (0,0,-300), TAMANHO 500 (muro do exército na borda, `_borda`).
  `_fresta` (muros + Area3D grupo "frestas") -> `Jogador._acha_fresta/_entra_fresta/_esgueira/sai_fresta` (de lado,
  raio ESGUEIRA_RAIO, analógico x; câmera presa de frente para a parede; Maos some). Teste: test_fresta (7).
  `_bloqueio` (ônibus tombado ou carros), `_veiculo`, `_pinta` (materiais do Blender -> texturas).
  Relevo (31/10): `terreno` no JSON (rio raso + morro no lugar mais vazio); `_terreno` (HeightMapShape3D de 1 m,
  `altura(p)`, `_malha_chao` de 3 m, `_agua`), `_pontes` (depois das ruas), AGUA_Y: jogador/zumbi lentos no rio.
  Teste: test_relevo (5). Foto: tools/foto_relevo.gd.
  Telhados (31/10): escada de incêndio no fundo de loja_r1/loja_r2/predio_r1 (`escada_incendio` no Blender, abre a mureta
  onde chega), `_tabuas_telhado` (TETO_MURETA; tábua entre tetos da mesma altura, vão até 8 m). Teste: test_telhado (3). Cada lote recebe
  uma RUÍNA modelada no Blender (30/10, pedido do dono): `tools/blender/ruinas.py` gera `assets/ruinas/*.glb`
  (casa_r1..r6: telhado caído, queimada, 2 andares com escada; loja_r1/r2: vitrine, gôndolas; predio_r1: canto
  desabado; móveis dentro: `mobilia` com sofá, tapete, TV, quadros, estante, mesa; quarto com cama/criado/guarda-roupa
  ou cozinha com balcão/geladeira/fogão/armário aéreo; `bagunca` (papéis sem colisão + caixas); 31/10: AO mais claro 0.42). Rodar: `~/.local/blender/blender -b -P tools/blender/ruinas.py --
  assets/ruinas` (e cidade.py igual) e depois `$G --headless --path . --import`; foto: `tools/blender/foto_ruinas.py -- assets/ruinas dir`.
  Colisão vem do glb (nome "-col"/"-colonly": sem parede invisível). `_ruina` escolhe pelo nome entre `RUINAS_CASA/
  LOJA/MANSAO` que cabem e não encostam na rua (senão lote vazio; mansão cai na casa em código `_construcao`),
  `_poe_ruina` (Porta no Empty "porta"), `_mat_ruina` (nome do material do Blender -> textura). As 3 maiores casas =
  `Mansao_k` (meta "dominavel", BauFac, Cama, BancadaFac, LojaFac). Texturas Poly Haven CC0 em `assets/texturas`
  (`_mat`, triplanar). Rua: carros (queimados), barricadas (`_barricadas`), árvores secas, hidrantes, barris com fogo.
  API: `pontos_zumbi`, `pontos_nascer`, `casa_em`, `dominavel`, `bau_da`, `frente_da`, `dentro_da`; malha própria em
  `_poe_zumbis` (célula 0.25, raio 0.25 para passar na porta). Nascer (11): `pontos_bons/ruins`, `Bairro.sorteia`,
  `main.ponto_nascer(nick)`. Testes: test_bairro (4), test_nascer (5). Fotos: tools/foto_bairro.gd.
- Raid DELEGACIA (31/10): modelo `delegacia` (Blender, Empties `zumbi_k`/`zumbi_arm_k`/`bau_k`) no lote do centro mais perto do
  meio (`Bairro._monta_raid`: `pontos_raid`, `raids`, `Bau.raid` -> `Loot.sorteia(.., raid)` RAID_RARO, viaturas).
  Zumbi: `armado` (TIRO_*: para, mira `_mira_e_atira`, rpc `_tiro_fx`, pistola na mão `_poe_arma`, chega devagar),
  `de_raid` (MORTO_RAID 15 min), `tipo_pedido`. HUD `_avisa_raid`. `Bairro._espalhados(n, larg)` espalha zumbis/carros/
  barricadas pelo comprimento das ruas. Teste: test_raid (8).
- Dividir o peso (31/10): `Zumbi.pensa` (peer que roda IA/movimento; 1 = servidor), `_pensa_aqui()`, rpc `muda_pensa`
  (troca a autoridade do sincronizador "Sincronia"; vida fica no "SincVida" do servidor), `_sente_golpe` (cambaleio no
  pensador). `main._divide_peso` (servidor, a cada PESO_A_CADA: jogador mais perto a até PESO_RAIO, folga PESO_FOLGA;
  chefe/armado/deitado/mordendo ficam no servidor); peer que sai devolve os zumbis. Jogador aceita dano de zumbi de
  qualquer peer (até 80). Teste: test_rede (parte nova no fim). Rede.VERSAO 31.
- `carro.gd` (Carro; 31/10, prompt 18 parte 1): os `carro_r1` inteiros do Bairro (`_carros`, `monta`) são CharacterBody3D
  (caixa + 4 SeparationRayShape3D de roda, frente +Z). `motorista` (peer; servidor decide em `pede_entrar`/`pede_sair`),
  quem dirige roda `dirige(mov, dt)` e manda `_estado` ao servidor (confere PULO_MAX) -> `pos_rede`/`rot_rede` no
  sincronizador. Jogador: `carro`, `no_carro` (sincronizado: some o boneco), `carro_perto`, `entra_no_carro`,
  `sai_do_carro` (`Carro.saida`: lado livre), `_dirige` (USAR sai). main `_peer_saiu` libera o carro. HUD: ENTRAR/SAIR
  DO CARRO no botão USAR. Falta: lockpick, combustível, atropelar, passageiro. Teste: test_carro (14) + test_rede.
  Rede.VERSAO 32.
- Novato (31/10, teste com agente jogador): 1ª vez nasce sempre em ponto bom (`main._ponto_inicial` -> `ponto_nascer("", 1.0)`),
  `Jogador.olha_pro_aberto` (câmera para o lado mais livre ao nascer), `_cai` zera mordida/agarrão (EMPURRAR ficava
  preso), sinal `golpe_de(dir)` -> controles `_SetaGolpe` (seta vermelha de onde veio o golpe), baú "fique parado".
  Atualização do novato (31/10): `Jogador.NOVATO_T/NOVATO_DANO` (dano x0,6 nos 3 primeiros minutos; testes de dano põem
  `j._jogo_t = Jogador.NOVATO_T`), morte guarda a arma da mão (`_larga_tudo`, sem as balas do pente), `dinheiro` salvo
  no Progresso, abates seguidos (`sequencia`, XP_SEQUENCIA) e soltar da mordida (XP_SOLTOU) dão XP, trocar arma cancela
  o golpe, relógio "NOITE EM / AMANHECE EM". Bairro: `_classifica` tira pontos de nascer perto do Arame (machucava ao
  nascer), `_mais_carros_e_achados` (rng próprio: CARROS_EXTRA carros dirigíveis "CarroExtra_k" + ACHADOS itens
  "Achado_k" nas ruas). NAV_VERSAO 2, Rede.VERSAO 33.
- Revistar (31/10, 0.83): `gaveta.gd` (Gaveta: MOVEIS pelo nome da malha do Blender, `revista_por` no servidor sorteia
  Loot fácil ou "vazio", `chave`, `aberta` sincronizado, REENCHE). Bairro `_gavetas_e_cofres` (rng próprio): Gaveta em
  cada móvel, COFRES `Bau.cofre/trava/gaveta_chave` (loot de raid; tranca de novo ao reencher) + bilhete com rumo e
  metros (`_rumo`). Jogador: `gaveta_perto`, `_pede_gaveta`, `_pede_destrancar`, item "chave"; `_recebe("vazio")`.
  Sala segura: refúgio (Sobreviventes) com lampião (OmniLight); `Jogador.segura` (`_passa_segura`, todos os aparelhos,
  CURA_SEGURA), Zumbi ignora/desiste de `segura`. controles: folha de papel `_mostra_papel` (bilhete), avisos
  vazio/trancado/destrancou/sala segura. Teste: test_gavetas (15). Rede.VERSAO 35.
- Zumbis com jeitos (31/10, 0.84): `Zumbi.VARIANTES` (parado/andar/correr fixos por nome; ataque/dano sorteados), `_real`
  (lógico -> animação; o lógico vai pela rede), `_passo` (ritmo próprio), RASTEJANTE (tipo "zumbi_rastejante": colisor
  baixo, rastejar/rastejar_rapido, `altura_cabeca` 0.45), `come` + `_comendo()` (ajoelhado no corpo `_poe_corpo`, ouve
  COMENDO_PERCEBE e vê COMENDO_VE), queda (`_derruba` rpc no pensador: QUEDA_DANO/CHANCE, NO_CHAO_T, QUEDA_MAIS),
  cabeça torta + espasmos (`_monta_torto`, anim em modo manual avançada em `_process`; SkeletonModifier3D não roda na
  4.7). Clipes novos em Anims.CLIPES_ZUMBI (tirados do exclude_filter do APK). Carro: `dispara_alarme` (tiro da
  Pistola acerta Carro -> rpc `_toca_alarme`, `assets/sons/alarme.wav` feito aqui, Zumbi.barulho ALARME_RAIO).
  Teste: test_zumbi_jeitos (13). Rede.VERSAO 36.
- Vídeo do dono (31/10, 0.85): desempenho `Zumbi._process` (anima de 3 em 3 quadros longe/atrás, de 8 em 8 além de
  ANIMA_LONGE e some além; anim em modo manual em todo cliente). Equilíbrio: DANO 20, CORRER 3.7, OUVE 6.5, NOITE_* menores,
  Pistola.BARULHO 20, GRITO_RAIO 14, GRITO_CHANCE (senão `_rosna` rpc), ALTURA_ATAQUE (não bate de baixo no telhado).
  Noite mais clara (Ciclo). Carro: câmera de 3ª pessoa (`CameraPrimeira._atras_do_carro`, volta atrás do carro após
  1,2 s sem olhar), `Carro.volante` suave e GIRO_ALTA. Casas: `mobilia(w, d, paredes)` por cômodo com tema sorteado
  (`comodo`: sala/cozinha/quarto/crianca/banheiro/escritorio/despensa; `ao_longo` de costas para a parede; nomes
  "<movel>_<comodo><k>": Gaveta acha pelo começo do nome), casa_r7..r14 (r13/r14 pequenas), cores TECIDOS no Bairro.
  Marcos novos (cidade.json): antena (já marcada), helicoptero, quarentena, posto (Blender), com
  `BauMarco_*` (loot raro) e 4 pontos de zumbi em volta; marco na altura do terreno. Enfeites: sem mato dentro de lote.
  Rede.VERSAO 37. Paredes invisíveis do vídeo: NÃO achadas (perguntar onde).
- Móveis realistas (31/10, 0.86): `moveis.gd` (Moveis.troca(casa) no `Bairro._gavetas_e_cofres`): cada caixa de móvel
  do Blender some e entra um modelo Poly Haven CC0 (`assets/moveis/<nome>/<nome>.gltf`, texturas size_limit 512 VRAM)
  pelo pedaço do nome (TROCA), cabendo no chão da caixa; colisão continua a da caixa; micro-ondas no balcão, lampião no
  criado; `visibility_range_end` LONGE, sem sombra. Gaveta `sem_caixa` (esconde a gavetinha). Quadros saíram (caíam na
  janela). Nick do jogador vai sempre pela rede. Rede.VERSAO 38. Próximo: paredes por dentro (papel de parede, lambri,
  azulejo), janelas com vidro/moldura, luz de abajur.
- Casa de verdade (31/10, 0.87; dono: "casa tem cômodo"): `casa_real` em tools/blender/ruinas.py (casa_r1..r3, r5, r7..r14;
  r4/r6 seguem queimadas): planta coluna A (sala/cozinha) | corredor | coluna B (quarto, banheiro, quarto), passagens
  sem porta com `batente`, `revestimento` por cômodo (lambri/azulejo embaixo + papel em cima, com as aberturas da parede:
  `aberturas_em`), piso por cômodo (piso_tabua/piso_ladrilho), forro, fachada sorteada (fachada_*), `janela_real`
  (moldura, peitoril, vidro inteiro/caco/sem, cortina), varanda com colunas, telhado de telha; móveis `comodo_real`.
  Texturas Poly Haven CC0 novas em assets/texturas (papel_1..3, lambri, piso_*, azulejo, forro, fachada_*; 512 px) e
  `Bairro._mat_ruina` para cada nome (+ `_vidro`). Céu: Ciclo CEU_* cinza-azulado (saiu o laranja), CEU com fumaça
  cinza e sol mais nítido, névoa menor. Tela: `tarefas.gd` (Tarefas: ROTEIRO de aprendizado + DEPOIS sorteadas, XP;
  eventos item_pego/revistou/abateu/entrou_segura/bilhete/amanheceu/marco via `Bairro.marcos_pos`), barra de vida verde
  com número (`_Barra.texto`). Arma `taco_pregos` (Blender, Armas.BRANCAS, pegada diagonal `Maos.POSE`); nas salas já vem
  na mão (`main.arma_inicial`); testes seguem com o facão.
- MODO CONSTRUÇÃO (31/10, 0.88; dono: "quero montar meu mapa"): catálogo `assets/catalogo/catalogo.json` (~2100 peças;
  Kenney CC0 17 kits, Poly Haven CC0 164, Majadroid CC0 ruínas, Atomic Realm grátis com crédito (FORA do git:
  tools/catalogo/baixa_atomic.sh), mais ruínas/móveis/sketchfab do jogo e "jogo:*"); refazer: gera_lista.py -> mede.gd ->
  junta.py (ESCALA por kit da Kenney). `mapa_custom.gd` (MapaCustom: lista/item, carrega/salva user://meu_mapa.json,
  para_texto/de_texto "MAPA1:" gzip+base64, cria (caixa de colisão; ruína usa Bairro._pinta), monta, _liga_jogo:
  nascer/zumbi/bau/bau_raro/sala_segura (grupo "salas_seguras")/carro/fogo/luz). `construcao.gd` (Construcao: câmera
  voando, `_Stick`, catálogo por categoria com busca, fantasma verde na mira, coloca/apaga/desfaz/gira/salva/compartilha/
  cola). main: `construir(continuar, base)`, `jogar_meu_mapa()` (`_nav_forcar`: assa a malha na hora), `_bairro_vazio`
  (`Bairro.vazio`: só chão e borda; zerado no _ready). Menu: MODO CONSTRUÇÃO. project.godot `[importer_defaults]`
  texture 512/VRAM (vale para TODA textura nova importada, inclusive de interface). Teste: test_construcao (16).
- `progresso.gd` (Progresso; 31/10): XP (XP_ZUMBI/RAID/CHEFE no `Zumbi._morre`, XP_NOITE ao amanhecer no `Ciclo`), nível
  (`xp_para`), pontos, `hab` vigor/folego/pontaria/forca (até NIVEL_HAB), salvo em user://progresso_<nick>.cfg. Jogador:
  `prog`, `vida_max()`, `mult_espalho/mult_fogo/mult_forca`, `aprende(h)`; `_recebe("xp")`. Pausa: HABILIDADES
  (`_monta_habs`). HUD: NV e XP no saldo. Teste: test_progresso (9).
- `bichos.gd` (Bichos, filho do main; 31/10; só cliente): bandos de corvos rodando alto (em cima do grupo "fogo_coluna"),
  corvos no chão que voam a ESPANTA m grasnando, papel rolando com VENTO perto do jogador. Teste: test_bichos (4).
- `fogo.gd` (Fogo; 31/10): `tamanho`, `coluna` (fumaça alta, de longe); chama em shader (CHAMA: ruído subindo), luz que
  treme, fumaça/faíscas CPUParticles, crepitar, Area de dano (DANO a cada DANO_A_CADA). Nos barris e em casas queimadas
  (Bairro). Teste: test_fogo (3). Foto: tools/foto_fogo.gd.
- `sobreviventes.gd` (Sobreviventes, filho do Bairro; 31/10): refúgios (N_REFUGIOS casas com `barricada_sobr` do Blender
  na frente + `Arame` que corta/prende), pichações (Label3D nas fachadas, PICHACOES), bilhetes (grupo "bilhetes", meta
  texto; controles `_le_bilhete` mostra na faixa). Teste: test_sobreviventes (5).
- `som_ambiente.gd` (SomAmbiente, filho do main; 31/10): vento (mais forte à noite), sustos ao longe (`_sustos`), passos por
  chão (`_passos`: casa=tábua, rua=concreto, resto=terra), eco no bus 0 só dentro de casa (`_eco`), coração (`_coracao_bate`),
  gemidos/rosnados presos no zumbi (`_gemidos`). Sons CC0 em `assets/sons/amb` (CREDITOS.txt); fogo nos barris (Bairro).
  Teste: test_som (6).
- `enfeites.gd` (Enfeites, filho do Bairro) — cara do jogo (30/10): chão `Enfeites.chao()` (shader grama/terra/cascalho),
  lixo/mato/manchas/sacos de corpo em MultiMesh por pedaço de 64 m (DENSIDADE pela qualidade, some de longe), postes
  com fio (`_postes`/`_fio`, colisão) e caçambas. Ruínas com sombra de canto assada no Blender (`assa_sombra`: cores dos
  vértices; `_mat(..., sombra=true)`). main: filtro de cor, glow e ajuste de saturação SAÍRAM (tela rosa no celular, 31/10); controles: `_filme`
  (bordas escuras, granulado, vermelho pulsando com pouca vida).
- `jogador.gd` (Jogador) — `entrada` dict (move, olhar, pular, correr, agachar, andar, mirar, mira_segurando, atacar,
  trocar, arma, recarregar, pegar, comer, beber). Vida/`levar_dano`/`_cai`/`_caido`, fome/sede (`_passa_fome`),
  itens (`_tenta_pegar`, `ganhar`→`_recebe`), portas (`porta_perto`), pistola (`_atira`, `raio_mira`, `_rede_tiro`),
  facão (`GOLPES`, `_inicia_golpe`, `_acerta`), overlay de braços (`_escolhe_cima`, `_aplica_cima`, `_aponta_tronco`),
  `_toca` (variante `_p` com pistola), lanterna na mão esquerda, `olha_camera`, `mirando_em`, sinais `dano_levado`,
  `item_pego`, `acertou_alvo`. Osso da mão: `MAO`, tronco: `TRONCO` (Mixamo).
- `zumbi.gd` (Zumbi) — servidor decide. Estados: alvo (ver 30 m/ouvir 9 m; 30/10: corre 4,6 m/s, não foge nem desvia, `main.BANDO` por ponto), ataque, cambaleio, grito/horda (22 m),
  ouvir tiro (`Zumbi.barulho`), procurar/voltar, cerco (`_calcula_cerco`), tocaia (`_deita/_acorda`), porta
  (`_porta_na_frente`), ziguezague/fuga, noite (`Ciclo.forca_noite`), patrulha (`rota`), cobertura (`_acha_abrigo`, `_custo_caminho`), chefe (`chefe`, `VIDA_CHEFE`, `DANO_CHEFE`). Camada 8.
- `anims.gd` — `CLIPES` (jogador) e `CLIPES_ZUMBI`: nome lógico → [arquivo, ini, fim]; "kaykit:" (retarget),
  "proprio:" (golpes.gd). `VELOCIDADE*` p/ pés.
- Personagens (Mixamo, mesmo esqueleto do X Bot, fora do git e do Drive: rebaixar pela API, type "Character",
  `assets/mixamo/personagens/`): `Anims.boneco(nome)` (altura igualada ao X Bot; escala *= p/ arquivos em cm),
  `Anims.adaptada(lib, nome)` (animações do X Bot convertidas pro descanso do personagem + quadril na escala dele),
  `Anims.ajuste_osso`, `Anims.JOGADOR` remy (humano; sobrevivente tinha cara de caveira),
  `Anims.ZUMBIS` (policial/mulher/soldado, escolhido pelo nome do nó; 31/10: zumbis realistas do Sketchfab em
  `assets/zumbis/zr_*.glb` (CC BY, CREDITOS.txt), convertidos por `tools/blender/zumbi_sketchfab.py`; `Anims.boneco`
  procura lá primeiro e põe o Skeleton3D direto na raiz; cada zumbi com altura/largura própria pelo nome), `Anims.CHEFE` parasita. Chefe: pancada no
  chão (`_pancada_no_chao`, PANCADA_RAIO/DANO/INTERVALO, rpc `_poeira`). Teste: tests/test_chefe.gd (7).
  Tipos (`Zumbi.TIPOS`, `aplica_tipo`, `tipo_fixo` p/ testes): corredora (rápida, frágil, `bote`), policial (médio,
  `agarrao` → `Jogador.agarrar`/`agarrado_t`), soldado (lento, duro, `blindado`); andar/correr próprios (Anims
  andar_rapido/correr_rapido/andar_lento/correr_lento). Teste: tests/test_tipos.gd (5).
- Escalar: `Jogador._beirada/_escala` (ESCALAR_T, BEIRADA_MIN/MAX), clipe "escalar" (soltas/escalar.fbx, Mixamo
  "Pulling Up To A Ledge", subida tirada do quadril em `Anims._tira_subida`). Teste: test_escalar (3).
  Foto do jogador visto de fora: tools/foto_terceira.gd. Botões: tamanho muda na hora (`_refaz_toque`), TROCAR voltou.
- `retarget.gd` — KayKit→X Bot. `golpes.gd` — golpes do facão feitos à mão (poses-chave).
- `pistola.gd` — arma de fogo: `tipo` (FOGO: pistola/smg) define pente/dano/cadência/dispersão/coice/recarga/automática;
  `modo_auto`, tiro (máscara 1|8), `efeito`, `Pistola.sangue`, `BARULHO`. Jogador: `pistola`, `smg`, `fogo()`, `e_fogo(tipo)`,
  entrada `atirando` (segurando) e `modo` (seletor). Teste: tests/test_auto.gd (13).
- `porta.gd` — camada 16, `alterna_por`, `leva_soco`, conserto 90 s. `item.gd` — tipos municao/lanterna/comida/agua, volta 60 s.
- `ciclo.gd` — dia 480 s/noite 300 s, `noite()` 0..1, `INICIO` provisório (noite em 1:30).
- `controles.gd` — HUD limpo (8b): `_Barra` finas no alto à esquerda, `_saldo`, relógio curto, munição, mira (`_Mira`);
  toque: botões só com ícone (`_Icone`: corte/tiro, mira, pular, agachar; contexto: recarga, pegar, modo), correr =
  analógico no fim; barra rápida discreta (Espaco.discreto). PC: WASD, mouse, E F G Q R B Tab 1–6.
- `lojista.gd` (Lojista: VENDE/PAGA, grupo "lojista"), `tela_loja.gd`. Jogador: `dinheiro`, `abates`, `comprar`, `vender`,
  `lojista_perto`. Zumbi paga a `_ultimo`. Teste: tests/test_loja.gd (8).
- `grupos.gd` (Grupos: de/convites, convidar/responder/sair/passa, `mesmo` p/ futuro PvP, MAX 4). main: `grupos`
  (servidor), `convidar_nick`, `responder_convite`, `sair_grupo`, `_manda_grupos` → `_grupos_cli`, `grupo_de`, `amigos()`.
  controles: `convite(nick)` (ACEITAR/RECUSAR), página GRUPO na pausa, `_Marcas` (nome/seta dos amigos). Teste: test_grupos (12).
  Resgate: `Jogador._cai` no grupo → `resgate`, `RESGATE_T` 90 s, `main.pede_resgate` (servidor confere
  `Grupos.pode_resgate`, `inicia_raid`, `Zumbi.raid`, `_passa_raids` → `Jogador.levanta`/`sem_resgate`, paga).
  `Lojista.valor(itens)`. Teste: tests/test_resgate.gd (9).
- `faccoes.gd` (Faccoes: faccoes/tentativas, comecar/passa/adicionar/dona/faccao_de; MIN_CRIAR 1 (pedido do dono),
  DOMINAR_T 360, REDOMINAR_T 180, LIMITE 10). main: `faccoes`, `pede_dominar`/`pede_adicionar` (rpc), `_passa_dominio`,
  `_manda_faccoes` → `_faccoes_cli`, `faccao_de`. Bairro: `casa_em(pos)`, grupo "casas", meta "tam". controles:
  `_btn_dominar` (bandeira, PC H; só em mansão), `_dominio` (relógio), página FACÇÃO na pausa. Teste: test_faccoes (11).
  Casa (13): cada casa tem `BauFac_k` (`Bau.de_faccao`/`faccao`/`pode`/`guarda_por`; `Jogador.guarda_no_bau`) e `Cama`
  (grupo "camas"; `Jogador._cama` CURA_CAMA). Manutenção: `Faccoes.passa_manutencao` (MANUT_DIAS 7, MANUT_CUSTO 20000,
  AVISO_DIAS 3, fundo via `main.pede_depositar`), `liberar` (main `_libera_casas` ao sair). Renasce em
  `bairro.frente_da(casa)` (`main.ponto_nascer(nick)`). Teste: test_casa_faccao (11).
- `rede.gd` — ENet 7777, broadcast 7778, pergunta direta 7779, `VERSAO`, `LISTA_URL` (servidores.json). Endereço
  "ws://"/"wss://" = WebSocket (servidor online atrás de site; `-- dedicado ws` escuta em `PORTA_WS` 7861).
- `salas.gd` (Salas) — PvP em salas (prompt 23), só dados: criar (código de 4 letras, pública/privada, limite, minutos),
  entrar, sair, comecar (dono, MIN_JOGADORES), vale(a, b), abate, passa (fim -> placar FIM_T -> espera), lista_publica.
  main.gd: `pede_*_sala` (RPC), `pede_dano_pvp` (confere a sala, conta abate, renasce em RENASCE_T por `_pvp_vai`),
  `_recebe_salas` (cópia em todos + `update_visibility`), `minha_sala`, `em_pvp`, `mesma_sala`, `ponto_pvp` (centro,
  RAIO_PVP). Jogador: grupo "golpeavel", `levar_golpe` (só no PvP), `renasce_pvp`, filtro de visibilidade da Sincronia
  (`_visivel_para`: só a mesma sala), tiro só para quem vê. Pistola mira jogadores (camada 4) no PvP. Tela:
  `tela_salas.gd` (pausa: PVP; menu: botão PVP abre direto). HUD: relógio e placar. Testes: test_salas (15),
  test_pvp (2 processos, como test_rede).
- Salas de sobrevivência (prompt 24): quem cria hospeda o mundo; o carteiro online (`relay.gd`, `relay_main.gd`,
  porta 7862, site `/salas`) lista as salas (busca por nome) e repassa pacotes; `relay_peer.gd` (RelayPeer,
  MultiplayerPeerExtension; host = id 1). main: `RELAY_URL`, `abre_relay`, `criar_sala_sobrev`, `entrar_sala_sobrev`,
  `sala_sobrev` {codigo, nome, max, n}, `esperando`/`muda_espera` (zumbis e relógio parados até encher ou COMEÇAR),
  `comecar_sala_sobrev`. controles: tela de espera (`_espera`). menu: página "sobrev" (SOBREVIVÊNCIA); o mundo de
  40 virou MUNDO ABERTO. Teste: test_sala_sobrev (3 processos: relay `-- porta=7899`, host, cliente).
- Infecção e mordida (30/10): `Jogador.infeccao`/`infectado`/`infecta(mais)`, CHANCE_INFECTAR por golpe de zumbi,
  INFECCAO_TEMPO até 100 (mata), `toma_antibiotico` (item "antibiotico", loot raro, loja 400). Mordida no pescoço
  (policial, `Zumbi.chance_mordida`, MORDIDA_T/DANO/ESPERA): `Zumbi._segura_mordida/_resolve_mordida/resultado_mordida`,
  `Jogador.comeca_mordida/_passa_mordida` (marcador `qte_pos`, faixa `qte_faixa`, ACERTOS_SOLTAR, entrada "soltar"),
  `mordido`; câmera `foco`; HUD `_Qte` (EMPURRAR!; PC espaço/E/clique) e barras com %. Céu: shader CEU (sol abafado,
  colunas de fumaça), cores em Ciclo. Teste: test_mordida (8).
- `config.gd` (Config) — `Config.v[...]` salvo em user://config.cfg, `muda()`, `aplica()`, `sensibilidade(arma, mirando)`,
  `cor_mira()`, `qualidade()` (QUALIDADE: Batata/Média/Alta/Ultra -> sombra, resolução, MSAA, distância de visão,
  detalhe). `tela_config.gd` (TelaConfig) — a tela (menu e pausa). Teste: tests/test_config.gd (10).
- `mochila.gd` (Mochila) — dados: 24 espaços (0–5 barra), PILHA/LIMITE/PRESOS/NOMES/TEXTOS, adicionar/tirar/definir/
  dividir/mover/tirar_espaco. Jogador: `mochila`, `comida`/`agua`/`pistola.reserva`/`tem_lanterna` leem dela, `largar(i)`,
  `usar_espaco(i)`; `main.solta_item()` + `spawner_itens` (itens soltos, `Item.solto`). `tela_mochila.gd` (TelaMochila +
  Espaco), `icones.gd` (Icones.de(tipo): modelo 3D renderizado). Teste: tests/test_mochila.gd (16).
- `bau.gd` (Bau) — `conteudo` (sincronizado), `pega_por(j, i)` no servidor, reenche em REENCHE; `loot.gd` (Loot.TABELA,
  `sorteia(rng, facil)`, raridade/cores); `tela_bau.gd`. Jogador: `bau_perto()`, abrir parado (`abrindo`), `pega_do_bau`.
  `main.BAUS` (posições). Teste: tests/test_baus.gd (11). Peças: Loot.PECAS, `Loot.drop(rng, chefe)` (Zumbi._larga_drop
  no servidor ao morrer, some em DROP_SOME). Teste: tests/test_pecas.gd (8).
  Morte: `Jogador._larga_tudo()` → `main.solta_saco()` (Bau com `saco`); `copia_mochila`/`dano_srv_t` no servidor e
  `main.saiu_morrendo(j)`. Teste: tests/test_morte.gd (11).
- `armas.gd` (Armas) — BRANCAS (modelo, ponta, tam, vel, dano[3], alcance, empurra, som), `modelo(tipo)` = pegada na
  origem e ponta em +Z (Maos, mão do corpo, Item). `main.BRANCAS_MAPA`. Teste: tests/test_armas.gd (16).
- `receitas.gd` (Receitas.LISTA, quantas/fabrica), `bancada.gd` (Bancada: pontos, MUDA, muda_de_lugar → main.aviso_todos),
  `tela_bancada.gd`. Jogador: `receitas`, `comeca_fabricar(arma, n)`, `bancada_perto()`. Teste: tests/test_receitas.gd (13).
- `ui_tema.gd` (UiTema) — visual único: `tema()`, `botao()`, `rotulo()`, `campo()`, `painel_central()`, cores.
- Carregamento (31/10): `carregando.gd` (Carregando: capa `assets/ui/capa.jpg` de tools/foto_capa.gd, linha, DICAS); main
  `mostra_carregando()` ao criar (antes de montar o mundo) e entrar; some quando o jogador local nasce. Sala começa na hora
  (sem espera). Malha de navegação PRONTA: `assets/mapa/nav_pista.res`/`nav_bairro.res` (main `_assa`, chave = md5 do
  mapa + ruínas + NAV_VERSAO; muda a cidade/ruínas -> `$G --headless --path . -s res://tools/assa_navegacao.gd -- salva_nav`).
  Carteiro (`relay.gd`) NÃO compara a versão com a dele: só quem entra vs quem criou (não precisa republicar a cada versão).
- `menu.gd` — páginas (`_mostra`): inicio (nome, CRIAR SALA, ENTRAR NUMA SALA, CONFIGURAÇÕES), criar, entrar (código,
  busca, lista), config. PvP, mundo aberto, Wi-Fi e sozinho saíram do menu (pedido do dono, 30/10; o código ficou).
  UiTema: cantos redondos, `painel_central` rola (ScrollContainer até 90% da altura), `UiTema.pagina(col)`,
  `duas_colunas`, `secao`. Fotos das telas em 20:9: foto_telas.gd com `--resolution 2000x900`. `controles.gd` também tem
  `aviso(texto)` (faixa no alto), `pausa(bool)` (Esc / botão II) e a tela de queda com contagem.
- `camera_primeira.gd` (CameraPrimeira) — primeira pessoa: olhos 1,62/1,05 m, `virar/coice/tremer`, `cam`, `maos`.
- `maos.gd` (Maos) — arma na tela: pistola = pacote `assets/sketchfab/fps/pistola_fp.glb` (olho em OLHO_PISTOLA,
  animação pelo estado do jogador); facão = sketchfab/facao.glb girando em volta de OMBRO pelos CORTES (código). `boneco_treino.gd`.
- tools/: `servidor/site/` (Dockerfile + nginx + start.sh: servidor online num serviço de site, porta $PORT, /jogo = WebSocket, /salas = carteiro; o site agora roda SÓ o carteiro (relay_main.gd), sem mundo; mudou o site: deploy pela API do Render), `foto.gd`, `baixa_mixamo.sh` (rebaixa assets/mixamo do Drive), `servidor/instalar.sh` + `publica.sh`.

## Mixamo (logado)
Sessão: `/root/.mixamo_sessao/estado.json` (fora do git; conta separada do dono). Token = localStorage `access_token`.
API: `GET https://www.mixamo.com/api/v1/products?page=1&limit=N&type=Motion%2CMotionPack&query=X` com headers
`Authorization: Bearer $TOK`, `X-Api-Key: mixamo2`. Se expirar: `tools/mixamo_login.js` (pede código por e-mail ao dono;
senha nunca em arquivo). Baixados vão para `assets/mixamo/` (não commitar).
Baixar um clipe: GET `/api/v1/characters/primary` (X Bot) → GET `/api/v1/products/<id>?similar=0&character_id=<ch>`
(`details.gms_hash`, params viram "a,b,c") → POST `/api/v1/animations/export` {character_id, gms_hash:[...],
preferences:{format:"fbx7_2019",skin:"false",fps:"30",reducekf:"0"}, product_name, type:"Motion"} → GET
`/api/v1/characters/<ch>/monitor` até "completed" → `job_result` é a URL. Baixados assim (não estão no Drive):
`soltas/pegar_chao.fbx` (Unarmed Grab Torch From Floor).

## CGTrader (logado)
Sessão: `/root/.cgtrader_sessao/estado.json` (login por código de e-mail; conta separada do dono). Scripts lá:
`busca2.js <palavra>` (lista grátis), `info.js <url>` (licença/polígonos), `direto.js <item_id> <arquivo>` + curl do
`url.txt` (baixar). Licença Royalty Free: arquivos em `assets/cgtrader/` (fora do git), créditos em LICENCAS.txt.

## Pendências do dono
Servidor online: Render grátis, serviço srv-dbhp57egekts73bs6j5g (chave em /root/.render/chave, API api.render.com/v1),
https://zumbi-servidor.onrender.com (status.json), wss://.../jogo. Env MAX=8. Deploy: POST /v1/services/<id>/deploys.
Publicar pacote: `publica.sh wss://zumbi-servidor.onrender.com/jogo` (o servidor troca sozinho em ~2 min).
Carga: vários `tools/carga.gd -- wss://.../jogo 120` em paralelo + ler status.json. Loop: ideias/zumbi-apocalipse/PROMPTS.md.
Teste local WS: `-- dedicado ws` + test_dedicado `-- ws://127.0.0.1:7861`.
Capacidade (medida 30/10, servidor preso a 1 núcleo: `taskset -c 0 ... -- dedicado ws status=$SP/st.json` + N `carga.gd`
em `taskset -c 1-3`): 14 jogadores ≈ 10 ms/quadro de 33 ms → ~40 por núcleo; memória 217 MB (servidor usa X Bot sem
textura: `Anims.boneco` com `servidor_sem_tela`). Zumbi longe (DORME_DIST 60 m) e quieto dorme (`Zumbi._quieto`).
Render grátis = 0,1 núcleo (~8 jogadores), 512 MB: servidor com a cidade de 0.58 = 315 MB (texturas dos modelos
importadas VRAM 512 px; escaneados fechados com caixa; servidor sem tela pula janelas; `Bairro._cubo` dividido).
Medir: rodar `-- dedicado ws` com --path e ler o RSS depois de 35 s. Próximo passo: Oracle Cloud grátis (4 núcleos ARM, 24 GB) com vários servidores.
