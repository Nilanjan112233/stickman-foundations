extends Node2D
class_name StickmanVisual

## StickmanVisual handles all procedural 2D rendering for a stickman unit.
## It uses Godot's built-in canvas drawing primitives (_draw, draw_line, draw_circle, draw_rect)
## to create clean, responsive stick figures without external art or texture assets.

# Color definitions
@export var team_color: Color = Color(0.22, 0.58, 0.98) # Default Blue
@export var outline_color: Color = Color(0.12, 0.14, 0.18) # Dark contrast outline
@export var skin_line_width: float = 4.0
@export var head_radius: float = 12.0
@export var archetype: String = "fighter"

# Current animation parameters
var facing_direction: int = 1 # 1 = right, -1 = left
var walk_phase: float = 0.0
var walk_speed_factor: float = 10.0 # Cycles per second of walk cycle

var is_attacking: bool = false
var attack_progress: float = 0.0 # 0.0 to 1.0

var flash_timer: float = 0.0
const FLASH_DURATION: float = 0.12

var is_dead: bool = false
var death_progress: float = 0.0 # 0.0 to 1.0
const DEATH_FALL_SPEED: float = 2.8

# Health bar representation
var current_health: float = 100.0
var max_health: float = 100.0

func _ready() -> void:
	# Initial redraw so the stickman renders immediately in idle pose
	queue_redraw()

func set_archetype(p_archetype: String) -> void:
	archetype = p_archetype
	queue_redraw()

func set_team_color(color: Color) -> void:
	team_color = color
	queue_redraw()

func set_facing_direction(direction: int) -> void:
	if facing_direction != direction:
		facing_direction = direction
		queue_redraw()

func set_health(curr: float, max_h: float) -> void:
	current_health = max(0.0, curr)
	max_health = max(1.0, max_h)
	queue_redraw()

func trigger_damage_flash() -> void:
	flash_timer = FLASH_DURATION
	queue_redraw()

func play_walk(delta: float, direction: int) -> void:
	if is_dead:
		return
	is_attacking = false
	facing_direction = direction
	walk_phase += delta * walk_speed_factor
	if walk_phase > TAU:
		walk_phase -= TAU
	queue_redraw()

func play_idle(direction: int) -> void:
	if is_dead:
		return
	is_attacking = false
	facing_direction = direction
	walk_phase = 0.0
	queue_redraw()

func play_attack(_delta: float, progress: float, direction: int) -> void:
	if is_dead:
		return
	is_attacking = true
	attack_progress = clampf(progress, 0.0, 1.0)
	facing_direction = direction
	queue_redraw()

func play_dead(delta: float, direction: int) -> void:
	is_dead = true
	is_attacking = false
	facing_direction = direction
	if death_progress < 1.0:
		death_progress = min(1.0, death_progress + delta * DEATH_FALL_SPEED)
		queue_redraw()

func reset_visual() -> void:
	is_dead = false
	is_attacking = false
	death_progress = 0.0
	walk_phase = 0.0
	attack_progress = 0.0
	flash_timer = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	# Tick hit flash timer down if active
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer < 0.0:
			flash_timer = 0.0
		queue_redraw()

func _draw() -> void:
	var fx: float = float(facing_direction)

	# Calculate colors (flash white during damage)
	var active_body_color: Color = team_color
	if flash_timer > 0.0:
		var flash_ratio: float = flash_timer / FLASH_DURATION
		active_body_color = team_color.lerp(Color.WHITE, flash_ratio * 0.85)

	# If dead, fade alpha slightly so fallen unit is distinguishable
	if is_dead:
		active_body_color.a = lerpf(1.0, 0.7, death_progress)

	# Calculate death tilt angle (falls backward onto back)
	var death_angle: float = 0.0
	var death_y_drop: float = 0.0
	if is_dead:
		# Fall backward relative to facing direction
		death_angle = -fx * (PI * 0.45) * death_progress
		death_y_drop = 30.0 * death_progress

	# Draw with death rotation transform if fallen
	draw_set_transform(Vector2(0.0, death_y_drop), death_angle, Vector2.ONE)

	# 1. Body Landmarks relative to unit origin (feet on ground at y=0)
	var neck_pos: Vector2 = Vector2(0.0, -64.0)
	var hip_pos: Vector2 = Vector2(0.0, -36.0)
	var head_center: Vector2 = Vector2(0.0, -78.0)

	# Apply damage recoil visual offset along X
	if flash_timer > 0.0:
		var recoil_offset: float = -fx * 4.0 * (flash_timer / FLASH_DURATION)
		neck_pos.x += recoil_offset
		hip_pos.x += recoil_offset
		head_center.x += recoil_offset

	# Quiver (drawn behind torso for Archers)
	if archetype == "archer":
		var quiver_top: Vector2 = Vector2(-fx * 7.0, -66.0)
		var quiver_bottom: Vector2 = Vector2(-fx * 12.0, -42.0)
		draw_line(quiver_bottom, quiver_top, outline_color, 7.0, true)
		draw_line(quiver_bottom, quiver_top, Color(0.32, 0.22, 0.16), 4.5, true)
		# Protruding arrow nocks
		draw_line(quiver_top, Vector2(quiver_top.x - fx * 2.0, quiver_top.y - 7.0), Color(0.85, 0.75, 0.55), 2.0, true)
		draw_line(quiver_top, Vector2(quiver_top.x + fx * 1.5, quiver_top.y - 6.0), Color(0.85, 0.75, 0.55), 2.0, true)

	# 2. Draw Legs
	var left_foot_offset: float = 0.0
	var right_foot_offset: float = 0.0
	var left_foot_y: float = 0.0
	var right_foot_y: float = 0.0

	if not is_dead and not is_attacking and walk_phase != 0.0:
		# Procedural sine wave leg swing
		var leg_swing: float = sin(walk_phase) * 14.0
		left_foot_offset = leg_swing
		right_foot_offset = -leg_swing
		left_foot_y = -abs(cos(walk_phase)) * 3.0
		right_foot_y = -abs(cos(walk_phase + PI)) * 3.0
	else:
		# Standing pose
		left_foot_offset = -7.0 * fx
		right_foot_offset = 7.0 * fx

	var left_foot: Vector2 = Vector2(left_foot_offset, left_foot_y)
	var right_foot: Vector2 = Vector2(right_foot_offset, right_foot_y)

	# Back leg
	draw_line(hip_pos, right_foot, outline_color, skin_line_width + 1.5, true)
	draw_line(hip_pos, right_foot, active_body_color.darkened(0.15), skin_line_width, true)

	# Front leg
	draw_line(hip_pos, left_foot, outline_color, skin_line_width + 1.5, true)
	draw_line(hip_pos, left_foot, active_body_color, skin_line_width, true)

	# 3. Draw Spine / Torso
	draw_line(hip_pos, neck_pos, outline_color, skin_line_width + 1.5, true)
	draw_line(hip_pos, neck_pos, active_body_color, skin_line_width, true)

	# 4. Draw Arms & Equipment
	var shoulder_pos: Vector2 = Vector2(neck_pos.x, neck_pos.y + 4.0)
	var back_hand: Vector2
	var front_hand: Vector2

	if archetype == "archer":
		if is_attacking:
			# Ranged aim and draw animation: front arm holds bow, back arm draws string
			front_hand = Vector2(fx * 22.0, -54.0)
			if attack_progress < 0.5:
				var draw_ratio: float = attack_progress / 0.5
				var draw_x: float = lerpf(fx * 10.0, -fx * 4.0, draw_ratio)
				back_hand = Vector2(draw_x, -54.0)
			else:
				var release_ratio: float = (attack_progress - 0.5) / 0.5
				var release_x: float = lerpf(fx * 14.0, fx * 6.0, release_ratio)
				back_hand = Vector2(release_x, -52.0)
		elif not is_dead and walk_phase != 0.0:
			var arm_swing: float = sin(walk_phase) * 8.0
			front_hand = Vector2(fx * 14.0, -48.0 + arm_swing)
			back_hand = Vector2(-fx * 8.0, -44.0 - arm_swing)
		else:
			front_hand = Vector2(fx * 14.0, -48.0)
			back_hand = Vector2(-fx * 8.0, -44.0)

		# Back Arm
		draw_line(shoulder_pos, back_hand, outline_color, skin_line_width + 1.5, true)
		draw_line(shoulder_pos, back_hand, active_body_color.darkened(0.2), skin_line_width, true)

		# Front Arm
		draw_line(shoulder_pos, front_hand, outline_color, skin_line_width + 1.5, true)
		draw_line(shoulder_pos, front_hand, active_body_color, skin_line_width, true)
		draw_circle(front_hand, 3.0, outline_color)
		draw_circle(front_hand, 2.0, active_body_color)

		# Bow stave & bowstring
		var bow_tip_top: Vector2 = Vector2(front_hand.x - fx * 2.0, front_hand.y - 19.0)
		var bow_tip_bottom: Vector2 = Vector2(front_hand.x - fx * 2.0, front_hand.y + 19.0)
		var bow_color: Color = Color(0.55, 0.36, 0.18)

		draw_line(bow_tip_top, front_hand, outline_color, 4.0, true)
		draw_line(bow_tip_top, front_hand, bow_color, 2.5, true)
		draw_line(front_hand, bow_tip_bottom, outline_color, 4.0, true)
		draw_line(front_hand, bow_tip_bottom, bow_color, 2.5, true)

		if is_attacking and attack_progress < 0.5:
			# String pulled back to back hand
			draw_line(bow_tip_top, back_hand, Color(0.9, 0.9, 0.9, 0.9), 1.2, true)
			draw_line(back_hand, bow_tip_bottom, Color(0.9, 0.9, 0.9, 0.9), 1.2, true)
			# Nocked arrow before release
			var arrow_nock: Vector2 = back_hand
			var arrow_head_pos: Vector2 = Vector2(front_hand.x + fx * 14.0, front_hand.y)
			draw_line(arrow_nock, arrow_head_pos, Color(0.85, 0.75, 0.55), 1.8, true)
		else:
			# Resting straight bowstring
			draw_line(bow_tip_top, bow_tip_bottom, Color(0.9, 0.9, 0.9, 0.8), 1.2, true)
	else:
		# Fighter arms and punch animation
		if is_attacking:
			var thrust_curve: float = sin(attack_progress * PI) # 0 -> 1 -> 0 peak punch
			var reach_x: float = fx * (12.0 + thrust_curve * 28.0)
			var punch_y: float = -62.0 - thrust_curve * 6.0
			front_hand = Vector2(reach_x, punch_y)
			back_hand = Vector2(-fx * 14.0, -48.0)
		elif not is_dead and walk_phase != 0.0:
			var arm_swing: float = sin(walk_phase) * 12.0
			front_hand = Vector2(-fx * arm_swing, -46.0)
			back_hand = Vector2(fx * arm_swing, -46.0)
		else:
			front_hand = Vector2(fx * 10.0, -44.0)
			back_hand = Vector2(-fx * 10.0, -44.0)

		# Back Arm
		draw_line(shoulder_pos, back_hand, outline_color, skin_line_width + 1.5, true)
		draw_line(shoulder_pos, back_hand, active_body_color.darkened(0.2), skin_line_width, true)

		# Front Arm
		draw_line(shoulder_pos, front_hand, outline_color, skin_line_width + 1.5, true)
		draw_line(shoulder_pos, front_hand, active_body_color, skin_line_width, true)
		# Draw front fist circle
		draw_circle(front_hand, 3.5, outline_color)
		draw_circle(front_hand, 2.5, active_body_color)

	# 5. Draw Head
	# Head outline + filled head
	draw_circle(head_center, head_radius + 1.0, outline_color)
	draw_circle(head_center, head_radius, active_body_color)

	# Eye dot to clearly show facing direction
	var eye_pos: Vector2 = Vector2(head_center.x + fx * 5.0, head_center.y - 1.0)
	draw_circle(eye_pos, 2.0, outline_color)

	# Reset transform before drawing Health Bar (so health bar does not rotate or tilt with death)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 6. Health Bar (drawn only while unit is alive or briefly falling)
	if not is_dead or death_progress < 0.95:
		_draw_health_bar()

func _draw_health_bar() -> void:
	var bar_width: float = 44.0
	var bar_height: float = 6.0
	var bar_x: float = -bar_width * 0.5
	var bar_y: float = -102.0

	var health_ratio: float = 0.0
	if max_health > 0.0:
		health_ratio = clampf(current_health / max_health, 0.0, 1.0)

	# Background (dark border and empty fill)
	var bg_rect: Rect2 = Rect2(bar_x - 1.0, bar_y - 1.0, bar_width + 2.0, bar_height + 2.0)
	draw_rect(bg_rect, outline_color, true)

	var empty_rect: Rect2 = Rect2(bar_x, bar_y, bar_width, bar_height)
	draw_rect(empty_rect, Color(0.18, 0.20, 0.24, 0.9), true)

	# Filled portion
	if health_ratio > 0.0:
		var fill_width: float = bar_width * health_ratio
		var fill_rect: Rect2 = Rect2(bar_x, bar_y, fill_width, bar_height)
		# Health color changes from green -> yellow -> red based on health ratio
		var bar_fill_color: Color = Color(0.2, 0.85, 0.35)
		if health_ratio < 0.35:
			bar_fill_color = Color(0.95, 0.25, 0.25)
		elif health_ratio < 0.65:
			bar_fill_color = Color(0.95, 0.75, 0.15)

		draw_rect(fill_rect, bar_fill_color, true)
