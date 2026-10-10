extends CanvasLayer

@export var player_path: NodePath
var player: CharacterBody2D

# JSON Verisi ve Seviye Durumu
var skill_data: Dictionary = {}
var skill_levels: Dictionary = {} # nid -> current_level: int
var current_category_id: String = ""

# Düğüm referansları
@onready var overlay = $Overlay
@onready var header_title = $Overlay/Header/TitleLabel
@onready var header_coins = $Overlay/Header/CoinLabel
@onready var btn_close = $Overlay/Header/CloseBtn
@onready var btn_back = $Overlay/Header/BackBtn

@onready var category_view = $Overlay/CategoryView
@onready var category_list = $Overlay/CategoryView/CategoryList

@onready var tree_scroll = $Overlay/TreeScroll
@onready var tree_canvas = $Overlay/TreeScroll/TreeCanvas

# Çizim bağlantıları: [{from: Vector2, to: Vector2, active: bool}]
var line_connections: Array = []

func _ready() -> void:
	if has_node(player_path):
		player = get_node(player_path) as CharacterBody2D
		
	btn_close.pressed.connect(close_tree)
	btn_back.pressed.connect(show_categories)
	
	load_skill_json()
	overlay.visible = false
	
	# Ağaç çizim katmanı
	tree_canvas.draw.connect(_on_tree_canvas_draw)

func load_skill_json() -> void:
	var path = "res://data/skill_tree.json"
	if not FileAccess.file_exists(path):
		push_error("Skill tree JSON dosyası bulunamadı: " + path)
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	if error == OK:
		skill_data = json.data
		build_category_buttons()
	else:
		push_error("JSON Parse hatası: " + json.get_error_message())

func open_tree() -> void:
	overlay.visible = true
	update_header_coins()
	show_categories()

func close_tree() -> void:
	overlay.visible = false

func toggle_tree() -> void:
	if overlay.visible:
		close_tree()
	else:
		open_tree()

func update_header_coins() -> void:
	if player and header_coins:
		var c = player.coins if "coins" in player else 0
		header_coins.text = "ALTIN: %d" % c

func get_icon_texture(icon_name: Variant) -> Texture2D:
	if icon_name == null:
		return null
	var name_str = str(icon_name).strip_edges()
	if name_str == "":
		return null
		
	var path = name_str
	if not path.begins_with("res://"):
		path = "res://assets/icons/" + name_str
		
	# 1. Godot ResourceLoader (eğer dosya içe aktarılmışsa)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
			
	# 2. Doğrudan dosya sisteminden okuma (editör açık olmadan da anında yükler)
	var global_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(global_path):
		var img = Image.new()
		var err = img.load(global_path)
		if err == OK:
			return ImageTexture.create_from_image(img)
			
	return null

# ═══════════════════════════════════════════
# 1. KATEGORİ GÖRÜNÜMÜ
# ═══════════════════════════════════════════
func build_category_buttons() -> void:
	for child in category_list.get_children():
		child.queue_free()
		
	if not skill_data.has("categories"):
		return
		
	for cat in skill_data["categories"]:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(170, 100)
		
		var icon_tex = get_icon_texture(cat.get("icon", ""))
		if icon_tex:
			btn.icon = icon_tex
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			btn.add_theme_constant_override("icon_max_width", 38)
			btn.text = "\n%s [%s]" % [cat.get("name", "").to_upper(), cat.get("code", "")]
		else:
			btn.text = "%s\n[%s]" % [cat.get("name", "").to_upper(), cat.get("code", "")]
			
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): select_category(cat["id"]))
		category_list.add_child(btn)

func show_categories() -> void:
	current_category_id = ""
	category_view.visible = true
	tree_scroll.visible = false
	btn_back.visible = false
	header_title.text = "YETENEK AGACI - KATEGORI SEC"
	update_header_coins()

# ═══════════════════════════════════════════
# 2. SEÇİLEN KATEGORİ VE DALLANAN AĞAÇ GÖRÜNÜMÜ
# ═══════════════════════════════════════════
func select_category(cat_id: String) -> void:
	current_category_id = cat_id
	category_view.visible = false
	tree_scroll.visible = true
	btn_back.visible = true
	
	var cat_data = get_category_data(cat_id)
	if cat_data.is_empty():
		return
		
	header_title.text = "%s YETENEK DALI" % cat_data.get("name", "").to_upper()
	build_category_tree(cat_data)
	update_header_coins()

func get_category_data(cat_id: String) -> Dictionary:
	for cat in skill_data.get("categories", []):
		if cat.get("id") == cat_id:
			return cat
	return {}

func get_node_cost(node_info: Dictionary, level: int) -> int:
	var base_c: float = float(node_info.get("base_cost", node_info.get("cost", 10)))
	var mult: float = float(node_info.get("cost_multiplier", 1.5))
	# Üstel artış ve yukarı yuvarlama: ceil(base_cost * mult^level)
	return int(ceil(base_c * pow(mult, level)))

func build_category_tree(cat_data: Dictionary) -> void:
	# Önceki düğümleri temizle
	for child in tree_canvas.get_children():
		child.queue_free()
	line_connections.clear()
	
	var nodes_list: Array = cat_data.get("nodes", [])
	if nodes_list.is_empty():
		return
		
	# 1. parent -> children eşlemesi
	var children_map: Dictionary = {}
	var node_map: Dictionary = {}
	var root_nodes: Array = []
	
	for n in nodes_list:
		var nid = n["id"]
		node_map[nid] = n
		children_map[nid] = []
		
	for n in nodes_list:
		var p = n.get("parent", "")
		if p == "" or not node_map.has(p):
			root_nodes.append(n)
		else:
			children_map[p].append(n)
			
	# 2. Alt-ağaç genişliklerini hesapla
	var widths: Dictionary = {}
	for r in root_nodes:
		calc_subtree_width(r["id"], children_map, widths)
		
	# 3. Düğümleri ve bağlantıları konumlandır
	var total_tree_width: float = 0.0
	for r in root_nodes:
		total_tree_width += widths[r["id"]] + 60.0
	total_tree_width = max(total_tree_width, 1000.0)
	
	var start_x: float = 80.0
	var positions: Dictionary = {}
	for r in root_nodes:
		var w = widths[r["id"]]
		var root_x = start_x + (w * 0.5)
		layout_node_recursive(r["id"], root_x, 80.0, children_map, widths, positions)
		start_x += w + 60.0
		
	# 4. Canvas boyutunu ayarla
	var max_y: float = 600.0
	for pos in positions.values():
		if pos.y + 150.0 > max_y:
			max_y = pos.y + 150.0
			
	tree_canvas.custom_minimum_size = Vector2(max(total_tree_width + 180.0, 1100.0), max_y + 120.0)
	
	# 5. Düğüm Butonlarını Ekle
	for nid in positions.keys():
		var ninfo = node_map[nid]
		var pos: Vector2 = positions[nid]
		create_node_button(ninfo, pos)
		
	# 6. Bağlantı Çizgilerini Kaydet
	for pid in children_map.keys():
		if not positions.has(pid):
			continue
		var p_pos: Vector2 = positions[pid]
		var p_bottom = p_pos + Vector2(75, 80) # Düğüm alt merkezi (genişlik 150, yükseklik 80)
		var p_unlocked = skill_levels.get(pid, 0) >= 1
		
		for child in children_map[pid]:
			var cid = child["id"]
			if not positions.has(cid):
				continue
			var c_pos: Vector2 = positions[cid]
			var c_top = c_pos + Vector2(75, 0) # Düğüm üst merkezi
			var c_unlocked = skill_levels.get(cid, 0) >= 1
			
			line_connections.append({
				"from": p_bottom,
				"to": c_top,
				"active": p_unlocked and c_unlocked
			})
			
	tree_canvas.queue_redraw()

func calc_subtree_width(nid: String, children_map: Dictionary, widths: Dictionary) -> float:
	var children: Array = children_map.get(nid, [])
	if children.is_empty():
		widths[nid] = 170.0
		return 170.0
		
	var total_w: float = 0.0
	for c in children:
		total_w += calc_subtree_width(c["id"], children_map, widths) + 30.0
	total_w -= 30.0
	total_w = max(total_w, 170.0)
	widths[nid] = total_w
	return total_w

func layout_node_recursive(nid: String, center_x: float, y: float, children_map: Dictionary, widths: Dictionary, positions: Dictionary) -> void:
	# Düğüm sol üst konumu (genişlik 150, yükseklik 80)
	positions[nid] = Vector2(center_x - 75.0, y)
	
	var children: Array = children_map.get(nid, [])
	if children.is_empty():
		return
		
	var total_w = widths[nid]
	var current_left = center_x - (total_w * 0.5)
	
	for c in children:
		var cid = c["id"]
		var cw = widths[cid]
		var c_center = current_left + (cw * 0.5)
		layout_node_recursive(cid, c_center, y + 135.0, children_map, widths, positions)
		current_left += cw + 30.0

func create_node_button(node_info: Dictionary, pos: Vector2) -> void:
	var nid: String = node_info["id"]
	var pid: String = node_info.get("parent", "")
	var max_lvl: int = int(node_info.get("max_level", 1))
	var cur_lvl: int = int(skill_levels.get(nid, 0))
	var is_maxed: bool = cur_lvl >= max_lvl
	
	var parent_lvl: int = int(skill_levels.get(pid, 0))
	var parent_unlocked: bool = (pid == "" or parent_lvl >= 1)
	var is_available: bool = parent_unlocked and not is_maxed
	
	var next_cost: int = get_node_cost(node_info, cur_lvl)
	var player_coins = player.coins if (player and "coins" in player) else 0
	var can_afford = player_coins >= next_cost
	
	var btn = Button.new()
	btn.position = pos
	btn.size = Vector2(150, 80)
	btn.custom_minimum_size = Vector2(150, 80)
	
	var base_name = node_info.get("name", "")
	var icon_tex = get_icon_texture(node_info.get("icon", ""))
	
	if icon_tex:
		btn.icon = icon_tex
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.add_theme_constant_override("icon_max_width", 34)
		
		if is_maxed:
			btn.text = "%s\nMAX %d/%d" % [base_name, cur_lvl, max_lvl]
			btn.modulate = Color(0.3, 1.0, 0.4)
			btn.disabled = true
		elif is_available:
			btn.text = "%s\n%d/%d • %d G" % [base_name, cur_lvl, max_lvl, next_cost]
			if can_afford:
				btn.modulate = Color(0.1, 0.95, 1.0)
			else:
				btn.modulate = Color(1.0, 0.65, 0.2)
			btn.pressed.connect(func(): buy_skill(node_info))
		else:
			btn.text = "%s\n[ KILITLI ]" % base_name
			btn.modulate = Color(0.5, 0.5, 0.6)
			btn.disabled = true
	else:
		if is_maxed:
			btn.text = "%s\n[MAX %d/%d]" % [base_name, cur_lvl, max_lvl]
			btn.modulate = Color(0.3, 1.0, 0.4) # Yeşil (Maksimum)
			btn.disabled = true
		elif is_available:
			btn.text = "%s [%d/%d]\n%d G" % [base_name, cur_lvl, max_lvl, next_cost]
			if can_afford:
				btn.modulate = Color(0.1, 0.95, 1.0) # Parlak Satın Alınabilir
			else:
				btn.modulate = Color(1.0, 0.65, 0.2) # Yetersiz Altın
			btn.pressed.connect(func(): buy_skill(node_info))
		else:
			btn.text = "%s [0/%d]\n[ KILITLI ]" % [base_name, max_lvl]
			btn.modulate = Color(0.5, 0.5, 0.6)
			btn.disabled = true
		
	btn.tooltip_text = "%s\nBedel: %d G (Seviye %d/%d)" % [node_info.get("desc", ""), next_cost, cur_lvl, max_lvl]
	tree_canvas.add_child(btn)

func buy_skill(node_info: Dictionary) -> void:
	var nid: String = node_info["id"]
	var max_lvl: int = int(node_info.get("max_level", 1))
	var cur_lvl: int = int(skill_levels.get(nid, 0))
	
	if cur_lvl >= max_lvl:
		return
		
	var cost: int = get_node_cost(node_info, cur_lvl)
	
	if not player:
		return
	var player_coins = player.coins if "coins" in player else 0
	if player_coins < cost:
		header_coins.text = "YETERSIZ ALTIN! (%d Gerekli)" % cost
		return
		
	# Altın düş ve seviyeyi artır
	player.coins -= cost
	skill_levels[nid] = cur_lvl + 1
	
	# İstatistik artışını uygula (yukarı yuvarlanarak)
	apply_skill_effect(node_info)
	
	# Ekranı tazele
	update_header_coins()
	var cat_data = get_category_data(current_category_id)
	build_category_tree(cat_data)

func apply_skill_effect(node_info: Dictionary) -> void:
	if not player:
		return
	var stat = node_info.get("stat", "")
	var raw_val = float(node_info.get("value", 5))
	
	# Atak ve diğer değerler için yukarı yuvarla
	var val = int(ceil(raw_val))
	
	match stat:
		"attack_dmg":
			if "attack_dmg" in player:
				player.attack_dmg += val
		"defense":
			if "defense" in player:
				player.defense += val
		"max_hp":
			if "max_hp" in player:
				player.max_hp += val
				player.current_hp += val
		"speed":
			if "speed" in player:
				player.speed += float(val)
		"magic_dmg":
			if "magic_dmg" in player:
				player.magic_dmg += val
		"crit_chance":
			if "crit_chance" in player:
				player.crit_chance += raw_val
		"crit_multiplier":
			if "crit_multiplier" in player:
				player.crit_multiplier += raw_val
		"coins":
			if "coins" in player:
				player.coins += val

# ═══════════════════════════════════════════
# 3. BAĞLANTI ÇİZGİLERİNİN ÇİZİMİ
# ═══════════════════════════════════════════
func _on_tree_canvas_draw() -> void:
	for conn in line_connections:
		var from_pos: Vector2 = conn["from"]
		var to_pos: Vector2 = conn["to"]
		var active: bool = conn["active"]
		
		var col = Color(0.0, 0.95, 1.0, 0.95) if active else Color(0.3, 0.4, 0.55, 0.7)
		var width = 3.5 if active else 2.0
		
		var mid_y = lerp(from_pos.y, to_pos.y, 0.5)
		
		# 1. Aşağı iniş
		tree_canvas.draw_line(from_pos, Vector2(from_pos.x, mid_y), col, width)
		# 2. Yatay köprü
		tree_canvas.draw_line(Vector2(from_pos.x, mid_y), Vector2(to_pos.x, mid_y), col, width)
		# 3. Hedefe iniş
		tree_canvas.draw_line(Vector2(to_pos.x, mid_y), to_pos, col, width)
		
		# 4. Ok ucu (Arrowhead)
		var arrow_size = 7.0
		tree_canvas.draw_line(to_pos, to_pos + Vector2(-arrow_size, -arrow_size), col, width)
		tree_canvas.draw_line(to_pos, to_pos + Vector2(arrow_size, -arrow_size), col, width)
