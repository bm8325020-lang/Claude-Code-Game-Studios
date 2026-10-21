# Concept Prototype Report: Combat Feel (souls-like dodge & punish)

*Date: 2026-10-21 · Path: Engine (Godot 4.7.2, debug APK on the user's Android phone)*

## Hypothesis

If the player dodges through a telegraphed attack and punishes the recovery with touch
controls, it feels satisfying and fair — true if the player lands 3+ dodge→punish chains
within 2 minutes and calls it fair and responsive.

## Riskiest Assumption Tested

Heavy, precise souls-like combat is fun on a phone with a virtual joystick and two buttons.

## Approach

One arena, one guardian with two telegraphed attacks (slam ring, locked lunge line), player
with move, light attack, dodge with i-frames, 150 ms input buffer, hit-stop, perfect-dodge
slow motion and punish bonus. Placeholder shapes only. Built and verified headless plus a
recorded run under Xvfb; exported as a signed debug APK and played by the user on their phone.

## Result

REFUTED. The user found it boring and checked every listed cause:
- Too slow: too much waiting for the boss to attack and for the punish window.
- Too little to do: move, attack and dodge alone are not enough; the user wants powers, skills, combos.
- No reward: hitting the boss gave no sense of progress or gain.
- Not appealing to look at: plain shapes do not excite.

The user's preferred direction: **explore and farm** — a small open world, hunt monsters,
level up, find items (closer to Blox Fruits).

## Metrics

HUD counters were not reported; the verdict came from the user's overall reaction.
Engine pipeline result (independent of fun): Android export works end to end from the
container (templates, SDK 35, debug keystore, signed APK 57 MB).

## Recommendation: PIVOT

The souls-like duel loop is not what this player finds fun. The fantasy (rare Seeds of
power, becoming a dragon) was never tested and stays. The loop changes to explore-and-farm
with fast, skill-based combat and constant rewards.

## If Pivoting

See `PIVOT-NOTE.md`.

## Lessons Learned

- For this audience, frequent rewards and visible numbers going up matter more than mastery of one fight.
- Waiting-heavy combat (telegraph → punish) reads as slow on a phone.
- Placeholder circles undersell a prototype; the next one uses ready-made CC0 art.
- The Android export pipeline is proven; future prototypes can ship to the phone the same day.
