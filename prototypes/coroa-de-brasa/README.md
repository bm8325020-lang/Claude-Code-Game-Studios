# Prototype: Coroa de Brasa

Isometric action RPG for Android phones (Godot 4.7, GDScript, Compatibility renderer).

## Hypothesis

A short-session dungeon crawler (rooms, a blessing after each room, a boss per floor) with a village to spend
gold in between is more fun on a phone than an open world, and looks finished when every asset comes from one
art family (KayKit, CC0).

## Run

- Desktop: `godot --path .` (WASD move, J attack, Space dodge, 1/2/3 skills, Q potion, E use, Esc pause; the
  mouse works as touch).
- Android: export the `Android` preset (arm64).
- Test robot: `COROA_AUTOPLAY=1 godot --headless --path . --quit-after 6000` plays runs on its own and prints the
  end-of-run messages.

## How it plays

- Village (`hub.gd`): hex island with the hero altar (pick one of five heroes, unlock with gold, eight armour
  colours), the forge (permanent upgrades) and the portal.
- Run (`main.gd`, `room.gd`): three floors (Cripta Esquecida, Floresta Sombria, Fortaleza da Brasa), five or six
  rooms each and a boss (`boss.gd`: slam, spin, nova, homing orbs, summons; phase 2 under half HP). Clear a room,
  pick one of three blessings (`data.gd` BLESSINGS: damage, attack speed, life, crit, life steal, cooldowns,
  burn, chain lightning, thorns, speed, potions, gold), walk through the gate.
- Heroes (`hero.gd`, `data.gd` HEROES): Cavaleiro, Bárbaro, Maga, Ladina, Arqueiro. Auto-aimed 3-hit combo,
  dodge with invulnerability, potion, three skills each (charge, shield bash, spin; leap, rage, whirlwind;
  fireball, blink, meteors; knife fan, shadow step, blade storm; volley, roll shot, arrow rain).
- Enemies (`enemy.gd`): skeleton minions, warriors, crossbowmen and necromancers (homing orbs, summons); elites
  are bigger and glow. Every attack shows a red ring on the floor first.
- You keep the gold and XP of a run even when you fall. Hero levels add 6% life and damage each.

## Art and sound (all CC0)

KayKit by Kay Lousberg: Adventurers 2.0, Skeletons 1.1, Character Animations 1.1 (Rig_Medium), Dungeon Pack
1.1, Forest Nature Pack 1.0, Medieval Hexagon Pack 1.0. Kenney: RPG Audio, Impact Sounds, Music Jingles.

## Status

In progress.
