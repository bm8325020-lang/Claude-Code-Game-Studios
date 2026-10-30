# Retomar o jogo de zumbi (nova conversa)

Leia nesta ordem: este arquivo, `jogo/CLAUDE.md` (mapa do código e comandos) e `ideias/zumbi-apocalipse/PROMPTS.md`
(plano e status por prompt). Branch: `zumbi-apocalipse` do repositório `bm8325020-lang/Claude-Code-Game-Studios`.

## Como o dono trabalha
- Não técnico, joga no celular Android, fala pt-BR. Respostas curtas. Economizar crédito: sem agentes, poucas fotos,
  testes curtos. Nada com cara de IA. A cada passo: testes, commit + push, APK assinado mandado para ele.
- Nunca commitar: `jogo/export_presets.cfg`, chaves, `jogo/assets/mixamo/`, `jogo/assets/cgtrader/`. Sem PR.

## Estado (APK 0.60, 30/10)
- Só modo **sobrevivência em salas**: menu = nome, CRIAR SALA, ENTRAR NUMA SALA, CONFIGURAÇÕES.
  Quem cria hospeda o mundo no celular; o servidor online (Render) roda só o **carteiro** (`scripts/relay.gd`,
  rota `/salas`) que lista as salas e repassa as mensagens. PvP e "mundo aberto" saíram do menu (código ficou).
- Cidade real do OpenStreetMap (Monroeville, AL), casas de modelo com cômodos, construções escaneadas, céu de fim do
  mundo. Memória cortada (servidor 1,2 GB -> 315 MB; APK 197 MB); a 0.58+ abre no celular do dono.
- Infecção (barra, antibiótico) e mordida no pescoço com briga no tempo certo (EMPURRAR!). Barras com %.
- Qualidade gráfica Batata/Média/Alta/Ultra nas configurações.

## Próximos passos pedidos pelo dono
1. Dividir o peso do mundo com quem entra na sala (cada celular cuida dos zumbis perto dele).
2. Sobrevivência muito difícil + sistema de progressão.
3. Raids de zumbi: delegacia (zumbis com arma de fogo e arma branca), bunker cheio de loot e zumbi.
4. Facções continuam, mas sem invasão de jogador (só zumbi).
5. Depois: PvP de novo como sala criada por jogador; modo história cooperativo (até 4).

## O que NÃO está no repositório (refazer na sessão nova se precisar)
- Godot 4.7.2 em `/home/user/.local/godot/`, Android build-tools e o keystore de debug
  (keystore novo = assinatura diferente: o dono tem que desinstalar o APK antigo antes).
- Personagens/animações do Mixamo (`jogo/assets/mixamo/`, fora do git): `tools/baixa_mixamo.sh` rebaixa do Drive.
- Chaves (pedir de novo ao dono, nunca guardar em arquivo do repositório): API do Render, token do Sketchfab,
  sessões do Mixamo e CGTrader. Serviço Render: srv-dbhp57egekts73bs6j5g (zumbi-servidor.onrender.com).
