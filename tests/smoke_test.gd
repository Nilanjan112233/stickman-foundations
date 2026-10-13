extends SceneTree

## Headless Smoke Test for Stickman Foundations.
## Validates scene loading, unit logic, damage handling, death state,
## combat state machine, economy, reinforcement loop, destructible bases,
## and victory conditions.
##
## Usage:
##   godot --headless -s tests/smoke_test.gd

var failures: int = 0
var tests_run: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("==================================================")
	print("RUNNING SMOKE TEST: Stickman Foundations")
	print("==================================================")

	test_scene_resources_exist()
	test_unit_instantiation_and_defaults()
	test_damage_clamping_and_health_reduction()
	test_attack_damage_lands_at_contact()
	test_death_state_and_single_signal_emission()
	test_dead_unit_ignores_further_damage()
	test_two_unit_combat_simulation()
	await test_economy_and_reinforcement_loop()
	await test_retargeting_and_dead_unit_cleanup()
	await test_battle_restart_safety()
	test_base_entity_and_combat_logic()
	await test_base_targeting_contact_damage_and_positioning()
	await test_base_destruction_and_victory_condition()
	test_tactical_archetypes_and_archer_mechanics()
	await test_arrow_projectile_physics_and_impact()
	await test_tactical_economy_dual_training_and_shared_cap()
	await test_deterministic_red_reinforcement_sequence()
	await test_ranged_targeting_base_assault_and_victory()

	print("==================================================")
	if failures == 0:
		print("ALL %d TESTS PASSED SUCCESSFULLY!" % tests_run)
		print("==================================================")
		quit(0)
	else:
		printerr("TEST FAILED! %d failure(s) out of %d test(s)." % [failures, tests_run])
		print("==================================================")
		quit(1)

func assert_true(condition: bool, test_name: String) -> void:
	tests_run += 1
	if condition:
		print("[PASS] %s" % test_name)
	else:
		failures += 1
		printerr("[FAIL] %s" % test_name)

func assert_almost_equal(a: float, b: float, tolerance: float, test_name: String) -> void:
	tests_run += 1
	if absf(a - b) <= tolerance:
		print("[PASS] %s (Expected ~%f, Got %f)" % [test_name, b, a])
	else:
		failures += 1
		printerr("[FAIL] %s (Expected ~%f, Got %f, Diff %f > %f)" % [test_name, b, a, absf(a - b), tolerance])

func test_scene_resources_exist() -> void:
	print("\n--- Test Suite 1: Resource Loading ---")
	assert_true(ResourceLoader.exists("res://scenes/main.tscn"), "Main scene resource exists")
	assert_true(ResourceLoader.exists("res://scenes/unit.tscn"), "Unit scene resource exists")
	assert_true(ResourceLoader.exists("res://scenes/base.tscn"), "Base scene resource exists")
	assert_true(ResourceLoader.exists("res://scenes/projectile.tscn"), "Projectile scene resource exists")
	assert_true(ResourceLoader.exists("res://scripts/projectile.gd"), "Projectile script resource exists")

	var main_res = load("res://scenes/main.tscn")
	assert_true(main_res != null, "Main scene loads successfully")

	var unit_res = load("res://scenes/unit.tscn")
	assert_true(unit_res != null, "Unit scene loads successfully")

	var base_res = load("res://scenes/base.tscn")
	assert_true(base_res != null, "Base scene loads successfully")

	var proj_res = load("res://scenes/projectile.tscn")
	assert_true(proj_res != null, "Projectile scene loads successfully")

func test_unit_instantiation_and_defaults() -> void:
	print("\n--- Test Suite 2: Unit Instantiation & Defaults ---")
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	assert_true(unit != null, "Unit scene instantiates StickmanUnit class")

	# Add to tree temporarily so @onready variables resolve
	root.add_child(unit)

	assert_true(unit.is_alive(), "Newly created unit is alive")
	assert_almost_equal(unit.current_health, 100.0, 0.01, "Default current health is 100")
	assert_almost_equal(unit.max_health, 100.0, 0.01, "Default max health is 100")
	assert_almost_equal(unit.move_speed, 90.0, 0.01, "Default move speed is 90")
	assert_almost_equal(unit.attack_range, 55.0, 0.01, "Default attack range is 55")
	assert_true(unit.current_state == StickmanUnit.State.WALK, "Initial state is WALK")

	unit.queue_free()

func test_damage_clamping_and_health_reduction() -> void:
	print("\n--- Test Suite 3: Damage & Health Clamping ---")
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(unit)

	unit.take_damage(25.0)
	assert_almost_equal(unit.current_health, 75.0, 0.01, "Health decreases accurately from 100 to 75")
	assert_true(unit.is_alive(), "Unit remains alive with 75 HP")

	# Taking negative damage should not heal
	unit.take_damage(-50.0)
	assert_almost_equal(unit.current_health, 75.0, 0.01, "Negative damage is ignored and does not heal")

	# Overkill damage must clamp at 0
	unit.take_damage(300.0)
	assert_almost_equal(unit.current_health, 0.0, 0.001, "Excessive damage clamps health cleanly at 0.0")
	assert_true(not unit.is_alive(), "Unit is no longer alive when health is 0")

	unit.queue_free()

func test_attack_damage_lands_at_contact() -> void:
	print("\n--- Test Suite 4: Attack Contact Timing ---")
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")

	var attacker: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(attacker)
	attacker.global_position = Vector2(0.0, 540.0)
	attacker.configure("blue", 100.0, 90.0, 55.0, 15.0, 0.7, 1)

	var defender: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(defender)
	defender.global_position = Vector2(55.0, 540.0)
	defender.configure("red", 100.0, 90.0, 55.0, 12.0, 0.7, -1)

	attacker.set_target(defender)
	attacker._transition_to_state(StickmanUnit.State.ATTACK)
	var attack_signal_count: Array[int] = [0]
	attacker.attack_performed.connect(func(_attacker, _target, _damage): attack_signal_count[0] += 1)

	# Starting the punch must not apply damage before the fist reaches the target.
	attacker._physics_process(1.0 / 60.0)
	assert_almost_equal(defender.current_health, 100.0, 0.01, "Punch start does not reduce health")

	attacker._physics_process(StickmanUnit.ATTACK_ANIM_DURATION * 0.49)
	assert_almost_equal(defender.current_health, 100.0, 0.01, "Health remains unchanged before contact")

	attacker._physics_process(StickmanUnit.ATTACK_ANIM_DURATION * 0.02)
	assert_almost_equal(defender.current_health, 85.0, 0.01, "Health decreases when fist reaches peak extension")
	assert_true(attack_signal_count[0] == 1, "Attack event emits once at contact")

	attacker._physics_process(0.05)
	assert_almost_equal(defender.current_health, 85.0, 0.01, "One punch cannot deal duplicate damage")

	attacker.queue_free()
	defender.queue_free()

	# A lethal hit can trigger retargeting inside take_damage(). The attack event
	# must still carry the unit that was actually struck instead of a cleared target.
	var lethal_attacker: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(lethal_attacker)
	lethal_attacker.global_position = Vector2(0.0, 540.0)
	lethal_attacker.configure("blue", 100.0, 90.0, 55.0, 15.0, 0.7, 1)

	var lethal_defender: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(lethal_defender)
	lethal_defender.global_position = Vector2(55.0, 540.0)
	lethal_defender.configure("red", 15.0, 90.0, 55.0, 12.0, 0.7, -1)

	var emitted_target: Array[Node2D] = [null]
	lethal_defender.died.connect(func(_dead_unit): lethal_attacker.set_target(null))
	lethal_attacker.attack_performed.connect(
		func(_attacker, struck_target, _damage): emitted_target[0] = struck_target
	)
	lethal_attacker.set_target(lethal_defender)
	lethal_attacker._transition_to_state(StickmanUnit.State.ATTACK)
	lethal_attacker._physics_process(1.0 / 60.0)
	lethal_attacker._physics_process(StickmanUnit.ATTACK_ANIM_DURATION * 0.51)

	assert_true(not lethal_defender.is_alive(), "Contact hit can defeat its target")
	assert_true(emitted_target[0] == lethal_defender, "Lethal attack event preserves the struck target")

	lethal_attacker.queue_free()
	lethal_defender.queue_free()

func test_death_state_and_single_signal_emission() -> void:
	print("\n--- Test Suite 5: Death State & Signal Emission ---")
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(unit)

	var death_signal_count: Array[int] = [0]
	unit.died.connect(func(_dead_unit): death_signal_count[0] += 1)

	unit.take_damage(100.0)

	assert_true(unit.current_state == StickmanUnit.State.DEAD, "Unit transitions to DEAD state on lethal damage")
	assert_true(death_signal_count[0] == 1, "Died signal emitted exactly once on death")

	# Repeated lethal damage should NOT emit signal again
	unit.take_damage(50.0)
	assert_true(death_signal_count[0] == 1, "Died signal is not emitted repeatedly after death")

	unit.queue_free()

func test_dead_unit_ignores_further_damage() -> void:
	print("\n--- Test Suite 6: Dead Unit Invariance ---")
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var unit: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(unit)

	unit.take_damage(100.0) # Lethal
	assert_true(unit.current_state == StickmanUnit.State.DEAD, "Unit is dead")

	unit.take_damage(40.0)
	assert_almost_equal(unit.current_health, 0.0, 0.001, "Health remains clamped at 0.0 after extra damage")

	# Dead unit cannot transition back to WALK
	unit._transition_to_state(StickmanUnit.State.WALK)
	assert_true(unit.current_state == StickmanUnit.State.DEAD, "Dead unit cannot transition out of DEAD state")

	unit.queue_free()

func test_two_unit_combat_simulation() -> void:
	print("\n--- Test Suite 7: Two-Unit Combat Simulation ---")
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")

	var blue: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(blue)
	blue.global_position = Vector2(280.0, 540.0)
	blue.configure("blue", 100.0, 90.0, 55.0, 15.0, 0.7, 1)

	var red: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(red)
	red.global_position = Vector2(1000.0, 540.0)
	red.configure("red", 100.0, 90.0, 55.0, 12.0, 0.7, -1)

	blue.set_target(red)
	red.set_target(blue)

	# Simulate 3.7 seconds of movement until combat range
	var delta: float = 1.0 / 60.0
	var total_time: float = 0.0
	while total_time < 3.7:
		blue._physics_process(delta)
		red._physics_process(delta)
		total_time += delta

	var distance: float = absf(red.global_position.x - blue.global_position.x)
	assert_almost_equal(distance, 55.0, 1.5, "Units close distance and stop at attack range (55px)")
	assert_true(blue.current_state == StickmanUnit.State.ATTACK, "Blue transitioned to ATTACK state")
	assert_true(red.current_state == StickmanUnit.State.ATTACK, "Red transitioned to ATTACK state")

	# Simulate combat for up to 6 seconds more
	var max_combat_time: float = 6.0
	var elapsed_combat: float = 0.0
	while elapsed_combat < max_combat_time and blue.is_alive() and red.is_alive():
		blue._physics_process(delta)
		red._physics_process(delta)
		elapsed_combat += delta

	assert_true(blue.is_alive(), "Blue unit survived the duel")
	assert_true(not red.is_alive(), "Red unit was defeated due to configured lower damage")
	assert_true(red.current_state == StickmanUnit.State.DEAD, "Red is in DEAD state")

	blue.queue_free()
	red.queue_free()

func test_economy_and_reinforcement_loop() -> void:
	print("\n--- Test Suite 8: Economy & Reinforcement Loop ---")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	assert_true(main_node.get_node_or_null("BaseContainer/BlueBase") != null, "Blue base exists")
	assert_true(main_node.get_node_or_null("BaseContainer/RedBase") != null, "Red base exists")
	assert_true(main_node.gold == 25, "Battle starts with 25 gold")
	assert_true(main_node.get_blue_unit_count() == 1, "Battle starts with one Blue unit")
	assert_true(main_node.get_red_unit_count() == 1, "Battle starts with one Red unit")

	main_node._on_train_button_pressed()
	assert_true(main_node.gold == 0, "Training spends exactly 25 gold")
	assert_true(main_node.get_blue_unit_count() == 2, "Training adds one Blue reinforcement")
	assert_true(main_node.train_button.disabled, "Training button disables without enough gold")

	main_node._process_passive_income(0.99)
	assert_true(main_node.gold == 0, "Gold is not awarded before a full second")
	main_node._process_passive_income(0.01)
	assert_true(main_node.gold == 5, "One full second awards 5 gold")
	main_node._process_passive_income(4.0)
	assert_true(main_node.gold == 25, "Five seconds of income restores the training cost")

	main_node._process_enemy_reinforcements(5.0)
	assert_true(main_node.get_red_unit_count() == 2, "Enemy timer adds one Red reinforcement")

	main_node.gold = 1000
	while main_node.get_blue_unit_count() < 6:
		main_node._on_train_button_pressed()
	var gold_at_cap: int = main_node.gold
	main_node._on_train_button_pressed()
	assert_true(main_node.get_blue_unit_count() == 6, "Blue population is capped at six living units")
	assert_true(main_node.gold == gold_at_cap, "Attempting to exceed the unit cap does not spend gold")
	assert_true(main_node.train_button.disabled, "Training button disables at the unit cap")

	main_node._on_restart_button_pressed()
	await process_frame
	assert_true(main_node.gold == 25, "Restart resets gold to 25")
	assert_true(main_node.get_blue_unit_count() == 1, "Restart resets Blue to one unit")
	assert_true(main_node.get_red_unit_count() == 1, "Restart resets Red to one unit")

	main_node.queue_free()
	await process_frame

func test_retargeting_and_dead_unit_cleanup() -> void:
	print("\n--- Test Suite 9: Retargeting & Dead Unit Cleanup ---")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	var surviving_blue: StickmanUnit = main_node.blue_unit
	var fallen_red: StickmanUnit = main_node.red_unit
	fallen_red.take_damage(100.0)

	assert_true(main_node.get_red_unit_count() == 0, "Defeated Red unit leaves the living-unit roster")
	assert_true(main_node.dead_units.size() == 1, "Defeated unit enters delayed cleanup")
	assert_true(surviving_blue.target == main_node.red_base, "A surviving unit targets the enemy base when no enemy units remain")

	main_node._process_enemy_reinforcements(5.0)
	assert_true(main_node.get_red_unit_count() == 1, "Enemy can reinforce after losing its last unit")
	assert_true(surviving_blue.target == main_node.red_unit, "A newly spawned defender causes attackers to retarget from the base to the defender")

	main_node._process_dead_unit_cleanup(1.2)
	assert_true(main_node.dead_units.is_empty(), "Expired dead unit leaves the cleanup roster")
	await process_frame
	assert_true(not is_instance_valid(fallen_red), "Expired dead unit is freed from the scene tree")

	main_node.queue_free()
	await process_frame

func test_battle_restart_safety() -> void:
	print("\n--- Test Suite 10: Battle Scene Re-Instantiation & Restart Safety ---")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	assert_true(main_node.blue_unit != null, "Blue unit spawned in main scene")
	assert_true(main_node.red_unit != null, "Red unit spawned in main scene")

	# Defensive guard: do not invoke is_alive() on null references if spawning failed
	if main_node.blue_unit == null or main_node.red_unit == null:
		main_node.queue_free()
		await process_frame
		return

	assert_true(main_node.blue_unit.is_alive(), "Blue unit alive on start")
	assert_true(main_node.red_unit.is_alive(), "Red unit alive on start")

	# Trigger restart while active and await process frame for node cleanup
	main_node._on_restart_button_pressed()
	await process_frame

	assert_true(main_node.blue_unit != null, "Blue unit valid after restart")
	assert_true(main_node.red_unit != null, "Red unit valid after restart")
	assert_true(not main_node.is_battle_over, "Battle over flag reset to false")

	# Defensive guard before accessing health after restart
	if main_node.blue_unit == null or main_node.red_unit == null:
		main_node.queue_free()
		await process_frame
		return

	assert_almost_equal(main_node.blue_unit.current_health, 100.0, 0.01, "Blue HP refreshed to 100")
	assert_almost_equal(main_node.red_unit.current_health, 100.0, 0.01, "Red HP refreshed to 100")

	main_node.queue_free()
	await process_frame

func test_base_entity_and_combat_logic() -> void:
	print("\n--- Test Suite 11: Base Entity & Combat Logic ---")
	var base_scene: PackedScene = load("res://scenes/base.tscn")
	var blue_base_test: StickmanBase = base_scene.instantiate() as StickmanBase
	var red_base_test: StickmanBase = base_scene.instantiate() as StickmanBase
	red_base_test.team = "red"

	root.add_child(blue_base_test)
	root.add_child(red_base_test)

	assert_true(blue_base_test != null, "Blue base instantiates successfully")
	assert_true(red_base_test != null, "Red base instantiates successfully")
	assert_true(blue_base_test.is_alive(), "Bases begin alive at full health")
	assert_almost_equal(blue_base_test.current_health, 500.0, 0.01, "Base begins with 500 max health")

	# Damage clamping
	blue_base_test.take_damage(50.0)
	assert_almost_equal(blue_base_test.current_health, 450.0, 0.01, "Base damage reduces health accurately")
	blue_base_test.take_damage(-20.0)
	assert_almost_equal(blue_base_test.current_health, 450.0, 0.01, "Negative base damage does not heal")

	# Destroyed signal
	var destroyed_count: Array[int] = [0]
	blue_base_test.destroyed.connect(func(_b): destroyed_count[0] += 1)

	blue_base_test.take_damage(600.0)
	assert_almost_equal(blue_base_test.current_health, 0.0, 0.001, "Base damage clamps cleanly at zero")
	assert_true(not blue_base_test.is_alive(), "Base is no longer alive when health is zero")
	assert_true(destroyed_count[0] == 1, "A destroyed signal emits exactly once")

	# Dead base ignores further damage
	blue_base_test.take_damage(100.0)
	assert_almost_equal(blue_base_test.current_health, 0.0, 0.001, "A destroyed base ignores further damage")
	assert_true(destroyed_count[0] == 1, "Destroyed signal is not emitted repeatedly after destruction")

	blue_base_test.queue_free()
	red_base_test.queue_free()

func test_base_targeting_contact_damage_and_positioning() -> void:
	print("\n--- Test Suite 12: Base Targeting, Contact Damage & Positioning ---")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	var blue_unit: StickmanUnit = main_node.blue_unit
	var red_unit: StickmanUnit = main_node.red_unit
	var red_base: StickmanBase = main_node.red_base

	# Eliminate red defender
	red_unit.take_damage(100.0)
	assert_true(blue_unit.target == red_base, "Blue survivor targets Red base when Red defenders are gone")

	# Test unit moves toward the enemy base instead of freezing
	var start_x: float = blue_unit.global_position.x
	blue_unit._physics_process(0.5)
	assert_true(blue_unit.global_position.x > start_x, "That unit moves toward the enemy base instead of freezing")

	# Position blue unit right at attack range of red base (Red base front edge is 1188 - 50 = 1138)
	var red_edge_x: float = red_base.get_combat_x()
	assert_almost_equal(red_edge_x, 1138.0, 0.01, "Red base front combat anchor is at x=1138")

	blue_unit.global_position = Vector2(red_edge_x - 55.0, 540.0)
	blue_unit._transition_to_state(StickmanUnit.State.ATTACK)

	# Verify punch damage reaches base only at contact time
	var base_hp_before: float = red_base.current_health
	blue_unit._physics_process(1.0 / 60.0)
	assert_almost_equal(red_base.current_health, base_hp_before, 0.01, "Punch start does not damage base")

	blue_unit._physics_process(StickmanUnit.ATTACK_ANIM_DURATION * 0.49)
	assert_almost_equal(red_base.current_health, base_hp_before, 0.01, "Base health unchanged before punch contact")

	blue_unit._physics_process(StickmanUnit.ATTACK_ANIM_DURATION * 0.02)
	assert_almost_equal(red_base.current_health, base_hp_before - 15.0, 0.01, "Punch damage reaches a base only at contact time")

	# Verify unit stops at correct base attack position without entering base
	# Red base center is 1188, left edge is 1138. Blue attacker at attack_range stops at 1083.
	assert_true(blue_unit.global_position.x < red_edge_x, "Units stop at the correct base attack position without entering the base")
	assert_almost_equal(blue_unit.global_position.x, red_edge_x - 55.0, 0.01, "Attacker stops at exactly 55px from base outer edge")

	main_node.queue_free()
	await process_frame

func test_base_destruction_and_victory_condition() -> void:
	print("\n--- Test Suite 13: Base Destruction & Victory Condition ---")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	# Deliver a lethal unit punch to reproduce the real event order: the base's
	# destroyed signal fires before the unit's attack_performed signal.
	main_node.red_base.take_damage(485.0)
	main_node.blue_unit.global_position.x = main_node.red_base.get_combat_x() - main_node.blue_unit.attack_range
	main_node.blue_unit.set_target(main_node.red_base)
	main_node.blue_unit._transition_to_state(StickmanUnit.State.ATTACK)
	main_node.blue_unit._physics_process(0.0)
	main_node.blue_unit._physics_process(StickmanUnit.ATTACK_ANIM_DURATION * 0.51)
	assert_true(main_node.is_battle_over, "Destroying Red's base produces a victory state")
	assert_true(main_node.winner_name == "Blue", "Destroying Red's base produces a Blue victory")
	assert_true("BLUE WINS" in main_node.status_label.text, "HUD status displays Blue victory message")
	assert_true(main_node.status_label.text == "BLUE WINS! The enemy base has been destroyed.", "Final hit cannot overwrite the victory message")

	# Income, enemy spawning, and training stop after victory
	var gold_at_victory: int = main_node.gold
	var red_units_at_victory: int = main_node.get_red_unit_count()
	var blue_units_at_victory: int = main_node.get_blue_unit_count()

	main_node._process_passive_income(2.0)
	assert_true(main_node.gold == gold_at_victory, "Income stops after victory")

	main_node._process_enemy_reinforcements(10.0)
	assert_true(main_node.get_red_unit_count() == red_units_at_victory, "Enemy spawning stops after victory")

	main_node._on_train_button_pressed()
	assert_true(main_node.get_blue_unit_count() == blue_units_at_victory, "Training is prevented after victory")
	assert_true(main_node.train_button.disabled, "Training button is disabled after victory")

	# Surviving units have target cleared after victory
	assert_true(main_node.blue_unit.target == null, "Surviving units stop targeting after victory")

	# Test restart restores both bases and all Milestone 2A state
	main_node._on_restart_button_pressed()
	await process_frame

	assert_true(not main_node.is_battle_over, "Restart clears battle over state")
	assert_true(main_node.winner_name == "", "Restart clears winner name")
	assert_true(main_node.blue_base.is_alive(), "Restart restores Blue base to alive")
	assert_true(main_node.red_base.is_alive(), "Restart restores Red base to alive")
	assert_almost_equal(main_node.blue_base.current_health, 500.0, 0.01, "Restart restores Blue base health to 500")
	assert_almost_equal(main_node.red_base.current_health, 500.0, 0.01, "Restart restores Red base health to 500")
	assert_true(not main_node.red_base.visual.is_destroyed, "Restart resets base visual destroyed state")
	assert_true(main_node.gold == 25, "Restart restores gold to 25")
	assert_true(main_node.get_blue_unit_count() == 1, "Restart restores Blue roster to one unit")
	assert_true(main_node.get_red_unit_count() == 1, "Restart restores Red roster to one unit")
	assert_true(not main_node.train_button.disabled, "Training button re-enables after restart")

	# Test destroying Blue base produces Red victory
	main_node.blue_base.take_damage(500.0)
	assert_true(main_node.is_battle_over, "Destroying Blue's base produces a victory state")
	assert_true(main_node.winner_name == "Red", "Destroying Blue's base produces a Red victory")
	assert_true("RED WINS" in main_node.status_label.text, "HUD status displays Red victory message")

	main_node.queue_free()
	await process_frame

func test_tactical_archetypes_and_archer_mechanics() -> void:
	print("\n--- Test Suite 14: Tactical Archetypes & Archer Mechanics ---")
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")

	# 1. Fighter defaults and stats
	var fighter: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(fighter)
	assert_true(fighter.archetype == "fighter", "Default unit archetype is fighter")
	fighter.configure("blue", 100.0, 90.0, 55.0, 15.0, 0.7, 1, "fighter")
	assert_almost_equal(fighter.max_health, 100.0, 0.01, "Fighter max health is 100")
	assert_almost_equal(fighter.move_speed, 90.0, 0.01, "Fighter move speed is 90")
	assert_almost_equal(fighter.attack_range, 55.0, 0.01, "Fighter attack range is 55")
	assert_almost_equal(fighter.attack_damage, 15.0, 0.01, "Fighter attack damage is 15")
	assert_almost_equal(fighter.attack_cooldown, 0.7, 0.01, "Fighter attack cooldown is 0.7")

	# 2. Archer configuration applies specified stats
	var archer: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(archer)
	archer.configure("blue", 60.0, 70.0, 260.0, 10.0, 1.2, 1, "archer")
	assert_true(archer.archetype == "archer", "Archer archetype is archer")
	assert_almost_equal(archer.max_health, 60.0, 0.01, "Archer max health is 60")
	assert_almost_equal(archer.move_speed, 70.0, 0.01, "Archer move speed is 70")
	assert_almost_equal(archer.attack_range, 260.0, 0.01, "Archer attack range is 260")
	assert_almost_equal(archer.attack_damage, 10.0, 0.01, "Blue Archer arrow damage is 10")
	assert_almost_equal(archer.attack_cooldown, 1.2, 0.01, "Archer attack cooldown is 1.2")
	assert_true(archer.visual != null and archer.visual.archetype == "archer", "Archer visual receives archer archetype")

	# Red Archer damage check
	var red_archer: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(red_archer)
	red_archer.configure("red", 60.0, 70.0, 260.0, 9.0, 1.2, -1, "archer")
	assert_almost_equal(red_archer.attack_damage, 9.0, 0.01, "Red Archer arrow damage is 9")

	# 3. Archer attack release emits exactly one request and deals no immediate damage
	var dummy: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(dummy)
	dummy.global_position = Vector2(200.0, 540.0)
	dummy.configure("red", 100.0, 90.0, 55.0, 12.0, 0.7, -1)
	archer.global_position = Vector2(0.0, 540.0)
	archer.set_target(dummy)

	var shot_data = {"count": 0, "attacker": null, "target": null, "damage": 0.0}
	archer.ranged_shot_requested.connect(func(atk, tgt, dmg):
		shot_data["count"] += 1
		shot_data["attacker"] = atk
		shot_data["target"] = tgt
		shot_data["damage"] = dmg
	)

	archer._transition_to_state(StickmanUnit.State.ATTACK)
	archer._physics_process(0.0) # triggers _perform_attack()
	# Progress before 50%
	archer._physics_process(StickmanUnit.ATTACK_ANIM_DURATION * 0.4)
	assert_true(shot_data["count"] == 0, "No shot request emitted before 50% attack animation")
	assert_almost_equal(dummy.current_health, 100.0, 0.01, "Dummy health unchanged before release")

	# Advance to 50% progress (release point)
	archer._physics_process(StickmanUnit.ATTACK_ANIM_DURATION * 0.15)
	assert_true(shot_data["count"] == 1, "Archer release emits exactly one projectile request")
	assert_true(shot_data["attacker"] == archer, "Projectile request reports archer as attacker")
	assert_true(shot_data["target"] == dummy, "Projectile request reports dummy as target")
	assert_almost_equal(shot_data["damage"], 10.0, 0.01, "Projectile request reports correct damage")
	assert_almost_equal(dummy.current_health, 100.0, 0.01, "Archer release itself does not reduce target health")

	# Further ticks during the same attack cycle do not re-emit
	archer._physics_process(StickmanUnit.ATTACK_ANIM_DURATION * 0.4)
	assert_true(shot_data["count"] == 1, "One attack cycle creates only one projectile request")

	fighter.queue_free()
	archer.queue_free()
	red_archer.queue_free()
	dummy.queue_free()

func test_arrow_projectile_physics_and_impact() -> void:
	print("\n--- Test Suite 15: Arrow Projectile Physics, Lifetime & Impact ---")
	var arrow_scene: PackedScene = load("res://scenes/projectile.tscn")
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")

	# 1. Delta-based movement and impact timing
	var dummy: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(dummy)
	dummy.global_position = Vector2(400.0, 540.0)
	dummy.configure("red", 100.0, 90.0, 55.0, 12.0, 0.7, -1)

	var arrow: StickmanArrow = arrow_scene.instantiate() as StickmanArrow
	root.add_child(arrow)
	arrow.global_position = Vector2(200.0, 540.0)
	arrow.setup("blue", "archer", dummy, 10.0, 1, 650.0)

	# 0.1s step at 650 speed = 65 pixels travel (200 -> 265)
	arrow._physics_process(0.1)
	assert_almost_equal(arrow.global_position.x, 265.0, 0.5, "Arrow movement is delta-based")
	assert_almost_equal(dummy.current_health, 100.0, 0.01, "Arrow does not damage target before impact")

	# Connect impact signal
	var impact_data = {"count": 0, "target": null, "damage": 0.0}
	arrow.impact.connect(func(_team, _arch, tgt, dmg):
		impact_data["count"] += 1
		impact_data["target"] = tgt
		impact_data["damage"] = dmg
	)

	# Advance remaining distance (135 px at 650 px/s = ~0.21s)
	arrow._physics_process(0.25)
	assert_true(impact_data["count"] == 1, "Arrow emits impact signal exactly once on arrival")
	assert_true(impact_data["target"] == dummy, "Arrow impact reports correct target")
	assert_almost_equal(impact_data["damage"], 10.0, 0.01, "Arrow delivers configured damage")
	assert_almost_equal(dummy.current_health, 90.0, 0.01, "Arrow damages a unit only on impact")

	# Check duplicate damage prevention
	arrow._deliver_impact()
	assert_true(impact_data["count"] == 1, "One arrow cannot deal duplicate damage")

	# 2. Lethal damage callback struck target preservation
	var lethal_dummy: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(lethal_dummy)
	lethal_dummy.global_position = Vector2(300.0, 540.0)
	lethal_dummy.configure("red", 10.0, 90.0, 55.0, 12.0, 0.7, -1)

	var lethal_arrow: StickmanArrow = arrow_scene.instantiate() as StickmanArrow
	root.add_child(lethal_arrow)
	lethal_arrow.global_position = Vector2(300.0, 540.0)
	lethal_arrow.setup("blue", "archer", lethal_dummy, 10.0, 1, 650.0)

	var lethal_data = {"target": null}
	lethal_arrow.impact.connect(func(_t, _a, tgt, _dmg): lethal_data["target"] = tgt)
	lethal_arrow._deliver_impact()
	assert_true(lethal_data["target"] == lethal_dummy, "Arrow preserves actual struck target across lethal damage callbacks")
	assert_true(lethal_dummy.current_state == StickmanUnit.State.DEAD, "Lethal arrow defeats target")

	# 3. Arrow disappears harmlessly if target dies before impact
	var doomed_dummy: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(doomed_dummy)
	doomed_dummy.global_position = Vector2(600.0, 540.0)

	var in_flight_arrow: StickmanArrow = arrow_scene.instantiate() as StickmanArrow
	root.add_child(in_flight_arrow)
	in_flight_arrow.global_position = Vector2(200.0, 540.0)
	in_flight_arrow.setup("blue", "archer", doomed_dummy, 10.0, 1, 650.0)

	doomed_dummy.take_damage(100.0) # Target dies while arrow in flight
	in_flight_arrow._physics_process(0.1)
	assert_true(in_flight_arrow.is_queued_for_deletion(), "Arrow disappears harmlessly if its target dies before impact")

	# 4. Arrow disappears harmlessly if target is freed
	var freed_dummy: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(freed_dummy)
	var arrow_freed: StickmanArrow = arrow_scene.instantiate() as StickmanArrow
	root.add_child(arrow_freed)
	arrow_freed.setup("blue", "archer", freed_dummy, 10.0, 1, 650.0)
	freed_dummy.queue_free()
	arrow_freed._physics_process(0.1)
	assert_true(arrow_freed.is_queued_for_deletion(), "Arrow disappears harmlessly if its target is freed")

	# 5. Arrow lifetime cleanup works
	var far_dummy: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	root.add_child(far_dummy)
	far_dummy.global_position = Vector2(9999.0, 540.0)
	var timed_arrow: StickmanArrow = arrow_scene.instantiate() as StickmanArrow
	root.add_child(timed_arrow)
	timed_arrow.setup("blue", "archer", far_dummy, 10.0, 1, 650.0)
	timed_arrow._physics_process(2.05)
	assert_true(timed_arrow.is_queued_for_deletion(), "Arrow lifetime cleanup works")

	dummy.queue_free()
	lethal_dummy.queue_free()
	doomed_dummy.queue_free()
	far_dummy.queue_free()

func test_tactical_economy_dual_training_and_shared_cap() -> void:
	print("\n--- Test Suite 16: Tactical Economy, Dual Training & Shared Cap ---")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	assert_true(main_node.FIGHTER_COST == 25, "Fighter costs 25 gold")
	assert_true(main_node.ARCHER_COST == 40, "Archer costs 40 gold")

	# Starting gold is 25: fighter affordable, archer not affordable
	assert_true(not main_node.train_fighter_button.disabled, "Fighter button is enabled at 25 gold")
	assert_true(main_node.train_archer_button.disabled, "Insufficient gold disables only the unaffordable choices")

	# Attempting to train Archer with 25 gold fails and does not spend gold
	main_node._on_train_archer_pressed()
	assert_true(main_node.gold == 25, "Failed training does not spend gold")
	assert_true(main_node.get_blue_unit_count() == 1, "Failed training does not spawn units")

	# Train Fighter: spends 25 gold, gold becomes 0, adds 1 unit
	main_node._on_train_fighter_pressed()
	assert_true(main_node.gold == 0, "Training Fighter spends exactly 25 gold")
	assert_true(main_node.get_blue_unit_count() == 2, "Training Fighter adds one Blue unit")
	assert_true(main_node.train_fighter_button.disabled, "Fighter button disables at 0 gold")
	assert_true(main_node.train_archer_button.disabled, "Archer button disables at 0 gold")

	# Add income until 40 gold (8 seconds)
	main_node._process_passive_income(8.0)
	assert_true(main_node.gold == 40, "Passive income accumulates to 40 gold")
	assert_true(not main_node.train_fighter_button.disabled, "Fighter button enabled at 40 gold")
	assert_true(not main_node.train_archer_button.disabled, "Archer button enabled at 40 gold")

	# Train Archer: spends 40 gold, gold becomes 0, adds 1 Archer
	main_node._on_train_archer_pressed()
	assert_true(main_node.gold == 0, "Training Archer spends exactly 40 gold")
	assert_true(main_node.get_blue_unit_count() == 3, "Training Archer adds one Blue unit")
	assert_true(main_node.blue_units[2].archetype == "archer", "Spawned unit is an Archer")

	# Shared 6-unit population cap test
	main_node.gold = 1000
	main_node._update_economy_hud()
	while main_node.get_blue_unit_count() < 6:
		main_node._on_train_archer_pressed()
	assert_true(main_node.get_blue_unit_count() == 6, "Shared six-unit population cap works across both archetypes")
	assert_true(main_node.train_fighter_button.disabled, "Fighter button disabled at shared unit cap")
	assert_true(main_node.train_archer_button.disabled, "Archer button disabled at shared unit cap")

	var gold_before_attempt: int = main_node.gold
	main_node._on_train_fighter_pressed()
	main_node._on_train_archer_pressed()
	assert_true(main_node.get_blue_unit_count() == 6, "Roster remains at 6 when attempting to train past cap")
	assert_true(main_node.gold == gold_before_attempt, "Attempting to train at cap does not spend gold")

	main_node.queue_free()
	await process_frame

func test_deterministic_red_reinforcement_sequence() -> void:
	print("\n--- Test Suite 17: Deterministic Red Reinforcement Sequence ---")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	# Starting Red unit is Fighter
	assert_true(main_node.red_units[0].archetype == "fighter", "Starting Red unit is a Fighter")

	# Reinforcement 1 (at 5.0s): Fighter
	main_node._process_enemy_reinforcements(5.0)
	assert_true(main_node.get_red_unit_count() == 2, "Red deploys first reinforcement")
	assert_true(main_node.red_units[1].archetype == "fighter", "First reinforcement is Fighter")

	# Reinforcement 2 (at 10.0s): Fighter
	main_node._process_enemy_reinforcements(5.0)
	assert_true(main_node.get_red_unit_count() == 3, "Red deploys second reinforcement")
	assert_true(main_node.red_units[2].archetype == "fighter", "Second reinforcement is Fighter")

	# Reinforcement 3 (at 15.0s): Archer
	main_node._process_enemy_reinforcements(5.0)
	assert_true(main_node.get_red_unit_count() == 4, "Red deploys third reinforcement")
	assert_true(main_node.red_units[3].archetype == "archer", "Red reinforcement sequence follows Fighter, Fighter, Archer")

	# Reinforcement 4 (at 20.0s): Fighter (loop repeats)
	main_node._process_enemy_reinforcements(5.0)
	assert_true(main_node.get_red_unit_count() == 5, "Red deploys fourth reinforcement")
	assert_true(main_node.red_units[4].archetype == "fighter", "Fourth reinforcement is Fighter")

	# Restart resets sequence index
	main_node._on_restart_button_pressed()
	await process_frame
	assert_true(main_node.red_reinforcement_index == 0, "Restart resets the reinforcement sequence")
	assert_true(main_node.get_red_unit_count() == 1, "Restart resets Red roster to one unit")
	assert_true(main_node.red_units[0].archetype == "fighter", "Reset starting unit is Fighter")

	# Next reinforcement after restart is Fighter
	main_node._process_enemy_reinforcements(5.0)
	assert_true(main_node.get_red_unit_count() == 2, "Post-restart reinforcement deploys")
	assert_true(main_node.red_units[1].archetype == "fighter", "Post-restart first reinforcement is Fighter")

	main_node.queue_free()
	await process_frame

func test_ranged_targeting_base_assault_and_victory() -> void:
	print("\n--- Test Suite 18: Ranged Targeting, Base Assault & Projectile Victory ---")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	# 1. Targeting priority: Archer prioritizes living defender before base
	main_node.gold = 100
	main_node._on_train_archer_pressed()
	var blue_archer: StickmanUnit = main_node.blue_units[1]
	assert_true(blue_archer.archetype == "archer", "Trained unit is Archer")
	assert_true(blue_archer.target == main_node.red_units[0], "Fighters and Archers prioritize living defenders before bases")

	# 2. When defender dies, Archer retargets enemy base
	main_node.red_units[0].take_damage(100.0) # Defeat Red defender
	main_node._process_dead_unit_cleanup(0.0)
	main_node._retarget_all_units()
	assert_true(blue_archer.target == main_node.red_base, "Archer targets enemy base when defenders are defeated")

	# 3. Archer advances to ranged distance from base
	# Red base combat anchor is at 1138. Archer range is 260. Archer stops at 1138 - 260 = 878.
	var delta: float = 1.0 / 60.0
	var sim_time: float = 0.0
	while sim_time < 12.0 and blue_archer.current_state != StickmanUnit.State.ATTACK:
		blue_archer._physics_process(delta)
		sim_time += delta
	assert_true(blue_archer.current_state == StickmanUnit.State.ATTACK, "Archer can attack a base from ranged distance")
	assert_almost_equal(blue_archer.global_position.x, 878.0, 1.5, "Archer stops at exactly 260px from base combat anchor")

	# 4. Projectile-caused base destruction produces correct winner
	main_node.red_base.current_health = 5.0 # Low HP base
	blue_archer._perform_attack()
	# Step through to release point
	blue_archer._physics_process(StickmanUnit.ATTACK_ANIM_DURATION * 0.55)
	assert_true(main_node.projectile_container.get_child_count() > 0, "Archer creates arrow in projectile container")

	# Process arrow movement to hit base
	var arrow: StickmanArrow = main_node.projectile_container.get_child(0) as StickmanArrow
	assert_true(arrow != null, "Arrow projectile is valid")
	arrow._physics_process(1.0) # Step arrow to impact base

	assert_true(main_node.is_battle_over, "Projectile-caused base destruction produces the correct winner")
	assert_true(main_node.winner_name == "Blue", "Destroying Red base produces Blue victory")
	assert_true("BLUE WINS" in main_node.status_label.text, "Status displays Blue victory")

	# 5. Final projectile impact cannot overwrite victory message
	main_node._on_projectile_impact("red", "archer", main_node.blue_base, 10.0)
	assert_true("BLUE WINS" in main_node.status_label.text, "Final projectile impact text cannot overwrite the winner message")

	# 6. Victory cancels remaining projectiles
	var stray_arrow = load("res://scenes/projectile.tscn").instantiate()
	main_node.projectile_container.add_child(stray_arrow)
	main_node._end_battle("Blue")
	assert_true(stray_arrow.is_queued_for_deletion() or stray_arrow.is_cancelled, "Victory cancels remaining projectiles")

	# 7. Restart removes all projectiles and restores buttons
	main_node._on_restart_button_pressed()
	await process_frame
	assert_true(main_node.projectile_container.get_child_count() == 0, "Restart removes all projectiles")
	assert_true(not main_node.train_fighter_button.disabled, "Restart restores both training buttons correctly (Fighter enabled)")
	assert_true(main_node.train_archer_button.disabled, "Restart restores Archer button correctly (costs 40, starts with 25)")

	main_node.queue_free()
	await process_frame
