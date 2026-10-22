# Sementes do Dragão v2 — architecture and module contracts

Godot 4.7.2, GDScript, Compatibility renderer (`gl_compatibility`), Android phones (arm64), landscape, touch.
Godot binary: `/home/user/.local/godot/Godot_v4.7.2-stable_linux.x86_64`. Run from this folder with `--path .`.

The old game's maps, animations, hero model, sword and shield are gone. This is a fresh build. `tools/main_old_reference.gd.txt`,
`actors/qrig_old.gd`, `ui/menu_old.gd`, `systems/rpg_old.gd`, `ui/npcs.gd`, `ui/dialog.gd` are the old code kept only as a
source of useful lines (combat feel, the Claude NPC chat, options menu). Port what helps; never load the `*_old*` files.

## Art direction (every module follows it)

- One family: Quaternius CC0 MegaKits. `assets/village` (Medieval Village MegaKit: modular walls, roofs, props),
  `assets/nature` (Stylized Nature MegaKit: trees, rocks, grass, flowers, rock paths), `assets/props` (Fantasy Props
  MegaKit: chests, barrels, crates, weapons, food, books, banners), `assets/chars` (Universal Base Characters heads/hair,
  Modular Outfits peasant/ranger, `parts/` for mix and match, Imp and Puglin monsters), `assets/anims` (Universal
  Animation Library 1 and 2: mocap clips on the same rig as every character).
- Look: warm, hand-made storybook medieval. Golden-hour sun, soft blue shadows, light haze. Saturated but not neon.
  No flat untextured colours on big surfaces, no noisy "AI" tiling, no grey brick texture on everything.
- Authentic, not generated: the map is designed by hand (named places, reasons for every road, buildings that face
  their street, props grouped into little stories: a woodpile by a house, a cart left by the gate, fishing nets on the
  pier). Never scatter by uniform noise alone; when you scatter (grass, pebbles), do it along rules (edges of paths,
  near water, under trees) and with variation in scale and rotation.
- Mobile budget per frame: under ~250 draw calls and ~400k triangles at the default view; merge static meshes per
  material; visibility ranges on small props; shadows only on characters and big landmarks.

## Folders and owners

| Module | Files | Owner |
|---|---|---|
| Map | `world/map.gd`, `world/*.gd`, `world/*.gdshader`, `assets/ground/` | map agent |
| Animation and characters | `actors/anim_lib.gd`, `actors/character.gd`, `actors/hero_anim.gd` | animation agent |
| Hero, enemies, combat | `actors/hero.gd`, `actors/enemy.gd`, `actors/boss.gd` | combat agent |
| Progression, quests, items | `systems/progression.gd`, `systems/quests.gd`, `systems/items.gd`, `tests/test_systems.gd` | progression agent |
| Interface | `ui/hud.gd`, `ui/touch.gd`, `ui/menu.gd`, `ui/dialog.gd`, `ui/npcs.gd` | UI agent |
| Glue | `main.gd`, `main.tscn`, `project.godot` | lead (main loop) |

Do not edit files you do not own. If you need something from another module, code against the contract below and
write what you assumed in your module's header comment.

## Contracts

### Map — `world/map.gd` (`extends Node3D`, `class_name GameMap`)
- `func build() -> void` builds the whole region under itself (terrain with collision on layer 1, water, buildings
  with collision, vegetation, lights). Runs once at start; may take a few seconds.
- `var spawns: Dictionary` named `Vector3` points: `"player_start"`, `"village_square"`, and one per place below.
- `var places: Array` of `{id: String, name: String (pt-BR), pos: Vector3, radius: float}`. Required ids:
  `village` (Vila de Brasalume: start), `farm` (fields and a farmhouse), `river` (river, bridge, mill),
  `forest` (Bosque dos Sussurros), `bandit_camp`, `watchtower` (ruined tower on a hill), `mine` (abandoned mine
  entrance), `castle` (Castelo de Vigília on a cliff: final area), `lake` (lake with a pier).
- `var camps: Array` of `{id, place, pos: Vector3, kinds: Array[String], count: int, level: int}` enemy groups.
  Kinds come from the combat contract (`wolf_imp`, `bandit`, `bandit_archer`, `puglin`, `possessed`, `knight`).
- `var npc_spots: Array` of `{id, pos: Vector3, facing: float, role: String}` for the NPCs (blacksmith, merchant,
  elder, farmer, fisher, guard captain, innkeeper, miner, priest).
- `var interactables: Array` of `{id, pos, kind}` (bonfire/rest spots, chests, doors, levers, the mine gate).
- `func ground_y(x: float, z: float) -> float` (height under a point, from the terrain data, no physics).
- `func area_name(pos: Vector3) -> String` (pt-BR name of the place you are in, or "").

### Characters and animation — `actors/character.gd`, `actors/anim_lib.gd`, `actors/hero_anim.gd`
- `CharacterKit.make(look: Dictionary) -> Node3D` builds a rigged character (outfit pieces, head, hair, colours,
  weapon in hand) with an `AnimationPlayer` named `Anim` and an `AnimationTree` if used. `look` keys: `body`
  ("Male"/"Female"), `outfit` ("Peasant"/"Ranger"), pieces, colours, `weapon` (prop name from `assets/props` or ""),
  `shield` (or "").
- `HeroAnim.new(character: Node3D)`; `func update(dt, velocity: Vector3, grounded: bool, mode: String)` drives
  locomotion (idle, walk, jog, sprint, strafe when locked, turn-in-place, lean, foot placement) with smooth blends;
  `mode` is "free", "lock", "block", "swim", "crouch".
- `func act(name: String) -> Dictionary` plays an action and returns `{length, hit: Array[float], cancel: float,
  invuln: Vector2}` (seconds). Action names: `light1`..`light4`, `heavy`, `sprint_attack`, `dodge`, `roll`,
  `backstep`, `block_hit`, `parry`, `hit_light`, `hit_heavy`, `knockdown`, `getup`, `death`, `cast`, `drink`,
  `interact`, `pickup`, `open_chest`, `talk`, `cheer`, `jump`, `fall`, `land`, `climb`, `sit`.
- Enemies use the same `CharacterKit` plus `anim_lib.gd` names; `anim_lib.gd` exposes the shared AnimationLibrary.

### Hero and combat — `actors/hero.gd`, `actors/enemy.gd`, `actors/boss.gd`
- `Hero` (`extends CharacterBody3D`): input from `ui/touch.gd` (`Touch.move_vector()`, `Touch.pressed(action)`,
  `Touch.held(action)`; actions `attack`, `heavy`, `dodge`, `block`, `skill`, `potion`, `interact`, `lock`, `jump`,
  `menu`) or the keyboard. Stamina, poise, lock-on, camera (third person, follow, soft collision).
- `Enemy` kinds above with telegraphed attacks, patrol, alert, flee, group tactics. `Boss` for the castle lord.
- Damage goes through `main.damage(target, amount, source, kind)` so progression and UI can react.

### Progression — `systems/progression.gd`, `systems/quests.gd`, `systems/items.gd`
- Start from nothing: peasant clothes, no weapon. A quest chain across the map ids above teaches and unlocks
  everything (first weapon from the blacksmith, the first fight, rest points, the shield, skills, the castle).
- `Progression`: level, XP curve, attributes, skill unlocks, gold; `func gain_xp(n)`, signals `leveled_up`.
- `Quests`: data-driven list (`id, title, giver, steps: [{type: talk|kill|reach|collect|interact, target, count}],
  rewards`), `func notify(event: String, target: String)`, `current() -> Dictionary`, signals for UI.
- `Items`: weapons and armour tiers that change the hero's look (outfit, weapon, shield), consumables, chests.
- Everything saves to `user://sementes2_save.json` through `func to_dict()` / `from_dict(d)`.

### Interface — `ui/*`
- HUD (life, stamina, XP bar, gold, quest tracker with distance/arrow, area name banner, boss bar), touch controls
  (left stick, action buttons placed for thumbs), pause menu (character, inventory, quests, map, options with the
  Claude API key for NPC chat), dialog with NPCs (quick choices plus free text via Claude), level-up and reward popups.
- Text in Brazilian Portuguese.

## Checks every module must pass before it is done
- `godot --headless --path . --quit-after 600` prints no `SCRIPT ERROR`.
- Screenshots of the work (xvfb: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3
  --resolution 1280x720 -s <script>`), looked at by the author before claiming done.
