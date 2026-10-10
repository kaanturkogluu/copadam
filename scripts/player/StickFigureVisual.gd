extends Node2D

# Çöp Adam Çizim ve Animasyon Motoru
var walk_time: float = 0.0
var idle_time: float = 0.0
var is_moving: bool = false
var is_on_floor: bool = true

# Gelişmiş Saldırı & Kombo Sistemi
var is_attacking: bool = false
var attack_progress: float = 0.0 # 0.0 -> 1.0
var attack_combo: int = 0        # 0: Yatay Kesiş, 1: Dikey İniş Kesişi
const ATTACK_DURATION: float = 0.28

# Renkler & Stil
var line_color: Color = Color(0.95, 0.95, 1.0, 1.0)
var sword_color: Color = Color(0.0, 0.95, 1.0, 1.0)
var line_width: float = 5.0

func _process(delta: float) -> void:
	if is_moving and is_on_floor and not is_attacking:
		walk_time += delta * 12.0
	else:
		walk_time = lerp(walk_time, 0.0, delta * 8.0)
	
	idle_time += delta * 2.5
	
	if is_attacking:
		attack_progress += delta / ATTACK_DURATION
		if attack_progress >= 1.0:
			is_attacking = false
			attack_progress = 0.0
			
	queue_redraw()

func _draw() -> void:
	var bob: float = 0.0
	var leg_l_angle: float = 0.0
	var leg_r_angle: float = 0.0
	var arm_l_angle: float = 0.0
	var arm_r_angle: float = 0.0
	var body_offset_x: float = 0.0
	var body_offset_y: float = 0.0
	var spine_lean: float = 0.0

	# 1. TEMEL DURUŞ / YÜRÜME HESABI
	if is_on_floor:
		if is_moving and not is_attacking:
			bob = abs(sin(walk_time)) * 5.0
			leg_l_angle = sin(walk_time) * 0.7
			leg_r_angle = -sin(walk_time) * 0.7
			arm_l_angle = -sin(walk_time) * 0.8
			arm_r_angle = sin(walk_time) * 0.8
		else:
			bob = sin(idle_time) * 2.0
			leg_l_angle = 0.15
			leg_r_angle = -0.15
			arm_l_angle = -0.2
			arm_r_angle = 0.2
	else:
		# Havadayken
		bob = 4.0
		leg_l_angle = -0.5
		leg_r_angle = 0.6
		arm_l_angle = -1.2
		arm_r_angle = 0.9

	# 2. SALDIRI ANİMASYONU VE KOMBOLAR
	if is_attacking:
		var p = clamp(attack_progress, 0.0, 1.0)
		
		if attack_combo == 0:
			# --- KOMBO 1: HIZLI YATAY KESİŞ (Slash 1) ---
			if p < 0.22:
				# Geriye kurulma (Wind-up)
				var t = p / 0.22
				body_offset_x = -7.0 * t
				spine_lean = -0.15 * t
				arm_r_angle = lerp(0.2, -2.5, t)
				arm_l_angle = lerp(-0.2, 0.6, t)
				leg_l_angle = 0.3
				leg_r_angle = -0.3
			elif p < 0.65:
				# Patlayıcı İleri Savurma (Slash swing)
				var t = (p - 0.22) / 0.43
				var ease_slash = ease(t, 0.25)
				body_offset_x = lerp(-7.0, 18.0, ease_slash)
				spine_lean = lerp(-0.15, 0.35, ease_slash)
				arm_r_angle = lerp(-2.5, 1.6, ease_slash)
				arm_l_angle = lerp(0.6, -1.1, ease_slash)
				leg_l_angle = lerp(0.3, -0.6, ease_slash) # Derin savaşçı hamlesi
				leg_r_angle = lerp(-0.3, 0.6, ease_slash)
			else:
				# Toparlanma (Recovery)
				var t = (p - 0.65) / 0.35
				body_offset_x = lerp(18.0, 0.0, t)
				spine_lean = lerp(0.35, 0.0, t)
				arm_r_angle = lerp(1.6, 0.2, t)
				arm_l_angle = lerp(-1.1, -0.2, t)
				leg_l_angle = lerp(-0.6, 0.15, t)
				leg_r_angle = lerp(0.6, -0.15, t)
		else:
			# --- KOMBO 2: YUKARIDAN AŞAĞI SERT İNİŞ (Overhead Smash) ---
			if p < 0.25:
				var t = p / 0.25
				body_offset_y = -9.0 * t
				spine_lean = -0.1 * t
				arm_r_angle = lerp(0.2, -3.0, t)
				arm_l_angle = lerp(-0.2, -2.8, t)
			elif p < 0.65:
				var t = (p - 0.25) / 0.40
				var ease_smash = ease(t, 0.2)
				body_offset_x = lerp(0.0, 15.0, ease_smash)
				body_offset_y = lerp(-9.0, 6.0, ease_smash)
				spine_lean = lerp(-0.1, 0.4, ease_smash)
				arm_r_angle = lerp(-3.0, 0.9, ease_smash)
				arm_l_angle = lerp(-2.8, 0.4, ease_smash)
				leg_l_angle = -0.4
				leg_r_angle = 0.5
			else:
				var t = (p - 0.65) / 0.35
				body_offset_x = lerp(15.0, 0.0, t)
				body_offset_y = lerp(6.0, 0.0, t)
				spine_lean = lerp(0.4, 0.0, t)
				arm_r_angle = lerp(0.9, 0.2, t)
				arm_l_angle = lerp(0.4, -0.2, t)

	# 3. İSKELET NOKTALARI
	var hip = Vector2(body_offset_x, -32 + bob + body_offset_y)
	var neck = hip + Vector2(sin(spine_lean) * 46, -46 * cos(spine_lean))
	var head_pos = neck + Vector2(sin(spine_lean * 1.2) * 18, -18 * cos(spine_lean * 1.2))

	# 4. ÇÖP ADAM ÇİZİMİ
	# Gövde (Omurga)
	_draw_capsule_line(hip, neck, line_color, line_width)

	# Sol Bacak (Arka bacak)
	var knee_l = hip + Vector2(sin(leg_l_angle) * 18, cos(leg_l_angle) * 18)
	var foot_l = knee_l + Vector2(sin(leg_l_angle + 0.2) * 20, cos(leg_l_angle + 0.2) * 20)
	_draw_capsule_line(hip, knee_l, line_color * 0.82, line_width - 0.5)
	_draw_capsule_line(knee_l, foot_l, line_color * 0.82, line_width - 0.5)

	# Sağ Bacak (Ön bacak)
	var knee_r = hip + Vector2(sin(leg_r_angle) * 18, cos(leg_r_angle) * 18)
	var foot_r = knee_r + Vector2(sin(leg_r_angle + 0.2) * 20, cos(leg_r_angle + 0.2) * 20)
	_draw_capsule_line(hip, knee_r, line_color, line_width)
	_draw_capsule_line(knee_r, foot_r, line_color, line_width)

	# Sol Kol (Arka kol)
	var shoulder = neck + Vector2(0, 4)
	var elbow_l = shoulder + Vector2(sin(arm_l_angle) * 16, cos(arm_l_angle) * 16)
	var hand_l = elbow_l + Vector2(sin(arm_l_angle + 0.2) * 16, cos(arm_l_angle + 0.2) * 16)
	_draw_capsule_line(shoulder, elbow_l, line_color * 0.82, line_width - 1.0)
	_draw_capsule_line(elbow_l, hand_l, line_color * 0.82, line_width - 1.0)

	# Sağ Kol (Kılıç tutan kol)
	var elbow_r = shoulder + Vector2(sin(arm_r_angle) * 18, cos(arm_r_angle) * 18)
	var hand_r = elbow_r + Vector2(sin(arm_r_angle + 0.3) * 18, cos(arm_r_angle + 0.3) * 18)
	_draw_capsule_line(shoulder, elbow_r, line_color, line_width)
	_draw_capsule_line(elbow_r, hand_r, line_color, line_width)

	# Kılıç (Neon Katana)
	var sword_dir = (hand_r - elbow_r).normalized().rotated(-0.4)
	var sword_base = hand_r
	var sword_tip = sword_base + sword_dir * 44.0
	# Kılıç kabzası
	_draw_capsule_line(sword_base - sword_dir * 9.0, sword_base + sword_dir * 2.0, Color(0.3, 0.3, 0.4), 6.0)
	# Kılıç namlusu (Neon parlak mavi)
	_draw_capsule_line(sword_base, sword_tip, sword_color, 4.5)
	_draw_capsule_line(sword_base, sword_tip, Color.WHITE, 2.0)

	# 5. NEON KILIÇ RÜZGARI (SLASH TRAIL EFEKTİ)
	if is_attacking and attack_progress >= 0.22 and attack_progress <= 0.72:
		var slash_alpha = sin((attack_progress - 0.22) / 0.50 * PI)
		var center_arc = neck + Vector2(16 + body_offset_x, -4)
		
		if attack_combo == 0:
			# Yatay hilal kesiş arkı
			var a_start = -PI * 0.55
			var a_end = PI * 0.45
			draw_arc(center_arc, 62.0, a_start, a_end, 20, Color(0.0, 0.85, 1.0, slash_alpha * 0.3), 16.0)
			draw_arc(center_arc, 62.0, a_start, a_end, 20, Color(0.0, 0.95, 1.0, slash_alpha * 0.8), 7.0)
			draw_arc(center_arc, 62.0, a_start, a_end, 20, Color(1.0, 1.0, 1.0, slash_alpha), 3.0)
			# Kesiş ucu kıvılcım parıltısı
			var spark_pos = center_arc + Vector2(cos(a_end), sin(a_end)) * 62.0
			draw_circle(spark_pos, 5.0 * slash_alpha, Color(0.2, 0.95, 1.0))
			draw_circle(spark_pos, 2.5 * slash_alpha, Color.WHITE)
		else:
			# Dikey tepeden iniş arkı
			var a_start = -PI * 0.85
			var a_end = 0.2
			draw_arc(center_arc, 68.0, a_start, a_end, 20, Color(0.0, 0.85, 1.0, slash_alpha * 0.3), 16.0)
			draw_arc(center_arc, 68.0, a_start, a_end, 20, Color(0.0, 0.95, 1.0, slash_alpha * 0.8), 7.0)
			draw_arc(center_arc, 68.0, a_start, a_end, 20, Color(1.0, 1.0, 1.0, slash_alpha), 3.0)

	# 6. BAŞ VE GÖZLER
	draw_circle(head_pos, 15.0, Color(0.08, 0.1, 0.16))
	draw_arc(head_pos, 15.0, 0, TAU, 32, line_color, line_width, true)

	# Savaşçı Gözü (Saldırıda daha parlak)
	var eye_offset = Vector2(7, -2).rotated(spine_lean * 0.5)
	var eye_pos = head_pos + eye_offset
	var eye_col = Color(0.0, 1.0, 1.0) if not is_attacking else Color(1.0, 0.5, 0.2)
	draw_circle(eye_pos, 3.5, eye_col)
	draw_circle(eye_pos, 1.8, Color.WHITE)

func _draw_capsule_line(from: Vector2, to: Vector2, col: Color, width: float) -> void:
	draw_line(from, to, col, width, true)
	draw_circle(from, width * 0.5, col)
	draw_circle(to, width * 0.5, col)

func trigger_attack() -> void:
	if is_attacking and attack_progress > 0.35:
		attack_combo = (attack_combo + 1) % 2
		attack_progress = 0.0
	else:
		attack_combo = 0
		attack_progress = 0.0
	is_attacking = true
