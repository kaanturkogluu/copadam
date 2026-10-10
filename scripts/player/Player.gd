extends CharacterBody2D
class_name Player

@export var speed: float = 320.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 1200.0

# Oyuncu İstatistikleri (SKILL.md)
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var attack_dmg: int = 15
@export var defense: int = 0
@export var coins: int = 500 # Test için başlangıç altını

# Kritik ve Büyü İstatistikleri
@export var crit_chance: float = 0.25      # %25 kritik vuruş ihtimali (Sarı yazı)
@export var crit_multiplier: float = 1.8   # Kritik hasar çarpanı
@export var magic_dmg: int = 12            # Büyü hasarı (Mavi yazı)

@onready var visual = get_node_or_null("StickFigureVisual")

# Mobil dokunmatik / Sanal buton girdileri
var touch_input_dir: float = 0.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	# 1. Yerçekimi
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# 2. Yatay Hareket (Hem Klavye hem Mobil Dokunmatik destekli)
	var move_dir: float = touch_input_dir
	
	# Klavye kontrolleri (A/D ve Yön Okları)
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_dir = -1.0
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_dir = 1.0
		
	if move_dir != 0.0:
		velocity.x = move_dir * speed
		# Yön çevirme
		if visual:
			visual.scale.x = 1.0 if move_dir > 0 else -1.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		
	# 3. Zıplama (W / Yukarı Ok / Space)
	if is_on_floor() and (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)):
		jump()

	# 4. Klavye Saldırı Kısayolu (J / F / Enter)
	if Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_ENTER):
		if visual and (not visual.is_attacking or visual.attack_progress > 0.35):
			attack()

	# 5. Klavye Büyü Saldırısı Kısayolu (K / E / M)
	if Input.is_key_pressed(KEY_K) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_M):
		if visual and (not visual.is_attacking or visual.attack_progress > 0.35):
			cast_magic()

	move_and_slide()
	
	# 6. Görsel Animasyon Güncellemesi
	if visual:
		visual.is_moving = abs(velocity.x) > 15.0 and is_on_floor()
		visual.is_on_floor = is_on_floor()

func jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity

func attack() -> void:
	if visual:
		visual.trigger_attack()
		# Saldırıda öne doğru atletik hamle (Lunge momentum)
		var facing = 1.0 if visual.scale.x >= 0 else -1.0
		velocity.x = facing * 240.0
		
		# Düşmanlara vuruş hasarı ver (Hit detection)
		hit_mobs_in_front(facing)

func cast_magic() -> void:
	if visual:
		visual.trigger_attack()
		var facing = 1.0 if visual.scale.x >= 0 else -1.0
		velocity.x = facing * 120.0
		
	# Büyü Patlaması: Önündeki ve etrafındaki tüm düşmanlara MAVİ büyü hasarı verir
	var mobs = get_tree().get_nodes_in_group("mobs")
	for mob in mobs:
		if is_instance_valid(mob) and mob.has_method("take_damage"):
			var diff_x = mob.global_position.x - global_position.x
			var diff_y = abs(mob.global_position.y - global_position.y)
			if diff_y < 85.0 and abs(diff_x) < 170.0:
				var m_dmg = max(10, magic_dmg)
				mob.take_damage(m_dmg, "magic")

func hit_mobs_in_front(facing: float) -> void:
	var mobs = get_tree().get_nodes_in_group("mobs")
	for mob in mobs:
		if is_instance_valid(mob) and mob.has_method("take_damage"):
			var diff_x = mob.global_position.x - global_position.x
			var diff_y = abs(mob.global_position.y - global_position.y)
			# Karakterin baktığı yönde ve kılıç menzili içindeyse
			if diff_y < 70.0 and (diff_x * facing) > -25.0 and abs(diff_x) < 110.0:
				# 1. Fiziksel Hasar: Kritik (SARI) veya Normal (KIRMIZI)
				var is_crit = randf() < crit_chance
				if is_crit:
					var crit_dmg = int(ceil(attack_dmg * crit_multiplier))
					mob.take_damage(crit_dmg, "critical")
				else:
					mob.take_damage(attack_dmg, "normal")
				
				# 2. İlave Büyü Hasarı (MAVİ) - Oyuncuda büyü gücü varsa
				if magic_dmg > 0 and is_instance_valid(mob) and mob.current_hp > 0:
					var target_mob = mob
					get_tree().create_timer(0.08).timeout.connect(func():
						if is_instance_valid(target_mob) and target_mob.current_hp > 0:
							target_mob.take_damage(magic_dmg, "magic")
					)

func take_damage(incoming: int) -> void:
	# Zırh / Savunma hesabı (SKILL.md)
	var net_dmg = max(1, incoming - defense)
	current_hp = max(0, current_hp - net_dmg)
	
	# Hasar alınca hafif geriye irkilme
	velocity.y = -100.0
	
	if current_hp <= 0:
		on_death()

func on_death() -> void:
	# Can 0 olunca yenilenme (test için)
	current_hp = max_hp
