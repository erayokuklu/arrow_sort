extends Control
class_name MainMenu
## Dikey mobil ekran için tasarlanmış, prosedürel animasyonlu ok blokları içeren Ana Menü.
## Oyuna devam etme, seviye seçimi, ses ayarı ve ilerleme sıfırlama işlevlerini sunar.

signal play_requested
signal level_selected(level_number: int)
signal sound_toggled
signal reset_progress_requested

const ARROW_BLOCK_SCENE: PackedScene = preload("res://scenes/arrow_block.tscn")

var play_button: Button
var sound_button: Button
var progress_label: Label
var level_select_backdrop: ColorRect
var level_grid: GridContainer
var reset_confirm_backdrop: ColorRect
var _deco_blocks: Array[ArrowBlock] = []


func _ready() -> void:
	_build_menu_ui()
	_spawn_decorative_blocks()


func _build_menu_ui() -> void:
	# 1. Arka Plan
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.055, 0.082, 0.137, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 2. Merkez Ana Kart
	var center_vbox: VBoxContainer = VBoxContainer.new()
	center_vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_vbox.offset_left = -300.0
	center_vbox.offset_top = -520.0
	center_vbox.offset_right = 300.0
	center_vbox.offset_bottom = 520.0
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 24)
	add_child(center_vbox)

	# Başlık Paneli
	var title_panel: PanelContainer = PanelContainer.new()
	title_panel.custom_minimum_size = Vector2(600, 290)
	title_panel.add_theme_stylebox_override("panel", _create_stylebox(Color("#1E293B"), 28, Color("#334155"), 3))
	center_vbox.add_child(title_panel)

	var title_vbox: VBoxContainer = VBoxContainer.new()
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.add_theme_constant_override("separation", 10)
	title_panel.add_child(title_vbox)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = "ARROW PUZZLE"
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 18)
	badge_lbl.add_theme_color_override("font_color", Color("#38BDF8"))
	title_vbox.add_child(badge_lbl)

	var main_title: Label = Label.new()
	main_title.text = "CHROMA FLOW"
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_title.add_theme_font_size_override("font_size", 46)
	main_title.add_theme_color_override("font_color", Color("#F8FAFC"))
	title_vbox.add_child(main_title)

	var sub_title: Label = Label.new()
	sub_title.text = "ARROW SORT"
	sub_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_title.add_theme_font_size_override("font_size", 24)
	sub_title.add_theme_color_override("font_color", Color("#F59E0B"))
	title_vbox.add_child(sub_title)

	# Dekoratif ok blokları için yuva
	var deco_holder: Control = Control.new()
	deco_holder.name = "DecoHolder"
	deco_holder.custom_minimum_size = Vector2(460, 100)
	deco_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_vbox.add_child(deco_holder)

	# İlerleme Özeti Kartı
	var stats_panel: PanelContainer = PanelContainer.new()
	stats_panel.custom_minimum_size = Vector2(600, 84)
	stats_panel.add_theme_stylebox_override("panel", _create_stylebox(Color("#0F172A"), 20, Color("#1E293B"), 2))
	center_vbox.add_child(stats_panel)

	progress_label = Label.new()
	progress_label.text = "Açılan Seviye: 1 / 10  |  Tamamlanan: 0"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 20)
	progress_label.add_theme_color_override("font_color", Color("#CBD5E1"))
	stats_panel.add_child(progress_label)

	# Menü Butonları
	var btn_vbox: VBoxContainer = VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", 18)
	center_vbox.add_child(btn_vbox)

	play_button = _create_button("OYNA (SEVİYE 1)", Color("#10B981"), Color("#34D399"), 26)
	play_button.custom_minimum_size = Vector2(520, 88)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(func() -> void: play_requested.emit())
	btn_vbox.add_child(play_button)

	var levels_btn: Button = _create_button("SEVİYE SEÇİMİ", Color("#2563EB"), Color("#3B82F6"), 22)
	levels_btn.custom_minimum_size = Vector2(520, 76)
	levels_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	levels_btn.pressed.connect(func() -> void: level_select_backdrop.visible = true)
	btn_vbox.add_child(levels_btn)

	sound_button = _create_button("SES: AÇIK", Color("#0F766E"), Color("#14B8A6"), 22)
	sound_button.custom_minimum_size = Vector2(520, 76)
	sound_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sound_button.pressed.connect(func() -> void: sound_toggled.emit())
	btn_vbox.add_child(sound_button)

	var reset_btn: Button = _create_button("İLERLEMEYİ SIFIRLA", Color("#475569"), Color("#64748B"), 19)
	reset_btn.custom_minimum_size = Vector2(520, 66)
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_btn.pressed.connect(func() -> void: reset_confirm_backdrop.visible = true)
	btn_vbox.add_child(reset_btn)

	_build_level_select_modal()
	_build_reset_confirm_modal()


## Logo altında canlı duran 5 adet dekoratif ok bloğu oluşturur ve hafif dalga animasyonu verir.
func _spawn_decorative_blocks() -> void:
	var holder: Control = get_node_or_null("VBoxContainer/PanelContainer/VBoxContainer/DecoHolder")
	if holder == null:
		holder = find_child("DecoHolder", true, false) as Control
	if holder == null:
		return

	var colors: Array[String] = ["red", "yellow", "green", "blue", "purple"]
	var dirs: Array[String] = ["left", "up", "up", "up", "right"]

	for i: int in range(5):
		var blk: ArrowBlock = ARROW_BLOCK_SCENE.instantiate() as ArrowBlock
		holder.add_child(blk)
		blk.setup(Vector2i(i, 0), colors[i], dirs[i], Vector2(76, 76))
		blk.is_interactable = false
		blk.position = Vector2(float(i) * 92.0 + 10.0, 12.0)
		_deco_blocks.append(blk)

		var tween: Tween = create_tween().set_loops()
		var base_y: float = blk.position.y
		tween.tween_property(blk, "position:y", base_y - 8.0, 0.75).set_delay(float(i) * 0.12).set_trans(Tween.TRANS_SINE)
		tween.tween_property(blk, "position:y", base_y, 0.75).set_trans(Tween.TRANS_SINE)


func _build_level_select_modal() -> void:
	level_select_backdrop = ColorRect.new()
	level_select_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_select_backdrop.color = Color(0.03, 0.05, 0.09, 0.92)
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

	var close_btn: Button = _create_button("KAPAT", Color("#475569"), Color("#64748B"), 20)
	close_btn.custom_minimum_size = Vector2(240, 62)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func() -> void: level_select_backdrop.visible = false)
	vbox.add_child(close_btn)


func _build_reset_confirm_modal() -> void:
	reset_confirm_backdrop = ColorRect.new()
	reset_confirm_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reset_confirm_backdrop.color = Color(0.03, 0.05, 0.09, 0.90)
	reset_confirm_backdrop.visible = false
	reset_confirm_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(reset_confirm_backdrop)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -180.0
	panel.offset_right = 280.0
	panel.offset_bottom = 180.0
	panel.add_theme_stylebox_override("panel", _create_stylebox(Color("#1E293B"), 26, Color("#EF4444"), 3))
	reset_confirm_backdrop.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "İLERLEME SIFIRLANSIN MI?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#F87171"))
	vbox.add_child(title)

	var desc: Label = Label.new()
	desc.text = "Açılan tüm seviyeler ve en iyi hamle rekorlarınız sıfırlanacak."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(460, 0)
	desc.add_theme_font_size_override("font_size", 19)
	desc.add_theme_color_override("font_color", Color("#E2E8F0"))
	vbox.add_child(desc)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	vbox.add_child(hbox)

	var cancel_btn: Button = _create_button("VAZGEÇ", Color("#475569"), Color("#64748B"), 19)
	cancel_btn.custom_minimum_size = Vector2(210, 62)
	cancel_btn.pressed.connect(func() -> void: reset_confirm_backdrop.visible = false)
	hbox.add_child(cancel_btn)

	var confirm_btn: Button = _create_button("EVET, SIFIRLA", Color("#DC2626"), Color("#EF4444"), 19)
	confirm_btn.custom_minimum_size = Vector2(210, 62)
	confirm_btn.pressed.connect(func() -> void:
		reset_confirm_backdrop.visible = false
		reset_progress_requested.emit()
	)
	hbox.add_child(confirm_btn)


## Ana Menü üzerindeki buton metinlerini ve seviye seçim ızgarasını güncel kayıt verisiyle yeniler.
func refresh_menu_state(save_mgr: SaveManager, total_levels: int) -> void:
	var completed_count: int = save_mgr.get_completed_levels_count()
	progress_label.text = "Açılan Seviye: %d / %d   |   Tamamlanan: %d / %d" % [
		save_mgr.max_unlocked_level,
		total_levels,
		completed_count,
		total_levels
	]

	if save_mgr.last_played_level > 1 or completed_count > 0:
		play_button.text = "DEVAM ET (SEVİYE %d)" % save_mgr.last_played_level
	else:
		play_button.text = "OYNA (SEVİYE 1)"

	sound_button.text = "SES: AÇIK" if save_mgr.sound_enabled else "SES: KAPALI"
	var snd_col: Color = Color("#0F766E") if save_mgr.sound_enabled else Color("#475569")
	sound_button.add_theme_stylebox_override("normal", _create_stylebox(snd_col, 18, snd_col.lightened(0.18), 2))

	for child: Node in level_grid.get_children():
		child.queue_free()

	for lvl: int in range(1, total_levels + 1):
		var is_unlocked: bool = lvl <= save_mgr.max_unlocked_level
		var is_done: bool = save_mgr.is_level_completed(lvl)
		var best_moves: int = save_mgr.get_best_moves(lvl)

		var btn_text: String = "SEVİYE %d" % lvl
		if is_done:
			btn_text += "\n(En İyi: %d Hamle)" % best_moves
		elif is_unlocked:
			btn_text += "\n(AÇIK)"
		else:
			btn_text += "\n(KİLİTLİ)"

		var col: Color = Color("#0F766E") if is_done else (Color("#2563EB") if is_unlocked else Color("#334155"))
		var btn: Button = _create_button(btn_text, col, col.lightened(0.15), 17)
		btn.custom_minimum_size = Vector2(245, 78)
		btn.disabled = not is_unlocked

		var target_lvl: int = lvl
		btn.pressed.connect(func() -> void:
			level_select_backdrop.visible = false
			level_selected.emit(target_lvl)
		)
		level_grid.add_child(btn)


func _create_stylebox(bg: Color, radius: int, border: Color, border_w: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	return sb


func _create_button(text_str: String, normal_col: Color, hover_col: Color, font_sz: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text_str
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.35))

	btn.add_theme_stylebox_override("normal", _create_stylebox(normal_col, 18, normal_col.lightened(0.18), 2))
	btn.add_theme_stylebox_override("hover", _create_stylebox(hover_col, 18, hover_col.lightened(0.22), 2))
	btn.add_theme_stylebox_override("pressed", _create_stylebox(normal_col.darkened(0.15), 18, normal_col, 2))
	btn.add_theme_stylebox_override("disabled", _create_stylebox(Color("#1E293B"), 18, Color("#334155"), 2))
	return btn