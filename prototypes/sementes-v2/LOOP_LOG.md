# Loop log — Sementes do Dragão v2

Each iteration: a playtest bot (`tools/player_bot.gd`) plays a fresh save like a new player, guided only by what
the screen shows (quest arrow, ✦ stars, ⚔ nameplates, the FALAR button). Findings drive the next changes.

Run: `godot --headless --path . --fixed-fps 30 -s tools/player_bot.gd -- <minutes> <seed>` → `tools/playtest_report.json`.

## Iteration 1

| Run | Level | Quests done | Deaths | Stalled on |
|---|---|---|---|---|
| baseline (15 min) | 1 | none | 0 | "Fale com Rosa" — the whole time |
| after fixes (30 min, seeds 1 and 2) | 8 | m01–m06, s4 | 8–11 | "Pegue a semente entre as raízes" |

Bugs found by the bot and fixed:
- Tapping FALAR never advanced "talk" steps: only typing a free-text line to the NPC did. Opening the dialog now counts.
- "Reach" steps never completed: main never told the quests where the hero was. Now notified every 0.25 s.
- Small quest props were invisible to a newcomer: a ✦ star now floats over every item/spot the current quest needs.
- Joana stands at her forge, so FALAR always opened her dialog instead of using the forge: the quest target now wins.
- Kill steps pointed the arrow at the empty middle of the area: it now points at the nearest living target.
- Enemies never respawned, so farming ended after one clear: camps refill 40 s after a kill when the hero is 30 m+ away.
- The relha (and any other prop) inside a building's collision box was unreachable: buried spots move to free ground.
- Quest targets show ⚔ on their nameplate.

## Iteration 2

Reviewer agent (casual-player view) approved: respawn at the nearest discovered Marco de Lume; gentler scaling
(same level or +1: −20% damage taken up to zone 12; +2 1.5×, +3 2×, +4 3×); keep "lose nothing on death";
one contextual tip after 3 deaths in an area within 5 min; "Recomendado: Nv X" when entering a zone 2+ above you.

Quest audit (every quest target vs the map) found 5 holes, all fixed: semente_carvalha and semente_afogada were
never placed, sino_vaca had 3 of 4, peixe_lua 1 of 3, and elmo_vigilia never dropped from knights.

Bot (40 min, seeds 1/2): level 13, m01–m07 + s4. New wall: m08 at the bandit camp (zone 12–15) and odd deaths at
the mill while over-levelled (cause logging added to the bot).

## Iteration 3

Death causes logged: at level 8–10 a pack of mill bandits (Nv 4–6) killed a 127-HP hero who never spent points.
Fixed: HP +10/level; enemies 3+/5+ levels below hit 50%/30%; hero outfit was rendered black (weapon tint string
read as cloth dye); enemies healed in the player's face while leashing home (now only when 15 m+ away, leash 45 m).

Reviewer agent ranked new features; built the top four: fast travel between discovered Marcos, a road-following
quest arrow (A* over the road network), auto-distributed attribute points (toggle in Opções), and a small combo
counter with a ding every 5 hits. Vetoed for now: horse (redundant with fast travel), post-game zone, fishing.

Bot (60 min, seeds 1/2): level 17 / 14, m01–m08 + s4, 6 areas, deaths 15–20. Stalls found: archers kited the
player for 34 min (now stand their ground away from home) and watchtower knights blocked everything (guard less,
light hits wear the guard down).

## Iterations 4–5

New seeds (3/4) exposed new blockers, all fixed:
- Enemies spawned on slopes started inside the hill and fell under the map (quest arrow pointed at y = −44).
  Spawns snap to the terrain; anything 5 m under ground is put back.
- Quest spot vs. nearby hunter/dropped chest on the interact button (554 presses at Tobias' tent).
- Watchtower knights: on-level discount at every level; enemy damage +10%/level past 10; enemy HP +18%/level
  (was +30%: a level-17 knight had 812 HP); hero damage +4%/level. Camps on an area's edge use its name.
- Toll bridge: no ramps (road ran under the deck) → 10 m-wide ramps; river trap → lifted to the nearest open
  road point after 4 s in the water; generic stuck rescue; arrow routes over the terrain's real roads;
  reach steps notify every containing area (a neighbouring camp hid "forest").

Reviewer-approved content: Joana's forge (+1..+5 for 100–1000 gold), selling loot (one-tap duplicate commons),
12 achievements with gold, discovered Marcos saved, quest card "Recomendado: Nv X · treine com o Caçador".

Bot (30 min, seeds 3/4): level 13–14, m01–m08 + s2 + s4, stuck events 9–10 (were 60–90).

## Iterations 6–7

- Skills on the attack button's neighbour: INVESTIDA at level 10, GIRO at level 20 (6 s cooldown ring).
- Ending panel "A Festa da Semeadura" after m14, with "Continuar explorando".
- Boss never spawned (no spawn point): it now uses the boss camp position.
- Mine camp held 3 puglins but the quest asked for 6: camp caps follow the largest quest kill count.
- Mine gate: its collider was permanent, so the galleries stayed shut after "Abra o portão da mina" and the
  puglin step stalled 40–55 min. The collider is now disabled once the story opens the gate (also on load).

Bot (160 min, seeds 5/6, before the gate fix): story finished (m14), level 29–30, 10 areas.

## Iterations 8–9

- Mine gate fix confirmed: story finished in 53 min (seed 6), was ~146; the mine step now takes ~2 min.
- Bot learned to tap "Continuar explorando" on the ending panel (it stood still 100 min).
- Collect steps: the arrow points at the nearest missing item (cow bells sat 40+ min with the arrow on the farm).
- A wanted pickup beats a townsperson with "!" standing next to it (Rosa's letters: 686 taps opened her dialog).
- New: 12 hidden treasure chests (never expire, +50 gold, saved once found) and the Caça-Tesouros achievement.

Bot (110 min, seed 7, before the pickup fix): story + s2/s3/s4/s5 done, level 30, stuck events 11.

## Iteration 10

Bot (110 min, seed 8): story + all side quests but s6 done, level 30. Rosa's letters fix confirmed.
- The pier's fishing spot gave nothing (kind "fishing" fell through to a plain interact); the quest only moved
  thanks to two spare fish dropped as pickups. Each cast now lands a fish ("Pescar" prompt).
- The arrow's road start was the nearest road node even behind a house: 15 min pushing into a village wall on
  the way to the bandit camp. It now takes the nearest node in clear line of sight.
