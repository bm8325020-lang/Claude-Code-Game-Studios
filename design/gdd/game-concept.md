# Game Concept: Seeds of the Dragon (Sementes do Dragão)

*Created: 2026-10-21 · Revised: 2026-10-21 (v2)*
*Status: v2 — revised after the combat-feel prototype PIVOT (see `prototypes/combat-feel-concept/PIVOT-NOTE.md`). v1 is superseded.*

---

## Elevator Pitch

> It's a pixel-art action RPG for phones where you explore islands, farm monsters for XP
> and loot, and hunt rare elemental Seeds that give you new skills — until you find the
> legendary Dragon Seed and become the dragon.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 2D top-down action RPG — explore, farm, level up, rare power drops |
| **Platform** | Mobile — Android (Google Play), landscape, touch |
| **Target Audience** | Mid-core mobile players 13-25 who play Mobile Legends, Free Fire, Blox Fruits |
| **Player Count** | Single-player, offline |
| **Session Length** | 10-30 min (farming sessions with natural stops at level-ups and boss kills) |
| **Monetization** | None at launch (free, no ads, no purchases); never sell power |
| **Estimated Scope** | Large (Tier C 6-9+ months, solo with AI agents); first public release is Tier B at 4-6 months |
| **Comparable Titles** | Blox Fruits (fruits, farming, bosses), Soul Knight (mobile pixel action), Archero (touch action) |

---

## Core Fantasy

You wash up on an archipelago where monsters roam and ancient trees grow Seeds of power.
Eat a Seed and its element becomes yours — fire, ice, lightning — each with its own skills.
Grow strong enough to face the island bosses, and one day find the rarest of all: the
Dragon Seed, which turns you into a dragon.

---

## Unique Hook

It's like Blox Fruits' farming and fruit hunting, **and also** a fast, offline, pixel-art
action RPG built for one thumb on a phone — where each Seed swaps your whole skill set and
the Dragon Seed is the ultimate trophy.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Fantasy** | 1 | Elemental Seeds with flashy skills; the Dragon Seed transformation |
| **Challenge** | 2 | Stronger monster zones, bosses, a harsh death penalty |
| **Sensation** | 3 | Big skill effects, damage numbers, loot bursts, level-up flash |
| **Discovery** | 4 | New areas, rare spawns, hidden chests, Seed trees |
| **Expression** | 5 | Which Seed to use, stat points, equipment |
| **Narrative** | 6 | Light island myth through NPCs and signs |
| **Submission** | 7 | Comfortable farming loop between harder fights |
| **Fellowship** | N/A | Single-player |

### Key Dynamics (Emergent player behaviors)

- Players farm a zone until they can push into the next, harder one.
- Players chase rare spawns and bosses for Seed drops.
- Players try each Seed's skills and pick a favourite.
- Players play carefully when carrying a lot of gold and loot, because death costs a lot.

### Core Mechanics (Systems we build)

1. Fast real-time combat: auto-aimed basic attack plus 3 skill buttons from the equipped Seed (cooldowns); a dodge.
2. Exploration of hand-made island zones with monster spawns of rising level.
3. XP, levels and stat growth; gold and item drops; equipment.
4. Seeds: rare drops and Seed trees; eating one swaps your 3 skills; Seeds level up with use.
5. Bosses with readable attacks and big drop tables; harsh death penalty.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Where to farm, which Seed to use, when to bank loot | Supporting |
| **Competence** | Levels, stronger skills, beating bosses, surviving with loot | Core |
| **Relatedness** | Screenshots of rare Seeds and the dragon | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — levels, rare Seeds, the Dragon Seed (primary)
- [x] **Explorers** — new zones, rare spawns, hidden chests (secondary)
- [ ] **Socializers** — not served
- [x] **Killers/Competitors** — bosses and personal records (minor)

### Flow State Design

- **Onboarding curve**: start in a safe beach zone with weak slimes; the first level-up arrives within a minute; the first Seed is found in the first 10 minutes.
- **Difficulty scaling**: zones are level-gated by monster strength; bosses sit at zone ends.
- **Feedback clarity**: damage numbers, XP bar, level-up burst, loot popping out of monsters.
- **Recovery from failure**: respawn at the last safe point quickly; the cost is the loot you carried (see Death).

---

## Core Loop

### Moment-to-Moment (30 seconds)

Run at a group of monsters, attack, fire a Seed skill into the pack, dodge a hit, collect
the coins and XP that burst out.

### Short-Term (5-15 minutes)

Clear a zone's spawns, level up, open a chest, fight a mini-boss, decide whether to bank
your loot at the safe point or push on.

### Session-Level (30-120 minutes)

Reach a new zone or beat its boss; hunt for a Seed drop; spend gold on gear at the safe point.

### Long-Term Progression

Level up, collect all elemental Seeds and level them, beat each island boss, and finally
earn the Dragon Seed and the dragon form.

### Retention Hooks

- **Curiosity**: the next island, rare spawns, the Dragon Seed.
- **Investment**: levels, Seeds, gear.
- **Social**: screenshots only.
- **Mastery**: harder zones and bosses; surviving with a full bag.

---

## Game Pillars

### Pillar 1: Always Something Dropping

Rewards are frequent and visible: XP, coins and items burst out of every fight.

*Design test*: Debating a quiet fight versus one that showers loot, choose the loot.

### Pillar 2: The Rare Seed Is an Event

Seeds are rare, celebrated drops (fanfare, screen flash), and each one changes how you play.

*Design test*: Fewer Seeds that each change the skill set over many small stat items.

### Pillar 3: Grow Into the Dragon

Progression shows on screen: bigger skills, new effects, and finally the dragon.

*Design test*: A new visible effect over a +% stat.

### Pillar 4: Thumb-First Action

Built for touch: joystick, auto-aimed attack, at most four action buttons, large targets.

*Design test*: Auto-aim and fewer buttons over precise aiming and more buttons.

### Anti-Pillars (What This Game Is NOT)

- **NOT selling power**: no loot boxes, paid Seeds or paid drop odds.
- **NOT multiplayer or an online MMO**: out of scope for a solo first game.
- **NOT slow, waiting-heavy combat**: the combat-feel prototype showed it bores this player.
- **NOT auto-battle**: the player always plays the fight.

---

## Visual Identity Anchor

**Direction: "Pixel Archipelago"** (user's choice after the prototype; replaces "Shadow and Flame").

**Visual rule: "Bright world, brighter powers."** A colourful 16×16 pixel-art world
(Kenney Tiny Town / Tiny Dungeon, CC0) with Seed skills as the most saturated, glowing effects on screen.

Supporting principles:
1. **Readable at phone size** — sprites scaled 4-5×, crisp nearest-neighbour filtering. *Test*: monsters are recognisable at arm's length.
2. **Element colours are sacred** — fire orange, ice cyan, lightning yellow, dragon gold-red are used only for Seed skills and Seeds. *Test*: a skill is never confused with scenery.
3. **Loot pops** — drops bounce out with a shine. *Test*: the eye goes to the drop.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Blox Fruits | Fruit powers, farming, bosses, rare drops | Offline, original Seeds, 2D pixel art, no paid power | The player's favourite loop |
| Soul Knight | Mobile pixel action with joystick + buttons | Open zones and progression instead of dungeon runs | Proves pixel action works on touch |
| Mobile Legends | Joystick + skill buttons with cooldowns | Single-player PvE | Matches the player's muscle memory |

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 13-25 |
| **Gaming experience** | Mid-core |
| **Time availability** | 10-30 minute sessions on a phone, daily |
| **Platform preference** | Android phone |
| **Current games they play** | Mobile Legends, Free Fire, Blox Fruits |
| **What they're looking for** | Blox-Fruits-style power hunting they can play offline on their phone |
| **What would turn them away** | Pay-to-win, slow combat, clumsy touch controls |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.7.2 (user's choice), GDScript, Compatibility renderer, Godot Physics 2D |
| **Key Technical Challenges** | Many monsters on screen at 60 fps; data-driven Seeds/skills/monsters/drops; save integrity; signed AAB |
| **Art Style** | 16×16 pixel art (Kenney CC0 packs) + code-drawn skill effects |
| **Art Pipeline Complexity** | Low (ready packs; custom Seed sprites and effects) |
| **Audio Needs** | Moderate (hits, skills, loot, level-up, zone music) |
| **Networking** | None |
| **Content Volume** | Tier C: 4 islands, ~12 monster types, 4 bosses, 4 Seeds + Dragon Seed, ~30 items |
| **Procedural Systems** | Spawn tables and drop tables from data; zones hand-made |

---

## Death

The user chose a harsh penalty: on death you respawn at the last safe point and **lose all
gold and items you were carrying**; levels, equipped gear and eaten Seeds are kept. Banking
loot at a safe point protects it. This creates the "do I push on or go bank?" tension.

---

## Risks and Open Questions

### Design Risks

- Farming loops can get repetitive: new zones, rare spawns and Seed skills must keep variety.
- The harsh death penalty may frustrate; banking at safe points is the release valve.

### Technical Risks

- Performance with many monsters and effects on mid-range phones.
- Android release pipeline (AAB via Gradle build, keystore backup).

### Market Risks

- Blox-Fruits-like games are popular; the Seed/dragon identity and offline play must stand out.
- Avoid copying Blox Fruits or One Piece names and designs.

### Scope Risks

- Content volume (zones, monsters, bosses) grows fast: cut whole islands, never half systems.
- Google Play needs an adult (18+) account owner and a 14-day closed test with 12 testers.

### Open Questions

- Is explore-and-farm with Seed skills fun on the user's phone? (prototype v2)

---

## MVP Definition

**Core hypothesis**: Roaming an island, killing monsters with fast attacks and Seed skills
while XP, levels and loot pour in makes the player want to keep playing.

**Required for MVP (Tier A, one island)**:
1. Player with joystick, auto-aimed attack, dodge, 3 Seed skill buttons.
2. One island with 3 zones (beach, forest, ruins) and 4 monster types; one boss.
3. XP, levels, stats; gold and item drops; a safe point to bank loot.
4. Two Seeds (fire, ice) with 3 skills each; Seed drop from the boss and a rare world spawn.
5. Harsh death rule; title, pause, settings; local save.
6. Android debug APK at 60 fps on the user's phone.

**Explicitly NOT in MVP**: other islands, the Dragon Seed, equipment crafting, shops beyond a basic one, English localisation, store release.

### Scope Tiers

| Tier | Content | Timeline |
| ---- | ---- | ---- |
| **A — MVP** | 1 island, 4 monsters, 1 boss, 2 Seeds | 8-12 weeks |
| **B — First release** | 2 islands, 3 Seeds, 2 bosses, shop, PT-BR + EN, signed AAB | 4-6 months |
| **C — Full vision** | 4 islands, 4 Seeds + Dragon Seed and dragon form | 6-9+ months |

---

## Decision Log (autonomous mode)

| Decision | Choice | Alternatives | Who |
| ---- | ---- | ---- | ---- |
| v1 concept | Souls-like island guardians, Seeds, dragon heart | — | User (superseded) |
| Prototype 1 verdict | PIVOT: souls-like duel was slow, too little to do, no reward, unappealing | Proceed; kill | User |
| New loop | Explore and farm (Blox-Fruits-like) | MOBA skills; hordes | User |
| Visuals | Pixel art (Kenney CC0) — "Pixel Archipelago" | Shadow and Flame; cartoon | User |
| Seeds | Each Seed gives 3 skills; Seeds level with use | Stat-only Seeds | User |
| Death | Lose all carried gold and items; keep levels, gear, Seeds | Lose some gold; lose nothing | User |
| Engine | Godot 4.7.2 | — | User |
| Process | Rigor standard until the Tier A fun check, then full | — | User (PR-SCOPE) |

Director gates on v1: CD-PILLARS CONCERNS (resolved) · AD-CONCEPT-VISUAL STRONG (direction later replaced by the user) · TD-FEASIBILITY CONCERNS · PR-SCOPE OPTIMISTIC (adjustments applied). v2 gates: not run (rigor standard → lean review mode until the Tier A fun check).

---

## Next Steps

1. `/prototype explore-and-farm` — v2 prototype on the user's phone.
2. On PROCEED: `/art-bible`, `/map-systems`, `/design-system` per MVP system, `/create-architecture`, `/architecture-decision`, `/gate-check`.
