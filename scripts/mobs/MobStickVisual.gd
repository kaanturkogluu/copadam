extends Node2D

var walk_time: float = 0.0
var idle_time: float = 0.0
var is_moving: bool = false
var is_attacking: bool = false
var attack_timer: float = 0.0
var hurt_timer: float = 0.0

# HP göstergesi
var max_hp: int = 40
var current_hp: int = 40

# Düşman Renkleri (Kırmızı / Gölge Savaşçı)
var line_color: Color = Color(1.0, 0.35, 0.35, 1.0)
var eye_color: Color = Color(1.0, 0.1, 0.1, 1.0)
var weapon_color: Color = Color(1.0, 0.4, 0.1, 1.0)
var line_width: float = 4.5

func _process(delta: float) -> void:
	if is_moving and not is_attacking:
		walk_time += delta * 10.0
	else:
		walk_time = lerp(walk_time, 0.0, delta * 6.0)
		
	idle_time += delta * 2.5
	
	if is_attacking:
		attack_timer += delta * 6.0
		if attack_timer >= PI:
			is_attacking = false
			attack_timer = 0.0
			
	if hurt_timer > 0.0:
		hurt_timer -= delta
		
	queue_redraw()

func _draw() -> void:
	var cur_col = line_color
	if hurt_timer > 0.0:
		cur_col = Color(1.0, 1.0, 0.6) # Hasar alınca sarı-beyaz flash
		
	var bob: float = abs(sin(walk_time)) * 4.0 if is_moving else sin(idle_time) * 1.5
	var leg_l_angle: float = sin(walk_time) * 0.6 if is_moving else 0.15
	var leg_r_angle: float = -sin(walk_time) * 0.6 if is_moving else -0.15
	var arm_l_angle: float = -sin(walk_time) * 0.7 if is_moving else -0.2
	var arm_r_angle: float = sin(walk_time) * 0.7 if is_moving else 0.2

	if is_attacking:
		arm_r_angle = -1.6 + sin(attack_timer) * 2.8

	# Noktalar
	var hip = Vector2(0, -30 + bob)
	var neck = Vector2(0, -70 + bob)
	var head_pos = Vector2(0, -88 + bob)

	# 1. Gövde
	_draw_capsule(hip, neck, cur_col, line_width)

	# 2. Bacaklar
	var knee_l = hip + Vector2(sin(leg_l_angle) * 16, cos(leg_l_angle) * 16)
	var foot_l = knee_l + Vector2(sin(leg_l_angle + 0.2) * 18, cos(leg_l_angle + 0.2) * 18)
	_draw_capsule(hip, knee_l, cur_col * 0.8, line_width - 0.5)
	_draw_capsule(knee_l, foot_l, cur_col * 0.8, line_width - 0.5)

	var knee_r = hip + Vector2(sin(leg_r_angle) * 16, cos(leg_r_angle) * 16)
	var foot_r = knee_r + Vector2(sin(leg_r_angle + 0.2) * 18, cos(leg_r_angle + 0.2) * 18)
	_draw_capsule(hip, knee_r, cur_col, line_width)
	_draw_capsule(knee_r, foot_r, cur_col, line_width)

	# 3. Kollar
	var shoulder = neck + Vector2(0, 3)
	var elbow_l = shoulder + Vector2(sin(arm_l_angle) * 15, cos(arm_l_angle) * 15)
	var hand_l = elbow_l + Vector2(sin(arm_l_angle + 0.2) * 15, cos(arm_l_angle + 0.2) * 15)
	_draw_capsule(shoulder, elbow_l, cur_col * 0.8, line_width - 1.0)
	_draw_capsule(elbow_l, hand_l, cur_col * 0.8, line_width - 1.0)

	var elbow_r = shoulder + Vector2(sin(arm_r_angle) * 15, cos(arm_r_angle) * 15)
	var hand_r = elbow_r + Vector2(sin(arm_r_angle + 0.3) * 16, cos(arm_r_angle + 0.3) * 16)
	_draw_capsule(shoulder, elbow_r, cur_col, line_width)
	_draw_capsule(elbow_r, hand_r, cur_col, line_width)

	# Silah (Kırmızı Hançer / Kama)
	var w_dir = (hand_r - elbow_r).normalized().rotated(-0.3)
	var w_tip = hand_r + w_dir * 30.0
	_draw_capsule(hand_r, w_tip, weapon_color, 4.0)

	# 4. Kafa ve Kırmızı Göz
	draw_circle(head_pos, 14.0, Color(0.12, 0.04, 0.04))
	draw_arc(head_pos, 14.0, 0, TAU, 28, cur_col, line_width, true)
	
	var eye_pos = head_pos + Vector2(5, -2)
	draw_circle(eye_pos, 3.0, eye_color)

	# 5. Baş Üstü Can Barı (Mini HP Bar)
	var bar_w = 42.0
	var bar_h = 5.0
	var bar_pos = Vector2(-bar_w * 0.5, head_pos.y - 20)
	# Arka plan
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.1, 0.1, 0.1, 0.8))
	# Doluluk
	var hp_pct = clamp(float(current_hp) / float(max(1, max_hp)), 0.0, 1.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_pct, bar_h)), Color(1.0, 0.2, 0.2))

func _draw_capsule(from: Vector2, to: Vector2, col: Color, width: float) -> void:
	draw_line(from, to, col, width, true)
	draw_circle(from, width * 0.5, col)
	draw_circle(to, width * 0.5, col)

func trigger_hurt() -> void:
	hurt_timer = 0.15

func trigger_attack() -> void:
	is_attacking = true
	attack_timer = 0.0
