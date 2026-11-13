extends Control
class_name GameUI
## Oyun içi üst bilgi barı, İpucu/Karıştır/Geri Al/Yeniden Başlat alt kontrol paneli
## ve Kazanma/Kaybetme/Seviye Seçim pencerelerini yönetir.

signal restart_requested
signal undo_requested
signal hint_requested
signal shuffle_requested
signal next_level_requested
signal level_selected(level_number: int)
signal sound_toggled
signal menu_requested

var level_label: Label
var moves_label: Label
var status_label: Label

var undo_button: Button
var hint_button: Button
var shuffle_button: Button
var restart_button: Button
var sound_button: Button
var levels_button: Button
var menu_button: Button

var overlay_backdrop: ColorRect
var overlay_title: Label
var overlay_message: Label
var overlay_next_btn: Button
var overlay_restart_btn: Button
var overlay_undo_btn: Button
var overlay_menu_btn: Button

var level_select_backdrop: ColorRect
var level_grid: GridContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# 1. Üst Başlık ve Kontrol Alanı
	var header_panel: PanelContainer = PanelContainer.new()
	header_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header_panel.offset_left = 20.0
	header_panel.offset_top = 28.0
	header_panel.offset_right = -20.0
	header_panel.offset_bottom = 158.0
	header_panel.add_theme_stylebox_override("panel", _create_stylebox(Color("#1E293B"), 20, Color("#334155"), 2))
	add_child(header_panel)

	var header_margin: MarginContainer = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 12)
	header_margin.add_theme_constant_override("margin_right", 12)
	header_margin.add_theme_constant_override("margin_top", 8)
	header_margin.add_theme_constant_override("margin_bottom", 8)
	header_panel.add_child(header_margin)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 8)
	header_margin.add_child(header_hbox)

	menu_button = _create_action_button("MENÜ", Color("#334155"), Color("#475569"), 15)
	menu_button.custom_minimum_size = Vector2(92, 54)
	menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	header_hbox.add_child(menu_button)

	levels_button = _create_action_button("SEVİYE", Color("#2563EB"), Color("#3B82F6"), 15)
	levels_button.custom_minimum_size = Vector2(96, 54)
	levels_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	levels_button.pressed.connect(func() -> void: level_select_backdrop.visible = true)
	header_hbox.add_child(levels_button)

	var header_vbox: VBoxContainer = VBoxContainer.new()
	header_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(header_vbox)

	var title_label: Label = Label.new()
	title_label.text = "CHROMA FLOW"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color("#F8FAFC"))
	header_vbox.add_child(title_label)

	level_label = Label.new()
	level_label.text = "SEVİYE 1"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color", Color("#38BDF8"))
	header_vbox.add_child(level_label)

	moves_label = Label.new()
	moves_label.text = "Hamle: 0 | En İyi: -"
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moves_label.add_theme_font_size_override("font_size", 14)
	moves_label.add_theme_color_override("font_color", Color("#94A3B8"))
	header_vbox.add_child(moves_label)

	sound_button = _create_action_button("SES: AÇIK", Color("#0F766E"), Color("#14B8A6"), 15)
	sound_button.custom_minimum_size = Vector2(112, 54)
	sound_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sound_button.pressed.connect(func() -> void: sound_toggled.emit())
	header_hbox.add_child(sound_button)

	# 2. Durum ve Geri Bildirim Etiketi
	status_label = Label.new()
	status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_top = 170.0
	status_label.offset_bottom = 210.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 19)
	status_label.add_theme_color_override("font_color", Color("#CBD5E1"))
	status_label.text = "Yolu açık olan bir ok bloğuna dokunun"
	add_child(status_label)

	# 3. Alt Kontrol ve Joker Paneli (2x2 Mobil Buton Izgarası)
	var bottom_grid: GridContainer = GridContainer.new()
	bottom_grid.columns = 2
	bottom_grid.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_grid.offset_left = 30.0
	bottom_grid.offset_top = -210.0
	bottom_grid.offset_right = -30.0
	bottom_grid.offset_bottom = -38.0
	bottom_grid.add_theme_constant_override("h_separation", 18)
	bottom_grid.add_theme_constant_override("v_separation", 14)
	add_child(bottom_grid)

	hint_button = _create_action_button("İPUCU (3)", Color("#D97706"), Color("#F59E0B"), 19)
	hint_button.custom_minimum_size = Vector2(320, 68)
	hint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_button.pressed.connect(func() -> void: hint_requested.emit())
	bottom_grid.add_child(hint_button)

	shuffle_button = _create_action_button("KARIŞTIR (2)", Color("#7C3AED"), Color("#8B5CF6"), 19)
	shuffle_button.custom_minimum_size = Vector2(320, 68)
	shuffle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shuffle_button.pressed.connect(func() -> void: shuffle_requested.emit())
	bottom_grid.add_child(shuffle_button)

	undo_button = _create_action_button("GERİ AL (0)", Color("#475569"), Color("#64748B"), 19)
	undo_button.custom_minimum_size = Vector2(320, 68)
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_button.pressed.connect(func() -> void: undo_requested.emit())
	bottom_grid.add_child(undo_button)

	restart_button = _create_action_button("YENİDEN BAŞLAT", Color("#2563EB"), Color("#3B82F6"), 19)
	restart_button.custom_minimum_size = Vector2(320, 68)
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	bottom_grid.add_child(restart_button)

	# 4. Kazanma / Kaybetme Sonuç Penceresi
	overlay_backdrop = ColorRect.new()
	overlay_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_backdrop.color = Color(0.03, 0.05, 0.09, 0.86)
	overlay_backdrop.visible = false
	overlay_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay_backdrop)

	var modal_panel: PanelContainer = PanelContainer.new()
	modal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal_panel.offset_left = -300.0
	modal_panel.offset_top = -250.0
	modal_panel.offset_right = 300.0
	modal_panel.offset_bottom = 250.0
	modal_panel.add_theme_stylebox_override("panel", _create_stylebox(Color("#1E293B"), 28, Color("#475569"), 3))
	overlay_backdrop.add_child(modal_panel)

	var modal_vbox: VBoxContainer = VBoxContainer.new()
	modal_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_vbox.add_theme_constant_override("separation", 20)
	modal_panel.add_child(modal_vbox)

	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 34)
	modal_vbox.add_child(overlay_title)

	overlay_message = Label.new()
	overlay_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_message.custom_minimum_size = Vector2(500, 0)
	overlay_message.add_theme_font_size_override("font_size", 21)
	overlay_message.add_theme_color_override("font_color", Color("#E2E8F0"))
	modal_vbox.add_child(overlay_message)

	var modal_btn_vbox: VBoxContainer = VBoxContainer.new()
	modal_btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_btn_vbox.add_theme_constant_override("separation", 14)
	modal_vbox.add_child(modal_btn_vbox)

	overlay_next_btn = _create_action_button("SONRAKİ SEVİYE ->", Color("#10B981"), Color("#34D399"), 22)
	overlay_next_btn.custom_minimum_size = Vector2(440, 68)
	overlay_next_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_next_btn.pressed.connect(func() -> void: next_level_requested.emit())
	modal_btn_vbox.add_child(overlay_next_btn)

	var modal_sub_hbox: HBoxContainer = HBoxContainer.new()
	modal_sub_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_sub_hbox.add_theme_constant_override("separation", 16)
	modal_btn_vbox.add_child(modal_sub_hbox)

	overlay_undo_btn = _create_action_button("HAMLEYİ GERİ AL", Color("#D97706"), Color("#F59E0B"), 18)
	overlay_undo_btn.custom_minimum_size = Vector2(212, 62)
	overlay_undo_btn.pressed.connect(func() -> void: undo_requested.emit())
	modal_sub_hbox.add_child(overlay_undo_btn)

	overlay_restart_btn = _create_action_button("TEKRAR OYNA", Color("#2563EB"), Color("#3B82F6"), 18)
	overlay_restart_btn.custom_minimum_size = Vector2(212, 62)
	overlay_restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	modal_sub_hbox.add_child(overlay_restart_btn)

	overlay_menu_btn = _create_action_button("ANA MENÜYE DÖN", Color("#475569"), Color("#64748B"), 18)
	overlay_menu_btn.custom_minimum_size = Vector2(440, 58)
	overlay_menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_menu_btn.pressed.connect(func() -> void:
		hide_overlay()
		menu_requested.emit()
	)
	modal_btn_vbox.add_child(overlay_menu_btn)

	_build_level_select_modal()


func _build_level_select_modal() -> void:
	level_select_backdrop = ColorRect.new()
	level_select_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_select_backdrop.color = Color(0.03, 0.05, 0.09, 0.90)
	level_select_backdrop.visible = false
	level_select_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(level_select_backdrop)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -310.0
	panel.offset_top = -390.0
	panel.offset_right = 310.0
	panel.offset_bottom = 390.0
	panel.add_theme_stylebox_override("panel", _create_stylebox(Color("#1E293B"), 28, Color("#475569"), 3))
	level_select_backdrop.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "SEVİYE SEÇİMİ (1 - 10)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#F8FAFC"))
	vbox.add_child(title)

	var center_grid: CenterContainer = CenterContainer.new()
	vbox.add_child(center_grid)

	level_grid = GridContainer.new()
	level_grid.columns = 2
	level_grid.add_theme_constant_override("h_separation", 18)
	level_grid.add_theme_constant_override("v_separation", 14)
	center_grid.add_child(level_grid)

	var close_btn: Button = _create_action_button("KAPAT", Color("#475569"), Color("#64748B"), 20)
	close_btn.custom_minimum_size = Vector2(240, 62)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func() -> void: level_select_backdrop.visible = false)
	vbox.add_child(close_btn)


func refresh_level_select_buttons(total_levels: int, max_unlocked: int, current_lvl: int, save_mgr: SaveManager) -> void:
	for child: Node in level_grid.get_children():
		child.queue_free()

	for lvl: int in range(1, total_levels + 1):
		var is_unlocked: bool = lvl <= max_unlocked
		var is_done: bool = save_mgr.is_level_completed(lvl)
		var best_moves: int = save_mgr.get_best_moves(lvl)

		var btn_text: String = "SEVİYE %d" % lvl
		if is_done:
			btn_text += "\n(En İyi: %d Hamle)" % best_moves
		elif is_unlocked:
			btn_text += "\n(AÇIK)"
		else:
			btn_text += "\n(KİLİTLİ)"

		var normal_col: Color = Color("#2563EB") if lvl == current_lvl else (Color("#0F766E") if is_done else Color("#334155"))
		var hover_col: Color = normal_col.lightened(0.15)
		var btn: Button = _create_action_button(btn_text, normal_col, hover_col, 17)
		btn.custom_minimum_size = Vector2(245, 78)
		btn.disabled = not is_unlocked

		var target_lvl: int = lvl
		btn.pressed.connect(func() -> void:
			level_select_backdrop.visible = false
			level_selected.emit(target_lvl)
		)
		level_grid.add_child(btn)


func set_level_info(level_id: int, total_levels: int, level_name: String) -> void:
	level_label.text = "SEVİYE %d/%d – %s" % [level_id, total_levels, level_name.to_upper()]


func set_moves_info(current_moves: int, best_moves: int) -> void:
	var best_str: String = str(best_moves) if best_moves > 0 else "-"
	moves_label.text = "Hamle: %d  |  En İyi: %s" % [current_moves, best_str]


func update_sound_button(enabled: bool) -> void:
	sound_button.text = "SES: AÇIK" if enabled else "SES: KAPALI"
	var col: Color = Color("#0F766E") if enabled else Color("#475569")
	sound_button.add_theme_stylebox_override("normal", _create_stylebox(col, 16, col.lightened(0.18), 2))


func set_status_message(msg: String, color: Color = Color("#CBD5E1")) -> void:
	status_label.text = msg
	status_label.add_theme_color_override("font_color", color)


func update_undo_count(count: int) -> void:
	undo_button.text = "GERİ AL (%d)" % count
	undo_button.disabled = (count <= 0)


func update_booster_counts(hints_left: int, shuffles_left: int, board_has_blocks: bool = true) -> void:
	hint_button.text = "İPUCU (%d)" % hints_left
	hint_button.disabled = (hints_left <= 0 or not board_has_blocks)

	shuffle_button.text = "KARIŞTIR (%d)" % shuffles_left
	shuffle_button.disabled = (shuffles_left <= 0 or not board_has_blocks)


func show_win_screen(level_id: int, total_levels: int, moves_count: int, best_moves: int) -> void:
	overlay_backdrop.visible = true
	var has_next: bool = level_id < total_levels
	overlay_title.text = "SEVİYE %d TAMAMLANDI!" % level_id if has_next else "TÜM SEVİYELER BİTTİ!"
	overlay_title.add_theme_color_override("font_color", Color("#34D399"))

	var msg: String = "Seviyeyi %d hamlede temizlediniz.\nEn iyi dereceniz: %d hamle." % [moves_count, best_moves]
	if not has_next:
		msg += "\n\n10 seviyenin tamamını başarıyla çözdünüz!"
	overlay_message.text = msg

	overlay_next_btn.visible = has_next
	overlay_undo_btn.visible = false
	overlay_restart_btn.text = "TEKRAR OYNA"


func show_lose_screen(can_undo: bool) -> void:
	overlay_backdrop.visible = true
	overlay_title.text = "BEKLEME ALANI DOLDU!"
	overlay_title.add_theme_color_override("font_color", Color("#F87171"))
	overlay_message.text = "7 yuvanın tamamı doldu ve üçlü eşleşme oluşmadı."
	overlay_next_btn.visible = false
	overlay_undo_btn.visible = can_undo
	overlay_restart_btn.text = "YENİDEN DENE"


func hide_overlay() -> void:
	overlay_backdrop.visible = false


func _create_stylebox(bg: Color, radius: int, border: Color, border_w: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	return sb


func _create_action_button(text_str: String, normal_col: Color, hover_col: Color, font_sz: int = 20) -> Button:
	var btn: Button = Button.new()
	btn.text = text_str
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.35))

	btn.add_theme_stylebox_override("normal", _create_stylebox(normal_col, 16, normal_col.lightened(0.18), 2))
	btn.add_theme_stylebox_override("hover", _create_stylebox(hover_col, 16, hover_col.lightened(0.22), 2))
	btn.add_theme_stylebox_override("pressed", _create_stylebox(normal_col.darkened(0.15), 16, normal_col, 2))
	btn.add_theme_stylebox_override("disabled", _create_stylebox(Color("#1E293B"), 16, Color("#334155"), 2))
	return btn