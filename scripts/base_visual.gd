extends Node2D
class_name StickmanBaseVisual

## Lightweight procedural base art with health bar and hit feedback.
## No textures, sprites, particles, shaders, or external assets.

@export_enum("blue", "red") var team: String = "blue"

var team_color: Color = Color(0.22, 0.58, 0.98)
var facing_direction: int = 1

var current_health: float = 500.0
var max_health: float = 500.0
var is_destroyed: bool = false

var flash_timer: float = 0.0
const FLASH_DURATION: float = 0.12

func _ready() -> void:
	_apply_team()
	queue_redraw()

func _apply_team() -> void:
	if team == "red":
		team_color = Color(0.95, 0.25, 0.25)
		facing_direction = -1
	else:
		team_color = Color(0.22, 0.58, 0.98)
		facing_direction = 1

func set_team(new_team: String) -> void:
	team = new_team
	_apply_team()
	queue_redraw()

func set_health(curr: float, max_h: float) -> void:
	current_health = maxf(0.0, curr)
	max_health = maxf(1.0, max_h)
	queue_redraw()

func trigger_damage_flash() -> void:
	flash_timer = FLASH_DURATION
	queue_redraw()

func set_destroyed(destroyed: bool) -> void:
	is_destroyed = destroyed
	queue_redraw()

func reset_visual() -> void:
	is_destroyed = false
	flash_timer = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer < 0.0:
			flash_timer = 0.0
		queue_redraw()

func _draw() -> void:
	var stone_color: Color = team_color.darkened(0.48)
	var shadow_color: Color = Color(0.10, 0.12, 0.16)
	var highlight_color: Color = team_color.lightened(0.12)

	# Flash white on hit
	if flash_timer > 0.0:
		var flash_ratio: float = flash_timer / FLASH_DURATION
		stone_color = stone_color.lerp(Color.WHITE, flash_ratio * 0.75)
		highlight_color = highlight_color.lerp(Color.WHITE, flash_ratio * 0.75)

	# When destroyed, darken stone and highlights to look ruined
	if is_destroyed:
		stone_color = stone_color.darkened(0.55)
		highlight_color = highlight_color.darkened(0.55)

	var fx: float = float(facing_direction)

	if not is_destroyed:
		# Main keep and side towers, positioned with their bases on the ground line (y=0)
		draw_rect(Rect2(-36.0, -88.0, 72.0, 88.0), shadow_color, true)
		draw_rect(Rect2(-33.0, -85.0, 66.0, 85.0), stone_color, true)
		draw_rect(Rect2(-50.0, -70.0, 26.0, 70.0), shadow_color, true)
		draw_rect(Rect2(-47.0, -67.0, 20.0, 67.0), stone_color, true)
		draw_rect(Rect2(24.0, -70.0, 26.0, 70.0), shadow_color, true)
		draw_rect(Rect2(27.0, -67.0, 20.0, 67.0), stone_color, true)

		# Simple battlements
		for x in [-44.0, -31.0, -18.0, -5.0, 8.0, 21.0, 34.0]:
			draw_rect(Rect2(x, -96.0 if absf(x) < 24.0 else -78.0, 9.0, 11.0), highlight_color, true)

		# Arched dark gate and team markers
		draw_rect(Rect2(-11.0, -34.0, 22.0, 34.0), shadow_color, true)
		draw_circle(Vector2(0.0, -34.0), 11.0, shadow_color)
		draw_circle(Vector2(-18.0, -49.0), 4.0, team_color)
		draw_circle(Vector2(18.0, -49.0), 4.0, team_color)

		# Flag standing tall and pointing toward the battlefield
		var pole_x: float = 18.0 * fx
		draw_line(Vector2(pole_x, -88.0), Vector2(pole_x, -138.0), shadow_color, 3.0, true)
		var flag_points := PackedVector2Array([
			Vector2(pole_x, -136.0),
			Vector2(pole_x + 34.0 * fx, -126.0),
			Vector2(pole_x, -115.0)
		])
		draw_colored_polygon(flag_points, team_color)
	else:
		# Ruined / collapsed state: cracked main keep and fallen battlements
		draw_rect(Rect2(-36.0, -48.0, 72.0, 48.0), shadow_color, true)
		draw_rect(Rect2(-33.0, -45.0, 66.0, 45.0), stone_color, true)
		draw_rect(Rect2(-50.0, -32.0, 26.0, 32.0), shadow_color, true)
		draw_rect(Rect2(-47.0, -29.0, 20.0, 29.0), stone_color, true)
		draw_rect(Rect2(24.0, -32.0, 26.0, 32.0), shadow_color, true)
		draw_rect(Rect2(27.0, -29.0, 20.0, 29.0), stone_color, true)

		# Broken rubble blocks
		draw_rect(Rect2(-24.0, -56.0, 18.0, 10.0), stone_color.darkened(0.2), true)
		draw_rect(Rect2(6.0, -52.0, 16.0, 8.0), stone_color.darkened(0.2), true)

		# Dark collapsed gate
		draw_rect(Rect2(-9.0, -20.0, 18.0, 20.0), shadow_color, true)

		# Broken / fallen flag pole tilted down onto the keep
		var pole_x: float = 18.0 * fx
		draw_line(Vector2(pole_x, -48.0), Vector2(pole_x + 30.0 * fx, -12.0), shadow_color, 3.0, true)
		var fallen_flag := PackedVector2Array([
			Vector2(pole_x + 18.0 * fx, -24.0),
			Vector2(pole_x + 32.0 * fx, -10.0),
			Vector2(pole_x + 12.0 * fx, -10.0)
		])
		draw_colored_polygon(fallen_flag, team_color.darkened(0.4))

	# Health bar drawn above the base
	_draw_health_bar()

func _draw_health_bar() -> void:
	var bar_width: float = 80.0
	var bar_height: float = 7.0
	var bar_x: float = -bar_width * 0.5
	var bar_y: float = -152.0 if not is_destroyed else -72.0

	var health_ratio: float = 0.0
	if max_health > 0.0:
		health_ratio = clampf(current_health / max_health, 0.0, 1.0)

	var outline_color: Color = Color(0.10, 0.12, 0.16)

	# Border & Background
	var bg_rect := Rect2(bar_x - 1.0, bar_y - 1.0, bar_width + 2.0, bar_height + 2.0)
	draw_rect(bg_rect, outline_color, true)

	var empty_rect := Rect2(bar_x, bar_y, bar_width, bar_height)
	draw_rect(empty_rect, Color(0.18, 0.20, 0.24, 0.9), true)

	# Filled portion
	if health_ratio > 0.0:
		var fill_width: float = bar_width * health_ratio
		var fill_rect := Rect2(bar_x, bar_y, fill_width, bar_height)
		var fill_color: Color = Color(0.2, 0.85, 0.35)
		if health_ratio < 0.25:
			fill_color = Color(0.95, 0.25, 0.25)
		elif health_ratio < 0.50:
			fill_color = Color(0.95, 0.75, 0.15)
		draw_rect(fill_rect, fill_color, true)
