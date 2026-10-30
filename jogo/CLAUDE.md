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
- `bairro.gd` (Bairro) — cidade real do OpenStreetMap (centro de Monroeville, AL; `assets/mapa/monroeville.json`, gerado
  por `tools/mapa/osm_para_json.py` do XML da API OSM 0.6; ORIGEM (0,0,-300), TAMANHO 500: termina em z -50, longe da pista). Prédio = paredes pelo contorno
  real, porta no lado da rua (`Porta_<nome>` em 2 de 3), janelas com moldura e vidro (1/4 quebradas, 1/3 com tábuas),
  parede interna com vão (`_divisoria`, área > 90 m²), forro/laje vistos de baixo, telhado de 4 águas nas casas. `_eh_casa`:
  "house" ou "yes" < 260 m²; o resto é loja (prateleiras). As 3 maiores casas = `Mansao_k` (meta "dominavel", BauFac, Cama,
  BancadaFac, LojaFac). Texturas Poly Haven CC0 em `assets/texturas` (`_mat`, triplanar). Rua: carros (queimados),
  barricadas do exército (`_barricadas`), árvores secas, hidrantes, barris com fogo. Detalhe pequeno some a LONGE_DETALHE.
  API: `pontos_zumbi`, `pontos_nascer`, `casa_em`, `dominavel`, `bau_da`, `frente_da`, `dentro_da`; malha própria em
  `_poe_zumbis` (célula 0.25, raio 0.25 para passar na porta). Nascer (11): `pontos_bons/ruins`, `Bairro.sorteia`,
  `main.ponto_nascer(nick)`. Testes: test_bairro (4), test_nascer (5). Fotos: tools/foto_bairro.gd.
- `jogador.gd` (Jogador) — `entrada` dict (move, olhar, pular, correr, agachar, andar, mirar, mira_segurando, atacar,
  trocar, arma, recarregar, pegar, comer, beber). Vida/`levar_dano`/`_cai`/`_caido`, fome/sede (`_passa_fome`),
  itens (`_tenta_pegar`, `ganhar`→`_recebe`), portas (`porta_perto`), pistola (`_atira`, `raio_mira`, `_rede_tiro`),
  facão (`GOLPES`, `_inicia_golpe`, `_acerta`), overlay de braços (`_escolhe_cima`, `_aplica_cima`, `_aponta_tronco`),
  `_toca` (variante `_p` com pistola), lanterna na mão esquerda, `olha_camera`, `mirando_em`, sinais `dano_levado`,
  `item_pego`, `acertou_alvo`. Osso da mão: `MAO`, tronco: `TRONCO` (Mixamo).
- `zumbi.gd` (Zumbi) — servidor decide. Estados: alvo (ver 18 m/ouvir 5 m), ataque, cambaleio, grito/horda (22 m),
  ouvir tiro (`Zumbi.barulho`), procurar/voltar, cerco (`_calcula_cerco`), tocaia (`_deita/_acorda`), porta
  (`_porta_na_frente`), ziguezague/fuga, noite (`Ciclo.forca_noite`), patrulha (`rota`), cobertura (`_acha_abrigo`, `_custo_caminho`), chefe (`chefe`, `VIDA_CHEFE`, `DANO_CHEFE`). Camada 8.
- `anims.gd` — `CLIPES` (jogador) e `CLIPES_ZUMBI`: nome lógico → [arquivo, ini, fim]; "kaykit:" (retarget),
  "proprio:" (golpes.gd). `VELOCIDADE*` p/ pés.
- Personagens (Mixamo, mesmo esqueleto do X Bot, fora do git e do Drive: rebaixar pela API, type "Character",
  `assets/mixamo/personagens/`): `Anims.boneco(nome)` (altura igualada ao X Bot; escala *= p/ arquivos em cm),
  `Anims.adaptada(lib, nome)` (animações do X Bot convertidas pro descanso do personagem + quadril na escala dele),
  `Anims.ajuste_osso`, `Anims.JOGADOR` remy (humano; sobrevivente tinha cara de caveira),
  `Anims.ZUMBIS` (policial/mulher/soldado, escolhido pelo nome do nó), `Anims.CHEFE` parasita. Chefe: pancada no
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
- `config.gd` (Config) — `Config.v[...]` salvo em user://config.cfg, `muda()`, `aplica()`, `sensibilidade(arma, mirando)`,
  `cor_mira()`. `tela_config.gd` (TelaConfig) — a tela (menu e pausa). Teste: tests/test_config.gd (8).
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
- `menu.gd` — páginas (`_mostra`): inicio, online (acorda o servidor), wifi, config. `controles.gd` também tem
  `aviso(texto)` (faixa no alto), `pausa(bool)` (Esc / botão II) e a tela de queda com contagem.
- `camera_primeira.gd` (CameraPrimeira) — primeira pessoa: olhos 1,62/1,05 m, `virar/coice/tremer`, `cam`, `maos`.
- `maos.gd` (Maos) — arma na tela: pistola = pacote `assets/sketchfab/fps/pistola_fp.glb` (olho em OLHO_PISTOLA,
  animação pelo estado do jogador); facão = sketchfab/facao.glb girando em volta de OMBRO pelos CORTES (código). `boneco_treino.gd`.
- tools/: `servidor/site/` (Dockerfile + nginx + start.sh: servidor online num serviço de site, porta $PORT, /jogo = WebSocket), `foto.gd`, `baixa_mixamo.sh` (rebaixa assets/mixamo do Drive), `servidor/instalar.sh` + `publica.sh`.

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
Render grátis = 0,1 núcleo (~8 jogadores). Próximo passo: Oracle Cloud grátis (4 núcleos ARM, 24 GB) com vários servidores.
