# Simple Zombies (GTA V) com Rea + Ghidra (06/11)

Pedido do dono: pegar um mod famoso do GTA V, desmontar com Rea e Ghidra e recriar as mecânicas no nosso código
(sem copiar código, modelo ou som do mod).

- Binário: `ZombiesMod.dll` (149 KB, .NET), versão 1.0.2d, do repositório ParisRP/GTAV-Simple-Zombies.NET (git clone;
  gta5-mods.com e as releases do GitHub são bloqueados nesta máquina).
- Ferramentas: Rea 6.7.0 (`npm i -g rea-agents`) com Ghidra 12.1.4 (pacote do Kali extraído em /root/ext/ghidra;
  `GHIDRA_INSTALL_DIR=/root/ext/ghidra/root/usr/share/ghidra`). `rea inspect`: 743 funções, 3 segmentos, PDB
  ZombiesMod.pdb referenciado. Nomes de tipos e métodos e textos do jogo lidos da tabela de metadados .NET.

## O que o mod tem (pelos nomes e textos do binário)
| Sistema | Evidência no binário | No DEAD DISTRICT |
|---|---|---|
| Caixa que cai do céu com marca no mapa | `Crate Drop`, `AddBlip`, `CantSeeCrate` | RECRIADO: `scripts/suprimento.gd`, blip verde no minimapa |
| Silenciador | `IsWeaponWellSilenced`, "Can be used to suppress a rifle, pistol, shotgun, or SMG." | RECRIADO: item `silenciador` (barulho x0,35, som baixo) |
| Bandagem | `Bandage`, "A strip of material used to bind a wound..." | RECRIADO: item `bandagem` (+30 de vida) |
| Percepção: correr chama, por trás perto | `RunningNoticeDistance`, `BehindZombieNoticeDistance`, `IsRunningNoticed` | já tínhamos (`Zumbi.ouve_de`) |
| Corredores e noite | `Runner`, `Fast Zombies`, "Nightfall approaches..." | já tínhamos (`noturno`) |
| Infecção | `InfectPed`, `InfectTarget`, `Infection Mode` | já tínhamos (infecção e mordida) |
| Saque de prateleira e de mortos | `IsShelf`, "Press ... to loot the shelf.", `LootDeadPeds` | já tínhamos (gavetas, saco) |
| Fome, água suja e limpa, carne crua e cozida | `Hunger`, `Dirty Water`, `Clean Water`, `Cooked Meat` | PRÓXIMO: ferver água e cozinhar carne na fogueira |
| Animais para caçar | `AnimalSpawner`, `AnimalLoot` | PRÓXIMO |
| Sobreviventes amigos e hostis, recrutar guarda-costas | `FriendlySurvivors`, `HostileSurvivors`, `RecruitPeds`, `Guard Tasks` | PRÓXIMO |
| Base: paredes, barreiras, barraca, fogueira, caixa de armas | `Wooden Wall`, `Barrier`, tent, `Camp Fire`, weapons crate | o dono tirou o modo construção |
| Apagão | "Enables/Disable blackout mode." | PRÓXIMO (luz da rua apagada) |
| Áreas proibidas | `InvalidZoneNames` (Fort Zancudo, prisão, aeroporto, Humane Labs) | não se aplica |
