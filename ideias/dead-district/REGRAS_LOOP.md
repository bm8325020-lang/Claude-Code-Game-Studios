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
   seção da operação fecha: ícone do app, tela inicial, créditos, sem erro no export, AAB para a loja (a assinatura de
   loja é do dono: pedir a chave dele, nunca inventar).

## Segurança (sempre)
Nunca commitar export_presets.cfg, assets/mixamo/, chaves. Commit com o trailer da sessão. Não passar segredo no chat.
Disco cheio: apagar só sobras próprias (APK já enviado, temporários de exportação).
