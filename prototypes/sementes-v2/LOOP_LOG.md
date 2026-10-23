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
