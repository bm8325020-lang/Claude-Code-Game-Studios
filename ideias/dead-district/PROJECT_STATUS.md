# PROJECT STATUS — DEAD DISTRICT / RAVEN CREEK (auditoria 05/11)

## Motor e projeto
- Godot 4.7.2, renderer GL Compatibility (Android + PC). Projeto em `jogo/` (branch `zumbi-apocalipse`).
- Uma cena (`main.tscn`); tudo o mais é montado por script: 55 scripts / ~16 mil linhas, 49 testes automáticos.
- Backup: commit `8693847c` no remoto + tag local `backup-antes-raven-creek` (push de tag recusado pelo proxy, 403).
  Fora do git (precisam de backup à parte): `assets/mixamo/` (458 MB, licença), Atomic Realm (`tools/catalogo/baixa_atomic.sh`).

## Mapa atual: SÃO JORGE (vai virar RAVEN CREEK)
- 500 x 500 m (Bairro.TAMANHO), centro em (0,0,-300); pista de teste ao sul; capital destruída de enfeite ao norte.
- Gerado: `tools/mapa/cidade_v2.py` -> `assets/mapa/cidade.json` (29 ruas, 365 prédios: 143 casas, 61 sobrados,
  121 barracos, 19 galpões, 8 aptos, igreja, hospital, mercado, delegacia, escola, capela; 677 muros, rio + morro).
- Modelos: `tools/blender/ruinas.py` + `cidade.py` (Blender 5.2.3 headless) -> `assets/ruinas/*.glb`.
- Montagem no jogo: `scripts/bairro.gd` (Bairro, ~2,5 mil linhas) + `planta.gd`; malha de navegação pronta em
  `assets/mapa/nav_*.res`.
- Desempenho medido (foto_cidade.gd, qualidade Média): centro ~1300 chamadas de desenho, rua de casas ~490.

## Qualidade do mapa (avaliação honesta)
- Bom: ruas com meio-fio e faixa, relevo com rio e pontes, interiores com cômodos, loot por cômodo, telhados andáveis,
  raids nos prédios públicos, desempenho dentro do limite.
- Ruim: estilo brasileiro (o dono quer americano), prédios em caixa simples, móveis em linha numa parede só
  (`comodo_real`), um andar só nas casas, sem garagem/quintal, poucas placas/semáforos, sem carregamento por regiões.

## Sistemas que funcionam (não mexer sem teste)
Rede (ENet/WebSocket/carteiro), PvP em salas, salas de sobrevivência, zumbis (tipos, horda andarilha, noturno, barulho),
loot (baús, gavetas por cômodo, porta-malas), facções e casas dominadas, construção (catálogo de 2111 peças), clima,
ciclo dia/noite, progresso/XP, carros dirigíveis, infecção/mordida, resgate.
