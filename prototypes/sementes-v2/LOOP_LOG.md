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
