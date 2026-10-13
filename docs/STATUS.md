# Engineering Status: Stickman Foundations

## 1. Current Milestone

- **Milestone:** 3 – Tactical Unit Choice — Fighter & Archer
- **Implementation:** Complete for the defined Milestone 3 scope.
- **Automated verification:** Godot 4.7.2 parser/import passes (exit code 0); all 200 headless smoke checks pass; real main scene ran headlessly for 1,800 frames without runtime errors (exit code 0). Memory profiling remains pending.
- **Visual verification:** Pending user playtest for Archer procedural vector details (bow, quiver, drawing animation), in-flight arrow trajectories, dual training buttons, and deterministic Red reinforcement pacing.
- **Android verification:** Pending physical-device export, touch, rotation, memory, and sustained-frame-rate testing.

Starting commit: `000fa83dfc3853e923024c5afa04d9a2aca97e05` (`Add economy and destructible base battle loop`). Milestone 3 changes remain uncommitted in the working tree for user review.

---

## 2. Milestone 3 Behavior

- **Tactical Archetypes:**
  - **Fighter:** Short-range melee frontline unit.
    - Blue: 25 Gold, 100 HP, 90 Speed, 55 Range, 15 Damage, 0.7s Cooldown.
    - Red: 100 HP, 90 Speed, 55 Range, 12 Damage, 0.7s Cooldown.
    - Deals contact-timed punch damage at peak fist extension.
  - **Archer:** Fragile ranged support unit.
    - Blue: 40 Gold, 60 HP, 70 Speed, 260 Range, 10 Damage, 1.2s Cooldown.
    - Red: 60 HP, 70 Speed, 260 Range, 9 Damage, 1.2s Cooldown.
    - Stops at 260 px and draws a procedural bow. Emits a ranged shot request at 50% animation progress. Deals no melee damage.
- **Procedural Projectiles (`StickmanArrow`):**
  - Lightweight `Node2D` with delta-based horizontal movement at 650 px/s (max lifetime 2.0s).
  - Rendered with vector canvas primitives (wood shaft, steel arrowhead, team-colored fletching).
  - Damage is delivered strictly on impact; cleans itself up harmlessly if the target dies or is freed in flight.
  - In-flight arrows retain their initial target even if new defenders spawn.
  - Struck target is preserved across lethal hit callbacks.
- **Dual Training UI & Shared Population Cap:**
  - Two responsive buttons: **Train Fighter (25 Gold)** and **Train Archer (40 Gold)**.
  - Buttons disable independently when gold is insufficient (e.g. at 25 gold, Fighter is enabled, Archer is disabled).
  - Shared strict cap of 6 living units per team across all archetypes.
  - Both buttons disable at the unit cap and re-enable when slots and gold become available.
- **Deterministic Red Reinforcements:**
  - Red reinforcement sequence strictly follows: **Fighter, Fighter, Archer, Fighter, Fighter, Archer...**
  - Sequence index advances only on successful deployment and resets cleanly on battle restart.
- **Victory & Battle Termination:**
  - Destroying Red's base declares Blue victory; destroying Blue's base declares Red victory.
  - Victory immediately cancels and clears all active projectiles, stops passive income, halts enemy spawns, disables both training buttons, and ceases unit attacks.
  - Final arrow impacts cannot overwrite the winner announcement.
- **Battle Restart:**
  - Restores both bases to 500 HP and normal visual state.
  - Cancels and removes all in-flight projectiles.
  - Resets gold to 25, income accumulator to zero, enemy timer to 5.0s, and Red reinforcement sequence index to 0.
  - Spawns initial 1 Blue Fighter and 1 Red Fighter, restoring rosters and HUD cleanly.

---

## 3. Lightweight Decisions

1. **No physics bodies or colliders:** Arrow movement and impact detection use delta math (`move_toward`) and target combat coordinates.
2. **No external art assets:** Units, bows, quivers, arrows, bases, and health bars are drawn procedurally in `_draw()`.
3. **No object pools needed:** With a 12-unit shared cap and 1.2s cooldown, lightweight scene instantiation and cleanup maintain minimal footprint.
4. **Target anchors:** Both units and bases expose `get_combat_x()`, allowing arrows and units to calculate exact distances without physics shapes.
5. **Event-driven status HUD:** Labels update on combat events rather than rebuilding per frame.

---

## 4. Files Created and Modified

### Created:
- `scripts/projectile.gd` – Lightweight procedural arrow entity (`StickmanArrow`).
- `scenes/projectile.tscn` – Reusable projectile scene.

### Modified:
- `scripts/unit.gd` – Added archetype support (`fighter`, `archer`), `ranged_shot_requested` signal, and archer attack handling.
- `scripts/stickman_visual.gd` – Added procedural bow, bowstring, quiver, and ranged draw-and-release animation.
- `scenes/main.tscn` – Added `ProjectileContainer`, `TrainFighterButton`, and `TrainArcherButton`.
- `scripts/main.gd` – Added dual training logic, projectile spawning, deterministic Red reinforcement sequence, status text formatting, and victory/restart projectile clearing.
- `tests/smoke_test.gd` – Expanded test suite to 200 checks across 18 suites.
- `README.md` – Updated controls, architecture, stats, and verification records.
- `docs/PROJECT_BRIEF.md` – Documented Milestone 3 scope while keeping long-term concepts deferred.
- `docs/STATUS.md` – Current engineering log and playtest checklist.

---

## 5. Validation Evidence

### Godot Parser / Import
Command:
```powershell
& 'C:\Users\nilan\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\PROJECTS\Game' --editor --quit
```
Result: **Passed**, exit code `0`. Registered `StickmanArrow`, `StickmanVisual`, and `StickmanUnit` global classes.

### Headless Smoke Suite
Command:
```powershell
& 'C:\Users\nilan\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\PROJECTS\Game' --script 'res://tests/smoke_test.gd'
```
Result: **200/200 checks passed**, exit code `0`.

Suites covered:
1. Resource Loading (10 tests)
2. Unit Instantiation & Defaults (7 tests)
3. Damage & Health Clamping (5 tests)
4. Attack Contact Timing (7 tests)
5. Death State & Signal Emission (3 tests)
6. Dead Unit Invariance (3 tests)
7. Two-Unit Combat Simulation (6 tests)
8. Economy & Reinforcement Loop (18 tests)
9. Retargeting & Dead Unit Cleanup (7 tests)
10. Battle Scene Re-Instantiation & Restart Safety (9 tests)
11. Base Entity & Combat Logic (11 tests)
12. Base Targeting, Contact Damage & Positioning (8 tests)
13. Base Destruction & Victory Condition (23 tests)
14. Tactical Archetypes & Archer Mechanics (22 tests)
15. Arrow Projectile Physics, Lifetime & Impact (12 tests)
16. Tactical Economy, Dual Training & Shared Cap (21 tests)
17. Deterministic Red Reinforcement Sequence (14 tests)
18. Ranged Targeting, Base Assault & Projectile Victory (15 tests)

### Integrated Runtime
Command:
```powershell
& 'C:\Users\nilan\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\PROJECTS\Game' --quit-after 1800
```
Result: **1,800 frames completed**, exit code `0`, with no runtime errors observed during that run. Memory profiling remains pending.

These automated checks do not replace visual or Android-device testing.

---

## 6. Git State

- Starting commit: `000fa83dfc3853e923024c5afa04d9a2aca97e05`.
- Milestone 3 changes remain uncommitted in the working tree for user visual review.
- No files are staged, no branches or commits created, no remote configured, and nothing uploaded.

---

## 7. Required Visual Playtest

1. **Archer Visuals:** Confirm Archers render with a visible bow, bowstring, and quiver behind their back in their team color.
2. **Opening Skirmish:** Confirm the battle begins with 25 gold, one Blue Fighter, and one Red Fighter.
3. **Button Disabling at Start:** Confirm **Train Fighter (25 Gold)** is enabled, while **Train Archer (40 Gold)** is disabled due to insufficient funds.
4. **Archer Training:** Accumulate 40 gold and click **Train Archer**; confirm 40 gold is spent, an Archer deploys, and both buttons disable at 0 gold.
5. **Ranged Attack Animation:** Confirm the Archer stops at 260 px, draws the bowstring, and releases an arrow at 50% animation progress.
6. **Arrow Flight & Impact:** Confirm arrows fly horizontally at 650 px/s with steel tips and team fletching, dealing damage only on impact.
7. **Defender Priority:** Confirm an Archer targets living enemy defenders first, and switches to the base only when no defenders remain.
8. **In-Flight Arrow Targeting:** Confirm that an in-flight arrow hits its original target even if a new defender spawns after release.
9. **Red Reinforcement Mix:** Watch Red reinforce and confirm the sequence: Fighter (start), Fighter, Fighter, Archer, Fighter, Fighter, Archer.
10. **Shared Population Cap:** Train units until Blue has 6 total (mix of Fighters and Archers); confirm both training buttons disable.
11. **Projectile Victory:** Allow an arrow to destroy the enemy base; confirm victory is proclaimed, in-flight arrows are cancelled, and late impacts do not overwrite the victory text.
12. **Battle Restart:** Press `R` or click Restart; confirm bases reset to 500 HP, in-flight arrows vanish, gold resets to 25, rosters reset to 1v1 Fighters, and the reinforcement sequence resets to start with Fighters.
13. **Responsive UI:** Resize the window and confirm both training buttons, gold label, and HUD remain properly aligned and touch-friendly.

---

## 8. Next Steps

- Perform visual playtesting using the checklist above.
- Address any subjective visual tuning (e.g. bow size, arrow trail).
- Proceed to Android export, touch verification, and physical device testing when ready.
