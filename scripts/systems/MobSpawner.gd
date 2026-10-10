extends Node2D

@export var mob_scene: PackedScene = preload("res://scenes/mobs/basic_mob.tscn")
@export var spawn_interval: float = 2.0
@export var max_active_mobs: int = 8
@export var spawn_x: float = 1240.0
@export var spawn_y: float = 580.0

var spawn_timer: float = 0.5

func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval
		try_spawn_mob()

func try_spawn_mob() -> void:
	var current_mobs = get_tree().get_nodes_in_group("mobs")
	if current_mobs.size() >= max_active_mobs:
		return
		
	if mob_scene:
		var mob = mob_scene.instantiate() as Node2D
		mob.global_position = Vector2(spawn_x, spawn_y)
		get_parent().add_child(mob)
