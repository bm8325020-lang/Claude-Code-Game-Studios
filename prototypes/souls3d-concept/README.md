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
- Enemies: Skeleton Warrior (blocks, then shield-bashes), Skeleton Minion (fast, dodges your swings) and Skeleton Caster (keeps its distance, throws slow-homing ghost fire). They rise from the floor, shamble when far, circle you at mid range, chain a second swing, taunt when you die, and half of the fallen warriors/minions pull themselves back together once after 4 s unless a Fire Seed burns the bones. All clips come from the KayKit skeleton files (the KayKit Knight set from animated-asset-skill is the same rig and clip set, kept in `assets/skeletons/` as reference).
- Sword and shield attacks, Fire Seed cast, flask and parry are hand-made clips (`hero_anims.gd`): key poses with two-bone IK for the hands, blade direction and torso/leg angles, baked into the animation library at load. Walk, run, roll, hits and deaths stay Mixamo. `tools/anim_sheet.gd` renders a clip's key poses, `tools/anim_reel.gd` plays them all for a review video.
- Great sword (ARMA button, Q): two-handed moveset with a 4-hit combo, a spinning heavy, a sliding sprint attack, a jump attack after a roll and its own riposte; more damage, reach and poise damage, costs more stamina and blocking drains more.
- Hero: dark-knight plate armour built in Blender by `tools/make_hero_armor.py` (one GLB, pieces named `<bone>__<piece>` in each Mixamo bone's local space, attached with BoneAttachment3D), over the X Bot body as a dark gambeson. Textures in `hero_look.gd` (object-space triplanar) come from Poly Haven CC0 `rusty_metal_04`, `fabric_leather_02` and `rough_linen`, recoloured. `tools/hero_portrait.gd` renders review portraits.
- Open island (`world.gd`, `terrain.gdshader`): 440 m heightmap terrain with sea, the walled ruins in the middle (gate in the south wall), five bonfires (Praia das Cinzas start, Ruínas do Guardião, Floresta Morta, Cemitério dos Juramentados, Sopé do Pico); resting lights a bonfire and makes it your respawn. Dead trees and pines are made in Blender by `tools/make_trees.py` and scattered with MultiMesh; the sea drowns you. Terrain textures: Poly Haven CC0 `brown_mud_leaves_01`, `aerial_rocks_02`, `coast_sand_rocks_02`.
- Breakable pots, jars and barrels (attack, roll or sprint into them): a few Embers, sometimes a flask charge; they come back when you rest at the bonfire.
- Scenery: Gobkit CC0 nature kit (`assets/nature`: pines, cliffs, rocks) outside the walls and Polygonal Mind CC0 ruins (`assets/pm`, see `SOURCES.md`): arch, columns, broken walls, Seed crystals, webs, cart.
- More enemies (KayKit Skeletons CC0, same rig): Skeleton Mage (the caster, hat hidden), Skeleton Rogue (dual blades, fast, dodges) and Skeleton Crossbowman (straight fast bolts). Skull keys are scaled to 0.66 to tone down the chibi look. Ash Wolves (Quaternius CC0, `assets/beasts`) hunt in packs: run, circle and pounce; the pounce is procedural since the model only has idle/walk.
- Seeds of power: Fire (fireball), Ice (slows for 3 s, heavy poise damage; found in the cemetery) and Lightning (instant strike that jumps to two more enemies; deep in the Dead Forest). SEED casts the current one, TROCAR (T) cycles.
- HUD map of the island (lit bonfires, Seeds, player arrow), region names on entry, fast travel between lit bonfires (VIAJAR / Y).
- Dragon form: after the first dragon falls you hold the Dragon Seed; damage you deal fills the Fury bar, and when it is full DRAGÃO (G) turns you into a black dragon for 15 s (fire breath cone, wing dash with i-frames, giant fireball, half damage taken). `SEMENTES_DRAGON=1` starts with the Seed for showcase runs.
- Loot: enemies drop items (35%, wolves 25%; bosses a guaranteed Legendary) in 4 rarities (Comum 70%, Raro 22%, Épico 7%, Lendário 1%) with a light beam in the rarity colour. Slots: sword and great sword (+% melee damage), ring (+max HP), amulet (+% Fury gain). Better items equip themselves; worse ones melt into Embers. Equipped gear is listed under the bars.
- Bosses: Guardian Dragon in the ruins (phase 2 at 50% HP, portcullis closes behind you; drops the Dragon Seed) and the Ancient Wyrm on the summit of Dragon's Peak (bigger, red, 2400 HP, adds a fire rain with ground warning rings; +5000 Embers and +50 max HP). Bosses share one AI; the nearest living one is the target for every other system.

## Findings

- v1 (2D duel) and v2 (2D farm) pivots: see `../combat-feel-concept/` and `../explore-farm-concept/`.
- Pending: playtest of v3 on the user's phone.
