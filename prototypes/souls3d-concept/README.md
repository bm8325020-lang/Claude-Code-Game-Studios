# Prototype: Souls 3D (Seeds of the Dragon)

**Hypothesis:** a dark 3D souls-like fight (stamina, roll, lock-on, Seed spell) is fun on a phone.
**Status:** in progress.

## Run

- Desktop: `godot --path .` (WASD move, J attack — hold for heavy, U shield, Space roll, K fire, H flask, L lock-on, N level up at the bonfire, Q switch weapon, right mouse drag camera).
- Android: export the `Android` preset to an APK.
- Mixamo animations are not in the repo (licence); put the Sword and Shield and Great Sword pack FBX files (great sword files prefixed `gs_`) in `assets/mixamo/` named in snake_case.

## Mechanics (v3)

- Sword and shield: 5-hit combo (the 5th is a backhand), each hit a different animation; hold ATTACK for a heavy; attacking while sprinting or right after a roll uses dedicated moves.
- Shield block (stamina), parry in the first 0.22 s of a block, shield + attack = kick that breaks guard.
- Poise: enemies get stunned when their poise bar empties; attack a stunned enemy for a critical riposte.
- Sprint (full stick for 0.6 s), lock-on strafing, Fire Seed costs Essence (blue bar).
- Bonfire: rest, level up with Embers; Sap Shards raise max flasks; Embers dropped on death can be recovered.
- Enemies: Skeleton Warrior (blocks) and Skeleton Minion (fast), rise from the floor, 5 attack types incl. a leaping chop.
- Great sword (ARMA button, Q): two-handed moveset with a 4-hit combo, a spinning heavy, a sliding sprint attack, a jump attack after a roll and its own riposte; more damage, reach and poise damage, costs more stamina and blocking drains more.
- Hero: dark-knight plate armour built in Blender by `tools/make_hero_armor.py` (one GLB, pieces named `<bone>__<piece>` in each Mixamo bone's local space, attached with BoneAttachment3D), over the X Bot body as a dark gambeson.
- Boss: dragon with phase 2 at 50% HP; a portcullis closes behind the player.

## Findings

- v1 (2D duel) and v2 (2D farm) pivots: see `../combat-feel-concept/` and `../explore-farm-concept/`.
- Pending: playtest of v3 on the user's phone.
