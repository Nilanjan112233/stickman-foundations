extends Node2D

## Main battle controller for Stickman Foundations.
## Milestone 3 adds tactical unit choices (Fighter and Archer),
## procedural projectiles, deterministic enemy reinforcement mixes,
## and dual training controls.

@export var unit_scene: PackedScene = preload("res://scenes/unit.tscn")
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

# Spawn positions and ground level
const BLUE_SPAWN_X: float = 280.0
const RED_SPAWN_X: float = 1000.0
const GROUND_Y: float = 540.0

# Fighter Stats
const FIGHTER_COST: int = 25
const TRAIN_COST: int = 25 # Backwards compatibility alias
const BLUE_FIGHTER_HP: float = 100.0
const BLUE_FIGHTER_SPEED: float = 90.0
const BLUE_FIGHTER_RANGE: float = 55.0
const BLUE_FIGHTER_DMG: float = 15.0
const BLUE_FIGHTER_CD: float = 0.7

const RED_FIGHTER_HP: float = 100.0
const RED_FIGHTER_SPEED: float = 90.0
const RED_FIGHTER_RANGE: float = 55.0
const RED_FIGHTER_DMG: float = 12.0
const RED_FIGHTER_CD: float = 0.7

# Archer Stats
const ARCHER_COST: int = 40
const BLUE_ARCHER_HP: float = 60.0
const BLUE_ARCHER_SPEED: float = 70.0
const BLUE_ARCHER_RANGE: float = 260.0
const BLUE_ARCHER_DMG: float = 10.0
const BLUE_ARCHER_CD: float = 1.2

const RED_ARCHER_HP: float = 60.0
const RED_ARCHER_SPEED: float = 70.0
const RED_ARCHER_RANGE: float = 260.0
const RED_ARCHER_DMG: float = 9.0
const RED_ARCHER_CD: float = 1.2

# Projectile Stats
const ARROW_SPEED: float = 650.0
const ARROW_LIFETIME: float = 2.0

# Legacy constants preserved for regression tests
const BLUE_MAX_HP: float = 100.0
const BLUE_MOVE_SPEED: float = 90.0
const BLUE_ATTACK_RANGE: float = 55.0
const BLUE_ATTACK_DMG: float = 15.0
const BLUE_COOLDOWN: float = 0.7
const RED_MAX_HP: float = 100.0
const RED_MOVE_SPEED: float = 90.0
const RED_ATTACK_RANGE: float = 55.0
const RED_ATTACK_DMG: float = 12.0
const RED_COOLDOWN: float = 0.7

# Economy and lightweight population limits
const STARTING_GOLD: int = 25
const GOLD_PER_SECOND: int = 5
const MAX_UNITS_PER_TEAM: int = 6
const ENEMY_SPAWN_INTERVAL: float = 5.0
const DEAD_BODY_LIFETIME: float = 1.2

# Deterministic Red reinforcement sequence
const RED_REINFORCEMENT_PATTERN: Array[String] = ["fighter", "fighter", "archer"]
var red_reinforcement_index: int = 0

# Legacy first-unit references remain useful for learning and regression tests.
var blue_unit: StickmanUnit = null
var red_unit: StickmanUnit = null

var blue_units: Array[StickmanUnit] = []
var red_units: Array[StickmanUnit] = []
var dead_units: Array[StickmanUnit] = []

var gold: int = STARTING_GOLD
var income_accumulator: float = 0.0
var enemy_spawn_timer: float = ENEMY_SPAWN_INTERVAL
var blue_spawn_count: int = 0
var red_spawn_count: int = 0

var is_battle_over: bool = false
var winner_name: String = ""

# Node references
@onready var blue_base: StickmanBase = $BaseContainer/BlueBase
@onready var red_base: StickmanBase = $BaseContainer/RedBase
@onready var unit_container: Node2D = $UnitContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var status_label: Label = %StatusLabel
@onready var blue_hp_label: Label = %BlueHPLabel
@onready var red_hp_label: Label = %RedHPLabel
@onready var gold_label: Label = %GoldLabel
@onready var income_label: Label = %IncomeLabel
@onready var train_fighter_button: Button = %TrainFighterButton
@onready var train_archer_button: Button = %TrainArcherButton
@onready var train_button: Button = %TrainFighterButton # Backwards compatibility alias
@onready var restart_button: Button = %RestartButton

func _ready() -> void:
	if train_fighter_button:
		train_fighter_button.pressed.connect(_on_train_fighter_pressed)
	if train_archer_button:
		train_archer_button.pressed.connect(_on_train_archer_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if blue_base:
		blue_base.destroyed.connect(_on_blue_base_destroyed)
	if red_base:
		red_base.destroyed.connect(_on_red_base_destroyed)

	_start_battle()

func _process(delta: float) -> void:
	if is_battle_over:
		return
	_process_passive_income(delta)
	_process_enemy_reinforcements(delta)
	_process_dead_unit_cleanup(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_on_restart_button_pressed()

func _start_battle() -> void:
	is_battle_over = false
	winner_name = ""
	gold = STARTING_GOLD
	income_accumulator = 0.0
	enemy_spawn_timer = ENEMY_SPAWN_INTERVAL
	red_reinforcement_index = 0
	blue_spawn_count = 0
	red_spawn_count = 0

	if blue_base:
		blue_base.reset_base()
	if red_base:
		red_base.reset_base()

	# Remove and cancel any in-flight projectiles from previous battles
	if projectile_container:
		for child in projectile_container.get_children():
			if child.has_method("cancel"):
				child.cancel()
			else:
				child.queue_free()

	# Remove old units from the active tree immediately, then free them safely.
	for child in unit_container.get_children():
		unit_container.remove_child(child)
		child.queue_free()

	blue_units.clear()
	red_units.clear()
	dead_units.clear()

	blue_unit = _spawn_unit("blue", "fighter")
	red_unit = _spawn_unit("red", "fighter")
	_retarget_all_units()
	_update_all_hud()
	_update_status("Battle started! Spend gold to train reinforcements.")

func _spawn_unit(team: String, archetype: String = "fighter") -> StickmanUnit:
	var team_units: Array[StickmanUnit] = blue_units if team == "blue" else red_units
	if team_units.size() >= MAX_UNITS_PER_TEAM:
		return null

	var unit: StickmanUnit = unit_scene.instantiate() as StickmanUnit
	if unit == null:
		return null

	if team == "blue":
		blue_spawn_count += 1
		unit.name = "Blue%s%d" % [archetype.capitalize(), blue_spawn_count]
		unit.position = Vector2(BLUE_SPAWN_X, GROUND_Y)
		unit_container.add_child(unit)
		if archetype == "archer":
			unit.configure("blue", BLUE_ARCHER_HP, BLUE_ARCHER_SPEED, BLUE_ARCHER_RANGE, BLUE_ARCHER_DMG, BLUE_ARCHER_CD, 1, "archer")
		else:
			unit.configure("blue", BLUE_FIGHTER_HP, BLUE_FIGHTER_SPEED, BLUE_FIGHTER_RANGE, BLUE_FIGHTER_DMG, BLUE_FIGHTER_CD, 1, "fighter")
		blue_units.append(unit)
		if blue_unit == null or not is_instance_valid(blue_unit) or not blue_unit.is_alive():
			blue_unit = unit
	else:
		red_spawn_count += 1
		unit.name = "Red%s%d" % [archetype.capitalize(), red_spawn_count]
		unit.position = Vector2(RED_SPAWN_X, GROUND_Y)
		unit_container.add_child(unit)
		if archetype == "archer":
			unit.configure("red", RED_ARCHER_HP, RED_ARCHER_SPEED, RED_ARCHER_RANGE, RED_ARCHER_DMG, RED_ARCHER_CD, -1, "archer")
		else:
			unit.configure("red", RED_FIGHTER_HP, RED_FIGHTER_SPEED, RED_FIGHTER_RANGE, RED_FIGHTER_DMG, RED_FIGHTER_CD, -1, "fighter")
		red_units.append(unit)
		if red_unit == null or not is_instance_valid(red_unit) or not red_unit.is_alive():
			red_unit = unit

	unit.died.connect(_on_unit_died)
	unit.attack_performed.connect(_on_unit_attack_performed)
	unit.ranged_shot_requested.connect(_on_unit_ranged_shot_requested)
	_update_unit_hud()
	return unit

func _process_passive_income(delta: float) -> void:
	if is_battle_over:
		return

	income_accumulator += delta
	if income_accumulator < 1.0:
		return

	var completed_seconds: int = floori(income_accumulator)
	income_accumulator -= float(completed_seconds)
	gold += completed_seconds * GOLD_PER_SECOND
	_update_economy_hud()

func _process_enemy_reinforcements(delta: float) -> void:
	if is_battle_over:
		return

	enemy_spawn_timer -= delta
	if enemy_spawn_timer > 0.0:
		return

	if red_units.size() < MAX_UNITS_PER_TEAM:
		var next_archetype: String = RED_REINFORCEMENT_PATTERN[red_reinforcement_index % RED_REINFORCEMENT_PATTERN.size()]
		var spawned_unit: StickmanUnit = _spawn_unit("red", next_archetype)
		if spawned_unit:
			red_reinforcement_index += 1
			_retarget_all_units()
			_update_status("The Red base deployed a %s!" % next_archetype.capitalize())
		enemy_spawn_timer += ENEMY_SPAWN_INTERVAL
	else:
		# Check again soon without doing per-frame spawn work while the cap is full.
		enemy_spawn_timer = 1.0

func _process_dead_unit_cleanup(delta: float) -> void:
	for index in range(dead_units.size() - 1, -1, -1):
		var unit: StickmanUnit = dead_units[index]
		if not is_instance_valid(unit):
			dead_units.remove_at(index)
			continue

		var remaining: float = float(unit.get_meta("cleanup_remaining", DEAD_BODY_LIFETIME)) - delta
		if remaining <= 0.0:
			dead_units.remove_at(index)
			unit.queue_free()
		else:
			unit.set_meta("cleanup_remaining", remaining)

func _on_train_fighter_pressed() -> void:
	if is_battle_over:
		return

	if blue_units.size() >= MAX_UNITS_PER_TEAM:
		_update_status("Blue unit cap reached (%d)." % MAX_UNITS_PER_TEAM)
		_update_economy_hud()
		return

	if gold < FIGHTER_COST:
		_update_status("Not enough gold. Fighter costs %d gold." % FIGHTER_COST)
		_update_economy_hud()
		return

	gold -= FIGHTER_COST
	var spawned_unit: StickmanUnit = _spawn_unit("blue", "fighter")
	if spawned_unit:
		_retarget_all_units()
		_update_status("Blue Fighter trained for %d gold!" % FIGHTER_COST)
	_update_all_hud()

func _on_train_archer_pressed() -> void:
	if is_battle_over:
		return

	if blue_units.size() >= MAX_UNITS_PER_TEAM:
		_update_status("Blue unit cap reached (%d)." % MAX_UNITS_PER_TEAM)
		_update_economy_hud()
		return

	if gold < ARCHER_COST:
		_update_status("Not enough gold. Archer costs %d gold." % ARCHER_COST)
		_update_economy_hud()
		return

	gold -= ARCHER_COST
	var spawned_unit: StickmanUnit = _spawn_unit("blue", "archer")
	if spawned_unit:
		_retarget_all_units()
		_update_status("Blue Archer trained for %d gold!" % ARCHER_COST)
	_update_all_hud()

func _on_train_button_pressed() -> void:
	# Default button handler for backwards compatibility
	_on_train_fighter_pressed()

func _on_unit_ranged_shot_requested(attacker: StickmanUnit, target: Node2D, damage: float) -> void:
	if is_battle_over:
		return
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_alive():
		return
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	if projectile_container == null or projectile_scene == null:
		return

	var arrow: StickmanArrow = projectile_scene.instantiate() as StickmanArrow
	if arrow == null:
		return

	var spawn_x: float = attacker.global_position.x + float(attacker.facing_direction) * 20.0
	var spawn_y: float = GROUND_Y - 48.0
	arrow.global_position = Vector2(spawn_x, spawn_y)
	projectile_container.add_child(arrow)
	arrow.setup(attacker.team, attacker.archetype, target, damage, attacker.facing_direction, ARROW_SPEED)
	arrow.impact.connect(_on_projectile_impact)

func _on_projectile_impact(team: String, archetype: String, target: Node2D, damage: float) -> void:
	# Critical rule: A lethal hit or arrow impact must never overwrite the final winner announcement.
	if is_battle_over:
		return

	var attacker_name: String = "%s %s" % [team.capitalize(), archetype.capitalize()]
	var target_team: String = target.team if "team" in target else ("red" if team == "blue" else "blue")
	var target_team_cap: String = target_team.capitalize()

	if target is StickmanBase:
		_update_status("%s hits the %s Base for %d damage." % [attacker_name, target_team_cap, int(damage)])
	elif target is StickmanUnit:
		var target_archetype: String = target.archetype.capitalize() if "archetype" in target else "Stickman"
		_update_status("%s hits %s %s for %d damage." % [attacker_name, target_team_cap, target_archetype, int(damage)])
	else:
		_update_status("%s hits target for %d damage." % [attacker_name, int(damage)])

func _on_unit_attack_performed(attacker: StickmanUnit, target: Node2D, damage: float) -> void:
	# A lethal hit destroys the base before this signal is handled. Preserve the
	# victory announcement instead of replacing it with the final hit message.
	if is_battle_over:
		return

	if attacker == null or not is_instance_valid(attacker):
		return
	if target == null or not is_instance_valid(target):
		_update_status("%s lands a hit for %d damage." % [attacker.team.capitalize(), int(damage)])
		return

	var attacker_name: String = "%s %s" % [attacker.team.capitalize(), attacker.archetype.capitalize()]
	var target_team: String = target.team if "team" in target else ("red" if attacker.team == "blue" else "blue")
	var target_team_cap: String = target_team.capitalize()

	if target is StickmanBase:
		_update_status("%s strikes the %s Base for %d damage!" % [attacker_name, target_team_cap, int(damage)])
	elif target is StickmanUnit:
		var target_archetype: String = target.archetype.capitalize() if "archetype" in target else "Stickman"
		_update_status("%s hits %s %s for %d damage." % [attacker_name, target_team_cap, target_archetype, int(damage)])
	else:
		_update_status("%s hits target for %d damage." % [attacker_name, int(damage)])

func _on_unit_died(dead_unit: StickmanUnit) -> void:
	var arch_name: String = dead_unit.archetype.capitalize() if "archetype" in dead_unit else "Stickman"
	if dead_unit.team == "blue":
		blue_units.erase(dead_unit)
		if dead_unit == blue_unit:
			blue_unit = _first_living_unit(blue_units)
		_update_status("A Blue %s was defeated." % arch_name)
	else:
		red_units.erase(dead_unit)
		if dead_unit == red_unit:
			red_unit = _first_living_unit(red_units)
		_update_status("A Red %s was defeated." % arch_name)

	dead_unit.set_meta("cleanup_remaining", DEAD_BODY_LIFETIME)
	dead_units.append(dead_unit)
	_retarget_all_units()
	_update_all_hud()

func _first_living_unit(units: Array[StickmanUnit]) -> StickmanUnit:
	for unit in units:
		if is_instance_valid(unit) and unit.is_alive():
			return unit
	return null

func _retarget_all_units() -> void:
	if is_battle_over:
		return

	for unit in blue_units:
		if is_instance_valid(unit) and unit.is_alive():
			unit.set_target(_find_best_target(unit, red_units, red_base))

	for unit in red_units:
		if is_instance_valid(unit) and unit.is_alive():
			unit.set_target(_find_best_target(unit, blue_units, blue_base))

func _find_best_target(unit: StickmanUnit, opponents: Array[StickmanUnit], enemy_base: StickmanBase) -> Node2D:
	# Priority 1: Nearest living enemy unit
	var nearest_unit: StickmanUnit = null
	var nearest_distance: float = INF

	for candidate in opponents:
		if is_instance_valid(candidate) and candidate.is_alive():
			var distance: float = absf(candidate.global_position.x - unit.global_position.x)
			if distance < nearest_distance:
				nearest_unit = candidate
				nearest_distance = distance

	if nearest_unit != null:
		return nearest_unit

	# Priority 2: Enemy base (if alive and not destroyed)
	if enemy_base != null and is_instance_valid(enemy_base) and enemy_base.is_alive():
		return enemy_base

	return null

func _on_blue_base_destroyed(_base: StickmanBase) -> void:
	if is_battle_over:
		return
	_end_battle("Red")

func _on_red_base_destroyed(_base: StickmanBase) -> void:
	if is_battle_over:
		return
	_end_battle("Blue")

func _end_battle(winner: String) -> void:
	is_battle_over = true
	winner_name = winner

	# Cancel and remove active projectiles so no projectile deals delayed damage after victory
	if projectile_container:
		for child in projectile_container.get_children():
			if child.has_method("cancel"):
				child.cancel()
			else:
				child.queue_free()

	# Clear targets on all surviving units so they stop moving and attacking
	for unit in blue_units:
		if is_instance_valid(unit):
			unit.set_target(null)
	for unit in red_units:
		if is_instance_valid(unit):
			unit.set_target(null)

	_update_all_hud()
	_update_status("%s WINS! The enemy base has been destroyed." % winner.to_upper())

func _on_restart_button_pressed() -> void:
	_start_battle()

func _update_status(message: String) -> void:
	if status_label:
		status_label.text = message

func _update_all_hud() -> void:
	_update_economy_hud()
	_update_unit_hud()

func _update_economy_hud() -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % gold
	if income_label:
		income_label.text = "+%d gold/sec" % GOLD_PER_SECOND
	var is_capped: bool = blue_units.size() >= MAX_UNITS_PER_TEAM
	if train_fighter_button:
		train_fighter_button.text = "Train Fighter (%d Gold)" % FIGHTER_COST
		train_fighter_button.disabled = is_battle_over or gold < FIGHTER_COST or is_capped
	if train_archer_button:
		train_archer_button.text = "Train Archer (%d Gold)" % ARCHER_COST
		train_archer_button.disabled = is_battle_over or gold < ARCHER_COST or is_capped

func _update_unit_hud() -> void:
	if blue_hp_label:
		blue_hp_label.text = "Blue Units: %d / %d" % [blue_units.size(), MAX_UNITS_PER_TEAM]
	if red_hp_label:
		red_hp_label.text = "Red Units: %d / %d" % [red_units.size(), MAX_UNITS_PER_TEAM]

func get_blue_unit_count() -> int:
	return blue_units.size()

func get_red_unit_count() -> int:
	return red_units.size()
