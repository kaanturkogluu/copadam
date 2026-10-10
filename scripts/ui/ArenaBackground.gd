extends Node2D

func _draw() -> void:
	var screen_w = 1280.0
	var screen_h = 720.0
	var ground_y = 580.0
	
	# Gökyüzü / Arka plan karanlık degrade
	draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0.04, 0.05, 0.08))
	
	# Uzak şehir silueti
	var city_color = Color(0.08, 0.1, 0.16)
	var buildings = [
		Rect2(50, 280, 90, 300),
		Rect2(160, 220, 110, 360),
		Rect2(300, 320, 80, 260),
		Rect2(420, 200, 140, 380),
		Rect2(600, 260, 100, 320),
		Rect2(730, 210, 120, 370),
		Rect2(880, 300, 90, 280),
		Rect2(1000, 240, 130, 340),
		Rect2(1150, 290, 100, 290)
	]
	for b in buildings:
		draw_rect(b, city_color)
		# Küçük pencereler
		for wx in range(int(b.position.x + 10), int(b.position.x + b.size.x - 10), 20):
			for wy in range(int(b.position.y + 20), int(ground_y - 20), 35):
				if (wx + wy) % 3 == 0:
					draw_rect(Rect2(wx, wy, 8, 12), Color(0.0, 0.8, 1.0, 0.15))
	
	# Zemin altı
	draw_rect(Rect2(0, ground_y, screen_w, screen_h - ground_y), Color(0.06, 0.08, 0.12))
	
	# Zemin Izgarası (Cyber Grid Floor)
	var grid_col = Color(0.0, 0.7, 1.0, 0.12)
	for x in range(0, int(screen_w) + 1, 64):
		draw_line(Vector2(x, ground_y), Vector2(x, screen_h), grid_col, 1.0)
	for y in range(int(ground_y), int(screen_h) + 1, 35):
		draw_line(Vector2(0, y), Vector2(screen_w, y), grid_col, 1.0)
		
	# Neon Zemin Çizgisi
	draw_line(Vector2(0, ground_y), Vector2(screen_w, ground_y), Color(0.0, 0.85, 1.0, 0.4), 6.0)
	draw_line(Vector2(0, ground_y), Vector2(screen_w, ground_y), Color(0.8, 0.95, 1.0), 2.0)
