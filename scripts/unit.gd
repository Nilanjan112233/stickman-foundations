extends Node2D
class_name StickmanUnit

## StickmanUnit represents a single stickman combatant.
## Handles state machine logic (WALK, ATTACK, DEAD), movement along the ground,
## target tracking, attack cooldowns, safe health clamping, and signal emission.

# Signals
signal health_changed(new_health: float, max_health: float)
signal died(unit: StickmanUnit)
signal attack_performed(attacker: StickmanUnit, target: Node2D, damage: float)
signal ranged_shot_requested(attacker: StickmanUnit, target: Node2D, damage: float)

# Finite State Machine Enum
enum State {
	WALK,
	ATTACK,
	DEAD
}

# Configurable unit properties
@export var team: String = "blue"
@export var archetype: String = "fighter" # "fighter" or "archer"
@export var max_health: float = 100.0
@export var move_speed: float = 90.0 # Pixels per second
@export var attack_range: float = 55.0 # Pixels
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 0.7 # Seconds between attacks
@export var facing_direction: int = 1 # 1 = right, -1 = left

# Runtime combat state
var current_health: float = 100.0
var current_state: State = State.WALK
var target: Node2D = null

var cooldown_timer: float = 0.0
var attack_anim_timer: float = 0.0
const ATTACK_ANIM_DURATION: float = 0.28 # Duration of procedural punch animation
const ATTACK_HIT_PROGRESS: float = 0.5 # Fist reaches maximum extension halfway through
var attack_hit_delivered: bool = true

var has_died: bool = false
var ground_y: float = 540.0

# Node references
@onready var visual: StickmanVisual = $StickmanVisual

func _ready() -> void:
	current_health = max_health
	ground_y = global_position.y
	_apply_visual_team()
	if visual:
		if visual.has_method("set_archetype"):
			visual.set_archetype(archetype)
		visual.set_health(current_health, max_health)
		visual.set_facing_direction(facing_direction)

func _apply_visual_team() -> void:
	if visual == null:
		return
	if team == "blue":
		visual.set_team_color(Color(0.22, 0.58, 0.98))
	elif team == "red":
		visual.set_team_color(Color(0.95, 0.25, 0.25))
	else:
		visual.set_team_color(Color(0.8, 0.8, 0.8))

func _physics_process(delta: float) -> void:
	# Tick cooldowns and animations
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		if cooldown_timer < 0.0:
			cooldown_timer = 0.0

	if attack_anim_timer > 0.0:
		attack_anim_timer -= delta
		if attack_anim_timer < 0.0:
			attack_anim_timer = 0.0

	# Keep unit grounded vertically (never move vertically off ground)
	global_position.y = ground_y

	# Execute State Logic
	match current_state:
		State.WALK:
			_process_walk_state(delta)
		State.ATTACK:
			_process_attack_state(delta)
		State.DEAD:
			_process_dead_state(delta)

## =============================================================================
## STATE LOGIC
## =============================================================================

func _process_walk_state(delta: float) -> void:
	# 1. Target check
	if not _is_target_valid_and_alive():
		# No valid target to pursue; stand idle
		if visual:
			visual.play_idle(facing_direction)
		return

	# 2. Update facing direction towards target
	var target_x: float = _get_target_combat_x()
	var distance_vector: float = target_x - global_position.x
	if absf(distance_vector) > 0.5:
		facing_direction = 1 if distance_vector > 0.0 else -1

	var distance_to_target: float = absf(distance_vector)

	# 3. Check if target is already within attack range
	if distance_to_target <= attack_range:
		_transition_to_state(State.ATTACK)
		return

	# 4. Move toward target at move_speed (delta-based)
	var step: float = facing_direction * move_speed * delta
	var new_x: float = global_position.x + step

	# Prevent passing through target: clamp movement so distance is at least attack_range
	var new_distance: float = absf(target_x - new_x)
	if new_distance <= attack_range:
		# Clamp right at attack range
		global_position.x = target_x - (facing_direction * attack_range)
		_transition_to_state(State.ATTACK)
	else:
		global_position.x = new_x
		if visual:
			visual.play_walk(delta, facing_direction)

func _process_attack_state(delta: float) -> void:
	# 1. Target check: if target died or was freed, stop attacking
	if not _is_target_valid_and_alive():
		attack_anim_timer = 0.0
		attack_hit_delivered = true
		if visual:
			visual.play_idle(facing_direction)
		return

	# 2. Face target
	var target_x: float = _get_target_combat_x()
	var distance_vector: float = target_x - global_position.x
	if absf(distance_vector) > 0.5:
		facing_direction = 1 if distance_vector > 0.0 else -1

	var distance_to_target: float = absf(distance_vector)

	# 3. If living target moved outside attack range, resume walking
	if distance_to_target > attack_range + 2.0:
		_transition_to_state(State.WALK)
		return

	# 4. Trigger attack when cooldown timer permits
	if cooldown_timer <= 0.0:
		_perform_attack()

	# 5. Apply damage once when the fist reaches the target at peak extension
	var attack_progress: float = 1.0 - (attack_anim_timer / ATTACK_ANIM_DURATION)
	if not attack_hit_delivered and attack_progress >= ATTACK_HIT_PROGRESS:
		_deliver_attack_hit()

	# 6. Play attack procedural animation or idle stance
	if visual:
		if attack_anim_timer > 0.0:
			visual.play_attack(delta, attack_progress, facing_direction)
		else:
			visual.play_idle(facing_direction)

func _process_dead_state(delta: float) -> void:
	# Do nothing active; visual plays death fall
	if visual:
		visual.play_dead(delta, facing_direction)

func _perform_attack() -> void:
	if not _is_target_valid_and_alive():
		return

	cooldown_timer = attack_cooldown
	attack_anim_timer = ATTACK_ANIM_DURATION
	attack_hit_delivered = false

func _deliver_attack_hit() -> void:
	# Mark first so one attack cycle can create only one arrow or deal damage once.
	attack_hit_delivered = true
	if not _is_target_valid_and_alive():
		return

	if archetype == "archer":
		# Archer emits a ranged shot request; damage is delivered by the arrow on impact
		ranged_shot_requested.emit(self, target, attack_damage)
	else:
		# Preserve the struck target locally. Lethal damage emits its death signal, and
		# the battle controller may retarget this attacker before take_damage returns.
		var hit_target: Node2D = target
		hit_target.take_damage(attack_damage)
		attack_performed.emit(self, hit_target, attack_damage)

func _transition_to_state(new_state: State) -> void:
	if current_state == State.DEAD:
		# Cannot transition out of DEAD state
		return

	current_state = new_state

	match current_state:
		State.WALK:
			attack_anim_timer = 0.0
			attack_hit_delivered = true
		State.ATTACK:
			# If cooldown is ready, unit can begin attacking immediately
			pass
		State.DEAD:
			_handle_death()

## =============================================================================
## COMBAT SAFETY & PUBLIC METHODS
## =============================================================================

func take_damage(amount: float) -> void:
	# Ignore all damage if already dead
	if current_state == State.DEAD or has_died:
		return

	var safe_damage: float = maxf(0.0, amount)
	current_health = clampf(current_health - safe_damage, 0.0, max_health)

	if visual:
		visual.set_health(current_health, max_health)
		visual.trigger_damage_flash()

	health_changed.emit(current_health, max_health)

	# Check for death condition
	if current_health <= 0.0:
		_transition_to_state(State.DEAD)

func _handle_death() -> void:
	if has_died:
		return # Ensure died signal is emitted exactly once
	has_died = true
	current_health = 0.0
	current_state = State.DEAD

	if visual:
		visual.set_health(0.0, max_health)

	died.emit(self)

func is_alive() -> bool:
	return not has_died and current_state != State.DEAD and current_health > 0.0

func _is_target_valid_and_alive() -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false
	if not target.has_method("is_alive") or not target.has_method("take_damage"):
		return false
	return target.is_alive()

func _get_target_combat_x() -> float:
	if target == null:
		return global_position.x
	if target.has_method("get_combat_x"):
		return target.get_combat_x()
	return target.global_position.x

func get_combat_x() -> float:
	return global_position.x

func set_target(new_target: Node2D) -> void:
	target = new_target

func configure(p_team: String, p_max_hp: float, p_speed: float, p_range: float, p_dmg: float, p_cd: float, p_dir: int, p_archetype: String = "fighter") -> void:
	team = p_team
	max_health = p_max_hp
	current_health = p_max_hp
	move_speed = p_speed
	attack_range = p_range
	attack_damage = p_dmg
	attack_cooldown = p_cd
	facing_direction = p_dir
	archetype = p_archetype
	_apply_visual_team()
	if visual:
		if visual.has_method("set_archetype"):
			visual.set_archetype(archetype)
		visual.set_health(current_health, max_health)
		visual.set_facing_direction(facing_direction)

func reset_unit(start_pos: Vector2, start_dir: int) -> void:
	global_position = start_pos
	ground_y = start_pos.y
	facing_direction = start_dir
	current_health = max_health
	has_died = false
	current_state = State.WALK
	cooldown_timer = 0.0
	attack_anim_timer = 0.0
	attack_hit_delivered = true

	_apply_visual_team()
	if visual:
		if visual.has_method("set_archetype"):
			visual.set_archetype(archetype)
		visual.reset_visual()
		visual.set_health(current_health, max_health)
		visual.set_facing_direction(facing_direction)

	health_changed.emit(current_health, max_health)
