extends CanvasLayer

@export var player_path: NodePath
var player: CharacterBody2D

# JSON Verisi ve Seviye Durumu
var skill_data: Dictionary = {}
var skill_levels: Dictionary = {} # nid -> current_level: int
var current_category_id: String = ""

# Düğüm Boyut Sabitleri (Altıgen Ölçüleri)
const NODE_W: float = 72.0
const NODE_H: float = 80.0
const HALF_W: float = 36.0
const SUBTREE_PAD: float = 24.0
const LEVEL_Y_STEP: float = 145.0

# Düğüm referansları
@onready var overlay = $Overlay
@onready var header_title = $Overlay/Header/TitleLabel
@onready var header_coins = $Overlay/Header/CoinLabel
@onready var btn_close = $Overlay/Header/CloseBtn

# Üst Ana Düğüm / Kategori Sekmeleri Barı
@onready var category_bar = get_node_or_null("Overlay/CategoryBar")
@onready var category_tabs = get_node_or_null("Overlay/CategoryBar/CategoryTabs")

@onready var tree_scroll = $Overlay/TreeScroll
@onready var tree_canvas = $Overlay/TreeScroll/TreeCanvas

# Detay & Yükseltme Modalı
@onready var detail_modal = get_node_or_null("Overlay/DetailModal")
@onready var modal_close = get_node_or_null("Overlay/DetailModal/Card/ModalCloseBtn")
@onready var modal_dimmer = get_node_or_null("Overlay/DetailModal/ModalDimmer")
@onready var modal_back = get_node_or_null("Overlay/DetailModal/Card/BackModalBtn")
@onready var modal_icon = get_node_or_null("Overlay/DetailModal/Card/IconRect")
@onready var modal_name = get_node_or_null("Overlay/DetailModal/Card/SkillName")
@onready var modal_level = get_node_or_null("Overlay/DetailModal/Card/SkillLevel")
@onready var modal_desc = get_node_or_null("Overlay/DetailModal/Card/DescLabel")
@onready var modal_stats = get_node_or_null("Overlay/DetailModal/Card/StatsLabel")
@onready var modal_cost = get_node_or_null("Overlay/DetailModal/Card/CostLabel")
@onready var modal_upgrade = get_node_or_null("Overlay/DetailModal/Card/UpgradeBtn")

var active_modal_node: Dictionary = {}

# Çizim bağlantıları (Düz, Çapraz, Yatay Köprü Barı)
var branch_connections: Array = []

func _ready() -> void:
	if has_node(player_path):
		player = get_node(player_path) as CharacterBody2D
		
	btn_close.pressed.connect(close_tree)
	
	if modal_close:
		modal_close.pressed.connect(close_node_detail)
	if modal_dimmer:
		modal_dimmer.pressed.connect(close_node_detail)
	if modal_back:
		modal_back.pressed.connect(close_node_detail)
	if modal_upgrade:
		modal_upgrade.pressed.connect(_on_modal_upgrade_clicked)
	
	load_skill_json()
	overlay.visible = false
	if detail_modal:
		detail_modal.visible = false
	
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
		build_top_category_tabs()
	else:
		push_error("JSON Parse hatası: " + json.get_error_message())

func open_tree() -> void:
	overlay.visible = true
	update_header_coins()
	# Varsayılan olarak ilk kategoriye aç
	if current_category_id == "":
		if skill_data.get("categories", []).size() > 0:
			current_category_id = skill_data["categories"][0]["id"]
	select_category(current_category_id)

func close_tree() -> void:
	close_node_detail()
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
			
	# 2. Doğrudan dosya sisteminden okuma
	var global_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(global_path):
		var img = Image.new()
		var err = img.load(global_path)
		if err == OK:
			return ImageTexture.create_from_image(img)
			
	return null

# ═══════════════════════════════════════════
# 1. EN ÜST ANA KATEGORİ SEKMELERİ (GEÇİŞ ÇUBUĞU)
# ═══════════════════════════════════════════
func build_top_category_tabs() -> void:
	if not category_tabs:
		return
		
	for child in category_tabs.get_children():
		child.queue_free()
		
	if not skill_data.has("categories"):
		return
		
	for cat in skill_data["categories"]:
		var cat_id = cat.get("id", "")
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(175, 42)
		btn.size = Vector2(175, 42)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var icon_tex = get_icon_texture(cat.get("icon", ""))
		if icon_tex:
			btn.icon = icon_tex
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			btn.add_theme_constant_override("icon_max_width", 26)
			
		btn.text = " %s [%s]" % [cat.get("name", "").to_upper(), cat.get("code", "")]
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func(): select_category(cat_id))
		category_tabs.add_child(btn)
		
	update_category_tab_styles()

func update_category_tab_styles() -> void:
	if not category_tabs:
		return
		
	var idx = 0
	for child in category_tabs.get_children():
		if child is Button and idx < skill_data.get("categories", []).size():
			var cat = skill_data["categories"][idx]
			var is_active = (cat.get("id", "") == current_category_id)
			if is_active:
				# Aktif Sekme (Parlak Neon Cyan & Dolgulu)
				child.modulate = Color(0.2, 0.95, 1.15, 1.0)
			else:
				# Pasif Sekme (Muted / Koyu)
				child.modulate = Color(0.65, 0.72, 0.82, 0.7)
		idx += 1

func select_category(cat_id: String) -> void:
	close_node_detail()
	current_category_id = cat_id
	update_category_tab_styles()
	
	var cat_data = get_category_data(cat_id)
	if cat_data.is_empty():
		return
		
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
	return int(ceil(base_c * pow(mult, level)))

# ═══════════════════════════════════════════
# 2. AĞAÇ OLUŞTURMA VE KUSURSUZ MERKEZLEME
# ═══════════════════════════════════════════
func build_category_tree(cat_data: Dictionary) -> void:
	for child in tree_canvas.get_children():
		child.queue_free()
	branch_connections.clear()
	
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
		
	# 3. Düğümleri 0 merkez noktası etrafında hesapla
	var positions: Dictionary = {}
	for r in root_nodes:
		layout_node_recursive(r["id"], 0.0, 40.0, children_map, widths, positions)
		
	# 4. KUSURSUZ MERKEZLEME: Ağacın Bounding Box'ını bul
	var min_node_x: float = 999999.0
	var max_node_x: float = -999999.0
	var max_node_y: float = 500.0
	
	for pos in positions.values():
		min_node_x = min(min_node_x, pos.x)
		max_node_x = max(max_node_x, pos.x + NODE_W)
		max_node_y = max(max_node_y, pos.y + NODE_H)
		
	var actual_tree_w = max_node_x - min_node_x
	var actual_tree_center = (min_node_x + max_node_x) * 0.5
	
	var viewport_w: float = 1280.0
	if tree_scroll and tree_scroll.size.x > 200.0:
		viewport_w = tree_scroll.size.x
		
	var canvas_w = max(viewport_w, actual_tree_w + 120.0)
	var canvas_center_x = canvas_w * 0.5
	var shift_x = canvas_center_x - actual_tree_center
	
	# Tüm düğümleri tam ekranda ortalanacak şekilde kaydır
	for nid in positions.keys():
		positions[nid].x += shift_x
		
	tree_canvas.custom_minimum_size = Vector2(canvas_w, max_node_y + 80.0)
	
	if canvas_w > viewport_w:
		tree_scroll.scroll_horizontal = int((canvas_w - viewport_w) * 0.5)
	else:
		tree_scroll.scroll_horizontal = 0
	
	# 5. Düğüm Butonlarını Ekle (Saf Altıgen İkon)
	for nid in positions.keys():
		var ninfo = node_map[nid]
		var pos: Vector2 = positions[nid]
		create_node_button(ninfo, pos)
		
	# 6. Çizimdeki Bağlantı Oklarını ve Köprüleri Ekle
	for pid in children_map.keys():
		var children = children_map[pid]
		if children.is_empty() or not positions.has(pid):
			continue
			
		var p_pos: Vector2 = positions[pid]
		var p_bottom = p_pos + Vector2(HALF_W, NODE_H)
		var p_unlocked = skill_levels.get(pid, 0) >= 1
		
		if children.size() == 1:
			var cid = children[0]["id"]
			if positions.has(cid):
				var c_pos: Vector2 = positions[cid]
				var c_top = c_pos + Vector2(HALF_W, 0)
				var c_unlocked = skill_levels.get(cid, 0) >= 1
				branch_connections.append({
					"type": "straight",
					"from": p_bottom,
					"to": c_top,
					"active": p_unlocked and c_unlocked
				})
		elif pid == "atk_tier1" or (children.size() == 2 and pid == root_nodes[0].get("id", "")):
			# İki yana açılan çapraz oklar (Seviye 1 -> Seviye 2)
			for child in children:
				var cid = child["id"]
				if positions.has(cid):
					var c_pos: Vector2 = positions[cid]
					var c_top = c_pos + Vector2(HALF_W, 0)
					var c_unlocked = skill_levels.get(cid, 0) >= 1
					branch_connections.append({
						"type": "diagonal",
						"from": p_bottom,
						"to": c_top,
						"active": p_unlocked and c_unlocked
					})
		else:
			# Yatay köprü ve dikey iniş okları (Seviye 2 -> Seviye 3)
			var bus_y = p_bottom.y + 35.0
			var c_info_list: Array = []
			for child in children:
				var cid = child["id"]
				if positions.has(cid):
					var c_pos: Vector2 = positions[cid]
					var c_top = c_pos + Vector2(HALF_W, 0)
					var c_unlocked = skill_levels.get(cid, 0) >= 1
					c_info_list.append({
						"pos": c_top,
						"active": p_unlocked and c_unlocked
					})
			branch_connections.append({
				"type": "bus",
				"from": p_bottom,
				"bus_y": bus_y,
				"child_tops": c_info_list,
				"active": p_unlocked
			})
			
	tree_canvas.queue_redraw()

func calc_subtree_width(nid: String, children_map: Dictionary, widths: Dictionary) -> float:
	var children: Array = children_map.get(nid, [])
	if children.is_empty():
		widths[nid] = NODE_W
		return NODE_W
		
	var total_w: float = 0.0
	for c in children:
		total_w += calc_subtree_width(c["id"], children_map, widths) + SUBTREE_PAD
	total_w -= SUBTREE_PAD
	total_w = max(total_w, NODE_W)
	widths[nid] = total_w
	return total_w

func layout_node_recursive(nid: String, center_x: float, y: float, children_map: Dictionary, widths: Dictionary, positions: Dictionary) -> void:
	positions[nid] = Vector2(center_x - HALF_W, y)
	
	var children: Array = children_map.get(nid, [])
	if children.is_empty():
		return
		
	# Eğer tam 2 çocuk varsa (Tier 1 gibi), merkezi iki yana dengeli aç
	if children.size() == 2:
		var c1 = children[0]["id"]
		var c2 = children[1]["id"]
		var w1 = widths[c1]
		var w2 = widths[c2]
		var branch_gap = 70.0
		var c1_center = center_x - (w1 * 0.5) - (branch_gap * 0.5)
		var c2_center = center_x + (w2 * 0.5) + (branch_gap * 0.5)
		layout_node_recursive(c1, c1_center, y + LEVEL_Y_STEP, children_map, widths, positions)
		layout_node_recursive(c2, c2_center, y + LEVEL_Y_STEP, children_map, widths, positions)
		return
		
	var total_w = widths[nid]
	var current_left = center_x - (total_w * 0.5)
	
	for c in children:
		var cid = c["id"]
		var cw = widths[cid]
		var c_center = current_left + (cw * 0.5)
		layout_node_recursive(cid, c_center, y + LEVEL_Y_STEP, children_map, widths, positions)
		current_left += cw + SUBTREE_PAD

# ═══════════════════════════════════════════
# 3. SAF ALTIGEN DÜĞÜM BUTONU
# ═══════════════════════════════════════════
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
	btn.size = Vector2(NODE_W, NODE_H)
	btn.custom_minimum_size = Vector2(NODE_W, NODE_H)
	btn.flat = true
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var base_name = node_info.get("name", "")
	var icon_tex = get_icon_texture(node_info.get("icon", ""))
	
	# 1. Altıgen İkon Görseli
	if icon_tex:
		var icon_rect = TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.position = Vector2(0, 0)
		icon_rect.size = Vector2(NODE_W, NODE_H)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)
	else:
		var placeholder = Label.new()
		placeholder.position = Vector2(0, 15)
		placeholder.size = Vector2(NODE_W, 40)
		placeholder.text = base_name.left(3)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_font_size_override("font_size", 16)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(placeholder)

	# 2. Minimalist Seviye İndikatörü
	var lvl_lbl = Label.new()
	lvl_lbl.position = Vector2(0, NODE_H - 18)
	lvl_lbl.size = Vector2(NODE_W, 16)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lvl_lbl.add_theme_font_size_override("font_size", 12)
	lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if is_maxed:
		lvl_lbl.text = "MAX"
		lvl_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	elif is_available:
		lvl_lbl.text = "%d/%d" % [cur_lvl, max_lvl]
		lvl_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	else:
		lvl_lbl.text = ""
	btn.add_child(lvl_lbl)
	
	# Parlama ve Durum Renkleri
	if is_maxed:
		btn.modulate = Color(0.35, 1.15, 0.55, 1.0) # Zümrüt Parlama
	elif is_available:
		if can_afford:
			btn.modulate = Color(0.3, 1.0, 1.15, 1.0) # Parlak Neon Cyan
		else:
			btn.modulate = Color(1.0, 0.8, 0.3, 1.0) # Yetersiz Bakiye
	else:
		btn.modulate = Color(0.35, 0.4, 0.5, 0.6) # Kilitli
		
	btn.tooltip_text = "%s (Seviye %d/%d)" % [base_name, cur_lvl, max_lvl]
	btn.pressed.connect(func(): open_node_detail(node_info))
	
	tree_canvas.add_child(btn)

# ═══════════════════════════════════════════
# 4. YETENEK DETAY & YÜKSELTME MODALI
# ═══════════════════════════════════════════
func open_node_detail(node_info: Dictionary) -> void:
	active_modal_node = node_info
	if detail_modal:
		detail_modal.visible = true
	refresh_node_detail()

func close_node_detail() -> void:
	if detail_modal:
		detail_modal.visible = false
	active_modal_node = {}

func refresh_node_detail() -> void:
	if active_modal_node.is_empty() or not detail_modal:
		return
		
	var nid: String = active_modal_node["id"]
	var pid: String = active_modal_node.get("parent", "")
	var max_lvl: int = int(active_modal_node.get("max_level", 1))
	var cur_lvl: int = int(skill_levels.get(nid, 0))
	var is_maxed: bool = cur_lvl >= max_lvl
	
	var parent_lvl: int = int(skill_levels.get(pid, 0))
	var parent_unlocked: bool = (pid == "" or parent_lvl >= 1)
	var is_available: bool = parent_unlocked and not is_maxed
	
	var next_cost: int = get_node_cost(active_modal_node, cur_lvl)
	var player_coins: int = player.coins if (player and "coins" in player) else 0
	var can_afford: bool = player_coins >= next_cost
	
	var base_name: String = active_modal_node.get("name", "")
	var desc: String = active_modal_node.get("desc", "")
	var stat_name: String = active_modal_node.get("stat", "")
	var stat_val: float = float(active_modal_node.get("value", 5))
	
	# 1. Başlık ve Büyük İkon
	if modal_name:
		modal_name.text = base_name
	var icon_tex = get_icon_texture(active_modal_node.get("icon", ""))
	if modal_icon:
		if icon_tex:
			modal_icon.texture = icon_tex
			modal_icon.visible = true
		else:
			modal_icon.visible = false
			
	# 2. Seviye
	if modal_level:
		if is_maxed:
			modal_level.text = "SEVİYE: %d / %d (MAKSİMUM)" % [cur_lvl, max_lvl]
			modal_level.modulate = Color(0.25, 1.0, 0.45)
		elif is_available:
			modal_level.text = "SEVİYE: %d / %d" % [cur_lvl, max_lvl]
			modal_level.modulate = Color(0.2, 0.9, 1.0)
		else:
			modal_level.text = "SEVİYE: 0 / %d [KİLİTLİ]" % max_lvl
			modal_level.modulate = Color(0.65, 0.7, 0.8)
			
	# 3. Açıklama
	if modal_desc:
		modal_desc.text = desc
		
	# 4. İstatistik Karşılaştırması
	if modal_stats:
		var is_rate = stat_name == "crit_chance"
		var is_mult = stat_name == "crit_multiplier"
		var cur_val_display = ""
		var next_val_display = ""
		
		if is_rate:
			cur_val_display = "%%%d" % int(stat_val * cur_lvl * 100)
			next_val_display = "%%%d" % int(stat_val * (cur_lvl + 1) * 100)
		elif is_mult:
			cur_val_display = "+%.2fx" % (stat_val * cur_lvl)
			next_val_display = "+%.2fx" % (stat_val * (cur_lvl + 1))
		else:
			cur_val_display = "+%d" % int(ceil(stat_val * cur_lvl))
			next_val_display = "+%d" % int(ceil(stat_val * (cur_lvl + 1)))
			
		var stat_title = "Etki Değeri"
		match stat_name:
			"attack_dmg": stat_title = "Saldırı Gücü"
			"defense": stat_title = "Savunma"
			"max_hp": stat_title = "Maksimum Can"
			"speed": stat_title = "Hareket Hızı"
			"magic_dmg": stat_title = "Büyü Hasarı"
			"crit_chance": stat_title = "Kritik Şansı"
			"crit_multiplier": stat_title = "Kritik Çarpanı"
			
		if is_maxed:
			modal_stats.text = "%s: %s (MAKSİMUM DÜZEY)" % [stat_title, cur_val_display]
		else:
			modal_stats.text = "%s:\nMevcut: %s  ->  Yükseltme Sonrası: %s" % [stat_title, cur_val_display, next_val_display]
			
	# 5. Bedel ve Yükseltme Butonu Durumu
	if modal_cost and modal_upgrade:
		if is_maxed:
			modal_cost.text = "TÜM SEVİYELER TAMAMLANDI"
			modal_cost.modulate = Color(0.25, 1.0, 0.45)
			modal_upgrade.text = "TAMAMLANDI (MAX)"
			modal_upgrade.disabled = true
			modal_upgrade.modulate = Color(0.5, 0.5, 0.5)
		elif not parent_unlocked:
			modal_cost.text = "BU YETENEK KİLİTLİ (Önceki Yeteneği Açın)"
			modal_cost.modulate = Color(0.8, 0.5, 0.5)
			modal_upgrade.text = "KİLİTLİ"
			modal_upgrade.disabled = true
			modal_upgrade.modulate = Color(0.5, 0.5, 0.5)
		elif not can_afford:
			modal_cost.text = "BEDEL: %d ALTIN (Mevcut Altınınız: %d)" % [next_cost, player_coins]
			modal_cost.modulate = Color(1.0, 0.4, 0.3)
			modal_upgrade.text = "YETERSİZ ALTIN (%d Gerekli)" % next_cost
			modal_upgrade.disabled = true
			modal_upgrade.modulate = Color(0.8, 0.4, 0.4)
		else:
			modal_cost.text = "BEDEL: %d ALTIN (Mevcut Altınınız: %d)" % [next_cost, player_coins]
			modal_cost.modulate = Color(1.0, 0.85, 0.2)
			modal_upgrade.text = "YÜKSELT (%d ALTIN)" % next_cost
			modal_upgrade.disabled = false
			modal_upgrade.modulate = Color(0.15, 0.95, 1.0)

func _on_modal_upgrade_clicked() -> void:
	if active_modal_node.is_empty():
		return
	buy_skill(active_modal_node)
	refresh_node_detail()

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
		return
		
	player.coins -= cost
	skill_levels[nid] = cur_lvl + 1
	apply_skill_effect(node_info)
	
	update_header_coins()
	var cat_data = get_category_data(current_category_id)
	build_category_tree(cat_data)

func apply_skill_effect(node_info: Dictionary) -> void:
	if not player:
		return
	var stat = node_info.get("stat", "")
	var raw_val = float(node_info.get("value", 5))
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
# 5. OKLAR VE KÖPRÜLERİN ÇİZİMİ
# ═══════════════════════════════════════════
func _on_tree_canvas_draw() -> void:
	for conn in branch_connections:
		var c_type = conn.get("type", "straight")
		
		match c_type:
			"straight":
				var from_pos: Vector2 = conn["from"]
				var to_pos: Vector2 = conn["to"]
				var active: bool = conn["active"]
				var col = Color(0.25, 0.95, 1.0, 0.95) if active else Color(0.42, 0.48, 0.58, 0.75)
				var width = 2.4 if active else 1.8
				
				tree_canvas.draw_line(from_pos, to_pos, col, width)
				draw_arrow_head(to_pos, Vector2.DOWN, col, width)
				
			"diagonal":
				var from_pos: Vector2 = conn["from"]
				var to_pos: Vector2 = conn["to"]
				var active: bool = conn["active"]
				var col = Color(0.25, 0.95, 1.0, 0.95) if active else Color(0.42, 0.48, 0.58, 0.75)
				var width = 2.4 if active else 1.8
				
				tree_canvas.draw_line(from_pos, to_pos, col, width)
				var dir = (to_pos - from_pos).normalized()
				draw_arrow_head(to_pos, dir, col, width)
				
			"bus":
				var from_pos: Vector2 = conn["from"]
				var bus_y: float = conn["bus_y"]
				var children_info: Array = conn["child_tops"]
				var active: bool = conn["active"]
				var col = Color(0.25, 0.95, 1.0, 0.95) if active else Color(0.42, 0.48, 0.58, 0.75)
				var width = 2.4 if active else 1.8
				
				# 1. Dikey iniş gövdesi
				tree_canvas.draw_line(from_pos, Vector2(from_pos.x, bus_y), col, width)
				
				# 2. Yatay köprü barı
				if children_info.size() > 0:
					var min_x = from_pos.x
					var max_x = from_pos.x
					for c in children_info:
						min_x = min(min_x, c["pos"].x)
						max_x = max(max_x, c["pos"].x)
					tree_canvas.draw_line(Vector2(min_x, bus_y), Vector2(max_x, bus_y), col, width)
					
					# 3. Her çocuğa dikey iniş okları
					for c in children_info:
						var c_pos = c["pos"]
						var c_active = c["active"]
						var c_col = Color(0.25, 0.95, 1.0, 0.95) if c_active else Color(0.42, 0.48, 0.58, 0.75)
						var c_width = 2.4 if c_active else 1.8
						
						tree_canvas.draw_line(Vector2(c_pos.x, bus_y), c_pos, c_col, c_width)
						draw_arrow_head(c_pos, Vector2.DOWN, c_col, c_width)

func draw_arrow_head(tip: Vector2, dir: Vector2, col: Color, width: float) -> void:
	var arrow_len = 9.0
	var normal = Vector2(-dir.y, dir.x)
	var left = tip - (dir * arrow_len) + (normal * 5.0)
	var right = tip - (dir * arrow_len) - (normal * 5.0)
	
	tree_canvas.draw_line(tip, left, col, width)
	tree_canvas.draw_line(tip, right, col, width)
