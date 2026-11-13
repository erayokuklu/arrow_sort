extends Control
class_name GameManager
## Oyunun ana durum makinesini, blok transfer animasyonunu, Undo geçmişini,
## İpucu (Hint) / Karıştırma (Shuffle) jokerlerini ve Ana Menü iletişimini yönetir.

signal return_to_menu_requested

enum GameState {
	PLAYING,
	WON,
	LOST
}

const DEFAULT_HINTS_PER_LEVEL: int = 3
const DEFAULT_SHUFFLES_PER_LEVEL: int = 2

@onready var save_manager: SaveManager = $SaveManager
@onready var sound_manager: SoundManager = $SoundManager
@onready var level_manager: LevelManager = $LevelManager
@onready var board_manager: BoardManager = $BoardManager
@onready var waiting_area: WaitingArea = $WaitingArea
@onready var animation_layer: Control = $AnimationLayer
@onready var game_ui: GameUI = $GameUI

var current_level: int = 1
var current_state: GameState = GameState.PLAYING
var current_moves: int = 0
var hints_remaining: int = DEFAULT_HINTS_PER_LEVEL
var shuffles_remaining: int = DEFAULT_SHUFFLES_PER_LEVEL
var is_busy: bool = false

## Her geçerli hamleden veya karıştırmadan önceki tahta ve bekleme alanı durumunu tutan Undo yığını
var undo_stack: Array[Dictionary] = []


func _ready() -> void:
	board_manager.block_selected.connect(_on_board_block_selected)
	waiting_area.match_occurred.connect(_on_waiting_area_match_occurred)
	game_ui.restart_requested.connect(_on_restart_requested)
	game_ui.undo_requested.connect(_on_undo_requested)
	game_ui.hint_requested.connect(_on_hint_requested)
	game_ui.shuffle_requested.connect(_on_shuffle_requested)
	game_ui.next_level_requested.connect(_on_next_level_requested)
	game_ui.level_selected.connect(_on_level_selected)
	game_ui.sound_toggled.connect(toggle_sound_setting)
	game_ui.menu_requested.connect(func() -> void: return_to_menu_requested.emit())

	sound_manager.sound_enabled = save_manager.sound_enabled
	game_ui.update_sound_button(save_manager.sound_enabled)


## Kayıtlı son seviyeden oyunu başlatır.
func start_from_saved_progress() -> void:
	start_game(save_manager.last_played_level)


## Belirtilen seviyeyi yükler ve oyunu başlatır.
func start_game(level_number: int) -> void:
	var total_levels: int = level_manager.get_total_levels()
	current_level = clampi(level_number, 1, total_levels)
	current_state = GameState.PLAYING
	current_moves = 0
	hints_remaining = DEFAULT_HINTS_PER_LEVEL
	shuffles_remaining = DEFAULT_SHUFFLES_PER_LEVEL
	is_busy = false
	undo_stack.clear()

	save_manager.set_last_played_level(current_level)

	for child: Node in animation_layer.get_children():
		child.queue_free()

	var level_data: Dictionary = level_manager.load_level_data(current_level)
	board_manager.build_board(level_data)
	waiting_area.clear_waiting_area()

	var lvl_name: String = str(level_data.get("level_name", "Seviye %d" % current_level))
	game_ui.set_level_info(current_level, total_levels, lvl_name)
	game_ui.set_moves_info(current_moves, save_manager.get_best_moves(current_level))
	game_ui.set_status_message("Yolu açık olan bir ok bloğuna dokunun", Color("#CBD5E1"))
	game_ui.update_undo_count(0)
	_sync_booster_ui()
	game_ui.hide_overlay()
	game_ui.refresh_level_select_buttons(
		total_levels,
		save_manager.max_unlocked_level,
		current_level,
		save_manager
	)


func _sync_booster_ui() -> void:
	var has_blocks: bool = board_manager.get_remaining_block_count() > 0
	game_ui.update_booster_counts(hints_remaining, shuffles_remaining, has_blocks)


## Oyuncu tahtadaki bir ok bloğuna dokunduğunda tetiklenir.
func _on_board_block_selected(block: ArrowBlock) -> void:
	if current_state != GameState.PLAYING or is_busy:
		return

	if not waiting_area.has_empty_slot():
		sound_manager.play_sfx("blocked")
		game_ui.set_status_message("Bekleme alanı dolu!", Color("#F87171"))
		return

	var path_clear: bool = board_manager.is_exit_path_clear(block.grid_pos, block.direction)
	if not path_clear:
		sound_manager.play_sfx("blocked")
		block.play_blocked_feedback()
		game_ui.set_status_message("Yol kapalı! Önce önündeki bloğu çıkarın.", Color("#FBBF24"))
		return

	board_manager.clear_all_hints()
	_push_undo_snapshot()
	current_moves += 1
	game_ui.set_moves_info(current_moves, save_manager.get_best_moves(current_level))

	is_busy = true
	block.is_interactable = false
	board_manager.detach_block_from_grid(block)
	sound_manager.play_sfx("select")

	var target_slot_idx: int = waiting_area.get_first_empty_slot_index()
	await _animate_block_to_waiting_slot(block, target_slot_idx)

	waiting_area.place_block_in_slot(block, target_slot_idx)
	sound_manager.play_sfx("place")
	game_ui.set_status_message("Blok bekleme alanına yerleşti.", Color("#CBD5E1"))

	await waiting_area.check_and_resolve_matches()

	_sync_booster_ui()
	_evaluate_game_state()
	is_busy = false


## İpucu (Hint) jokeri: Bekleme alanındaki renklere göre en avantajlı açık bloğu parlatır.
func _on_hint_requested() -> void:
	if current_state != GameState.PLAYING or is_busy or hints_remaining <= 0:
		return

	var waiting_counts: Dictionary = waiting_area.get_waiting_color_counts()
	var best_block: ArrowBlock = board_manager.find_best_hint_block(waiting_counts)
	if best_block == null:
		sound_manager.play_sfx("blocked")
		game_ui.set_status_message("Şu an çıkabilecek uygun blok bulunamadı!", Color("#F87171"))
		return

	hints_remaining -= 1
	_sync_booster_ui()
	sound_manager.play_sfx("hint")
	board_manager.clear_all_hints()
	best_block.play_hint_highlight()
	game_ui.set_status_message(
		"İpucu: (%d, %d) konumundaki %s bloğu çıkarabilirsiniz." % [
			best_block.grid_pos.x + 1,
			best_block.grid_pos.y + 1,
			best_block.color_id.to_upper()
		],
		Color("#FBBF24")
	)


## Karıştırma (Shuffle) jokeri: Tahtadaki kalan blokların renk ve yönlerini kilitlenmesiz karıştırır.
func _on_shuffle_requested() -> void:
	if current_state != GameState.PLAYING or is_busy or shuffles_remaining <= 0:
		return
	if board_manager.get_remaining_block_count() <= 1:
		return

	is_busy = true
	board_manager.clear_all_hints()
	_push_undo_snapshot()

	shuffles_remaining -= 1
	_sync_booster_ui()
	sound_manager.play_sfx("shuffle")
	game_ui.set_status_message("Tahtadaki bloklar yeniden karıştırıldı!", Color("#C084FC"))

	board_manager.shuffle_board_blocks()
	await get_tree().create_timer(0.36).timeout
	is_busy = false


func _animate_block_to_waiting_slot(block: ArrowBlock, slot_idx: int) -> void:
	var start_global: Vector2 = block.global_position
	block.reparent(animation_layer)
	block.global_position = start_global

	var dir_vec: Vector2 = Vector2(block.get_direction_vector())
	var exit_pos: Vector2 = start_global + dir_vec * (board_manager.cell_size * 0.55)
	var target_global: Vector2 = waiting_area.get_slot_global_position(slot_idx)
	var target_size: Vector2 = Vector2(waiting_area.slot_size, waiting_area.slot_size)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(block, "global_position", exit_pos, 0.09)
	tween.tween_property(block, "global_position", target_global, 0.17).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(block, "size", target_size, 0.17)
	await tween.finished


func _push_undo_snapshot() -> void:
	var snapshot: Dictionary = {
		"board": board_manager.serialize_board_state(),
		"waiting": waiting_area.serialize_waiting_state(),
		"moves": current_moves
	}
	undo_stack.append(snapshot)
	game_ui.update_undo_count(undo_stack.size())


func _evaluate_game_state() -> void:
	var total_levels: int = level_manager.get_total_levels()
	var remaining_on_board: int = board_manager.get_remaining_block_count()
	if remaining_on_board == 0:
		current_state = GameState.WON
		sound_manager.play_sfx("win")
		save_manager.record_level_completed(current_level, current_moves, total_levels)
		var best_moves: int = save_manager.get_best_moves(current_level)
		game_ui.set_moves_info(current_moves, best_moves)
		game_ui.refresh_level_select_buttons(
			total_levels,
			save_manager.max_unlocked_level,
			current_level,
			save_manager
		)
		game_ui.set_status_message("Tebrikler! Seviye tamamlandı.", Color("#34D399"))
		game_ui.show_win_screen(current_level, total_levels, current_moves, best_moves)
		return

	if waiting_area.is_full():
		current_state = GameState.LOST
		sound_manager.play_sfx("lose")
		waiting_area.play_lose_shake()
		game_ui.set_status_message("Bekleme alanı doldu! Oyun bitti.", Color("#F87171"))
		game_ui.show_lose_screen(not undo_stack.is_empty())


func _on_waiting_area_match_occurred(color_id: String) -> void:
	sound_manager.play_sfx("match")
	game_ui.set_status_message("%s bloklar eşleşti!" % color_id.to_upper(), Color("#34D399"))


func _on_restart_requested() -> void:
	if is_busy:
		return
	sound_manager.play_sfx("button")
	start_game(current_level)


func _on_next_level_requested() -> void:
	if is_busy:
		return
	sound_manager.play_sfx("button")
	var next_lvl: int = mini(current_level + 1, level_manager.get_total_levels())
	start_game(next_lvl)


func _on_level_selected(level_number: int) -> void:
	if is_busy:
		return
	sound_manager.play_sfx("button")
	start_game(level_number)


func toggle_sound_setting() -> void:
	var new_state: bool = not save_manager.sound_enabled
	save_manager.set_sound_enabled(new_state)
	sound_manager.sound_enabled = new_state
	game_ui.update_sound_button(new_state)
	if new_state:
		sound_manager.play_sfx("button")


func _on_undo_requested() -> void:
	if is_busy or undo_stack.is_empty():
		return

	sound_manager.play_sfx("undo")
	var last_snapshot: Dictionary = undo_stack.pop_back()
	board_manager.restore_board_state(last_snapshot["board"])
	waiting_area.restore_waiting_state(last_snapshot["waiting"])
	current_moves = int(last_snapshot.get("moves", maxi(0, current_moves - 1)))

	current_state = GameState.PLAYING
	game_ui.hide_overlay()
	game_ui.set_moves_info(current_moves, save_manager.get_best_moves(current_level))
	game_ui.update_undo_count(undo_stack.size())
	_sync_booster_ui()
	game_ui.set_status_message("Son işlem geri alındı.", Color("#38BDF8"))