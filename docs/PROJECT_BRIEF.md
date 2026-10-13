# Project Brief: Stickman Foundations

## 1. Vision & Lightweight-First Philosophy

**Stickman Foundations** is an original, lightweight 2D stickman strategy game developed from the ground up in Godot 4.

The core philosophy of this project is **extreme lightweight engineering**:
1. **Minimal Footprint:** Total source and project files remain tiny, avoiding multi-megabyte art and audio assets.
2. **High Accessibility:** Designed to execute at high framerates on low-end hardware, older PCs, and budget mobile devices.
3. **Pure Code Aesthetics:** Visual presentation is driven by clean 2D vector primitives (`_draw()`), providing crisp scaling at any display resolution with zero texture memory overhead.
4. **Clean Code Architecture:** Emphasizes simple, readable, and typed GDScript structures that a beginner can study, understand, and modify without being overwhelmed by unnecessary enterprise design patterns or external dependencies.

---

## 2. Originality Requirement

This project is strictly an original creation.
- **Working Title:** *Stickman Foundations* (internal development title).
- **Prohibited Elements:**
  - No copying or borrowing of names, lore, characters, or faction concepts from *Stick War* or other commercial stickman games.
  - No decompiled, copied, or unlicensed source code.
  - No external sprite packs, textures, or copied animations.
  - All visual assets, gameplay mechanics, and balancing numbers are created uniquely for this project.

---

## 3. Educational & Beginner-Learning Objective

This project serves as an accessible introduction to 2D game programming in Godot 4.
Key learning concepts demonstrated in the codebase include:
- **Project Structure:** How scenes (`.tscn`), scripts (`.gd`), and configuration (`project.godot`) interact.
- **Finite State Machines (FSM):** Why enums and clear state transitions prevent race conditions and invalid behavior in AI combatants.
- **Delta Timing:** Moving units reliably across different monitor refresh rates using `delta`.
- **Signal-Driven Architecture:** Decoupling gameplay events (health changes, attacks, deaths) from UI updates through Godot signals.
- **Procedural Animation:** Generating responsive walking, punching, and falling motions using basic trigonometry (`sin`, `cos`) without sprite sheets.

---

## 4. Completed Milestone 1 Scope

The first milestone establishes the minimal playable combat foundation:
- Single battlefield with sky, ground, and ground baseline.
- Two procedural code-drawn stickmen: Team Blue (left) and Team Red (right).
- Walk towards each other along a fixed ground line.
- Stop within attack range (55 px).
- Trade hits deterministically via cooldown timers.
- Visual feedback on hit (damage flash, recoil offset) and health reduction on the head health bar.
- Clamped death sequence with single signal emission.
- HUD reporting combat events and declaring the winner.
- Safe, instant battle restart via UI button or the `R` key.

---

## 5. Milestone 2 Scope: Economy, Reinforcements & Destructible Bases

Milestone 2 expands the foundational 1v1 battle into a lane combat loop:

### Milestone 2A: Economy & Reinforcements
- Procedural, code-drawn bases at the battlefield flanks.
- Starting gold of 25 and passive income of 5 gold per second.
- A **Train Stickman** button costing 25 gold.
- Automatic Red reinforcements deployed every five seconds.
- A strict cap of six living units per team.
- Nearest-living-enemy targeting and retargeting after combat deaths.
- Delayed removal of fallen bodies after the death animation.

### Milestone 2B: Destructible Bases & Victory Condition
- **Destructible Bases:** Blue and Red bases (`StickmanBase`, 500 HP each) with clamped health, a single `destroyed` signal, and ruined/collapsed visual feedback (cracked masonry, darkened stone, fallen flag).
- **Generalized Combat Targeting:** Units validate and target either enemy stickmen or the enemy base using a lightweight `Node2D` combat contract (`is_alive()`, `take_damage()`, `get_combat_x()`).
- **Target Priority:** Units always prioritize living enemy defenders first. When no enemy units remain alive, attackers advance toward and strike the enemy base.
- **Dynamic Retargeting:** When a new defending unit spawns, attackers immediately retarget to the nearest living defender.
- **Base Attack Positioning:** Units stop at punch range (55 px) from the base's front combat anchor without overlapping or clipping inside.
- **Victory Condition:** Destroying Red's base declares Blue the winner; destroying Blue's base declares Red the winner. Battle end stops passive income, enemy reinforcement timers, disables the training button, and prevents further unit attacks.
- **Complete Restart:** Restores both bases to 500 HP and intact visual state, one living unit per team, 25 gold, timers, rosters, and HUD state cleanly.

---

## 6. Milestone 3 Scope: Tactical Unit Choice — Fighter & Archer

Milestone 3 introduces meaningful tactical decision-making without adding external assets or heavyweight systems:

### Tactical Archetypes
- **Fighter:** Short-range melee frontline unit.
  - Blue: 25 Gold, 100 HP, 90 Speed, 55 Range, 15 Damage, 0.7s Cooldown.
  - Red: 100 HP, 90 Speed, 55 Range, 12 Damage, 0.7s Cooldown.
  - Delivers contact-timed punch damage at peak extension.
- **Archer:** Fragile ranged support unit firing visible procedural arrows.
  - Blue: 40 Gold, 60 HP, 70 Speed, 260 Range, 10 Damage, 1.2s Cooldown.
  - Red: 60 HP, 70 Speed, 260 Range, 9 Damage, 1.2s Cooldown.
  - Emits a ranged shot request at 50% attack animation progress; does not apply melee damage.

### Procedural Projectiles (`StickmanArrow`)
- Lightweight `Node2D` with delta-based horizontal travel (650 px/s, max 2.0s lifetime).
- Drawn procedurally via `_draw()` with wood shaft, steel tip, and team-colored fletching.
- Applies damage strictly on impact; cleans itself up harmlessly if its target dies or is freed in flight.
- Preserves struck target across lethal damage callbacks.

### Dual Training Controls & Shared Population
- Separate **Train Fighter (25 Gold)** and **Train Archer (40 Gold)** buttons.
- Buttons disable independently when funds are insufficient.
- Shared 6-unit cap across both archetypes per team.

### Deterministic Enemy Reinforcements
- Red reinforcements follow a fixed, deterministic sequence: **Fighter, Fighter, Archer, Fighter, Fighter, Archer...**
- Sequence index advances only on successful deployment and resets cleanly on battle restart.

---

## 7. Long-Term Game Concepts (Deferred Systems)

The following systems are envisioned for future phases of the game. **They must NOT be implemented in early milestones** to keep the codebase focused and manageable:

1. **Advanced Tower Defence & Base Structures:** Defensive ramparts, base upgrades, and territory control.
2. **Resource Harvesting & Economy:** Workers or automated nodes gathering gold, lumber, or mana.
3. **Hunting & Hiding:** Ambient wildlife, wilderness hunting for rations/buffs, and stealth/brush concealing mechanics.
4. **Traps & Ambushes:** Deployable spikes, snares, pitfalls, and flanking tactics.
5. **Animals & Monsters:** Neutral beasts, wild predators, and wandering mythical encounters.
6. **Diverse Factions:** Asymmetric stickman factions with distinct visual styles, technology trees, and unique doctrines.
7. **Strategic Victory Conditions:** Winning battles not merely through brute combat force, but through supply starvation, diplomatic subjugation, or tactical objective capture.

---

## 8. Deliberate Deferral of Multiplayer

Multiplayer is intentionally excluded from the initial roadmap. Introducing networked multiplayer prematurely introduces severe developmental overhead:
- **Deterministic Synchronization:** Managing state replication, input prediction, and rollback across distributed devices.
- **Network Latency & Jitter:** Interpolation, reconciliation, and lag compensation.
- **Infrastructure & Hosting:** Dedicated server expenses, socket matchmaking, and peer-to-peer NAT punch-through.
- **Security & Anti-Cheat:** Validating all client actions server-side.
- **Maintenance Complexity:** Debugging multi-threaded, asynchronous networking bugs slows single-player gameplay iteration.

Focusing first on a robust single-player foundation ensures rapid feature progress and rock-solid combat logic.
