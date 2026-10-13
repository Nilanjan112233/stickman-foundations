extends Node2D
class_name StickmanArrow

## StickmanArrow represents a lightweight procedural projectile fired by Archers.
## Moves horizontally toward its designated target's combat position using delta time.
## Applies damage on impact, preserves the struck target across lethal callbacks,
## and cleans itself up if the target dies or lifetime expires.

signal impact(source_team: String, source_archetype: String, target: Node2D, damage: float)

@export var speed: float = 650.0 # Pixels per second
@export var max_lifetime: float = 2.0 # Seconds before self-destruction

var source_team: String = "blue"
var source_archetype: String = "archer"
var target: Node2D = null
var damage: float = 10.0
var facing_direction: int = 1 # 1 = right, -1 = left

var lifetime: float = 0.0
var has_impacted: bool = false
var is_cancelled: bool = false

func _ready() -> void:
	queue_redraw()

func setup(p_team: String, p_archetype: String, p_target: Node2D, p_damage: float, p_dir: int, p_speed: float = 650.0) -> void:
	source_team = p_team
	source_archetype = p_archetype
	target = p_target
	damage = p_damage
	facing_direction = p_dir
	speed = p_speed
	queue_redraw()

func cancel() -> void:
	is_cancelled = true
	has_impacted = true
	set_physics_process(false)
	set_process(false)
	queue_free()

func _physics_process(delta: float) -> void:
	if is_cancelled or has_impacted:
		return

	# 1. Lifetime check
	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return

	# 2. Target validity check: if target died or was freed before arrow arrives, remove harmlessly
	if not _is_target_valid_and_alive():
		queue_free()
		return

	# 3. Horizontal movement toward target's combat anchor
	var target_x: float = _get_target_combat_x()
	var distance_to_target: float = absf(target_x - global_position.x)
	var max_step: float = speed * delta

	# Update facing direction if needed
	if absf(target_x - global_position.x) > 0.5:
		facing_direction = 1 if target_x > global_position.x else -1

	if distance_to_target <= max_step or is_zero_approx(distance_to_target):
		global_position.x = target_x
		_deliver_impact()
	else:
		global_position.x = move_toward(global_position.x, target_x, max_step)

func _deliver_impact() -> void:
	if has_impacted or is_cancelled:
		return
	has_impacted = true

	if not _is_target_valid_and_alive():
		queue_free()
		return

	# Preserve the struck target locally before take_damage to survive lethal retargeting callbacks
	var struck_target: Node2D = target
	struck_target.take_damage(damage)
	impact.emit(source_team, source_archetype, struck_target, damage)
	queue_free()

func _is_target_valid_and_alive() -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false
	if target.is_queued_for_deletion():
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

func _draw() -> void:
	var fx: float = float(facing_direction)
	var shaft_length: float = 18.0
	var half_shaft: float = shaft_length * 0.5

	var tail_x: float = -fx * half_shaft
	var tip_x: float = fx * half_shaft

	# Color scheme
	var shaft_color: Color = Color(0.86, 0.76, 0.58) # Light cedar wood
	var outline_color: Color = Color(0.12, 0.14, 0.18)
	var head_color: Color = Color(0.78, 0.82, 0.88) # Steel arrowhead
	var fletching_color: Color = Color(0.22, 0.58, 0.98) if source_team == "blue" else Color(0.95, 0.25, 0.25)

	# 1. Shaft line
	draw_line(Vector2(tail_x, 0.0), Vector2(tip_x, 0.0), outline_color, 3.5, true)
	draw_line(Vector2(tail_x, 0.0), Vector2(tip_x, 0.0), shaft_color, 2.0, true)

	# 2. Triangular Arrowhead at tip
	var tip_point: Vector2 = Vector2(tip_x + fx * 4.0, 0.0)
	var barb_top: Vector2 = Vector2(tip_x - fx * 2.0, -3.5)
	var barb_bottom: Vector2 = Vector2(tip_x - fx * 2.0, 3.5)
	var head_poly: PackedVector2Array = PackedVector2Array([tip_point, barb_top, barb_bottom])

	draw_colored_polygon(head_poly, head_color)
	draw_polyline(PackedVector2Array([barb_top, tip_point, barb_bottom]), outline_color, 1.5, true)

	# 3. Fletching at tail
	var fletch_angle: float = 3.0
	draw_line(Vector2(tail_x, 0.0), Vector2(tail_x - fx * 2.0, -fletch_angle), fletching_color, 1.8, true)
	draw_line(Vector2(tail_x, 0.0), Vector2(tail_x - fx * 2.0, fletch_angle), fletching_color, 1.8, true)
	draw_line(Vector2(tail_x + fx * 3.0, 0.0), Vector2(tail_x + fx * 1.0, -fletch_angle), fletching_color, 1.8, true)
	draw_line(Vector2(tail_x + fx * 3.0, 0.0), Vector2(tail_x + fx * 1.0, fletch_angle), fletching_color, 1.8, true)
