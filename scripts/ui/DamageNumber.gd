extends Node2D
class_name DamageNumber

static var font_res: Font = preload("res://assets/fonts/Rajdhani-Bold.ttf")

static func spawn(caller: Node, world_pos: Vector2, amount: int, type: String = "normal") -> DamageNumber:
	if not is_instance_valid(caller) or not caller.is_inside_tree():
		return null
		
	var root = caller.get_tree().current_scene
	if not root:
		root = caller.get_parent()
	if not root:
		return null
		
	var dmg_node = DamageNumber.new()
	# Hafif rastgele dağılım ile üst üste binmeyi önle
	dmg_node.global_position = world_pos + Vector2(randf_range(-16.0, 16.0), randf_range(-10.0, 5.0))
	root.add_child(dmg_node)
	dmg_node.setup(amount, type)
	return dmg_node

func setup(amount: int, type: String) -> void:
	z_index = 80
	
	var label = Label.new()
	if font_res:
		label.add_theme_font_override("font", font_res)
	
	var peak_scale = Vector2(1.2, 1.2)
	
	# Hasar türüne göre renk ve boyut belirleme
	match type.to_lower():
		"critical", "kritik":
			# SARI HASAR (Kritik vuruş)
			label.text = "%d!" % amount
			label.add_theme_font_size_override("font_size", 28)
			label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1, 1.0))
			label.add_theme_color_override("font_outline_color", Color(0.18, 0.12, 0.0, 0.95))
			label.add_theme_constant_override("outline_size", 6)
			peak_scale = Vector2(1.45, 1.45)
			
		"magic", "buyu", "büyü":
			# MAVİ HASAR (Büyü hasarı)
			label.text = "%d" % amount
			label.add_theme_font_size_override("font_size", 24)
			label.add_theme_color_override("font_color", Color(0.25, 0.82, 1.0, 1.0))
			label.add_theme_color_override("font_outline_color", Color(0.02, 0.12, 0.28, 0.95))
			label.add_theme_constant_override("outline_size", 5)
			peak_scale = Vector2(1.25, 1.25)
			
		_: # "normal"
			# KIRMIZI HASAR (Normal saldırı)
			label.text = "%d" % amount
			label.add_theme_font_size_override("font_size", 22)
			label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28, 1.0))
			label.add_theme_color_override("font_outline_color", Color(0.22, 0.02, 0.02, 0.95))
			label.add_theme_constant_override("outline_size", 5)
			peak_scale = Vector2(1.2, 1.2)

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-60, -20)
	label.size = Vector2(120, 40)
	add_child(label)
	
	# Dinamik Animasyon: Başlangıç ölçeği, büyüme ve yukarı süzülme
	scale = Vector2(0.4, 0.4)
	
	# 1. Ölçek animasyonu (Pop / Punch)
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", peak_scale, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. Yukarı doğru yüzme (Float)
	var move_tween = create_tween()
	var drift_x = randf_range(-18.0, 18.0)
	var target_y = position.y - 56.0
	move_tween.tween_property(self, "position:x", position.x + drift_x, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(self, "position:y", target_y, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 3. Yavaşça solma ve bellekten temizleme (Fade out & Free)
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.45)
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_tween.tween_callback(queue_free)
