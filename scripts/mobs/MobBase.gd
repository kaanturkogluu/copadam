extends CharacterBody2D
class_name MobBase

@export var max_hp: int = 40
@export var current_hp: int = 40
@export var damage: int = 10
@export var speed: float = 110.0
@export var reward_coins: int = 5
@export var attack_interval: float = 1.4
@export var gravity: float = 1200.0

@onready var visual = get_node_or_null("MobStickVisual")

var target_player: CharacterBody2D = null
var attack_cooldown: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	add_to_group("mobs")
	# Oyuncuyu bul
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]
	else:
		target_player = get_parent().get_node_or_null("Player")
		
	if visual:
		visual.max_hp = max_hp
		visual.current_hp = current_hp

func _physics_process(delta: float) -> void:
	# 1. Yerçekimi
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# 2. Saldırı bekleme süresi
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
		
	if not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
			
	# 3. Oyuncuya doğru yürüme / Saldırma yapay zekası
	if is_instance_valid(target_player):
		var diff = target_player.global_position.x - global_position.x
		var dist = abs(diff)
		var dir = sign(diff)
		
		# Yönü ayarla
		if visual and dir != 0:
			visual.scale.x = dir
			
		if dist > 60.0:
			# Yürü
			velocity.x = dir * speed
			if visual:
				visual.is_moving = true
		else:
			# Yakında dur ve saldır
			velocity.x = move_toward(velocity.x, 0.0, speed * 6.0 * delta)
			if visual:
				visual.is_moving = false
				
			if attack_cooldown <= 0.0:
				perform_attack()
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 4.0 * delta)
		if visual:
			visual.is_moving = false

	move_and_slide()

func perform_attack() -> void:
	attack_cooldown = attack_interval
	if visual:
		visual.trigger_attack()
	if is_instance_valid(target_player) and target_player.has_method("take_damage"):
		target_player.take_damage(damage)

func take_damage(amount: int, damage_type: String = "normal") -> void:
	current_hp -= amount
	if visual:
		visual.current_hp = current_hp
		visual.trigger_hurt()
		
	# Hasar sayısını ekranda uçurarak göster (Kırmızı / Sarı / Mavi)
	DamageNumber.spawn(self, global_position + Vector2(0, -65), amount, damage_type)
		
	# Geriye savrulma (Knockback)
	var knock_dir = 1.0
	if is_instance_valid(target_player):
		knock_dir = 1.0 if global_position.x > target_player.global_position.x else -1.0
	velocity.x = knock_dir * 260.0
	velocity.y = -120.0
	
	if current_hp <= 0:
		die()

func die() -> void:
	# Oyuncuya altın ödülü ver
	if is_instance_valid(target_player) and "coins" in target_player:
		target_player.coins += reward_coins
		
	queue_free()
