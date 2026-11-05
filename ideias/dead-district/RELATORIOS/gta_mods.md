# Mods de zumbi do GTA V: código aberto desmontado (05/11)

Pedido do dono: "procura um mod de zumbi de GTA V público, desmonta o código inteiro... sistema, casas, comportamento
de zumbi, tudo que der pra pegar". Só código publicado no GitHub. Nada copiado: só ideias e números.

| Mod | Tipo | Licença | Linhas lidas | Observação |
|---|---|---|---|---|
| McThizzin/GTAZ-ZombieMod | GTA V, C# (SHVDN3) | MIT | ~13 mil + 12 docs | o mais completo; documenta 59 lições de playtest |
| ParisRP/GTAV-Simple-Zombies.NET | GTA V, C# | sem licença | ~6,9 mil | é o Simple Zombies (sollaholla) **descompilado e publicado por terceiro**: só lemos as ideias |
| n0yzcl/fivem-zsr | FiveM (GTA V online), Lua | sem licença | ~9 mil | servidor de sobrevivência com saque e missões |
| Dislaik/zombieoutbreak | FiveM, Lua | GPL-3.0 | ~4,9 mil | infecção, inventário, ambiente |
| Nacorpio/GTA-Z | GTA V, C# | sem licença | ~3 mil | inventário, carro abandonado com porta-malas/capô |
| tymelx/GTAV-Zombies | GTA V, C# | sem licença | ~500 | modo zumbi simples |
| ABUGIZA/COREX-Framework | FiveM | MIT | só README | sem código no clone leve |

Fonte com arquivo:linha: `FONTES/gta_mods.txt`.

## 1. Comportamento do zumbi

**Percepção (os 4 mods fazem parecido) — FATO**
- Ver = distância + linha de visão livre (GTAZ: andador 40 m, corredor 60 m; Simple Zombies 35 m).
  GTAZ tem cone de 120 graus escrito, mas usa a checagem sem cone.
- Ouvir = só distância (GTAZ: andador 25 m, corredor 40 m; o jogador conta em dobro).
- **O barulho depende do que o jogador faz:**
  - zombieoutbreak: base 20 m; atirando +100; correndo +20; de carro +60; helicóptero/avião +100.
  - Simple Zombies: percebe quem corre a até 25 m, quem atira sem silenciador, ou quem chega a 5 m por trás.
    Com silenciador só ouve a até 15 m.
  - fivem-zsr: visão curta (10 m), audição enorme (1000 m) = zumbi guiado pelo som.
- Grunhido de alerta uma vez quando acha o alvo (zombieoutbreak); som ambiente a cada ~10 s, 40% de chance, até 45 m (GTAZ).

**Tipos — FATO**
- Andador / corredor / chefe ou "superzumbi" em todos. Velocidade (multiplicador do GTA): andador 0.8, corredor 1.8,
  líder de horda 1.3 (GTAZ). Superzumbi (fivem-zsr): vida 1000 + colete, dano corpo a corpo x4, visual "atropelado".
- **Corredor depende da hora:** Simple Zombies 5,5% de dia, 40-50% à noite (20h-3h). GTAZ 40% à noite, 15% nas hordas.
- Vida e dano: zombieoutbreak 300/10, tiro na cabeça mata na hora, tiro não derruba; GTAZ 100/10; Simple Zombies dano 15.

**Máquina de estados (GTAZ) — FATO**
- Parado -> Vagando -> Perseguindo -> Atacando -> Fugindo.
- **Cada tipo pensa num ritmo:** corredor a cada 3 quadros, líder 5, andador 6 (economiza CPU).
- **Destrava:** se a velocidade fica < 0,5 m/s por ~30 ciclos perseguindo, manda a ordem de novo
  (o motor às vezes apaga a tarefa e o zumbi fica parado).
- **Histerese no ataque:** entra no ataque a 1,8-2,8 m, só sai a +1 m; pausa de 0,5 s entre golpes.
  Sem isso o zumbi tremia na borda.
- Bloqueado de usar escada de mão (duas travas). Zumbi caído na água volta para a margem.

**Infecção (Simple Zombies) — FATO**
- NPC morto por zumbi com menos de 1/4 da vida **levanta zumbi**. O jogador não vira.

## 2. Quantidade, nascimento e hordas

**Orçamento (GTAZ) — FATO, a melhor ideia de desempenho**
- 120 vagas de personagem no total; a vaga é reservada **antes** de criar. Lotado: tira o de menor prioridade
  ou mais longe. Recalcula a prioridade por faixas de distância a cada quadro.
- Fila de nascimento: 3 por vez, pedido expira em 8 s, prioridade sobe com a espera.
- Ambiente: grupos de 2-4, alvo 80 zumbis num raio de 200 m, nunca a menos de 75-80 m, some passando de 300 m.
- fivem-zsr: 15 por jogador, nunca a menos de 35 m, some a 225 m. Simple Zombies: nunca nasce **na tela**.
- Ponto de nascimento achado andando na malha de navegação (nunca "altura do chão" pura: nascia no ar/no telhado).

**Hordas (GTAZ) — FATO**
- Horda andarilha a cada 15 min de jogo (20 zumbis); cerco 1 vez por noite com 50% de chance (40 zumbis).
- Nasce a 100-220 m fora da tela; **o destino fica do outro lado do jogador**, então ela atravessa a área dele.
- A cada ~5 s o destino anda ~140 m à frente do centro da horda: anda como um bloco só.
- Quem se afasta > 25 m é puxado de volta (solta a 15 m: histerese).
- Membro da horda só quer o jogador (não se distrai com outros). Se um vê, todos convergem.
- **Líder da horda:** 1 por horda, não toma dano enquanto houver outro membro vivo; morre por último.
- Ícone de caveira no mapa; avisa com som e mensagem antes de chegar.

## 3. Saque, casas e mundo

- **GTA V quase não tem interior aberto**: os mods saqueiam lojas, prateleiras, carros e pontos marcados.
  Nenhum dos 6 entra em casa comum. Confirma o nosso diferencial (casas inteiras abertas).
- Simple Zombies: prateleira da loja de conveniência saqueia **uma vez só** (lista de já-saqueadas), a 1,5 m,
  70% comida embalada; animação de roubo do caixa.
- fivem-zsr: **428 pontos de busca postos à mão**; em cada um nasce uma mochila sorteada; revistar leva **5 s**.
  Itens soltos nascem num raio de 250 m, nunca a menos de 60 m do jogador, até 12 m de altura de diferença.
- zombieoutbreak: zumbi morto tem 15% de chance de roupa, 85% nada.
- Carros: zombieoutbreak deixa 40% dos carros quebrados (queimados); Simple Zombies cria carro com motor morto,
  sujo, 1-2 vidros quebrados e 20% com porta aberta, sempre fora da tela. GTA-Z: carro abandonado (não anda) com
  porta-malas que abre inventário e capô que abre um menu (conserto: INFERÊNCIA pelo nome).
- Zombimod (só a página): carro conserta ou desmonta em peças.
- Zonas seguras com raio (zombieoutbreak, GTAZ "território"): sem zumbi nascendo dentro.

## 4. Lições de engenharia do GTAZ (servem para nós)
1. Toda ordem de IA que "se sustenta sozinha" precisa de um plano B quando o motor a apaga (destravar por velocidade).
2. Limite com histerese (entrar a X, sair a X+1) em tudo que liga e desliga (ataque, puxar de volta).
3. Nascimento por fila + orçamento: nunca criar dezenas no mesmo quadro.
4. Alvo morto tem que ser largado na hora, senão o zumbi fica parado olhando o corpo.
5. Não confiar em "altura do chão" sem a área carregada: nasce no ar.

## 5. Comparação com o DEAD DISTRICT e decisão

| Ideia | Nós hoje | Decisão |
|---|---|---|
| Barulho pelo jeito de andar (correr alto, agachado baixo, carro) | só raio fixo 6,5 m | **APLICADO 05/11**: correr x2, agachado x0,5, carro 15 m (`Zumbi.ouve_de`) |
| Tiro chama zumbi | sim (20 m) | já temos |
| Corredor mais comum à noite | noite deixa mais rápido/forte | ADAPTAR: chance de corredor à noite (próximo) |
| Ritmo de pensar por tipo/distância | zumbi longe (60 m) e quieto dorme; animação some de longe | já temos parecido |
| Destravar zumbi parado | — | DESCARTAR: testado (passo de lado) e atrapalhou contornar prédio; no Godot a rota é refeita todo quadro |
| Orçamento + fila de nascimento | zumbis fixos por ponto | ADAPTAR quando a cidade nova tiver mais zumbis |
| Horda andarilha que atravessa o jogador, com líder | grito chama os de perto | ADAPTAR (evento novo, combina com o raid) |
| NPC morto vira zumbi | — | ADAPTAR nas facções |
| Carro abandonado: vidro quebrado, porta aberta, porta-malas para revistar, desmontar em peças | carros largados + alarme | ADAPTAR na cidade nova |
| Prateleira/ponto saqueia uma vez, revistar leva tempo | gaveta com loot por cômodo | já temos (melhor: por cômodo) |
| Saque só em loja e carro | casas inteiras | DESCARTAR (nosso é melhor) |
