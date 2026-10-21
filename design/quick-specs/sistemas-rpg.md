# Sistemas de RPG — o que entra em Sementes do Dragão

> Status: decisão de 2026-10-21, a partir da lista de mecânicas enviada pelo dono do jogo.
> Código: `prototypes/souls3d-concept/rpg.gd` (regras), `menu.gd` (menu), `main.gd` (uso no combate).
> Teste: `prototypes/souls3d-concept/tests/rpg_test.gd`.

O jogo é um RPG de ação no estilo Dark Souls, para celular e jogado offline.
Entra o que reforça isso. Fica de fora o que exige servidor, troca o combate por turnos ou cobra o jogador.

## Já no jogo

| Sistema | Como funciona |
|---|---|
| Níveis | Brasas compram níveis na fogueira (custo 100 + 50 × nível). |
| Atributos | Vigor, Fôlego, Força, Destreza e Inteligência. Cada nível dá 1 ponto. |
| Classes | Cavaleiro, Andarilho e Piromante, escolhidos no Novo Jogo. Todas têm o mesmo total de atributos (58). |
| Talentos | Três ramos (Guerreiro, Sombra, Chama), cada um com 4 talentos em ordem. Ganha 1 ponto a cada 2 níveis, mais 1 por sino e por chefe. |
| Renascer (respec) | Na fogueira. A primeira vez é grátis; depois custa 100 × nível em brasas. |
| Combate de ação | Já existia: combo infinito, postura, aparar, contra-ataque e troca entre espada e espadão. |
| Elementos e fraquezas | Físico, fogo, gelo e raio. Cada inimigo tem uma tabela de fraquezas, que também aparece no Bestiário. |
| Efeitos de status | Queimadura (fogo), lentidão (gelo), sangramento (talento) e veneno (Espreitador). O Frasco cura o veneno, e o veneno sozinho não mata. |
| Quebra de postura | Já existia: a barra de postura esvazia e o inimigo fica atordoado. |
| Viagem rápida | Já existia, entre fogueiras acesas. |
| Segredos e colecionáveis | Fragmentos de Seiva escondidos. |
| Saque com raridade | Já existia, em 4 raridades. |
| Reforço de arma | +1 até +5, com titanita e brasas, na fogueira. |
| Duas moedas | Brasas e titanita. |
| Diário de missões | Missão principal com objetivo sempre na tela e 4 missões secundárias. |
| Opções | Sombras, resolução 3D, limite de FPS, mostrar FPS e sensibilidade da câmera. |

## Próximos (cabem no estilo)

- **NPCs com diálogo:** a Guardiã, o ferreiro e um mercador. Daqui saem loja e mercado negro, relação de afinidade e escolhas com consequência.
- **Invocação de aliado (estilo "sinal de invocação"):** é a versão souls de "companheiro com IA".
- **Pedras engastadas na arma (gemas):** dão elemento e efeitos.
- **Fabricação simples:** ervas e materiais viram consumíveis, como cura de veneno, resina de fogo e bombas.
- **Mapa com áreas reveladas aos poucos.**
- **Ciclo de dia e noite:** inimigos diferentes à noite.
- **Novo Jogo+:** mantém o personagem e aumenta a dificuldade. Finais diferentes conforme os Sinos e as escolhas.
- **Torre / masmorra infinita:** um modo de andares gerados, com recompensas.

## Fora (não combinam ou exigem servidor)

- **Por turnos, ATB, grade tática e pausa tática:** trocam o combate de ação, que é o centro do jogo.
- **Gacha, energia, passe de temporada e progresso offline:** cobram ou limitam o jogador. São contra a ideia de um RPG clássico.
- **PvP, guildas e ranking:** precisam de servidor online.
- **Grupo de 3–4 heróis com troca no meio da luta:** é um jogo grande à parte. O aliado invocado cobre a parte de companhia.
- **Construção de deck, pesca e fotografia:** podem virar minijogos no futuro, mas não agora.
