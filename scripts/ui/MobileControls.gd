extends CanvasLayer

@export var player_path: NodePath
var player: CharacterBody2D

@onready var btn_left = get_node_or_null("Control/LeftBtn")
@onready var btn_right = get_node_or_null("Control/RightBtn")
@onready var btn_jump = get_node_or_null("Control/JumpBtn")
@onready var btn_attack = get_node_or_null("Control/AttackBtn")
@onready var btn_magic = get_node_or_null("Control/MagicBtn")
@onready var btn_skill_tree = get_node_or_null("Control/SkillTreeBtn")

@onready var lbl_hp = get_node_or_null("Control/StatsPanel/VBox/HpLabel")
@onready var lbl_attack = get_node_or_null("Control/StatsPanel/VBox/AttackLabel")
@onready var lbl_defense = get_node_or_null("Control/StatsPanel/VBox/DefenseLabel")
@onready var lbl_coin = get_node_or_null("Control/StatsPanel/VBox/CoinLabel")

var skill_tree_ui = null

func _ready() -> void:
	if has_node(player_path):
		player = get_node(player_path) as CharacterBody2D
		
	skill_tree_ui = get_node_or_null("../SkillTreeUI")
		
	if btn_left:
		btn_left.button_down.connect(_on_left_down)
		btn_left.button_up.connect(_on_left_up)
	if btn_right:
		btn_right.button_down.connect(_on_right_down)
		btn_right.button_up.connect(_on_right_up)
	if btn_jump:
		btn_jump.pressed.connect(_on_jump_pressed)
	if btn_attack:
		btn_attack.pressed.connect(_on_attack_pressed)
	if btn_magic:
		btn_magic.pressed.connect(_on_magic_pressed)
	if btn_skill_tree and skill_tree_ui:
		btn_skill_tree.pressed.connect(func(): skill_tree_ui.toggle_tree())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			if skill_tree_ui:
				skill_tree_ui.toggle_tree()

func _process(_delta: float) -> void:
	if player:
		if lbl_hp:
			lbl_hp.text = "CAN: %d / %d" % [player.current_hp, player.max_hp]
		if lbl_attack:
			lbl_attack.text = "SALDIRI: %d" % player.attack_dmg
		if lbl_defense:
			lbl_defense.text = "SAVUNMA: %d" % player.defense
		if lbl_coin:
			lbl_coin.text = "ALTIN: %d" % player.coins

func _on_left_down() -> void:
	if player:
		player.touch_input_dir = -1.0

func _on_left_up() -> void:
	if player and player.touch_input_dir == -1.0:
		player.touch_input_dir = 0.0

func _on_right_down() -> void:
	if player:
		player.touch_input_dir = 1.0

func _on_right_up() -> void:
	if player and player.touch_input_dir == 1.0:
		player.touch_input_dir = 0.0

func _on_jump_pressed() -> void:
	if player:
		player.jump()

func _on_attack_pressed() -> void:
	if player:
		player.attack()

func _on_magic_pressed() -> void:
	if player and player.has_method("cast_magic"):
		player.cast_magic()

