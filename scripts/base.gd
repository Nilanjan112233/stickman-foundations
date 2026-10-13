extends Node2D
class_name StickmanBase

## StickmanBase handles combat logic, health clamping, damage reactions,
## and destruction signals for a team's base.

signal health_changed(new_health: float, max_health: float)
signal destroyed(base: StickmanBase)

@export_enum("blue", "red") var team: String = "blue"
@export var max_health: float = 500.0

var current_health: float = 500.0
var has_been_destroyed: bool = false

@onready var visual: StickmanBaseVisual = $BaseVisual

func _ready() -> void:
	current_health = max_health
	if visual:
		visual.set_team(team)
		visual.set_health(current_health, max_health)

func is_alive() -> bool:
	return not has_been_destroyed and current_health > 0.0

func take_damage(amount: float) -> void:
	# Dead bases ignore all further damage
	if has_been_destroyed or current_health <= 0.0:
		return

	var safe_damage: float = maxf(0.0, amount)
	current_health = clampf(current_health - safe_damage, 0.0, max_health)

	if visual:
		visual.set_health(current_health, max_health)
		visual.trigger_damage_flash()

	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		_handle_destruction()

func _handle_destruction() -> void:
	if has_been_destroyed:
		return
	has_been_destroyed = true
	current_health = 0.0

	if visual:
		visual.set_health(0.0, max_health)
		visual.set_destroyed(true)

	destroyed.emit(self)

func reset_base() -> void:
	has_been_destroyed = false
	current_health = max_health
	if visual:
		visual.set_team(team)
		visual.set_destroyed(false)
		visual.set_health(current_health, max_health)
		visual.reset_visual()
	health_changed.emit(current_health, max_health)

func get_combat_x() -> float:
	# Front edge facing the battlefield:
	# Blue base is on the left (x=92), so enemies approach from the right (+X). Outer edge is +50 px.
	# Red base is on the right (x=1188), so enemies approach from the left (-X). Outer edge is -50 px.
	var edge_offset: float = 50.0 if team == "blue" else -50.0
	return global_position.x + edge_offset
