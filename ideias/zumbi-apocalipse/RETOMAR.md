# Retomar o jogo de zumbi (nova conversa)

Leia nesta ordem: este arquivo, `jogo/CLAUDE.md` (mapa do código e comandos) e `ideias/zumbi-apocalipse/PROMPTS.md`
(plano e status por prompt). Branch: `zumbi-apocalipse` do repositório `bm8325020-lang/Claude-Code-Game-Studios`.

## Como o dono trabalha
- Não técnico, joga no celular Android, fala pt-BR. Respostas curtas. Economizar crédito: sem agentes, poucas fotos,
  testes curtos. Nada com cara de IA. A cada passo: testes, commit + push, APK assinado mandado para ele.
- Nunca commitar: `jogo/export_presets.cfg`, chaves, `jogo/assets/mixamo/`, `jogo/assets/cgtrader/`. Sem PR.

## Estado (APK 0.76, 31/10)
- Salas de sobrevivência pelo carteiro online (Render). O carteiro só compara a versão de quem entra com a de quem criou
  (não precisa republicar a cada versão; republicar: `GODOT=$G bash tools/servidor/publica.sh wss://zumbi-servidor.onrender.com/jogo`,
  precisa de aprovação do dono). Sala começa na hora, com tela de carregamento.
- Feito em 30–31/10 (ver jogo/CLAUDE.md): cidade nossa com ruínas do Blender, rio/pontes/morro, telhados ligados, frestas,
  delegacia (raid), zumbis realistas e difíceis, som, fogo, corvos, sobreviventes/bilhetes, progressão (livro de
  habilidades na mochila), dividir o peso dos zumbis entre celulares. Pausa só com CONFIGURAÇÕES; botão FACÇÃO na tela.
- Tela rosa no celular: tirado filtro de cor/glow na 0.76 (confirmar com o dono).

## Próximo (pedido do dono, 31/10)
1. (feito 31/10, APK 0.77) Carro simples: entrar/dirigir/sair, sincronizado na rede, controle de celular.
2. Lockpick (outra conversa); depois combustível, atropelar zumbi, passageiro.
3. Rumo à nota 10 (agente jogador, 31/10; dono: tudo no MODO SOBREVIVÊNCIA, modo história depois). Feito na 0.83:
   (0.84: zumbis com jeitos próprios, rastejante, comendo corpo, queda com golpe forte, cabeça torta/espasmos,
   alarme de carro.) gavetas/armários para revistar, bilhete em folha na tela, cofres trancados com chave + bilhete com a pista,
   sala segura nos refúgios. Falta (ordem do agente): começo que ensina fazendo; objetivo/marcador na tela;
   combate com peso (chute, zumbi cai, som com direção); inventário apertado; atalhos destrancados; reviver amigo;
   chefe e mais tipos; noite que pede lanterna; polimento do toque ("Jogar sozinho" volta? perguntar ao dono).
   Mapa: marcos de longe (torre de rádio, igreja, viaduto caído, prédio em chamas), bairros com cara própria,
   prédios grandes (hospital, escola, mercado) com andares e chave, interiores que contam história, céu/luz por
   hora do dia, CLIMA (chuva, neblina, trovão), caminhos alternativos (telhado, esgoto), sons do lugar (alarme,
   cachorro, porta batendo, rádio), ruas que guiam, perigo maior longe da sala segura com loot melhor.
- 31/10 (0.89): MAPA DEFINITIVO "São Jorge" (tools/mapa/cidade_v2.py + tools/blender/cidade.py + scripts/planta.gd):
   praça/igreja, sobrados com letreiro, favela no morro, hospital/mercado/igreja como raid, casas com muro, cemitério,
   capital ao longe; interiores com reboco pintado, azulejo e cerâmica; malhas juntas (celular: ~1300 chamadas de
   desenho no centro contra ~2100 da cidade velha). Próximo: dono jogar e dizer o que mudar (é ESTE mapa pra sempre).
- Sem convite pelo nome (não há nome fixo). GASTAR POUCO: sem loop, sem fotos, só testes do que mudou, APK só no fim.

## O que NÃO está no repositório (refazer na sessão nova se precisar)
- Godot 4.7.2 em `/home/user/.local/godot/`, Android build-tools e o keystore de debug
  (keystore novo = assinatura diferente: o dono tem que desinstalar o APK antigo antes).
- Personagens/animações do Mixamo (`jogo/assets/mixamo/`, fora do git): `tools/baixa_mixamo.sh` rebaixa do Drive.
- Chaves (pedir de novo ao dono, nunca guardar em arquivo do repositório): API do Render, token do Sketchfab,
  sessões do Mixamo e CGTrader. Serviço Render: srv-dbhp57egekts73bs6j5g (zumbi-servidor.onrender.com).
